
# out-of-date
# Get the image in *rectangle* of the view in a data url and the a list of areas (rectangle) which could not be rasterized because they are outside the view
# @param rectangle [Paper Rectangle] a rectangle in project coordinate representing the area to extract
# @return [String or { dataURL: String, areasNotRasterized: Array<Paper Rectangle>}] an object with the dataURL and the areas not rasterized
this.areaToImageDataUrlWithAreasNotRasterized = (rectangle)->

	if view.zoom != 1
		g.romanesco_alert("You are creating or modifying an item in a zoom different than 100. \nThis will not be rasterized, other users will have to render it \n(please consider drawing and modifying items at zoom 100 for better loading performances).", "warning", 3000)
		return { dataURL: null, rectangle: rectangle, areasNotRasterized: [g.boxFromRectangle(rectangle)] }

	viewCenter = view.center
	view.center = view.bounds.topLeft.round().add(view.size.multiply(0.5))

	rectangle = g.expandRectangleToInteger(rectangle)
	intersection = rectangle.intersect(view.bounds)
	intersection = g.shrinkRectangleToInteger(intersection)	
	viewIntersection = g.roundRectangle(g.projectToViewRectangle(intersection))

	# rectangle = g.projectToViewRectangle(rectangle)
	# rectangle = g.expandRectangleToInteger(rectangle)
	# intersection = rectangle.intersect(new Rectangle(0, 0, view.size.width, view.size.height))
	
	# intersection = g.shrinkRectangleToInteger(intersection)
	
	# viewIntersection = intersection
	# rectangle = g.roundRectangle(g.viewToProjectRectangle(rectangle))
	# intersection = g.roundRectangle(g.viewToProjectRectangle(intersection))

	if view.bounds.contains(rectangle) and not g.shrinkRectangleToInteger(intersection).equals(rectangle)
		console.log "ERROR: good error :-) but unlikely..."
		debugger

	# console.log 'rectangle: ' + rectangle.toString()
	# console.log 'intersection: ' + intersection.toString()
	# console.log 'viewIntersection: ' + viewIntersection.toString()

	if not rectangle.topLeft.round().equals(rectangle.topLeft) or not rectangle.bottomRight.round().equals(rectangle.bottomRight)
		console.log 'Error: rectangle is not rounded!'
		debugger
	if not intersection.topLeft.round().equals(intersection.topLeft) or not intersection.bottomRight.round().equals(intersection.bottomRight)
		console.log 'Error: rectangle is not rounded!'
		debugger
	if not viewIntersection.topLeft.round().equals(viewIntersection.topLeft) or not viewIntersection.bottomRight.round().equals(viewIntersection.bottomRight)
		console.log 'Error: rectangle is not rounded!'
		debugger

	# deselect items (in paper.js view) and keep them in an array to reselect them after rasterization
	selectedItems = []
	for item in project.getItems({selected: true})
		if item.constructor?.name != "Group" and item.constructor?.name != "Layer"
			selectedItems.push( { item: item, fullySelected: item.fullySelected } )
	
	project.activeLayer.selected = false
	g.carLayer.visible = false
	g.debugLayer.visible = false

	view.update()
	
	# rasterize (only what it is possible to rasterize)
	dataURL = areaToImageDataUrl(viewIntersection, false)
	
	view.center = viewCenter
	# debugRaster = new Raster( source: dataURL, position: rectangle.intersect(view.bounds).center )
	# debugRaster.selected = true
	# debugRaster.opacity = 0.5
	# debugRaster.on('mousedrag', (event)-> this.position = event.point )
	# g.debugLayer.addChild(debugRaster)
	
	g.debugLayer.visible = true
	g.carLayer.visible = true
	
	# reselect items
	for itemObject in selectedItems
		if itemObject.fullySelected
			itemObject.item.fullySelected = true
		else
			itemObject.item.selected = true

	# make a list of rectangles (areas) which we can not extract since it is outside the view
	areasNotRasterized = g.getRectangleListFromIntersection(rectangle, intersection)

	# convert the list of area in a GeoJSON compatible format
	areasNotRasterizedBox = (g.boxFromRectangle(area) for area in areasNotRasterized)
	# or: areasNotRasterizedBox = areasNotRasterized.map( (areaNotRasterized)-> return g.boxFromRectangle(area) )
	
	for area in areasNotRasterized
		console.log area

	return { dataURL: dataURL, rectangle: intersection, areasNotRasterized: areasNotRasterizedBox }

# doc is out-of-date
# - add areas to update in g.areasToUpdate, from result of server
# called in loadCallback, and on updateRastersCallback (when we rasterize part of an area, we must add the new remaining areas)
# @param newAreasToUpdate [Array<AreaToUpdate>] the list of new areas to update
this.addAreasToUpdate = (newAreasToUpdate)->
	# add areas to update in g.areasToUpdate
	for area in newAreasToUpdate
		
		if g.areasToUpdate[area._id.$oid]?
			continue 	# do not add if it is already there (meaning we add areas from loadCallback)

		rectangle = g.rectangleFromBox(area)

		# console.log 'add: ' + area._id.$oid + ', rectangle: ' + rectangle.toString()
		g.areasToUpdate[area._id.$oid] = rectangle
		# debug
		debugRectangle = new Path.Rectangle(rectangle)
		debugRectangle.strokeColor = 'red'
		debugRectangle.strokeWidth = 1
		debugRectangle.name = area._id.$oid
		g.debugLayer.addChild(debugRectangle)

		g.areasToUpdateRectangles[area._id.$oid] = debugRectangle

	return

# out-of-date
# update rasters on the server
# todo: change doc: called in one case only.
# called in two cases:
# - by RPath.update when a path must be updated, the rasters must also be updated
# - by updateAreasToUpdate: when the view is moved on top of an area to update, the rasters are updated
# - on server response, the callback will also add the new areas to update to g.areasToUpdate (the remaining areas)
# @param rectangle [Paper Rectangle] the rectangle to update
# @param areaPk [ID] the primary key of the area that we updated (used when called from updateAreasToUpdate)
this.updateRasters = (rectangle, areaPk=null)->
	extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)
	console.log 'request to add ' + extraction.areasNotRasterized?.length + ' areas'

	for area in extraction.areasNotRasterized
		console.log "---"
		console.log area

		planet = new Point(area.planet)
		
		tl = posOnPlanetToProject(area.tl, planet)
		br = posOnPlanetToProject(area.br, planet)
		console.log new Rectangle(tl, br).toJSON()

	if extraction.dataURL == "data:,"
		console.log "Warning: trying to add an area outside the screen!"

	# Dajaxice.draw.updateRasters(g.updateRastersCallback, { 'data': extraction.dataURL, 'position': extraction.rectangle.topLeft, 'areasNotRasterized': extraction.areasNotRasterized, 'areaToDeletePk': areaPk } )
	return

# out-of-date
# - call updateRastersCallback multiple times
this.batchUpdateRastersCallback = (results)->
	for result in results
		updateRastersCallback(result)
	return

# out-of-date
# - delete areas to delete (areas which were overlapping with the areas which were just added)
# call addAreasToUpdate
this.updateRastersCallback = (results)->
	if not g.checkError(results) then return
	if results.state == 'log' and results.message == 'Delete impossible: area does not exist' then return 	# dirty way to ignore when the area was deleted (probaby updated by another user before) 

	# console.log 'areas to delete: ' + results.areasDeleted?.length
	# delete areas to delete (areas which were overlapping with the areas which were just added)
	if results.areasDeleted?
		for areaToDeletePk in results.areasDeleted
			# console.log 'delete area: ' + areaToDeletePk
			if g.areasToUpdate[areaToDeletePk]?
				debugRectangle = debugLayer.getItem( name: areaToDeletePk )
				if debugRectangle?
					debugRectangle.strokeColor = 'green'
					setTimeout(((debugRectangle)-> return ()-> debugRectangle.remove())(debugRectangle), 2000)
				# else
				# 	console.log 'Error: could not find debug rectangle'
				delete g.areasToUpdate[areaToDeletePk]
			else
				console.log 'Error: area to delete could not be found'
				debugger

	newAreasToUpdate = []
	if results.areasToUpdate?
		for area in results.areasToUpdate
			newAreasToUpdate.push(JSON.parse(area))
	g.addAreasToUpdate(newAreasToUpdate)
	return

# out-of-date
# draw/update the areas to update:
# for all areas to update: if it is in the view, refresh the view and delete area
# if the area was not entirely in the view, the remaining areas are sent to the server to be added
# on server callback, the remaining areas will be added to g.areasToUpdate (in addAreasToUpdate)
this.updateAreasToUpdate = ()->

	if view.zoom != 1 then return

	viewUpdated = false
	args = []
	for pk, rectangle of g.areasToUpdate
		intersection = rectangle.intersect(view.bounds)
		
		# console.log 'try to update area ' + pk + ', rectangle: ' + rectangle.toString() + '...'
		if (rectangle.width > 1 and intersection.width <= 1) or (rectangle.height > 1 and intersection.height <= 1)
			# console.log '...not in view'
			continue

		# debugRectangle = debugLayer.getItem( name: pk )
		debugRectangle = g.areasToUpdateRectangles[pk]
		if debugRectangle?
			debugRectangle.strokeColor = 'blue'
			# setTimeout((()-> debugRectangle.remove()), 2000)
			setTimeout(((debugRectangle)-> return ()-> debugRectangle.remove())(debugRectangle), 2000)
		else
			console.log 'Error: could not find debug rectangles'
	
		# draw all items on this area
		# for item in newItems
		# 	if item.getBounds().intersects(intersection)
		# 		item.draw()
		
		# refresh view (only once)
		if not viewUpdated
			g.updateView()
			viewUpdated = true

		# newAreas = g.getRectangleListFromIntersection(rectangle, intersection)

		# newAreasBox = []
		# for area in newAreas
		# 	newAreasBox.push(g.boxFromRectangle(area))

		# Dajaxice.draw.updateAreasToUpdate(addAreasToUpdate, { 'pk': area.pk, 'newAreas': newAreasBox } )

		# updateRasters(rectangle, pk)
		extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)
		if extraction.dataURL == "data:,"
			console.log "Warning: trying to add an area outside the screen!"
		args.push({ 'data': extraction.dataURL, 'position': extraction.rectangle.topLeft, 'areasNotRasterized': extraction.areasNotRasterized, 'areaToDeletePk': pk })

		# console.log '...updated'
		delete g.areasToUpdate[pk]
	
	areaToDeletePks = []
	for arg in args
		if areaToDeletePks.indexOf(arg.areaToDeletePk)>=0
			console.log 'areaToDeletePk is twice!!'
			debugger
		for areaNotRasterized in arg.areasNotRasterized
			for pk, rectangle in g.areasToUpdate
				intersection = areaNotRasterized.intersect(rectangle)
				if intersection.area>0
					console.log 'rectangles ' + rectangle.toString() + ', and ' + areaNotRasterized.toString() + ' should not intersect'
					debugger
		areaToDeletePks.push(arg.areaToDeletePk)

	if args.length>0
		Dajaxice.draw.batchUpdateRasters(g.batchUpdateRastersCallback, {'args': args})

	g.willUpdateAreasToUpdate = false
	return

# hide rasters and redraw all items (except ritem if specified)
# @param item [RItem] (optional) the item not to update (draw)
this.updateView = (ritem=null)->
	# if g.viewUpdated
	# 	return

	# console.log "updateView: remove rasters and redraw"

	# remove all rasters
	for x, rasterColumn of g.rasters
		for y, raster of rasterColumn
			raster.remove()
			delete g.rasters[x][y]
			if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

	# redraw paths (could redraw all RItems)
	for pk, item of g.paths 		# could be g.items
		item.draw()

	# g.viewUpdated = true
	return

# split *rectangle* in 1000 pixels wide tiles if necessary
# rasterize those tiles and add them to g.rastersToUpload
# call loopUpdateRasters to send those tiles one by one
# @param rectangle [Paper Rectangle] the rectangle to rasterize
this.rasterizeArea = (rectangle)->

	rectangle = g.expandRectangleToInteger(rectangle)

	viewCenter = view.center
	viewZoom = view.zoom
	
	# deselect items (in paper.js view) and keep them in an array to reselect them after rasterization
	selectedItems = []
	for item in project.getItems({selected: true})
		if item.constructor?.name != "Group" and item.constructor?.name != "Layer"
			selectedItems.push( { item: item, fullySelected: item.fullySelected } )
	
	project.activeLayer.selected = false

	view.zoom = 1
	view.center = view.bounds.topLeft.round().add(view.size.multiply(0.5))

	restoreView = ()->
		view.zoom = viewZoom
		view.center = viewCenter

		g.debugLayer.visible = true
		g.carLayer.visible = true

		# reselect items
		for itemObject in selectedItems
			if itemObject.fullySelected
				itemObject.item.fullySelected = true
			else
				itemObject.item.selected = true

		view.update()
		
		return

	if view.bounds.contains(rectangle)
		dataURL = areaToImageDataUrl(g.roundRectangle(g.projectToViewRectangle(rectangle)), false)
		g.rastersToUpload.push( data: dataURL, position: rectangle.topLeft )
	else
		# if the rectangle if too big, we do not rasterize it now, a rasterizer bot will do it
		if rectangle.area > 4*Math.min(view.bounds.area, 1000*1000)
			# Dajaxice.draw.updateRasters(g.updateRastersCallback, { areasNotRasterized: [g.boxFromRectangle(rectangle)] } )
			restoreView()
			return
		
		# check that the areas where the rectangle lies are loaded

		## find top, left, bottom and right positions of the rectangle in the quantized space
		t = Math.floor(rectangle.top / scale)
		l = Math.floor(rectangle.left / scale)
		b = Math.floor(rectangle.bottom / scale)
		r = Math.floor(rectangle.right / scale)

		for x in [l .. r]
			for y in [t .. b]
				if not g.areaIsQuickLoaded(x: x, y: y)
					# Dajaxice.draw.updateRasters(g.updateRastersCallback, { areasNotRasterized: [g.boxFromRectangle(rectangle)] } )
					restoreView()
					return

		view.center = rectangle.topLeft.add(view.size.multiply(0.5))
		
		while view.bounds.bottom < rectangle.bottom
			while view.bounds.right < rectangle.right
				width = Math.min(Math.min(view.size.width, 1000), rectangle.right - view.bounds.left)
				height = Math.min(Math.min(view.size.height, 1000), rectangle.bottom - view.bounds.top)
				dataURL = areaToImageDataUrl(new Rectangle(0, 0, width, height), false)
				g.rastersToUpload.push( data: dataURL, position: view.bounds.topLeft )
				view.center = view.center.add(Math.min(view.size.width, 1000), 0)
			view.center = new Point(rectangle.left+view.size.width*0.5, view.center.y+Math.min(view.size.height, 1000))

	if not g.isUpdatingRasters then g.loopUpdateRasters()
	
	restoreView()
	return

# send rasters in g.rastersToUpload one after the other
# @param results [Object] the result from the server
this.loopUpdateRasters = (results)->
	g.checkError(results)
	if g.rastersToUpload.length>0
		g.isUpdatingRasters = true
		# Dajaxice.draw.updateRasters(g.loopUpdateRasters, g.rastersToUpload.shift() )
	else
		g.isUpdatingRasters = false
	return

# get areas to update and rasterize them one by one (updating the view for fun)
# in this mode, the client works as a bot rasterizing romanesco
this.rasterizeAreasToUpdate = ()->
	Dajaxice.draw.getAreasToUpdate(rasterizeAreasToUpdateCallback)
	return

# getAreasToUpdate callback:
# - convert the areas to update in project coordinates 
# - intialize the view on the first area
# - start the rasterization process (in rasterizeAreasToUpdate_loop)
# @param areas [Array<Box>] the areas to rasterize
this.rasterizeAreasToUpdateCallback = (areas)->
	g.areasToRasterize = areas
	area = g.areasToRasterize.first()
	if not area then return
	rectangle = g.rectangleFromBox(area)

	project.activeLayer.selected = false
	g.carLayer.visible = false
	g.debugLayer.visible = false

	view.zoom = 1
	view.center = rectangle.topLeft.add(view.size.multiply(0.5))
	this.rasterizeAreasToUpdate_loop()
	return

# the rasterization process 
# - rasterize the current view
# - move the view to the next tile (1000 pixels wide tile) and go to step one
# - if the current tile has been fully covered, 
this.rasterizeAreasToUpdate_loop = ()->
	# if there are too many images on the client, wait to send them to the server
	if g.rastersToUpload.length>10
		if not g.isUpdatingRasters then g.loopUpdateRasters()
		setTimeout(rasterizeAreasToUpdate_loop, 1000)
		return

	area = g.areasToRasterize.first()
	if not area
		console.log 'area is null, g.areasToRasterize is empty?'
		debugger
		return
	rectangle = g.rectangleFromBox(area)
	width = Math.min(Math.min(view.size.width, 1000), rectangle.right - view.bounds.left)
	height = Math.min(Math.min(view.size.height, 1000), rectangle.bottom - view.bounds.top)
	dataURL = areaToImageDataUrl(new Rectangle(0, 0, width, height), false)

	g.rastersToUpload.push( data: dataURL, position: view.bounds.topLeft )
	view.update()

	view.center = view.center.add(Math.min(view.size.width, 1000), 0)
	if view.bounds.left > rectangle.right
		view.center = new Point(rectangle.left+view.size.width*0.5, view.center.y+Math.min(view.size.height, 1000))
	if view.bounds.top > rectangle.bottom # if we finished
		g.rastersToUpload.last().areaToDeletePk = area._id.$oid 		# if it is the last tile for this area: delete the AreaToUpdate
		g.areasToRasterize.shift()
		if g.areasToRasterize.length>0
			area = g.areasToRasterize.first()
			rectangle = g.rectangleFromBox(area)
			view.center = rectangle.topLeft.add(view.size.multiply(0.5))
		else
			waitUntilLastRastersAreUpdloaded = ()->
				if g.isUpdatingRasters
					setTimeout(waitUntilLastRastersAreUpdloaded, 1000)
				else
					g.loopUpdateRasters()
				return
			waitUntilLastRastersAreUpdloaded()
			g.debugLayer.visible = true
			g.carLayer.visible = true
			return

	if not g.isUpdatingRasters then g.loopUpdateRasters()

	setTimeout(rasterizeAreasToUpdate_loop, 0)
	return

# get a list of rectangles obtained from the cut of rectangle 2 in rectangle 1
# the rectangles A, B, C and D are the resulting rectangles
#
# example 1 when the rectangle 1 is bigger than the rectangle 2 in every directions:
#  ----------------------
#  |		A			|
#  |--------------------|
#  |    |         |     |
#  |  B | Rect 2  |  C  |
#  |    |         |     |
#  |--------------------|
#  |        D           |
#  ----------------------
#  
# example 2 when the bottom-left corner of the rectangle 1 is outside the rectangle 2:
#  
#  -----------
#  |         |------
#  | Rect 2  |  C  |
#  |         |     |
#  ----------------|
#     |     D      |
#     --------------
# @param rectangle1 [Paper Rectangle] the rectangle 1
# @param rectangle2 [Paper Rectangle] the rectangle 2
# @return [Array<Paper Rectangle>] the resulting list of rectangles of the cut of rectangle 2 in rectangle 1
this.getRectangleListFromIntersection = (rectangle1, rectangle2)->
	
	rectangles = []
	
	# if the rectangles do not interect or if rectangle 1 is contained within rectangle 2: return an empty list
	if (not rectangle1.intersects(rectangle2)) or (rectangle2.contains(rectangle1)) then return rectangles

	# push all rectangles A, B, C, D as if we were in example 1, and then remove rectangle which have negative width or height

	rA = new Rectangle()
	rA.topLeft = rectangle1.topLeft
	rA.bottomRight = new Point(rectangle1.right, rectangle2.top)
	rectangles.push(rA)

	rB = new Rectangle()
	rB.topLeft = new Point(rectangle1.left, Math.max(rectangle2.top, rectangle1.top))
	rB.bottomRight = new Point(rectangle2.left, Math.min(rectangle2.bottom, rectangle1.bottom))
	rectangles.push(rB)

	rC = new Rectangle()
	rC.topLeft = new Point(rectangle2.right, Math.max(rectangle2.top, rectangle1.top))
	rC.bottomRight = new Point(rectangle1.right, Math.min(rectangle2.bottom, rectangle1.bottom))
	rectangles.push(rC)

	rD = new Rectangle()
	rD.topLeft = new Point(rectangle1.left, rectangle2.bottom)
	rD.bottomRight = rectangle1.bottomRight
	rectangles.push(rD)

	# remove rectangles which have negative width or height
	i = rectangles.length-1
	while i>=0
		rectangle = rectangles[i]

		if rectangle.width<=0 or rectangle.height<=0
			rectangles.splice(i,1)
		i--

	return rectangles

this.testRectangleIntersection = ()->
	r = new Rectangle(0,0,250,400)
	pr = new Path.Rectangle(r)
	pr.strokeColor = 'blue'
	pr.strokeWidth = 5

	r2 = new Rectangle(-30,10,10,10)
	pr2 = new Path.Rectangle(r2)
	pr2.strokeColor = 'green'
	pr2.strokeWidth = 5
	
	rectangles = g.getRectangleListFromIntersection(r2,r)
	
	for rectangle in rectangles
		p = new Path.Rectangle(rectangle)
		p.strokeColor = 'red'
		p.strokeWidth = 1
	
	return
