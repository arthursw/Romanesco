import datetime
import logging
import json
from django.utils import simplejson
from dajaxice.decorators import dajaxice_register
from django.core import serializers
from dajaxice.core import dajaxice_functions
from models import Path, Box
import ast
from pprint import pprint
from django.contrib.auth import authenticate, login, logout
from math import *

from django.core.validators import URLValidator
from django.core.exceptions import ValidationError

from mongoengine.queryset import Q

logger = logging.getLogger(__name__)

# import pdb; pdb.set_trace()

def makeBox(tlX, tlY, brX, brY):
	return { "type": "Polygon", "coordinates": [ [ [tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY] ] ] }

@dajaxice_register
def load(request, areasToLoad):

	paths = []
	boxes = []

	for area in areasToLoad:
				
		tlX = area['pos']['x']
		tlY = area['pos']['y']

		planet = str(area['planet']['x'])+','+str(area['planet']['y'])

		p = Path.objects(planet=planet, points__geo_intersects=makeBox(tlX, tlY, tlX+1, tlY+1) )
		b = Box.objects(planet=planet, box__geo_intersects=makeBox(tlX, tlY, tlX+1, tlY+1) )

		paths.append(p.to_json())
		boxes.append(b.to_json())

	return simplejson.dumps( {'paths': paths, 'boxes': boxes, 'user': request.user.username} )

@dajaxice_register
def savePaths(request, paths, strokeWidth, strokeColor, object_type, fillColor=None):
	# if not request.user.is_authenticated():
	# 	return simplejson.dumps({'state': 'not_logged_in'})
	
	print "hih"
	print request.user.username

	pIDs = []
	pks = []

	for path in paths:
		pID = path['pID']
		points = path['points']
		planet = str(path['planet']['x'])+','+str(path['planet']['y'])

		lockedAreas = Box.objects(planet=planet, box__geo_intersects={"type": "LineString", "coordinates": points } )
		if lockedAreas.count()>0:
			return simplejson.dumps( {'state': 'error', 'message': 'Your drawing intersects with a locked area'} )

		p = Path(planet=planet, points=points, owner=request.user.username, strokeColor=strokeColor, fillColor=fillColor, strokeWidth=strokeWidth, object_type=object_type, pID=pID )
		p.save()

		pIDs.append(pID)
		pks.append(p.pk)

	return simplejson.dumps( {'state': 'success', 'pIDs': pIDs, 'pk': pks} )

@dajaxice_register
def saveBoxes(request, boxes, bb, object_type, message, name="", url="", modify=None, pk=None):
	if not request.user.is_authenticated():
		return simplejson.dumps({'state': 'not_logged_in'})

	validate = URLValidator()
	if object_type=='link' and url != "":
		try:
			validate(url)
		except ValidationError, e:
			print e
			return simplejson.dumps({'state': 'error', 'message': 'invalid_url'})
	elif object_type=='link' and url == "":
		return simplejson.dumps({'state': 'system_error', 'message': 'invalid_data'})

	if modify:
		boxes = Box.objects(pk=pk, owner=request.user.username)
		if not boxes:
			return simplejson.dumps({'state': 'error', 'message': 'Element does not exist for this user'})
		for box in boxes:
			box.name = name
			box.url = url
			box.message = message
			box.save()
			return simplejson.dumps( {'state': 'success', 'bb': bb, 'object_type':object_type, 'message': message, 'name': name, 'url': url, 'owner': request.user.username, 'pk':str(box.pk), 'box':box.box, 'planet': box.planet,  'modified': True } )

	for box in boxes:
		
		points = box['points']
		planet = str(box['planet']['x'])+','+str(box['planet']['y'])
		lockedAreas = Box.objects(planet=planet, box__geo_intersects=makeBox(points[0][0], points[0][1], points[2][0], points[2][1]) )
		if lockedAreas.count()>0:
			return simplejson.dumps( {'state': 'error', 'message': 'This area was already locked'} )

		b = Box(planet=planet, box=[points], owner=request.user.username, object_type=object_type, url=url, message=message, name=name, bb=bb)
		b.save()

		return simplejson.dumps( {'state': 'success', 'bb': bb, 'object_type':object_type, 'message': message, 'name': name, 'url': url, 'owner': request.user.username, 'pk':str(b.pk), 'box':b.box, 'planet': planet } )





































# @dajaxice_register
# def save(request,paths,object_type,data=None):
# 	if not request.user.is_authenticated():
# 		return simplejson.dumps({'state': 'not_logged_in'})

# 	if object_type=="link":

# 		validate = URLValidator()
# 		if 'url' in data:
# 			try:
# 				validate(data['url'])
# 			except ValidationError, e:
# 				print e
# 				return simplejson.dumps({'state': 'error', 'message': 'invalid_url'})
# 		else:
# 			return simplejson.dumps({'state': 'system_error', 'message': 'invalid_data'})

# 	if object_type=="link" or object_type=="lock":
# 		if 'modify' in data:
# 			geometries = Geometry.objects(pk=data['pk'], owner= request.user.username)
# 			if not geometries:
# 				return simplejson.dumps({'state': 'error', 'message': 'Element does not exist for this user'})
# 			for geometry in geometries:
# 				del data['modify']
# 				geometry.data = json.dumps(data)
# 				geometry.save()
# 				return simplejson.dumps({'state': 'success', 'object_type': object_type, 'owner': request.user.username, 'data': data, 'paths': paths, 'pk': str(geometry.pk), 'modified': True })

# 	for path in paths:

# 		planetX = (path[0][0]+180)/360
# 		planetY = (path[0][1]+180)/360
		
# 		path.append(path[0])

# 		planet = str(planetX)+','+str(planetY)
# 		geometry = Geometry(planet=planet, owner=request.user.username, polygon=[path], object_type=object_type, data=json.dumps(data))
# 		geometry.save()

# 	if object_type=="link" or object_type=='lock':
# 		return simplejson.dumps({'state': 'success', 'object_type': object_type, 'owner': request.user.username, 'data': data, 'pathss': pathss, 'pk': str(geometry.pk) })
# 	elif object_type=="line":
# 		return simplejson.dumps({'state': 'success', 'object_type': object_type, 'data':data, 'pk': str(geometry.pk) })
# 	return simplejson.dumps({'state': 'success', 'object_type': object_type, 'pk': str(geometry.pk) })

# @dajaxice_register
# def delete(request,eraserPoints):
# 	if not request.user.is_authenticated():
# 		return simplejson.dumps({'state': 'not_logged_in'})

# 	lines = Line.objects( point__geo_intersects={ "type": "LineString", "coordinates": eraserPoints }, object_type='line' )

# 	deletedLines = '['

# 	newLines = []
# 	for line in lines:
# 		newPoints = []
# 		for point in line.point['coordinates']:
# 			found = False
# 			for eraserPoint in eraserPoints:
# 				diffX = eraserPoint[0]-point[0]
# 				diffY = eraserPoint[1]-point[1]
# 				if sqrt(diffX*diffX+diffY*diffY)<(10.0/1000.0):
# 					if len(newPoints)>0:
# 						newLines.append(dict(points=newPoints, owner=line.owner, data=line.data))
# 						newPoints = []
# 					found = True
# 					break
# 			if not found:
# 				newPoints.append(point)
# 		if len(newPoints)>0:
# 			newLines.append(dict(points=newPoints, owner=line.owner, data=line.data))
# 		deletedLines += '"' + str(line.pk) + '",'
	
# 	if deletedLines == '[':
# 		deletedLines += ']'
# 	else:
# 		deletedLines = deletedLines[:-1] + ']'

# 	lines.delete()

# 	newLinesJSON = '['

# 	for line in newLines:
# 		if len(line['points'])>1:
# 			newLine = Line(owner=line['owner'], point=line['points'], object_type='line', data=line['data'])
# 			newLine.save()
# 			newLinesJSON += json.dumps({'pk': str(newLine.pk), 'line': newLine.point, 'owner': newLine.owner, 'object_type': newLine.object_type, 'data': newLine.data }) + ','

# 	if newLinesJSON == '[':
# 		newLinesJSON += ']'
# 	else:
# 		newLinesJSON = newLinesJSON[:-1] + ']'
	 
# 	newLinesJSON = simplejson.dumps({'lines': newLinesJSON, 'user': request.user.username})
	
# 	return simplejson.dumps({'state': 'success', 'deletedLines': deletedLines, 'newLines': newLinesJSON})

# --- Old code --- #

# @dajaxice_register
# def load(request,areasToLoad):

# 	linesJSON = '['

# 	# lines = Line.objects( point__geo_intersects={ "type": "Polygon", "coordinates": [ [ [tlX, tlY], [tlX+1, tlY], [tlX+1, tlY+1], [tlX, tlY+1], [tlX, tlY] ] ] } )
# 	# ids = lines.values_list('_id')
# 	# ids = map(lambda id:  ObjectId(id), ids)
# 	# lines = Line.objects( point__geo_intersects={ "type": "Polygon", "coordinates": [ [ [tlX, tlY], [tlX+1, tlY], [tlX+1, tlY+1], [tlX, tlY+1], [tlX, tlY] ] ] }, id__nin=ids )

		# lines = Line.objects( point__geo_within={ "type": "Polygon", "coordinates": [ [ [tlX, tlY], [tlX+1, tlY], [tlX+1, tlY+1], [tlX, tlY+1], [tlX, tlY] ] ] } )

	#lines = Line.objects(__raw__= { "line": { "$geoIntersects" : { "$geometry ": { "type" : "Polygon",	"coordinates" : [ [ [tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY] ] ] } } } } )



# @dajaxice_register
# def load(request,tlX, tlY, brX, brY):
# 	#s.find( {shape: {$geoIntersects: {$geometry: BOX}}}, {_id:1})
# 	# lines = Line.objects(line__geo_within_box=[(-125.0, 35.0), (-100.0, 40.0)])

# 	# lines = Line.objects(line__geo_within_box=box)
# 	# lines = Line.objects(line__geo_within_box=[(tlX, tlY), (brX*1000000.0, brY*1000000.0)])
# 	# lines = Line.objects( point__geo_intersects=[[tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY]] )
	
# 	lines = Line.objects( point__geo_within={ "type": "Polygon", "coordinates": [ [ [tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY] ] ] } )
	
# 	#lines = Line.objects(__raw__= { "line": { "$geoIntersects" : { "$geometry ": { "type" : "Polygon",	"coordinates" : [ [ [tlX, tlY], [brX, tlY], [brX, brY], [tlX, brY], [tlX, tlY] ] ] } } } } )

# 	if lines.count()==0:
# 		return simplejson.dumps({'message': 'no_points'})

# 	data = '['
# 	for line in lines:
# 		data += json.dumps({'line': line.point, 'owner': line.owner}) + ','
# 	data = data[:-1]  + ']'

# 	return data

