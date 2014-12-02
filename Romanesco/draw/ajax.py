import datetime
import logging
import os
import errno
import json
from django.utils import simplejson
from dajaxice.decorators import dajaxice_register
from django.core import serializers
from dajaxice.core import dajaxice_functions
from django.contrib.auth.models import User
from django.db.models import F
from models import Path, Box, Div, UserProfile, Tool, Site
import ast
from pprint import pprint
from django.contrib.auth import authenticate, login, logout
from paypal.standard.ipn.signals import payment_was_successful, payment_was_flagged, payment_was_refunded, payment_was_reversed
from math import *
import re
from django.core.validators import URLValidator
from django.core.exceptions import ValidationError

from mongoengine.base import ValidationError
from mongoengine.queryset import Q
import time

logger = logging.getLogger(__name__)

# pprint(vars(object))
# import pdb; pdb.set_trace()
# import pudb; pu.db

def makeBox(tlX, tlY, brX, brY):
	return { "type": "Polygon", "coordinates": [ [ [tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY] ] ] }

userID = 0

@dajaxice_register
def load(request, areasToLoad):

	paths = []
	divs = []
	boxes = []

	ppks = []
	dpks = []
	bpks = []

	start = time.time()
	for area in areasToLoad:
				
		tlX = area['pos']['x']
		tlY = area['pos']['y']

		planetX = area['planet']['x']
		planetY = area['planet']['y']

		geometry = makeBox(tlX, tlY, tlX+1, tlY+1)
		# geometry = makeBox(tlX, tlY, tlX+0.5, tlY+0.5)

		p = Path.objects(planetX=planetX, planetY=planetY, points__geo_intersects=geometry, pk__nin=ppks)
		d = Div.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, pk__nin=dpks)
		b = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, pk__nin=bpks)

		if len(p)>0:
			paths.append(p.to_json())
			ppks += p.scalar("id")
		if len(b)>0:
			boxes.append(b.to_json())
			bpks += b.scalar("id")
		if len(d)>0:
			divs.append(d.to_json())
			dpks += d.scalar("id")

	end = time.time()
	print "Time elapsed: " + str(end - start)

	global userID
	user = request.user.username
	if not user:
		user = userID
	userID += 1
	return simplejson.dumps( { 'paths': paths, 'boxes': boxes, 'divs': divs, 'user': user } )

@dajaxice_register
def savePath(request, points, pID, planet, object_type, data=None):

	planetX = planet['x']
	planetY = planet['y']

	lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects={"type": "LineString", "coordinates": points }, owner__ne=request.user.username )
	if lockedAreas.count()>0:
		return simplejson.dumps( {'state': 'error', 'message': 'Your drawing intersects with a locked area'} )

	p = Path(planetX=planetX, planetY=planetY, points=points, owner=request.user.username, object_type=object_type, data=data )
	p.save()

	return simplejson.dumps( {'state': 'success', 'pID': pID, 'pk': str(p.pk) } )

@dajaxice_register
def updatePath(request, pk, points=None, planet=None, data=None):

	try:
		p = Path.objects.get(pk=pk)
	except Path.DoesNotExist:
		return simplejson.dumps({'state': 'error', 'message': 'Update impossible: element does not exist for this user'})

	if p.locked and request.user.username != p.owner:
		return simplejson.dumps({'state': 'error', 'message': 'Not owner of path'})

	if points or planet:
		planetX = planet['x']
		planetY = planet['y']

		lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects={"type": "LineString", "coordinates": points }, owner__ne=request.user.username )
		if lockedAreas.count()>0:
			return simplejson.dumps( {'state': 'error', 'message': 'Your drawing intersects with a locked area'} )

	if points:
		p.points = points
	if planet:
		p.planetX = planet['x']
		p.planetY = planet['y']
	if data:
		p.data = data

	p.save()

	return simplejson.dumps( {'state': 'success'} )

@dajaxice_register
def deletePath(request, pk):

	try:
		p = Path.objects.get(pk=pk)
	except Path.DoesNotExist:
		return simplejson.dumps({'state': 'error', 'message': 'Delete impossible: element does not exist for this user'})

	if p.locked and request.user.username != p.owner:
		return simplejson.dumps({'state': 'error', 'message': 'Not owner of path'})

	p.delete()
	
	return simplejson.dumps( { 'state': 'success', 'pk': pk } )

@dajaxice_register
def saveBox(request, box, object_type, message, name="", url="", clonePk=None, website=False, restrictedArea=False, disableToolbar=False):
	if not request.user.is_authenticated():
		return simplejson.dumps({'state': 'not_logged_in'})

	points = box['points']
	planetX = box['planet']['x']
	planetY = box['planet']['y']

	# check if the box intersects with another one
	geometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])
	lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, owner__ne=request.user.username )
	if lockedAreas.count()>0:
		return simplejson.dumps( {'state': 'error', 'message': 'This area intersects with another locked area'} )

	if len(url)==0:
		url = None

	loadEntireArea = object_type == 'video-game'

	try:
		data = simplejson.dumps( { 'loadEntireArea': loadEntireArea } )
		b = Box(planetX=planetX, planetY=planetY, box=[points], owner=request.user.username, object_type=object_type, url=url, message=message, name=name, website=website, data=data)
		b.save()
	except ValidationError:
		return simplejson.dumps({'state': 'error', 'message': 'invalid_url'})

	if website:
		site = Site(box=b, restrictedArea=restrictedArea, disableToolbar=disableToolbar, loadEntireArea=loadEntireArea, name=name)
		site.save()

	# pathsToLock = Path.objects(planetX=planetX, planetY=planetY, box__geo_within=geometry)
	# for path in pathsToLock:
	# 	path.locked = True
	# 	path.save()

	Path.objects(planetX=planetX, planetY=planetY, points__geo_within=geometry).update(set__locked=True, set__owner=request.user.username)
	Div.objects(planetX=planetX, planetY=planetY, box__geo_within=geometry).update(set__locked=True, set__owner=request.user.username)

	return simplejson.dumps( {'state': 'success', 'object_type':object_type, 'message': message, 'name': name, 'url': url, 'owner': request.user.username, 'pk':str(b.pk), 'box':box, 'clonePk': clonePk, 'website': website } )

@dajaxice_register
def updateBox(request, object_type, pk, box=None, message=None, name=None, url=None, data=None):
	if not request.user.is_authenticated():
		return simplejson.dumps({'state': 'not_logged_in'})
	
	if box:
		points = box['points']
		planetX = box['planet']['x']
		planetY = box['planet']['y']

		geometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])

		# check if new box intersects with another one
		lockedAreas = Box.objects(planetX=planetX, planetY=planetY, box__geo_intersects=geometry, owner__ne=request.user.username )
		if lockedAreas.count()>0:
			return simplejson.dumps( {'state': 'error', 'message': 'This area intersects with a locked area'} )

	try:
		b = Box.objects.get(pk=pk, owner=request.user.username)
	except Box.DoesNotExist:
		return simplejson.dumps({'state': 'error', 'message': 'Element does not exist for this user'})

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

	try:
		b.save()
	except ValidationError:
		return simplejson.dumps({'state': 'error', 'message': 'invalid_url'})

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

	return simplejson.dumps( {'state': 'success', 'object_type':object_type } )

@dajaxice_register
def deleteBox(request, pk):
	if not request.user.is_authenticated():
		return simplejson.dumps({'state': 'not_logged_in'})

	try:
		b = Box.objects.get(pk=pk, owner=request.user.username)
	except Box.DoesNotExist:
		return simplejson.dumps({'state': 'error', 'message': 'Element does not exist for this user'})

	points = b.box['coordinates'][0]
	planetX = b.planetX
	planetY = b.planetY
	oldGeometry = makeBox(points[0][0], points[0][1], points[2][0], points[2][1])

	Path.objects(planetX=planetX, planetY=planetY, points__geo_within=oldGeometry).update(set__locked=False)
	Div.objects(planetX=planetX, planetY=planetY, box__geo_within=oldGeometry).update(set__locked=False)

	if request.user.username != b.owner:
		return simplejson.dumps({'state': 'error', 'message': 'Not owner of div'})

	b.delete()
	
	return simplejson.dumps( { 'state': 'success', 'pk': pk } )

@dajaxice_register
def saveDiv(request, box, object_type, message=None, url=None, data=None, clonePk=None):

	points = box['points']
	planetX = box['planet']['x']
	planetY = box['planet']['y']

	lockedAreas = Box.objects( planetX=planetX, planetY=planetY, box__geo_intersects=makeBox(points[0][0], points[0][1], points[2][0], points[2][1]) ) # , owner__ne=request.user.username )
	locked = False
	for area in lockedAreas:
		if area.owner == request.user.username:
			locked = True
		else:
			return simplejson.dumps( {'state': 'error', 'message': 'Your div intersects with a locked area'} )

	# if lockedAreas.count()>0:
	# 	return simplejson.dumps( {'state': 'error', 'message': 'Your div intersects with a locked area'} )

	d = Div(planetX=planetX, planetY=planetY, box=[points], owner=request.user.username, object_type=object_type, message=message, url=url, data=data, locked=locked)
	d.save()

	return simplejson.dumps( {'state': 'success', 'object_type':object_type, 'message': message, 'url': url, 'owner': request.user.username, 'pk':str(d.pk), 'box': box, 'data': data, 'clonePk': clonePk } )

@dajaxice_register
def updateDiv(request, object_type, pk, box=None, message=None, url=None, data=None):

	try:
		d = Div.objects.get(pk=pk)
	except Div.DoesNotExist:
		return simplejson.dumps({'state': 'error', 'message': 'Element does not exist'})

	if d.locked and request.user.username != d.owner:
		return simplejson.dumps({'state': 'error', 'message': 'Not owner of div'})

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
				return simplejson.dumps( {'state': 'error', 'message': 'Your div intersects with a locked area'} )

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
	
	d.save()

	return simplejson.dumps( {'state': 'success' } )

@dajaxice_register
def deleteDiv(request, pk):

	try:
		d = Div.objects.get(pk=pk)
	except Div.DoesNotExist:
		return simplejson.dumps({'state': 'error', 'message': 'Element does not exist for this user.'})

	if d.locked and request.user.username != d.owner:
		return simplejson.dumps({'state': 'error', 'message': 'You are not the owner of this div.'})

	d.delete()
	
	return simplejson.dumps( { 'state': 'success', 'pk': pk } )

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
	# return simplejson.dumps( { 'image': imageData, 'url': imageName } )
	
	return simplejson.dumps( { 'url': imageName } )

# --- tools --- #

@dajaxice_register
def addTool(request, name, className, source, compiledSource, isTool):
	try:
		tool = Tool(owner=request.user.username, name=name, className=className, source=source, compiledSource=compiledSource, isTool=isTool)
	except OperationError:
		return simplejson.dumps( { 'state': 'error', 'message': 'A tool with the name ' + name + ' or the className ' + className + ' already exists.' } )
	tool.save()
	return simplejson.dumps( { 'state': 'success', 'message': 'Request for adding ' + name + ' successfully sent.' } )

@dajaxice_register
def updateTool(request, name, className, source, compiledSource):
	try:
		tool = Tool.objects.get(name=name)		
	except Tool.DoesNotExist:
		return simplejson.dumps( { 'state': 'error', 'message': 'The tool with the name ' + name + ' or the className ' + className + ' does not exist.' } )

	tool.nRequests += 1
	tool.save()
	newName = name + str(tool.nRequests)
	newClassName = className + str(tool.nRequests)
	newTool = Tool(owner=request.user.username, name=newName, originalName=name, originalClassName=className, className=newClassName, source=source, compiledSource=compiledSource, isTool=tool.isTool)
	newTool.save()

	return simplejson.dumps( { 'state': 'success', 'message': 'Request for updating ' + name + ' successfully sent.' } )

@dajaxice_register
def getTools(request):
	tools = Tool.objects(accepted=True)
	return simplejson.dumps( { 'state': 'success', 'tools': tools.to_json() } )

# --- admin --- #

@dajaxice_register
def getWaitingTools(request):
	if request.user.username != 'arthur.sw':
		return simplejson.dumps( { 'state': 'error', 'message': 'You must be administrator to get the waiting tools.' } )
	tools = Tool.objects(accepted=False)
	return simplejson.dumps( { 'state': 'success', 'tools': tools.to_json() } )

@dajaxice_register
def acceptTool(request, name):
	if request.user.username != 'arthur.sw':
		return simplejson.dumps( { 'state': 'error', 'message': 'You must be administrator to accept tools.' } )
	try:
		tool = Tool.objects.get(name=name)
	except Tool.DoesNotExist:
		return simplejson.dumps( { 'state': 'success', 'message': 'New tool does not exist.' } )
	if tool.originalName:
		try:
			originalTool = Tool.objects.get(name=tool.originalName)
		except Tool.DoesNotExist:
			return simplejson.dumps( { 'state': 'success', 'message': 'Original tool does not exist.' } )
		originalTool.source = tool.source
		originalTool.compiledSource = tool.compiledSource
		originalTool.save()
		tool.delete()
	else:
		tool.accepted = True
		tool.save()
	return simplejson.dumps( { 'state': 'success' } )

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

		data = simplejson.loads(ipn_obj.custom)
		
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
		print "payment was not successfull: "
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