
# --- load --- #

# @return [Boolean] true if the area was already loaded, false otherwise
this.areaIsLoaded = (pos,planet) ->
	for area in g.loadedAreas
		if area.planet.x == planet.x && area.planet.y == planet.y
			if area.pos.x == pos.x && area.pos.y == pos.y
				return true
	return false

# this.areaIsQuickLoaded = (area) ->
# 	for a in g.loadedAreas
# 		if a.x == area.x && a.y == area.y
# 			return true
# 	return false

# load an area from the server
# the project coordinate system is divided into square cells of size *g.scale*
# an Area is an object { pos: Point, planet: Point } corresponding to a cell (pos is the top left corner of the cell, the server consider the cells to be 1 unit wide (1000 pixels))
# a load does:
# - build a list of Area overlapping *area* and not already loaded
# - define a load limit rectangle equels to *area* expanded to 2 x g.scale
# - remove RItems which are not within this limit anymore AND in an area which must be unloaded
#   (do not remove items on an area which is not unloaded, otherwise they wont be reloaded if user comes back on it)
# - remove loaded areas which where unloaded
# - load areas
# @param [Rectangle] (optional) the area to load, *area* equals the bounds of the view if not defined
this.load = (area=null) ->

	if not g.rasterizerMode and g.previousLoadPosition? and g.previousLoadPosition.subtract(view.center).length<50
		return false

	console.log "load"
	if area? then console.log area.toString()

	# g.startLoadingBar()

	debug = false

	scale = g.scale

	g.previousLoadPosition = view.center

	if not area?
		if view.bounds.width <= window.innerWidth and view.bounds.height <= window.innerHeight
			bounds = view.bounds
		else
			halfSize = new Point(window.innerWidth*0.5, window.innerHeight*0.5)
			bounds = new Rectangle(view.center.subtract(halfSize), view.center.add(halfSize))
	else
		bounds = area

	if debug
		g.unloadRectangle?.remove()
		g.viewRectangle?.remove()
		g.limitRectangle?.remove()

	# unload:
	# define unload limit rectangle
	unloadDist = Math.round(scale / view.zoom)

	if not g.entireArea
		limit = bounds.expand(unloadDist)
	else
		limit = g.entireArea

	itemsOutsideLimit = []

	# remove RItems which are not on within limit anymore AND in area which must be unloaded
	# (do not remove items on an area which is not unloaded, otherwise they wont be reloaded if user comes back on it)
	for own pk, item of g.items
		if not item.getBounds().intersects(limit)
			itemsOutsideLimit.push(item)

	if debug
		g.unloadRectangle = new Path.Rectangle(limit)
		g.unloadRectangle.name = 'debug load unload rectangle'
		g.unloadRectangle.strokeWidth = 1
		g.unloadRectangle.strokeColor = 'red'
		g.unloadRectangle.dashArray = [10, 4]
		g.debugLayer.addChild(g.unloadRectangle)

	if debug
		removeRectangle = (rectangle)->
			removeRect = ()-> rectangle.remove()
			setTimeout(removeRect, 1500)
			return
	
	# remove rasters which are outside the limit
	g.rasterizer.unload(limit)
	# for x, rasterColumn of g.rasters
	# 	for y, raster of rasterColumn
	# 		if not raster.bounds.intersects(limit)
	# 			raster.remove()
	# 			delete g.rasters[x][y]
	# 			if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

	# remove loaded areas which must be unloaded
	i = g.loadedAreas.length
	while i--
		area = g.loadedAreas[i]
		pos = posOnPlanetToProject(area.pos, area.planet)
		rectangle = new Rectangle(pos.x, pos.y, scale, scale)
		
		if not rectangle.intersects(limit)

			if debug
				area.rectangle.strokeColor = 'red'
				removeRectangle(area.rectangle)

			# # remove raster corresponding to the area
			# x = area.x*1000 	# should be equal to pos.x
			# y = area.y*1000		# should be equal to pos.y
			
			# if g.rasters[x]?[y]?
			# 	g.rasters[x][y].remove()
			# 	delete g.rasters[x][y]
			# 	if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

			# remove area from loaded areas
			g.loadedAreas.splice(i,1)

			# remove items on this area
			# items to remove must not intersect with the limit, and can overlap two areas:
			j = itemsOutsideLimit.length
			while j--
				item = itemsOutsideLimit[j]
				if item.getBounds().intersects(rectangle)
					item.remove()
					itemsOutsideLimit.splice(j,1)
	
	itemsOutsideLimit = null

	# find top, left, bottom and right positions of the area in the quantized space
	t = g.roundToLowerMultiple(bounds.top, scale)
	l = g.roundToLowerMultiple(bounds.left, scale)
	b = g.roundToLowerMultiple(bounds.bottom, scale)
	r = g.roundToLowerMultiple(bounds.right, scale)

	if debug
		g.viewRectangle = new Path.Rectangle(bounds)
		g.viewRectangle.name = 'debug load view rectangle'
		g.viewRectangle.strokeWidth = 1
		g.viewRectangle.strokeColor = 'blue'
		g.debugLayer.addChild(g.viewRectangle)

		g.limitRectangle = new Path.Rectangle(new Point(l, t), new Point(r, b))
		g.limitRectangle.name = 'debug load limit rectangle'
		g.limitRectangle.strokeWidth = 2
		g.limitRectangle.strokeColor = 'blue'
		g.limitRectangle.dashArray = [10, 4]
		g.debugLayer.addChild(g.limitRectangle)

	# add areas to load
	areasToLoad = []
	for x in [l .. r] by scale
		for y in [t .. b] by scale
			planet = projectToPlanet(new Point(x,y))
			pos = projectToPosOnPlanet(new Point(x,y))

			if g.rasterizerMode or not areaIsLoaded(pos, planet)

				if debug
					areaRectangle = new Path.Rectangle(x, y, scale, scale)
					areaRectangle.name = 'debug load area rectangle'
					areaRectangle.strokeWidth = 1
					areaRectangle.strokeColor = 'green'
					g.debugLayer.addChild(areaRectangle)

				area = { pos: pos, planet: planet }

				areasToLoad.push(area)
				if debug then area.rectangle = areaRectangle
				
				if not g.rasterizerMode or not areaIsLoaded(pos, planet)
					g.loadedAreas.push(area)

	if not g.rasterizerMode and areasToLoad.length<=0 	# return if there is nothing to load
		return false

	# load areas
	if not g.loadingBarTimeout?
		showLoadingBar = ()->
			$("#loadingBar").show()
			return
		g.loadingBarTimeout = setTimeout(showLoadingBar , 0)

	rectangle = { left: l, top: t, right: r, bottom: b }

	console.log 'request loading'
	console.log rectangle
	
	if not g.rasterizerMode
		Dajaxice.draw.load(loadCallback, { rectangle: rectangle, areasToLoad: areasToLoad, zoom: 1.0 / view.zoom })
	else
		itemsDates = g.createItemsDates(bounds)
		Dajaxice.draw.loadRasterizer(loadCallback, { areasToLoad: areasToLoad, itemsDates: itemsDates })
	# ajaxPost '/load', args, loadCallback
	return true

# load callback: add loaded RItems
this.loadCallback = (results)->
	console.log "load callback"

	dispatchLoadFinished = ()->
		console.log "dispatch command executed"
		commandEvent = document.createEvent('Event')
		commandEvent .initEvent('command executed', true, true)
		document.dispatchEvent(commandEvent)
		return

	checkError(results)

	if results.hasOwnProperty('message') && results.message == 'no_paths'
		dispatchLoadFinished()
		return

	# set g.me (the server sends the username at each load)
	if not g.me? and results.user?
		g.me = results.user
		if g.chatJ? and g.chatJ.find("#chatUserNameInput").length==0
			g.startChatting( g.me )

	if results.rasters?
		g.rasterizer.load(results.rasters, results.zoom)
		# # add rasters
		# # todo: ask only required rasters (currently, all rasters of all areas are requested, and then ignored if already added :/ )
		# for raster in results.rasters
		# 	position = new Point(raster.position).multiply(1000)
		# 	if g.rasters[position.x]?[position.y]?.rZoom == results.zoom then continue
		# 	raster = new Raster(g.romanescoURL + raster.url)		# Paper rasters are positionned from centers, thus we must add 500 to the top left corner position
		# 	if results.zoom > 0.2
		# 		raster.position = position.add(1000/2)
		# 	else if results.zoom > 0.04
		# 		raster.scale(5)
		# 		raster.position = position.add(5000/2)
		# 	else
		# 		raster.scale(25)
		# 		raster.position = position.add(25000/2)
		# 	console.log "raster.position: " + raster.position.toString() + ", raster.scaling" + raster.scaling.toString()
		# 	raster.name = 'raster: ' + raster.position.toString() + ', zoom: ' + results.zoom
		# 	raster.rZoom = results.zoom
		# 	g.rasters[position.x] ?= {}
		# 	g.rasters[position.x][position.y] = raster

	# if g.rasterizerMode then g.removeItemsToUpdate(results.itemsToUpdate)

	# newAreasToUpdate = []

	itemsToLoad = []

	for i in results.items
		item = JSON.parse(i)

		g.items[item._id.$oid]?.remove() 	# if item is loaded: remove it (it must be updated)

		if item.rType == 'Box'	# add RLocks: RLock, RLink, RWebsite and RVideoGame
			box = item
			if box.box.coordinates[0].length<5
				console.log "Error: box has less than 5 points"
			
			data = if box.data? and box.data.length>0 then JSON.parse(box.data) else null
			date = box.date.$date

			lock = null
			switch box.object_type
				when 'link'
					lock = new RLink(g.rectangleFromBox(box), data, box._id.$oid, box.owner, date)
				when 'lock'
					lock = new RLock(g.rectangleFromBox(box), data, box._id.$oid, box.owner, date)
				when 'website'
					lock = new RWebsite(g.rectangleFromBox(box), data, box._id.$oid, box.owner, date)
				when 'video-game'
					lock = new RVideoGame(g.rectangleFromBox(box), data, box._id.$oid, box.owner, date)
			
			lock.lastUpdateDate = box.lastUpdate.$date
		else
			itemsToLoad.push(item)

	for item in itemsToLoad
		switch item.rType
			
			when 'Div'			# add RDivs (RText and RMedia)
				div = item
				if div.box.coordinates[0].length<5
					console.log "Error: box has less than 5 points"
								
				data = if div.data? and div.data.length>0 then JSON.parse(div.data) else null
				date = div.date.$date

				# rdiv = new g[div.object_type](g.rectangleFromBox(box), data, div._id.$oid, date, div.lock)

				switch div.object_type
					when 'text'
						rdiv = new RText(g.rectangleFromBox(div), data, div._id.$oid, date, if div.lock? then g.items[div.lock] else null)
					when 'media'
						rdiv = new RMedia(g.rectangleFromBox(div), data, div._id.$oid, date, if div.lock? then g.items[div.lock] else null)

				rdiv.lastUpdateDate = div.lastUpdate.$date

			when 'Path' 		# add RPaths
				path = item
				planet = new Point(path.planetX, path.planetY)

				# parse data
				date = path.date.$date
				if path.data? and path.data.length>0
					data = JSON.parse(path.data)
					data.planet = planet

				points = []

				# convert points from planet coordinates to project coordinates
				for point in path.points.coordinates
					points.push( posOnPlanetToProject(point, planet) )

				# create the RPath with the corresponding RTool
				rpath = null
				if g.tools[path.object_type]?
					rpath = new g.tools[path.object_type].RPath(date, data, path._id.$oid, points, if path.lock? then g.items[path.lock] else null)
					
					rpath.lastUpdateDate = path.lastUpdate.$date

					if rpath.constructor.name == "Checkpoint"
						console.log rpath
				else
					console.log "Unknown path type: " + path.object_type
			# when 'AreaToUpdate'
			# 	newAreasToUpdate.push(item)
			else
				continue

	RDiv.updateZIndex(g.sortedDivs)

	if not g.rasterizerMode

		# update areas to update (draw items which lie on those areas)
		# for pk, rectangle of g.areasToUpdate
		# 	if rectangle.intersects(view.bounds)
		# 		g.updateView()
		# 		break

		# loadFonts()
		# view.draw()
		# updateView()
		
		clearTimeout(g.loadingBarTimeout)
		g.loadingBarTimeout = null
		$("#loadingBar").hide()

		dispatchLoadFinished()
	
	if typeof window.saveOnServer == "function"
		g.rasterizeAndSaveOnServer()

	# g.stopLoadingBar()
	return

# this.benchmark_load = ()->
# 	bounds = view.bounds
# 	scale = g.scale
# 	t = g.roundToLowerMultiple(bounds.top, scale)
# 	l = g.roundToLowerMultiple(bounds.left, scale)
# 	b = g.roundToLowerMultiple(bounds.bottom, scale)
# 	r = g.roundToLowerMultiple(bounds.right, scale)

# 	# add areas to load
# 	areasToLoad = []

# 	for x in [l .. r] by scale
# 		for y in [t .. b] by scale
# 			planet = projectToPlanet(new Point(x,y))
# 			pos = projectToPosOnPlanet(new Point(x,y))

# 			area = { pos: pos, planet: planet, x: x/1000, y: y/1000 }

# 			areasToLoad.push(area)

# 	console.log "areasToLoad: "
# 	console.log areasToLoad

# 	Dajaxice.draw.benchmark_load(g.checkError, { areasToLoad: areasToLoad })
# 	return
