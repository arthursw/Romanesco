import datetime
import logging
import os
import os.path
import errno
import json
# from django.utils import json
from dajaxice.decorators import dajaxice_register
from django.core import serializers
from dajaxice.core import dajaxice_functions
from django.contrib.auth.models import User
from django.db.models import F
from models import Path, Box, Div, UserProfile, Tool, Site, AreaToUpdate, Area
import ast
from pprint import pprint
from django.contrib.auth import authenticate, login, logout
from paypal.standard.ipn.signals import payment_was_successful, payment_was_flagged, payment_was_refunded, payment_was_reversed
from math import *
import random
import re
from django.core.validators import URLValidator
from django.core.exceptions import ValidationError

from mongoengine.base import ValidationError
from mongoengine.queryset import Q
import time

from PIL import Image
import cStringIO
import StringIO
# from wand.image import Image

logger = logging.getLogger(__name__)

# pprint(vars(object))
# import pdb; pdb.set_trace()
# import pudb; pu.db

def makeBox(tlX, tlY, brX, brY):
	return { "type": "Polygon", "coordinates": [ [ [tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY] ] ] }

userID = 0
# defaultPathTools = ["Checkpoint", "EllipseShape", "FaceShape", "GeometricLines", "GridPath", "Meander", "PrecisePath", "RectangleShape", "ShapePath", "SpiralShape", "StarShape", "ThicknessPath"]
defaultPathTools = ["Precise path", "Thickness path", "Meander", "Grid path", "Geometric lines", "Shape path", "Rectangle", "Ellipse", "Star", "Spiral", "Face generator", "Checkpoint"]


@dajaxice_register
def quick_load(request, box, boxes, zoom):

	items = {}

	for b in boxes:
		try:
			area = Area.objects.get(x=b['x'], y=b['y'])
		except:
			continue

		for item in area.items:
			if not items.has_key(item.pk):
				items[item.pk] = item.to_json()

	# areas = Area.objects(x__gte=l, x__lt=r, y__gte=t, y__lt=b)

	l = box['left']
	t = box['top']
	r = box['right']
	b = box['bottom']

	# load rasters
	rasters = []

	step = 1

	if zoom > 0.2:
		step = 1
	elif zoom > 0.04:
		step = 5
	else:
		step = 25

	for x1 in range(l,r+step,step):
		for y1 in range(t,b+step,step):

			x5 = roundToLowerMultiple(x1, 5)
			y5 = roundToLowerMultiple(y1, 5)

			x25 = roundToLowerMultiple(x1, 25)
			y25 = roundToLowerMultiple(y1, 25)

			if zoom > 0.2:
				position = { 'x': x1, 'y': y1 }
				rasterPath = 'media/rasters/zoom100/' + str(x25) + ',' + str(y25) + '/' + str(x5) + ',' + str(y5) + '/'
			elif zoom > 0.04:
				position = { 'x': x5, 'y': y5 }
				rasterPath = 'media/rasters/zoom20/' + str(x25) + ',' + str(y25) + '/'
			else:
				position = { 'x': x25, 'y': y25 }
				rasterPath = 'media/rasters/zoom4/'

			rasterName = rasterPath + str(position['x']) + "," + str(position['y']) + ".png"
			
			if os.path.isfile(os.getcwd() + '/' + rasterName):
				rasters.append( { 'url': rasterName, 'position': position } )

	global userID
	user = request.user.username
	if not user:
		user = userID
	userID += 1

	return json.dumps( { 'items': items.values(), 'rasters': rasters, 'zoom': zoom, 'user': user } )

@dajaxice_register
def load(request, areasToLoad, zoom):

	paths = []
	divs = []
	boxes = []
	areas = []
	rasters = []
	rasterPositions = []

	ppks = []
	dpks = []
	bpks = []
	apks = []

	start = time.time()

	for area in areasToLoad:
				
		tlX = area['pos']['x']
		tlY = area['pos']['y']

		planetX = area['planet']['x']
		planetY = area['planet']['y']

		geometry = makeBox(tlX, tlY, tlX+1, tlY+1)
		# geometry = makeBox(tlX, tlY, tlX+0.5, tlY+0.5)

		# load items
		p = Path.objects(planetX=planetX, planetY=planetY, points__geo_intersects=geometry, pk__nin=ppks)
		d = Div.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, pk__nin=dpks)
		b = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, pk__nin=bpks)
		a = AreaToUpdate.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, pk__nin=apks)
		
		if len(p)>0:
			paths.append(p.to_json())
			ppks += p.scalar("id")
		if len(b)>0:
			boxes.append(b.to_json())
			bpks += b.scalar("id")
		if len(d)>0:
			divs.append(d.to_json())
			dpks += d.scalar("id")
		if len(a)>0:
			areas.append(a.to_json())
			apks += a.scalar("id")

		# load rasters
		x1 = int(area['x'])
		y1 = int(area['y'])

		x5 = roundToLowerMultiple(x1, 5)
		y5 = roundToLowerMultiple(y1, 5)

		x25 = roundToLowerMultiple(x1, 25)
		y25 = roundToLowerMultiple(y1, 25)

		rasterPath = None
		rasterName = None

		if zoom > 0.2:
			position = { 'x': x1, 'y': y1 }
			if position not in rasterPositions:
				rasterPath = 'media/rasters/zoom100/' + str(x25) + ',' + str(y25) + '/' + str(x5) + ',' + str(y5) + '/'
		elif zoom > 0.04:
			position = { 'x': x5, 'y': y5 }
			if position not in rasterPositions:
				rasterPath = 'media/rasters/zoom20/' + str(x25) + ',' + str(y25) + '/'
		else:
			position = { 'x': x25, 'y': y25 }
			if position not in rasterPositions:
				rasterPath = 'media/rasters/zoom4/'
		
		print 'area: ' + str(area)
		print 'position: ' + str(position)
		print 'raster path: ' + str(rasterPath)
		print rasterPositions

		if rasterPath != None:
			rasterName = rasterPath + str(position['x']) + "," + str(position['y']) + ".png"
			print 'raster name: ' + rasterName
			if os.path.isfile(os.getcwd() + '/' + rasterName):
				rasterPositions.append(position)
				rasters.append( { 'url': rasterName, 'position': position } )

	end = time.time()
	print "Time elapsed: " + str(end - start)

	global userID
	user = request.user.username
	if not user:
		user = userID
	userID += 1
	return json.dumps( { 'paths': paths, 'boxes': boxes, 'divs': divs, 'user': user, 'rasters': rasters, 'areasToUpdate': areas, 'zoom': zoom } )

# add areas with item
def addAreas(areas, item):

	if not areas:
		print "ERROR: no areas to update."
		return
	
	for x, column in areas.iteritems():
		for y in column:
			# area = Area.objects(x=a['x'], y=a['y']).modify(upsert=True, push__items=item)
			# Area.objects(x=a['x'], y=a['y']).update_one(push__paths=p, upsert=True) # good but how to get id?
			try:
				area = Area.objects.get(x=x, y=y)
			except Area.DoesNotExist:		
				area = Area(x=x, y=y)
			area.items.append(item)
			area.save()

			item.areas.append(area)
			item.save()

	return

# update areas with item
# areas: the list of areas which now intersect with item
def updateAreas(areas, item):

	if areas:
		print "ERROR: no areas to update."
		return

	# remove areas which do not intersect with item anymore
	for area in item.areas:
		if areas.has_key(area.x) and areas[area.x].has_key(area.y): 	# if the area still intersects: do not remove it
			del areas[area.x][area.y]
		else: 															# otherwise: remove it
			area.items.remove(item)
			item.areas.remove(area)
			if len(area.items)==0:
				area.delete()
			else:
				area.save()
	
	# for all areas which now intersect with item: create or update them, and 
	for x, column in areas.iteritems():
		for y in column:
			# area = Area.objects(x=a['x'], y=a['y']).modify(upsert=True, push__items=item)
			try:
				area = Area.objects.get(x=x, y=y)
			except Area.DoesNotExist:		
				area = Area(x=x, y=y)
			area.items.append(item)
			area.save()
			item.areas.append(area)

	item.save()
	return

# update areas with item
def deleteAreas(item):
	for area in item.areas:
		area.items.remove(item)
	if len(area.items)==0:
		area.delete()
	else:
		area.save()
	return

@dajaxice_register
def savePath(request, points, pID, planet, object_type, areas, data=None):
# def savePath(request, points, pID, planet, object_type, data=None, rasterData=None, rasterPosition=None, areasNotRasterized=None):

	planetX = planet['x']
	planetY = planet['y']

	lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects={"type": "LineString", "coordinates": points }, owner__ne=request.user.username )
	if lockedAreas.count()>0:
		return json.dumps( {'state': 'error', 'message': 'Your drawing intersects with a locked area'} )

	try:
		tool = Tool.objects.get(name=object_type, accepted=True)
	except Tool.DoesNotExist:
		global defaultPathTools
		if not object_type in defaultPathTools:
			return json.dumps( { 'state': 'warning', 'message': 'The path "' + object_type + '" does not exist.' } )

	p = Path(planetX=planetX, planetY=planetY, points=points, owner=request.user.username, object_type=object_type, data=data )
	p.save()

	addAreas(areas, p)

	# rasterResult = updateRastersJson(rasterData, rasterPosition, areasNotRasterized)

	# return json.dumps( {'state': rasterResult['state'], 'pID': pID, 'pk': str(p.pk), 'message': rasterResult['message'] if 'message' in rasterResult else '' } )
	return json.dumps( {'state': 'success', 'pID': pID, 'pk': str(p.pk) } )

@dajaxice_register
def updatePath(request, pk, points=None, planet=None, areas=None, data=None):

	try:
		p = Path.objects.get(pk=pk)
	except Path.DoesNotExist:
		return json.dumps({'state': 'error', 'message': 'Update impossible: element does not exist for this user'})

	if p.locked and request.user.username != p.owner:
		return json.dumps({'state': 'error', 'message': 'Not owner of path'})

	if points or planet:
		planetX = planet['x']
		planetY = planet['y']

		lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects={"type": "LineString", "coordinates": points }, owner__ne=request.user.username )
		if lockedAreas.count()>0:
			return json.dumps( {'state': 'error', 'message': 'Your drawing intersects with a locked area'} )

	if points:
		p.points = points
	if planet:
		p.planetX = planet['x']
		p.planetY = planet['y']
	if data:
		p.data = data

	updateAreas(areas, p)

	p.save()

	return json.dumps( {'state': 'success'} )

@dajaxice_register
def deletePath(request, pk):

	try:
		p = Path.objects.get(pk=pk)
	except Path.DoesNotExist:
		return json.dumps({'state': 'error', 'message': 'Delete impossible: element does not exist for this user'})

	if p.locked and request.user.username != p.owner:
		return json.dumps({'state': 'error', 'message': 'Not owner of path'})

	deleteAreas(p)
	p.delete()
	
	return json.dumps( { 'state': 'success', 'pk': pk } )

@dajaxice_register
def saveBox(request, box, object_type, message, areas, name="", url="", clonePk=None, website=False, restrictedArea=False, disableToolbar=False):
	if not request.user.is_authenticated():
		return json.dumps({'state': 'not_logged_in'})

	points = box['points']
	planetX = box['planet']['x']
	planetY = box['planet']['y']

	# check if the box intersects with another one
	geometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])
	lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, owner__ne=request.user.username )
	if lockedAreas.count()>0:
		return json.dumps( {'state': 'error', 'message': 'This area intersects with another locked area'} )

	if len(url)==0:
		url = None

	loadEntireArea = object_type == 'video-game'

	# todo: warning: website is not defined in Box model...
	try:
		data = json.dumps( { 'loadEntireArea': loadEntireArea } )
		b = Box(planetX=planetX, planetY=planetY, box=[points], owner=request.user.username, object_type=object_type, url=url, message=message, name=name, website=website, data=data)
		b.save()
	except ValidationError:
		return json.dumps({'state': 'error', 'message': 'invalid_url'})

	addAreas(areas, b)

	if website:
		site = Site(box=b, restrictedArea=restrictedArea, disableToolbar=disableToolbar, loadEntireArea=loadEntireArea, name=name)
		site.save()

	# pathsToLock = Path.objects(planetX=planetX, planetY=planetY, box__geo_within=geometry)
	# for path in pathsToLock:
	# 	path.locked = True
	# 	path.save()

	Path.objects(planetX=planetX, planetY=planetY, points__geo_within=geometry).update(set__locked=True, set__owner=request.user.username)
	Div.objects(planetX=planetX, planetY=planetY, box__geo_within=geometry).update(set__locked=True, set__owner=request.user.username)

	return json.dumps( {'state': 'success', 'object_type':object_type, 'message': message, 'name': name, 'url': url, 'owner': request.user.username, 'pk':str(b.pk), 'box':box, 'clonePk': clonePk, 'website': website } )

@dajaxice_register
def updateBox(request, object_type, pk, box=None, areas=None, message=None, name=None, url=None, data=None):
	if not request.user.is_authenticated():
		return json.dumps({'state': 'not_logged_in'})
	
	if box:
		points = box['points']
		planetX = box['planet']['x']
		planetY = box['planet']['y']

		geometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])

		# check if new box intersects with another one
		lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, owner__ne=request.user.username )
		if lockedAreas.count()>0:
			return json.dumps( {'state': 'error', 'message': 'This area intersects with a locked area'} )

	try:
		b = Box.objects.get(pk=pk, owner=request.user.username)
	except Box.DoesNotExist:
		return json.dumps({'state': 'error', 'message': 'Element does not exist for this user'})

	if box:
		# retrieve the old paths and divs to unlock them if they are not in the new box:
		points = b.box['coordinates'][0]

		planetX = b.planetX
		planetY = b.planetY
		
		geometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])
		oldPaths = Path.objects(planetX=planetX, planetY=planetY, points__geo_within=geometry)
		oldDivs = Div.objects(planetX=planetX, planetY=planetY, box__geo_within=geometry)

	# update the box:
	if box:
		b.box = [box['points']]
		b.planetX = box['planet']['x']
		b.planetY = box['planet']['y']
	if name:
		b.name = name
	if url and len(url)>0:
		b.url = url
	if message:
		b.message = message
	if data:
		b.data = data

	updateAreas(areas, b)

	try:
		b.save()
	except ValidationError:
		return json.dumps({'state': 'error', 'message': 'invalid_url'})

	if box:
		# retrieve the new paths and divs to lock them if they were not in the old box:
		points = box['points']
		planetX = box['planet']['x']
		planetY = box['planet']['y']
		geometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])

		newPaths = Path.objects(planetX=b.planetX, planetY=b.planetY, points__geo_within=geometry)
		newDivs = Div.objects(planetX=b.planetX, planetY=b.planetY, box__geo_within=geometry)
		
		# update old and new paths and divs
		newPaths.update(set__locked=True, set__owner=request.user.username)
		newDivs.update(set__locked=True, set__owner=request.user.username)

		oldPaths.filter(pk__nin=newPaths.scalar("id")).update(set__locked=False, set__owner='public')
		oldDivs.filter(pk__nin=newDivs.scalar("id")).update(set__locked=False, set__owner='public')

		# for oldPath in oldPaths:
		# 	if oldPath not in newPaths:
		# 		oldPath.locked = False
		# 		oldPath.save()

		# for oldDiv in oldDivs:
		# 	if oldDiv not in newDivs:
		# 		oldDiv.locked = False
		# 		oldDiv.save()

	return json.dumps( {'state': 'success', 'object_type':object_type } )

@dajaxice_register
def deleteBox(request, pk):
	if not request.user.is_authenticated():
		return json.dumps({'state': 'not_logged_in'})

	try:
		b = Box.objects.get(pk=pk, owner=request.user.username)
	except Box.DoesNotExist:
		return json.dumps({'state': 'error', 'message': 'Element does not exist for this user'})

	points = b.box['coordinates'][0]
	planetX = b.planetX
	planetY = b.planetY
	oldGeometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])

	Path.objects(planetX=planetX, planetY=planetY, points__geo_within=oldGeometry).update(set__locked=False)
	Div.objects(planetX=planetX, planetY=planetY, box__geo_within=oldGeometry).update(set__locked=False)

	if request.user.username != b.owner:
		return json.dumps({'state': 'error', 'message': 'Not owner of div'})

	deleteAreas(b)
	b.delete()
	
	return json.dumps( { 'state': 'success', 'pk': pk } )

@dajaxice_register
def saveDiv(request, box, object_type, areas, message=None, url=None, data=None, clonePk=None):

	points = box['points']
	planetX = box['planet']['x']
	planetY = box['planet']['y']

	lockedAreas = Box.objects( planetX=planetX, planetY=planetY, box__geo_intersects=makeBox(points[0][0], points[0][1], points[2][0], points[2][1]) ) # , owner__ne=request.user.username )
	locked = False
	for area in lockedAreas:
		if area.owner == request.user.username:
			locked = True
		else:
			return json.dumps( {'state': 'error', 'message': 'Your div intersects with a locked area'} )

	# if lockedAreas.count()>0:
	# 	return json.dumps( {'state': 'error', 'message': 'Your div intersects with a locked area'} )

	d = Div(planetX=planetX, planetY=planetY, box=[points], owner=request.user.username, object_type=object_type, message=message, url=url, data=data, locked=locked)
	d.save()

	addAreas(areas, d)

	return json.dumps( {'state': 'success', 'object_type':object_type, 'message': message, 'url': url, 'owner': request.user.username, 'pk':str(d.pk), 'box': box, 'data': data, 'clonePk': clonePk } )

@dajaxice_register
def updateDiv(request, object_type, pk, box=None, areas=None, message=None, url=None, data=None):

	try:
		d = Div.objects.get(pk=pk)
	except Div.DoesNotExist:
		return json.dumps({'state': 'error', 'message': 'Element does not exist'})

	if d.locked and request.user.username != d.owner:
		return json.dumps({'state': 'error', 'message': 'Not owner of div'})

	if box:
		points = box['points']
		planetX = box['planet']['x']
		planetY = box['planet']['y']

		lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=makeBox(points[0][0], points[0][1], points[2][0], points[2][1]) ) # , owner__ne=request.user.username )
		d.locked = False
		for area in lockedAreas:
			if area.owner == request.user.username:
				d.locked = True
			else:
				return json.dumps( {'state': 'error', 'message': 'Your div intersects with a locked area'} )

	if url:
		#	No need to update URL?
		# 	valid, errorMessage = validateURL(url)
		# 	if not valid:
		# 		return errorMessage
		d.url = url
	if box:
		d.box = [box['points']]
		d.planetX = box['planet']['x']
		d.planetY = box['planet']['y']
	if message:
		d.message = message
	if data:
		d.data = data
	
	updateAreas(areas, d)

	d.save()

	return json.dumps( {'state': 'success' } )

@dajaxice_register
def deleteDiv(request, pk):

	try:
		d = Div.objects.get(pk=pk)
	except Div.DoesNotExist:
		return json.dumps({'state': 'error', 'message': 'Element does not exist for this user.'})

	if d.locked and request.user.username != d.owner:
		return json.dumps({'state': 'error', 'message': 'You are not the owner of this div.'})

	deleteAreas(d)
	d.delete()
	
	return json.dumps( { 'state': 'success', 'pk': pk } )

# --- rasters --- #

@dajaxice_register
def updateRasters(request, data=None, position=None, areasNotRasterized=None, areaToDeletePk=None):
	result = updateRastersJson(data, position, areasNotRasterized, areaToDeletePk);
	return json.dumps(result)
	
def roundToLowerMultiple(x, m):
	return int(floor(x/float(m))*m)

# warning: difference between ceil(x/m)*m and floor(x/m)*(m+1)
def roundToGreaterMultiple(x, m):
	return int(ceil(x/float(m))*m)

# @dajaxice_register
def updateRastersJson(data=None, position=None, areasNotRasterized=None, areaToDeletePk=None):

	if areaToDeletePk:
		try:
			areaToUpdate = AreaToUpdate.objects.get(pk=areaToDeletePk)
		except AreaToUpdate.DoesNotExist:
			return json.dumps({'state': 'log', 'message': 'Delete impossible: area does not exist'})

		areaToUpdate.delete()

	areasDeleted = []
	areasToUpdate = []

	if areasNotRasterized:
		for area in areasNotRasterized:

			points = area['points']
			planetX = area['planet']['x']
			planetY = area['planet']['y']

			# merge all overlapping areas into one (and delete them)
			overlappingAreas = AreaToUpdate.objects(planetX=planetX, planetY=planetY, box__geo_intersects=[points])
			left = xMin = points[0][0]
			right = xMax = points[2][0]
			top = yMin = points[0][1]
			bottom = yMax = points[2][1]
			for overlappingArea in overlappingAreas:
				
				c = overlappingArea.box['coordinates'][0]
				cleft = c[0][0]
				ctop = c[0][1]
				cright = c[2][0]
				cbottom = c[2][1]
				
				# if the areas just share an edge: continue
				uleft = max(left, cleft)
				utop = max(top, ctop)
				uright = min(right, cright)
				ubottom = min(bottom, cbottom)
				
				if (uright-uleft) * (ubottom-utop) <= 0.001:
					continue

				if not xMin or cleft < xMin:
					xMin = cleft
				if not xMax or cright > xMax:
					xMax = cright
				if not yMin or ctop < yMin:
					yMin = ctop
				if not yMax or cbottom > yMax:
					yMax = cbottom

				areasDeleted.append(str(overlappingArea.pk))
				overlappingArea.delete()

			areaToUpdate = AreaToUpdate(planetX=planetX, planetY=planetY, box=[[ [xMin, yMin], [xMax, yMin], [xMax, yMax], [xMin, yMax], [xMin, yMin] ]])
			areaToUpdate.save()
			
			areasToUpdate.append( areaToUpdate.to_json() )

	if (not data) or (data == "data:,"):
		return { 'state': 'success', 'areasToUpdate': areasToUpdate, 'areasDeleted': areasDeleted }

	imageData = re.search(r'base64,(.*)', data).group(1)

	try:
		image = Image.open(StringIO.StringIO(imageData.decode('base64')))				# Pillow version
	except IOError:
		return { 'state': 'error', 'message': 'impossible to read image.'}

	# with Image(file=cStringIO.StringIO(imageData.decode('base64'))) as image: 		# Wand version

	# # find top, left, bottom and right positions of the area in the quantized space

	start = time.time()

	x = int(position['x'])
	y = int(position['y'])
	width = int(image.size[0])
	height = int(image.size[1])

	l = roundToLowerMultiple(x, 1000)
	t = roundToLowerMultiple(y, 1000)
	r = roundToLowerMultiple(x+width, 1000)+1000
	b = roundToLowerMultiple(y+height, 1000)+1000

	imageOnGrid25x = roundToLowerMultiple(x, 25)
	imageOnGrid25y = roundToLowerMultiple(y, 25)
	imageOnGrid25width = roundToGreaterMultiple(x+width, 25)-imageOnGrid25x
	imageOnGrid25height = roundToGreaterMultiple(y+height, 25)-imageOnGrid25y

	# debug

	# image.save('media/rasters/image.png')

	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print 'original rect'
	# print x
	# print y
	# print width
	# print height
	# print 'rounded rect'
	# print l
	# print t
	# print r
	# print b

	# print 'image size:'
	# print image.size[0]
	# print image.size[1]

	# print 'big image:'
	# print imageOnGrid25x
	# print imageOnGrid25y
	# print imageOnGrid25width
	# print imageOnGrid25height

	# try:
	imageOnGrid25 = Image.new("RGBA", (1000, 1000))

	for xi in range(l,r,1000):
		for yi in range(t,b,1000):

			x1 = int(xi/1000)
			y1 = int(yi/1000)

			x5 = roundToLowerMultiple(x1, 5)
			y5 = roundToLowerMultiple(y1, 5)

			x25 = roundToLowerMultiple(x1, 25)
			y25 = roundToLowerMultiple(y1, 25)

			rasterPath = 'media/rasters/zoom100/' + str(x25) + ',' + str(y25) + '/' + str(x5) + ',' + str(y5) + '/'

			try:
				os.makedirs(rasterPath)
			except OSError as exception:
				if exception.errno != errno.EEXIST:
					raise

			rasterName = rasterPath + str(x1) + "," + str(y1) + ".png"

			try:
				# raster = Image(filename=rasterName)  		# Wand version
				raster = Image.open(rasterName)				# Pillow version
			except IOError:
				# raster = Image(width=1000, height=1000) 	# Wand version
				raster = Image.new("RGBA", (1000, 1000)) 	# Pillow version
				
			left = max(xi,x)
			right = min(xi+1000,x+width)
			top = max(yi,y)
			bottom = min(yi+1000,y+height)

			# print '-----'
			# print '-----'
			# print 'raster pos:'
			# print xi
			# print yi
			
			# print 'rectangle cutted:'
			# print left
			# print top
			# print right
			# print bottom

			# print 'width, height:'
			# print right-left
			# print bottom-top

			# print 'sub image rect:'
			# print left-x
			# print top-y
			# print right-x
			# print bottom-y
			
			# import pdb; pdb.set_trace()
			subImage = image.crop((left-x, top-y, right-x, bottom-y))

			# subImage = image.clone().crop(left=subImageLeft,top=subImageTop,width=subImageWidth,height=subImageHeight) # unefficient: clone the whole image instead of the sub image

			# print 'posInRaster:'
			# print left-xi
			# print top-yi
			
			# print 'sub image size:'
			# print subImage.size[0]
			# print subImage.size[1]

			# import pdb; pdb.set_trace()

			# raster.composite(image=subImage, left=posInRasterX, top=posInRasterY) 	# problem: we want to totally replace current raster with new one
			# raster100.composite_channel(channel='all_channels', image=subImage, operator='replace', left=posInRasterX, top=posInRasterY) 		# Wand version
			raster.paste(subImage, (left-xi, top-yi))
			raster.save(rasterName)

			left = max(xi,imageOnGrid25x)
			right = min(xi+1000,imageOnGrid25x+imageOnGrid25width)
			top = max(yi,imageOnGrid25y)
			bottom = min(yi+1000,imageOnGrid25y+imageOnGrid25height)

			# subImage.save('media/rasters/subimage_' + str(x1) + ',' + str(y1) + '.png')
			# print 'sub imageOnGrid25 in global coordinates:'
			# print left
			# print top
			# print right
			# print bottom
			# print 'in raster100 coordinates:'
			# print left-xi
			# print top-yi
			# print 'in imageOnGrid25 coordinates:'
			# print left-imageOnGrid25x
			# print top-imageOnGrid25y

			subRaster = raster.crop((left-xi, top-yi, right-xi, bottom-yi))
			imageOnGrid25.paste(subRaster, (left-imageOnGrid25x, top-imageOnGrid25y))
	
	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print 'raster20:'

	l = roundToLowerMultiple(x, 5000)
	t = roundToLowerMultiple(y, 5000)
	r = roundToLowerMultiple(x+width, 5000)+5000
	b = roundToLowerMultiple(y+height, 5000)+5000

	for xi in range(l,r,5000):
		for yi in range(t,b,5000):

			x1 = int(xi/1000)
			y1 = int(yi/1000)

			x5 = roundToLowerMultiple(x1, 5)
			y5 = roundToLowerMultiple(y1, 5)

			x25 = roundToLowerMultiple(x1, 25)
			y25 = roundToLowerMultiple(y1, 25)

			rasterPath = 'media/rasters/zoom20/' + str(x25) + ',' + str(y25) + '/'

			try:
				os.makedirs(rasterPath)
			except OSError as exception:
				if exception.errno != errno.EEXIST:
					raise

			rasterName = rasterPath + str(x5) + "," + str(y5) + ".png"
	
			try:
				raster = Image.open(rasterName)
			except IOError:
				raster = Image.new("RGBA", (1000, 1000))
			
			left = max(xi,imageOnGrid25x)
			right = min(xi+5000,imageOnGrid25x+imageOnGrid25width)
			top = max(yi,imageOnGrid25y)
			bottom = min(yi+5000,imageOnGrid25y+imageOnGrid25height)

			# print '-----'
			# print '-----'
			# print 'raster pos:'
			# print xi
			# print yi
			# print 'sub imageOnGrid25 in global coordinates:'
			# print left
			# print top
			# print right
			# print bottom
			# print 'in raster20 coordinates:'
			# print (left-xi)/5
			# print (top-yi)/5
			# print 'in imageOnGrid25 coordinates:'
			# print left-imageOnGrid25x
			# print top-imageOnGrid25y

			subImage = imageOnGrid25.crop((left-imageOnGrid25x, top-imageOnGrid25y, right-imageOnGrid25x, bottom-imageOnGrid25y))
			subImageSmall = subImage.resize((subImage.size[0]/5, subImage.size[1]/5), Image.LANCZOS)
			raster.paste(subImageSmall, ((left-xi)/5, (top-yi)/5))
			raster.save(rasterName)
	
	# print '-----'
	# print '-----'
	# print '-----'
	# print '-----'
	# print 'raster4:'

	l = roundToLowerMultiple(x, 25000)
	t = roundToLowerMultiple(y, 25000)
	r = roundToLowerMultiple(x+width, 25000)+25000
	b = roundToLowerMultiple(y+height, 25000)+25000

	for xi in range(l,r,25000):
		for yi in range(t,b,25000):

			x1 = int(xi/1000)
			y1 = int(yi/1000)

			x25 = roundToLowerMultiple(x1, 25)
			y25 = roundToLowerMultiple(y1, 25)

			rasterPath = 'media/rasters/zoom4/'

			try:
				os.makedirs(rasterPath)
			except OSError as exception:
				if exception.errno != errno.EEXIST:
					raise

			rasterName = rasterPath + str(x25) + "," + str(y25) + ".png"

			try:
				raster = Image.open(rasterName)
			except IOError:
				raster = Image.new("RGBA", (1000, 1000))
				
			left = max(xi,imageOnGrid25x)
			right = min(xi+25000,imageOnGrid25x+imageOnGrid25width)
			top = max(yi,imageOnGrid25y)
			bottom = min(yi+25000,imageOnGrid25y+imageOnGrid25height)

			# print '-----'
			# print '-----'
			# print 'raster pos:'
			# print xi
			# print yi
			# print 'sub imageOnGrid25 in global coordinates:'
			# print left
			# print top
			# print right
			# print bottom
			# print 'in raster4 coordinates:'
			# print (left-xi)/25
			# print (top-yi)/25
			# print 'in imageOnGrid25 coordinates:'
			# print left-imageOnGrid25x
			# print top-imageOnGrid25y

			subImage = imageOnGrid25.crop((left-imageOnGrid25x, top-imageOnGrid25y, right-imageOnGrid25x, bottom-imageOnGrid25y))
			subImageSmall = subImage.resize((subImage.size[0]/25, subImage.size[1]/25), Image.LANCZOS)
			raster.paste(subImageSmall, ((left-xi)/25, (top-yi)/25))
			raster.save(rasterName)

	# except:
	# 	import pdb; pdb.set_trace()
	# 	return { 'state': 'error', 'message': 'Failed to open, create or save an image.' }

	# another solution, slower since open and close many images

	# for xi in range(l,r,1000):
	# 	for yi in range(t,b,1000):

	# 		xm = int(xi/1000)
	# 		ym = int(yi/1000)

	# 		x5 = roundToLowerMultiple(xm, 5)
	# 		y5 = roundToLowerMultiple(ym, 5)

	# 		x25 = roundToLowerMultiple(xm, 25)
	# 		y25 = roundToLowerMultiple(ym, 25)

	# 		rasterPath100 = 'media/rasters/zoom100/' + str(x25) + ',' + str(y25) + '/' + str(x5) + ',' + str(y5) + '/'
	# 		rasterPath20 = 'media/rasters/zoom20/' + str(x25) + ',' + str(y25) + '/'
	# 		rasterPath4 = 'media/rasters/zoom4/'

	# 		try:
	# 			os.makedirs(rasterPath100)
	# 		except OSError as exception:
	# 			if exception.errno != errno.EEXIST:
	# 				raise

	# 		try:
	# 			os.makedirs(rasterPath20)
	# 		except OSError as exception:
	# 			if exception.errno != errno.EEXIST:
	# 				raise

	# 		try:
	# 			os.makedirs(rasterPath4)
	# 		except OSError as exception:
	# 			if exception.errno != errno.EEXIST:
	# 				raise

	# 		rasterName100 = rasterPath100 + str(xm) + "," + str(ym) + ".png"
	# 		rasterName20 = rasterPath20 + str(x5) + "," + str(y5) + ".png"
	# 		rasterName4 = rasterPath4 + str(x25) + "," + str(y25) + ".png"

	# 		try:
	# 			# raster100 = Image(filename=rasterName100)  		# Wand version
	# 			raster100 = Image.open(rasterName100)				# Pillow version
	# 		except IOError:
	# 			try:
	# 				# raster100 = Image(width=1000, height=1000) 	# Wand version
	# 				raster100 = Image.new("RGBA", (1000, 1000)) 	# Pillow version
	# 			except:
	# 				return { 'state': 'error', 'message': 'Failed to create the image.' }
			
	# 		try:
	# 			raster20 = Image.open(rasterName20)
	# 		except IOError:
	# 			try:
	# 				raster20 = Image.new("RGBA", (1000, 1000))
	# 			except:
	# 				return { 'state': 'error', 'message': 'Failed to create the image.' }
			
	# 		try:
	# 			raster4 = Image.open(rasterName4)
	# 		except IOError:
	# 			try:
	# 				raster4 = Image.new("RGBA", (1000, 1000))
	# 			except:
	# 				return { 'state': 'error', 'message': 'Failed to create the image.' }

	# 		left = max(xi,x)
	# 		right = min(xi+1000,x+width)
	# 		top = max(yi,y)
	# 		bottom = min(yi+1000,y+height)

	# 		print '-----'
	# 		print '-----'
	# 		print '-----'
	# 		print '-----'
	# 		print '-----'
	# 		print '-----'
	# 		print 'raster pos:'
	# 		print xi
	# 		print yi
			
	# 		print 'rectangle:'
	# 		print x
	# 		print y
	# 		print width
	# 		print height

	# 		print 'rectangle cutted:'
	# 		print left
	# 		print top
	# 		print right
	# 		print bottom
	# 		print 'width, height:'
	# 		print right-left
	# 		print bottom-top

	# 		subImageLeft = left-x
	# 		subImageTop = top-y
	# 		subImageRight = right-x
	# 		subImageBottom = bottom-y
	# 		subImageWidth = subImageRight-subImageLeft
	# 		subImageHeight = subImageBottom-subImageTop

	# 		print 'sub image rect:'
	# 		print subImageLeft
	# 		print subImageTop
	# 		print subImageRight
	# 		print subImageBottom
	# 		print 'width, height:'
	# 		print subImageWidth
	# 		print subImageHeight
			
	# 		print 'image size:'
	# 		print image.size[0]
	# 		print image.size[1]

	# 		print 'raster size:'
	# 		print raster100.size[0]
	# 		print raster100.size[1]

	# 		# import pdb; pdb.set_trace()
	# 		subImage = image.crop((subImageLeft, subImageTop, subImageWidth, subImageHeight))

	# 		# subImage = image.clone().crop(left=subImageLeft,top=subImageTop,width=subImageWidth,height=subImageHeight) # unefficient: clone the whole image instead of the sub image
	# 		posInRasterX = left-xi
	# 		posInRasterY = top-yi

	# 		print 'posInRaster:'
	# 		print posInRasterX
	# 		print posInRasterY

	# 		# import pdb; pdb.set_trace()

	# 		# raster.composite(image=subImage, left=posInRasterX, top=posInRasterY) 	# problem: we want to totally replace current raster with new one
	# 		# raster100.composite_channel(channel='all_channels', image=subImage, operator='replace', left=posInRasterX, top=posInRasterY) 		# Wand version
	# 		raster100.paste(subImage, (posInRasterX, posInRasterY))
	# 		raster100.save(rasterName100)
			
	# 		raster100cropX = roundToLowerMultiple(posInRasterX, 5)
	# 		raster100cropY = roundToLowerMultiple(posInRasterY, 5)
	# 		raster100cropWidth = roundToGreaterMultiple(posInRasterX+subImageWidth, 5)-raster100cropX
	# 		raster100cropHeight = roundToGreaterMultiple(posInRasterY+subImageHeight, 5)-raster100cropY

	# 		print 'raster100crop:'
	# 		print raster100cropX
	# 		print raster100cropY
	# 		print raster100cropWidth
	# 		print raster100cropHeight
	# 		raster100crop = raster100.crop((raster100cropX, raster100cropY, raster100cropWidth, raster100cropHeight))
	# 		raster100crop.resize((raster100cropWidth/5, raster100cropHeight/5), Image.LANCZOS)

	# 		print 'raster100crop final size:'
	# 		print raster100cropWidth/5
	# 		print raster100cropHeight/5

	# 		print 'xm & ym:'
	# 		print xm
	# 		print ym
	# 		print 'x5 & y5:'
	# 		print x5
	# 		print y5
	# 		print '(xm-x5)*1000:'
	# 		print (xm-x5)*1000
	# 		print (ym-y5)*1000

	# 		posInRasterX = ((xm-x5)*1000+raster100cropX)/5
	# 		posInRasterY = ((ym-y5)*1000+raster100cropY)/5
	# 		print 'posInRaster:'
	# 		print posInRasterX
	# 		print posInRasterY
	# 		raster20.paste(raster100crop, (posInRasterX, posInRasterY))
	# 		raster20.save(rasterName20)

	# 		raster20cropX = roundToLowerMultiple(posInRasterX,5)
	# 		raster20cropY = roundToLowerMultiple(posInRasterY,5)
	# 		raster20cropWidth = roundToGreaterMultiple(posInRasterX+raster100cropWidth/5, 5)-raster20cropX
	# 		raster20cropHeight = roundToGreaterMultiple(posInRasterY+raster100cropHeight/5, 5)-raster20cropY

	# 		print 'x25 & y25:'
	# 		print x25
	# 		print y25
	# 		print 'raster20crop:'
	# 		print raster20cropX
	# 		print raster20cropY
	# 		print raster20cropWidth
	# 		print raster20cropHeight
	# 		raster20crop = raster20.crop((raster20cropX, raster20cropY, raster20cropWidth, raster20cropHeight))
	# 		raster20crop.resize((raster20cropWidth/5, raster20cropHeight/5), Image.LANCZOS)

	# 		posInRasterX = ((x5-x25)*1000/5+raster20cropX)/5
	# 		posInRasterY = ((y5-y25)*1000/5+raster20cropY)/5
	# 		print 'posInRaster:'
	# 		print posInRasterX
	# 		print posInRasterY
	# 		raster4.paste(raster20crop, (posInRasterX, posInRasterY))
	# 		raster20.save(rasterName4)
			
	# 		# Wand version
	# 		# with image[subImageLeft:subImageRight, subImageTop:subImageBottom] as subImage: 		

	# 		# subImage.resize(filter='triangle', width=subImage.width/5, height=subImage.height/5)
	# 		# raster20.composite_channel(channel='all_channels', image=subImage, operator='replace', left=posInRasterX, top=posInRasterY)
	# 		# raster20.save(filename=rasterName)

	# 		# posInRasterX = int((left-x25*1000)/25)
	# 		# posInRasterY = int((top-y25*1000)/25)
	# 		# subImage.resize(filter='triangle', width=subImage.width/5, height=subImage.height/5)
	# 		# raster4.composite_channel(channel='all_channels', image=subImage, operator='replace', left=posInRasterX, top=posInRasterY)
	# 		# raster4.save(filename=rasterName)


	# 		raster100.close()
	# 		raster20.close()
	# 		raster4.close()

	image.close()

	end = time.time()

	print "Time elapsed: " + str(end - start)

	return { 'state': 'success', 'areasToUpdate': areasToUpdate, 'areasDeleted': areasDeleted }

@dajaxice_register
def loadRasters(request, areasToLoad):

	images = []
	start = time.time()
	for area in areasToLoad:

		x = area['x']
		y = area['y']

		rasterPath = 'media/rasters/' + str(floor(x/10)*10) + ',' + str(floor(y/10)*10) + '/'
		rasterName = rasterPath + str(x) + "," + str(y) + ".png"

		with open(rasterName, 'rb') as inputFile:
			imageData = inputfile.read().encode('base64')
			inputfile.close()
			images.append(imageData)

	end = time.time()
	print "Time elapsed: " + str(end - start)

	return json.dumps( { 'images': images } )

# @dajaxice_register
# def updateAreasToUpdate(request, pk, newAreas):

# 	try:
# 		areaToUpdate = AreaToUpdate.objects.get(pk=pk)
# 	except AreaToUpdate.DoesNotExist:
# 		return json.dumps({'state': 'log', 'message': 'Delete impossible: area does not exist'})

# 	areaToUpdate.delete()

# 	areasToUpdate = []
# 	for area in newAreas:
# 		points = area['points']
# 		planetX = area['planet']['x']
# 		planetY = area['planet']['y']

# 		areaToUpdate = AreaToUpdate(planetX=planetX, planetY=planetY, box=[points])
# 		areaToUpdate.save()

# 		areasToUpdate.append( areasToUpdate.to_json() )

# 	return json.dumps( { 'state': 'success', 'areasToUpdate': areasToUpdate } )

# --- images --- #

@dajaxice_register
def saveImage(request, image):

	imageData = re.search(r'base64,(.*)', image).group(1)
	
	imagePath = 'media/images/' + request.user.username + '/'
	
	try:
		os.mkdir(imagePath)
	except OSError as exception:
		if exception.errno != errno.EEXIST:
			raise

	date = str(datetime.datetime.now()).replace (" ", "_").replace(":", ".")
	imageName = imagePath + date + ".png"

	output = open(imageName, 'wb')
	output.write(imageData.decode('base64'))
	output.close()

	# to read the image
	# inputfile = open(imageName, 'rb')
	# imageData = inputfile.read().encode('base64')
	# inputfile.close()
	# return json.dumps( { 'image': imageData, 'url': imageName } )
	
	return json.dumps( { 'url': imageName } )

# --- tools --- #

@dajaxice_register
def addTool(request, name, className, source, compiledSource, isTool):
	try:
		tool = Tool(owner=request.user.username, name=name, className=className, source=source, compiledSource=compiledSource, isTool=isTool)
	except OperationError:
		return json.dumps( { 'state': 'error', 'message': 'A tool with the name ' + name + ' or the className ' + className + ' already exists.' } )
	tool.save()
	return json.dumps( { 'state': 'success', 'message': 'Request for adding ' + name + ' successfully sent.' } )

@dajaxice_register
def updateTool(request, name, className, source, compiledSource):
	try:
		tool = Tool.objects.get(name=name)
	except Tool.DoesNotExist:
		return json.dumps( { 'state': 'error', 'message': 'The tool with the name ' + name + ' or the className ' + className + ' does not exist.' } )

	tool.nRequests += 1
	tool.save()
	newName = name + str(tool.nRequests)
	newClassName = className + str(tool.nRequests)
	newTool = Tool(owner=request.user.username, name=newName, originalName=name, originalClassName=className, className=newClassName, source=source, compiledSource=compiledSource, isTool=tool.isTool)
	newTool.save()

	return json.dumps( { 'state': 'success', 'message': 'Request for updating ' + name + ' successfully sent.' } )

@dajaxice_register
def getTools(request):
	tools = Tool.objects(accepted=True)
	return json.dumps( { 'state': 'success', 'tools': tools.to_json() } )

# --- admin --- #

@dajaxice_register
def getWaitingTools(request):
	if request.user.username != 'arthur.sw':
		return json.dumps( { 'state': 'error', 'message': 'You must be administrator to get the waiting tools.' } )
	tools = Tool.objects(accepted=False)
	return json.dumps( { 'state': 'success', 'tools': tools.to_json() } )

@dajaxice_register
def acceptTool(request, name):
	if request.user.username != 'arthur.sw':
		return json.dumps( { 'state': 'error', 'message': 'You must be administrator to accept tools.' } )
	try:
		tool = Tool.objects.get(name=name)
	except Tool.DoesNotExist:
		return json.dumps( { 'state': 'success', 'message': 'New tool does not exist.' } )
	if tool.originalName:
		try:
			originalTool = Tool.objects.get(name=tool.originalName)
		except Tool.DoesNotExist:
			return json.dumps( { 'state': 'success', 'message': 'Original tool does not exist.' } )
		originalTool.source = tool.source
		originalTool.compiledSource = tool.compiledSource
		originalTool.save()
		tool.delete()
	else:
		tool.accepted = True
		tool.save()
	return json.dumps( { 'state': 'success' } )

# --- loadSite --- #

@dajaxice_register
def loadSite(request, siteName):
	try:
		site = Site.objects.get(name=siteName)
	except:
		return { 'state': 'error', 'message': 'Site ' + siteName + ' does not exist.' }
	return { 'state': 'success', 'box': site.box.to_json(), 'site': site.to_json(), 'loadEntireArea': site.loadEntireArea }

# --- payment signal --- #

def updateUserRomanescoins(sender, **kwargs):
	ipn_obj = sender

	print "updateUserRomanescoins"
	
	if ipn_obj.payment_status == "Completed":

		data = json.loads(ipn_obj.custom)
		
		import pdb; pdb.set_trace()

		# profile = User.objects.get(username=data['user']).profile
		# profile.romanescoins += ipn_obj.num_cart_items

		# Fails with: OperationalError: no such column: user_profile.romanescoins:
		# UserProfile.objects.filter(user__username=data['user']).update(romanescoins=F('romanescoins')+1000*ipn_obj.num_cart_items)
		# so instead:
		
		try:
			userProfile = User.objects.get(username=data['user']).profile
			userProfile.romanescoins += 1000*ipn_obj.num_cart_items
			userProfile.save()
		except UserProfile.DoesNotExist:
			pass

	else:
		print "payment was not successful: "
		print ipn_obj.payment_status

payment_was_successful.connect(updateUserRomanescoins)

def paymentWasFlagged(sender, **kwargs):
	ipn_obj = sender
	print "paymentWasFlagged"

payment_was_flagged.connect(paymentWasFlagged)

def paymentWasRefunded(sender, **kwargs):
	ipn_obj = sender
	print "paymentWasRefunded"

payment_was_refunded.connect(paymentWasRefunded)

def paymentWasReversed(sender, **kwargs):
	ipn_obj = sender
	print "paymentWasReversed"

payment_was_reversed.connect(paymentWasReversed)