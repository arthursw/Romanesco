
# --- load --- #

# @return [Boolean] true if the area was already loaded, false otherwise
this.areaIsLoaded = (pos,planet) ->
	for area in g.loadedAreas
		if area.planet.x == planet.x && area.planet.y == planet.y
			if area.pos.x == pos.x && area.pos.y == pos.y
				return true
	return false

this.areaIsQuickLoaded = (area) ->
	for a in g.loadedAreas
		if a.x == area.x && a.y == area.y
			return true
	return false

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

	if g.previousLoadPosition? and g.previousLoadPosition.subtract(view.center).length<50
		return

	console.log "load"

	# g.startLoadingBar()

	debug = false

	scale = if not debug then g.scale else 500

	g.previousLoadPosition = view.center

	if not area?
		bounds = if not debug then view.bounds else view.bounds.scale(0.3,0.3)
	else
		bounds = area

	if debug
		g.unloadRectangle?.remove()
		g.viewRectangle?.remove()
		g.limitRectangle?.remove()

	# unload:
	# define unload limit rectangle
	unloadDist = Math.round(2*scale)#/g.project.view.zoom)
	
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
	for x, rasterColumn of g.rasters
		for y, raster of rasterColumn
			if not raster.rRectangle.intersects(limit)
				raster.remove()
				delete g.rasters[x][y]
				if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

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

			if not areaIsLoaded(pos, planet)

				if debug
					areaRectangle = new Path.Rectangle(x, y, scale, scale)
					areaRectangle.name = 'debug load area rectangle'
					areaRectangle.strokeWidth = 1
					areaRectangle.strokeColor = 'green'
					g.debugLayer.addChild(areaRectangle)

				area = { pos: pos, planet: planet, x: x/1000, y: y/1000 }

				areasToLoad.push(area)
				if debug then area.rectangle = areaRectangle
				g.loadedAreas.push(area)

	if areasToLoad.length<=0 	# return if there is nothing to load
		return

	# load areas
	if not g.loadingBarTimeout?
		showLoadingBar = ()->
			$("#loadingBar").show()
			return
		g.loadingBarTimeout = setTimeout(showLoadingBar , 0)

	console.log "load areas: " + areasToLoad.length

	box = { left: l/1000, top: t/1000, right: r/1000, bottom: b/1000 }
	Dajaxice.draw.load(load_callback, { box: box, areasToLoad: areasToLoad, zoom: view.zoom })
	# ajaxPost '/load', args, load_callback
	return

# load callback: add loaded RItems
this.load_callback = (results)->

	checkError(results)

	if results.hasOwnProperty('message') && results.message == 'no_paths'
		return

	# set g.me (the server sends the username at each load)
	if not g.me?
		g.me = results.user
		if g.chatJ.find("#chatUserNameInput").length==0
			g.startChatting( g.me )

	# helper to check it the item is already loaded
	itemIsLoaded = (pk)->
		return g.items[pk]?

	# add rasters
	# todo: ask only required rasters (currently, all rasters of all areas are requested, and then ignored if already added :/ )
	for raster in results.rasters
		position = new Point(raster.position).multiply(1000)
		if g.rasters[position.x]?[position.y]?.rZoom == results.zoom then continue
		raster = new Raster(g.romanescoURL + raster.url)		# Paper rasters are positionned from centers, thus we must add 500 to the top left corner position
		if results.zoom > 0.2
			raster.position = position.add(1000/2)
			raster.rRectangle = new Rectangle(position, new Size(1000,1000))
		else if results.zoom > 0.04
			raster.scale(5)
			raster.position = position.add(5000/2)
			raster.rRectangle = new Rectangle(position, new Size(5000,5000))
		else
			raster.scale(25)
			raster.position = position.add(25000/2)
			raster.rRectangle = new Rectangle(position, new Size(25000,25000))
		console.log "raster.position: " + raster.position.toString() + ", raster.scaling" + raster.scaling.toString()
		raster.name = 'raster: ' + raster.position.toString() + ', zoom: ' + results.zoom
		raster.rZoom = results.zoom
		g.rasters[position.x] ?= {}
		g.rasters[position.x][position.y] = raster

	newAreasToUpdate = []

	itemsToLoad = []

	for i in results.items
		item = JSON.parse(i)
		if g.items[item._id.$oid]? 	# if item is loaded: continue
			continue

		if item.rType == 'Box'	# add RLocks: RLock, RLink, RWebsite and RVideoGame
			box = item
			if box.box.coordinates[0].length<5
				console.log "Error: box has less than 5 points"
			
			planet = new Point(box.planetX, box.planetY)
			
			tl = posOnPlanetToProject(box.box.coordinates[0][0], planet)
			br = posOnPlanetToProject(box.box.coordinates[0][2], planet)
			
			data = if box.data? and box.data.length>0 then JSON.parse(box.data) else null

			lock = null
			switch box.object_type
				when 'link'
					lock = new RLink(tl, new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, box.name, box.url, data)
				when 'lock'
					lock = new RLock(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, false, data)
				when 'website'
					lock = new RWebsite(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, data)
				when 'video-game'
					lock = new RVideoGame(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, data)
			
			if data?.loadEntireArea
				g.entireAreas.push(lock)
		else
			itemsToLoad.push(item)

	for i in itemsToLoad
		switch item.rType
			
			when 'Div'			# add RDivs (RText and RMedia)
				div = item
				if div.box.coordinates[0].length<5
					console.log "Error: box has less than 5 points"
				
				planet = new Point(div.planetX, div.planetY)
				
				tl = posOnPlanetToProject(div.box.coordinates[0][0], planet)
				br = posOnPlanetToProject(div.box.coordinates[0][2], planet)
				
				data = if div.data? and div.data.length>0 then JSON.parse(div.data) else null
				date = div.date.$date

				divJ = null
				rdiv = null
				if div.object_type == 'text'
					rdiv = new RText(tl, new Size(br.subtract(tl)), div.owner, div._id.$oid, div.lock, div.message, data, date)
					divJ = rdiv.divJ
				else if div.object_type == 'media'				
					rdiv = new RMedia(tl, new Size(br.subtract(tl)), div.owner, div._id.$oid, div.lock, div.url, data, date)
					divJ = rdiv.divJ

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
					rpath = new g.tools[path.object_type].RPath(date, data, path._id.$oid, points, path.lock)
					if rpath.constructor.name == "Checkpoint"
						console.log rpath
				else
					console.log "Unknown path type: " + path.object_type
			when 'AreaToUpdate'
				newAreasToUpdate.push(item)
			else
				continue

	RDiv.updateZIndex(g.sortedDivs)

	# update areas to update (draw items which lie on those areas)
	g.addAreasToUpdate(newAreasToUpdate)
	for pk, rectangle of g.areasToUpdate
		if rectangle.intersects(view.bounds)
			g.updateView()
			break

	# loadFonts()
	view.draw()
	
	clearTimeout(g.loadingBarTimeout)
	g.loadingBarTimeout = null
	$("#loadingBar").hide()

	# g.stopLoadingBar()
	return

# Another way to load objects 

	# # add RLocks: RLock, RLink, RWebsite and RVideoGame
	# for b in results.boxes
	# 	for box in JSON.parse(b)

	# 		if itemIsLoaded(box._id.$oid)
	# 			continue

	# 		if box.box.coordinates[0].length<5
	# 			console.log "Error: box has less than 5 points"
			
	# 		planet = new Point(box.planetX, box.planetY)
			
	# 		tl = posOnPlanetToProject(box.box.coordinates[0][0], planet)
	# 		br = posOnPlanetToProject(box.box.coordinates[0][2], planet)
			
	# 		data = if box.data? and box.data.length>0 then JSON.parse(box.data) else null

	# 		lock = null
	# 		switch box.object_type
	# 			when 'link'
	# 				lock = new RLink(tl, new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, box.name, box.url, data)
	# 			when 'lock'
	# 				lock = new RLock(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, false, data)
	# 			when 'website'
	# 				lock = new RWebsite(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, data)
	# 			when 'video-game'
	# 				lock = new RVideoGame(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, data)
			
	# 		if data?.loadEntireArea
	# 			g.entireAreas.push(lock)

	# 		newItems.push(lock)

	# # add and draw RPath
	# for p in results.paths
	# 	for path in JSON.parse(p)

	# 		if itemIsLoaded(path._id.$oid)
	# 			continue

	# 		planet = new Point(path.planetX, path.planetY)

	# 		# parse data
	# 		date = path.date.$date
	# 		if path.data? and path.data.length>0
	# 			data = JSON.parse(path.data)
	# 			data.planet = planet

	# 		points = []

	# 		# convert points from planet coordinates to project coordinates
	# 		for point in path.points.coordinates
	# 			points.push( posOnPlanetToProject(point, planet) )

	# 		# create the RPath with the corresponding RTool
	# 		rpath = null
	# 		if g.tools[path.object_type]?
	# 			rpath = new g.tools[path.object_type].RPath(date, data, path._id.$oid, points)
	# 			if rpath.constructor.name == "Checkpoint"
	# 				console.log rpath
	# 		else
	# 			console.log "Unknown path type: " + path.object_type

	# 		newItems.push(rpath)

	# # add the RDivs (RText and RMedia)
	# for d in results.divs
	# 	for div in JSON.parse(d)

	# 		if itemIsLoaded(div._id.$oid)
	# 			continue

	# 		if div.box.coordinates[0].length<5
	# 			console.log "Error: box has less than 5 points"
			
	# 		planet = new Point(div.planetX, div.planetY)
			
	# 		tl = posOnPlanetToProject(div.box.coordinates[0][0], planet)
	# 		br = posOnPlanetToProject(div.box.coordinates[0][2], planet)
			
	# 		data = if div.data? and div.data.length>0 then JSON.parse(div.data) else null
			
	# 		divJ = null
	# 		rdiv = null
	# 		if div.object_type == 'text'
	# 			rdiv = new RText(tl, new Size(br.subtract(tl)), div.owner, div._id.$oid, div.locked, div.message, data)
	# 			divJ = rdiv.divJ
	# 		else if div.object_type == 'media'				
	# 			rdiv = new RMedia(tl, new Size(br.subtract(tl)), div.owner, div._id.$oid, div.locked, div.url, data)
	# 			divJ = rdiv.divJ

	# 		newItems.push(rdiv)

# # (quick) load an area from the server
# this.quick_load = () ->

# 	# manage zoom
# 	newZoom = view.zoom
# 	if view.zoom > 0.2
# 		newZoom = 1
# 	else if view.zoom > 0.04
# 		newZoom = 0.2
# 	else
# 		newZoom = 0.04

# 	zoomLoad = false
# 	if g.lastZoom != newZoom
# 		zoomLoad = true
	
# 	g.lastZoom = newZoom

# 	# return if we must not load (we are too close from the previous load position)
# 	if g.previousLoadPosition? and g.previousLoadPosition.subtract(view.center).length<50 and not zoomLoad
# 		return

# 	# g.startLoadingBar()

# 	debug = false

# 	# define the load rectangle / bounds
# 	scale = if not debug then g.scale else 500

# 	g.previousLoadPosition = view.center

# 	if not area?
# 		bounds = if not debug then view.bounds else view.bounds.scale(0.3,0.3)
# 	else
# 		bounds = area

# 	if debug
# 		g.unloadRectangle?.remove()
# 		g.viewRectangle?.remove()
# 		g.limitRectangle?.remove()
	
# 	# check if we must load rasters (true if rasters do not cover the load rectangle)
# 	rasterLoad = false
# 	totalArea = bounds.area
	
# 	for x, rasterColumn of g.rasters
# 		for y, raster of rasterColumn
# 			totalArea -= bounds.intersect(raster.rRectangle).area
	
# 	if totalArea>0 then rasterLoad = true

# 	# define unload limit rectangle
# 	unloadDist = Math.round(2*scale)#/g.project.view.zoom)
	
# 	if not g.entireArea
# 		limit = bounds.expand(unloadDist)
# 	else
# 		limit = g.entireArea

# 	itemsOutsideLimit = []

# 	# load
# 	# find top, left, bottom and right positions of the area in the quantized space
# 	t = Math.floor(bounds.top / scale)
# 	l = Math.floor(bounds.left / scale)
# 	b = Math.floor(bounds.bottom / scale)
# 	r = Math.floor(bounds.right / scale)
# 	box = { left: l, top: t, right: r, bottom: b }

# 	if debug
# 		g.viewRectangle = new Path.Rectangle(bounds)
# 		g.viewRectangle.name = 'debug load view rectangle'
# 		g.viewRectangle.strokeWidth = 1
# 		g.viewRectangle.strokeColor = 'blue'
# 		g.debugLayer.addChild(g.viewRectangle)

# 		g.limitRectangle = new Path.Rectangle(new Point(l, t), new Point(r, b))
# 		g.limitRectangle.name = 'debug load limit rectangle'
# 		g.limitRectangle.strokeWidth = 2
# 		g.limitRectangle.strokeColor = 'blue'
# 		g.limitRectangle.dashArray = [10, 4]
# 		g.debugLayer.addChild(g.limitRectangle)
	
# 	# add areas to load
# 	# check if there are area to load or not (if nothing to load: return)
# 	areasToLoad = []
# 	for x in [l .. r]
# 		for y in [t .. b]
# 			area = { x: x, y: y }
# 			if not areaIsQuickLoaded(area)			

# 				if debug
# 					areaRectangle = new Path.Rectangle(x*scale, y*scale, scale, scale)
# 					areaRectangle.name = 'debug load area rectangle'
# 					areaRectangle.strokeWidth = 1
# 					areaRectangle.strokeColor = 'green'
# 					g.debugLayer.addChild(areaRectangle)
# 					area.rectangle = areaRectangle
# 				g.loadedAreas.push(area)
# 				areasToLoad.push(area)

# 	if areasToLoad.length<=0 and not zoomLoad and not rasterLoad		# return if there is nothing to load
# 		return

# 	# unload:

# 	# remove RItems which are not on within limit anymore AND in area which must be unloaded
# 	# (do not remove items on an area which is not unloaded, otherwise they wont be reloaded if user comes back on it)
# 	for own pk, item of g.items
# 		if not item.getBounds().intersects(limit)
# 			itemsOutsideLimit.push(item)

# 	if debug
# 		g.unloadRectangle = new Path.Rectangle(limit)
# 		g.unloadRectangle.name = 'debug load unload rectangle'
# 		g.unloadRectangle.strokeWidth = 1
# 		g.unloadRectangle.strokeColor = 'red'
# 		g.unloadRectangle.dashArray = [10, 4]
# 		g.debugLayer.addChild(g.unloadRectangle)

# 	if debug
# 		removeRectangle = (rectangle)->
# 			removeRect = ()-> rectangle.remove()
# 			setTimeout(removeRect, 1500)
# 			return
	
# 	# remove rasters which are outside the limit
# 	for x, rasterColumn of g.rasters
# 		for y, raster of rasterColumn
# 			if not raster.rRectangle.intersects(limit)
# 				raster.remove()
# 				delete g.rasters[x][y]
# 				if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

# 	# remove loaded areas which must be unloaded
# 	i = g.loadedAreas.length
# 	while i--
# 		loadedArea = g.loadedAreas[i]
# 		rectangle = new Rectangle(loadedArea.x*scale, loadedArea.y*scale, scale, scale)
		
# 		if not rectangle.intersects(limit)

# 			if debug
# 				area.rectangle.strokeColor = 'red'
# 				removeRectangle(area.rectangle)

# 			# remove area from loaded areas
# 			g.loadedAreas.splice(i,1)

# 			# remove items on this area
# 			# items to remove must not intersect with the limit, and can overlap two areas:
# 			j = itemsOutsideLimit.length
# 			while j--
# 				item = itemsOutsideLimit[j]
# 				if item.getBounds().intersects(rectangle)
# 					item.remove()
# 					itemsOutsideLimit.splice(j,1)
	
# 	itemsOutsideLimit = null

# 	if not g.loadingBarTimeout?
# 		showLoadingBar = ()->
# 			$("#loadingBar").show()
# 			return
# 		g.loadingBarTimeout = setTimeout(showLoadingBar , 0)

# 	console.log "areasToLoad:"
# 	console.log areasToLoad.toString()
# 	console.log "loadedAreas:"
# 	console.log g.loadedAreas.toString()

# 	Dajaxice.draw.quick_load(quick_load_callback, { box: box, boxes: areasToLoad, zoom: newZoom })
# 	# ajaxPost '/load', args, load_callback
# 	return

# # (quick) load callback: add loaded RItems
# this.quick_load_callback = (results)->

# 	checkError(results)

# 	# set g.me (the server sends the username at each load)
# 	if not g.me?
# 		g.me = results.user
# 		if g.chatJ.find("#chatUserNameInput").length==0
# 			g.startChatting( g.me )

# 	# remove rasters which are at different zoom
# 	for x, rasterColumn of g.rasters
# 		for y, raster of rasterColumn
# 			if raster.rZoom != results.zoom
# 				raster.remove()
# 				delete g.rasters[x][y]
# 				if g.isEmpty(g.rasters[x]) then delete g.rasters[x]
	
# 	# add rasters
# 	# todo: ask only required rasters (currently, all rasters of all areas are requested, and then ignored if already added :/ )
# 	for raster in results.rasters
# 		position = new Point(raster.position).multiply(1000)
# 		if g.rasters[position.x]?[position.y]?.rZoom == results.zoom then continue
# 		raster = new Raster(g.romanescoURL + raster.url)		# Paper rasters are positionned from centers, thus we must add 500 to the top left corner position
# 		if results.zoom > 0.2
# 			raster.position = position.add(1000/2)
# 			raster.rRectangle = new Rectangle(position, new Size(1000,1000))
# 		else if results.zoom > 0.04
# 			raster.scale(5)
# 			raster.position = position.add(5000/2)
# 			raster.rRectangle = new Rectangle(position, new Size(5000,5000))
# 		else
# 			raster.scale(25)
# 			raster.position = position.add(25000/2)
# 			raster.rRectangle = new Rectangle(position, new Size(25000,25000))
# 		# console.log "raster.position: " + raster.position.toString() + ", raster.scaling" + raster.scaling.toString()
# 		raster.name = 'raster: ' + raster.position.toString() + ', zoom: ' + results.zoom
# 		raster.rZoom = results.zoom
# 		g.rasters[position.x] ?= {}
# 		g.rasters[position.x][position.y] = raster
# 		g.viewUpdated = false

# 	newAreasToUpdate = []

# 	for i in results.items
# 		item = JSON.parse(i)
# 		if g.items[item._id.$oid]? 	# if item is loaded: continue
# 			continue
# 		switch item.rType
			
# 			when 'Box' 			# add RLocks: RLock, RLink, RWebsite and RVideoGame
# 				box = item
# 				if box.box.coordinates[0].length<5
# 					console.log "Error: box has less than 5 points"
				
# 				planet = new Point(box.planetX, box.planetY)
				
# 				tl = posOnPlanetToProject(box.box.coordinates[0][0], planet)
# 				br = posOnPlanetToProject(box.box.coordinates[0][2], planet)
				
# 				data = if box.data? and box.data.length>0 then JSON.parse(box.data) else null

# 				lock = null
# 				switch box.object_type
# 					when 'link'
# 						lock = new RLink(tl, new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, box.name, box.url, data)
# 					when 'lock'
# 						lock = new RLock(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, false, data)
# 					when 'website'
# 						lock = new RWebsite(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, data)
# 					when 'video-game'
# 						lock = new RVideoGame(tl,new Size(br.subtract(tl)), box.owner, box._id.$oid, box.message, data)
				
# 				if data?.loadEntireArea
# 					g.entireAreas.push(lock)

# 			when 'Div'			# add RDivs (RText and RMedia)
# 				div = item
# 				if div.box.coordinates[0].length<5
# 					console.log "Error: box has less than 5 points"
				
# 				planet = new Point(div.planetX, div.planetY)
				
# 				tl = posOnPlanetToProject(div.box.coordinates[0][0], planet)
# 				br = posOnPlanetToProject(div.box.coordinates[0][2], planet)
				
# 				data = if div.data? and div.data.length>0 then JSON.parse(div.data) else null
				
# 				divJ = null
# 				rdiv = null
# 				if div.object_type == 'text'
# 					rdiv = new RText(tl, new Size(br.subtract(tl)), div.owner, div._id.$oid, div.locked, div.message, data)
# 					divJ = rdiv.divJ
# 				else if div.object_type == 'media'				
# 					rdiv = new RMedia(tl, new Size(br.subtract(tl)), div.owner, div._id.$oid, div.locked, div.url, data)
# 					divJ = rdiv.divJ

# 			when 'Path' 		# add RPaths
# 				path = item
# 				planet = new Point(path.planetX, path.planetY)

# 				# parse data
# 				date = path.date.$date
# 				if path.data? and path.data.length>0
# 					data = JSON.parse(path.data)
# 					data.planet = planet

# 				points = []

# 				# convert points from planet coordinates to project coordinates
# 				for point in path.points.coordinates
# 					points.push( posOnPlanetToProject(point, planet) )

# 				# create the RPath with the corresponding RTool
# 				rpath = null
# 				if g.tools[path.object_type]?
# 					rpath = new g.tools[path.object_type].RPath(date, data, path._id.$oid, points)
# 					if rpath.constructor.name == "Checkpoint"
# 						console.log rpath
# 				else
# 					console.log "Unknown path type: " + path.object_type
# 			when 'AreaToUpdate'
# 				newAreasToUpdate.push(item)

# 	# update areas to update (draw items which lie on those areas)
# 	# if not g.willUpdateAreasToUpdate
# 	# 	g.updateAreasToUpdate()
	
# 	g.addAreasToUpdate(newAreasToUpdate)
# 	for pk, rectangle of g.areasToUpdate
# 		if rectangle.intersects(view.bounds)
# 			g.updateView()
# 			break

# 	# loadFonts()
# 	view.draw()
	
# 	clearTimeout(g.loadingBarTimeout)
# 	g.loadingBarTimeout = null
# 	$("#loadingBar").hide()

# 	# g.stopLoadingBar()
# 	return

this.benchmark_load = ()->
	bounds = view.bounds
	scale = g.scale
	t = g.roundToLowerMultiple(bounds.top, scale)
	l = g.roundToLowerMultiple(bounds.left, scale)
	b = g.roundToLowerMultiple(bounds.bottom, scale)
	r = g.roundToLowerMultiple(bounds.right, scale)

	# add areas to load
	areasToLoad = []

	for x in [l .. r] by scale
		for y in [t .. b] by scale
			planet = projectToPlanet(new Point(x,y))
			pos = projectToPosOnPlanet(new Point(x,y))

			area = { pos: pos, planet: planet, x: x/1000, y: y/1000 }

			areasToLoad.push(area)

	console.log "areasToLoad: "
	console.log areasToLoad

	Dajaxice.draw.benchmark_load(g.checkError, { areasToLoad: areasToLoad })
	return


# --- save path --- #

# this.pathOverlapsTwoPlanets = (path) ->

# 	limit = getLimit()

# 	limitPathV = null
# 	limitPathH = null

# 	if view.bounds.contains(limit)
# 		limitPathV = new Path()
# 		limitPathV.add(limit.x,view.bounds.top)
# 		limitPathV.add(limit.x,view.bounds.bottom)

# 		limitPathH = new Path()
# 		limitPathH.add(view.bounds.left, limit.y)
# 		limitPathH.add(view.bounds.right, limit.y)

# 	if limitPathV?
# 		intersections = path.getIntersections(limitPathV)
# 		limitPathV.remove()
# 		if intersections.length>0
# 			return true

# 	if limitPathH?
# 		intersections = path.getIntersections(limitPathH)
# 		limitPathH.remove()
# 		if intersections.length>0
# 			return true

# 	return false

# this.savePath = (rpath) ->
	
# 	path = rpath.controlPath
# 	data = null

# 	if path.segments.length<2 # User want to add a single point
# 		p0 = path.segments[0].point
# 		path.add( new Point(p0.x+1, p0.y) )

# 	if rpath is PreciseBrush
# 		path = rpath.controlPath.copy()
# 		path.flatten(25)

# 	if pathOverlapsTwoPlanets(path)
# 		romanesco_alert("You can not add line in between two planets, this is not yet supported.", "info")
# 		return

# 	planet = rpath.planet()
# 	points = rpath.pathOnPlanet()

# 	Dajaxice.draw.savePath( savePath_callback, {'points':points, 'pID': rpath.id, 'planet': pointToObj(planet), 'object_type': rpath.constructor.rname, 'data':JSON.stringify(rpath.data) } )

# this.savePath_callback = (result)->
# 	checkError(result)
# 	g.paths[result.pID].setPK(result.pk)
	
# 	g.chatSocket.emit( "setPathPK", result.pID, result.pk)

# --- update path --- #

# this.updatePath = (rpath, updateType='data') ->

# 	if not rpath.pk?
# 		return

# 	path = rpath.controlPath

# 	if updateType == 'points'

# 		data = null

# 		if path.segments.length<2 # User want to add a single point
# 			p0 = path.segments[0].point
# 			path.add( new Point(p0.x+1, p0.y) )

# 		if rpath is PreciseBrush
# 			path = rpath.controlPath.copy()
# 			path.flatten(25)
# 			data = rpath.getData()

# 		if pathOverlapsTwoPlanets(path)
# 			romanesco_alert("You can not update a line in between two planets, this is not yet supported.", "info")
# 			return

# 		p0 = path.segments[0].point
# 		planet = projectToPlanet( p0 )
# 		points = getPathOnPlanet(path, rpath.constructor.Shape?)

# 		pointsProject = []

# 		for segment in path.segments
# 			pointsProject.push( {x: segment.point.x, y: segment.point.y} )

# 		Dajaxice.draw.updatePath( updatePath_callback, {'pk': rpath.pk, 'points':points, 'planet': pointToObj(planet), 'data':JSON.stringify(rpath.data) } )

# 	else if updateType == 'data'
# 		Dajaxice.draw.updatePath( updatePath_callback, {'pk': rpath.pk, 'data':JSON.stringify(rpath.data) } )
	
# 	if g.me?
# 		g.chatSocket.emit( "updatePath", g.me, rpath.pk, pointsProject, rpath.data.fillColor, rpath.data.strokeColor, rpath.data.strokeWidth )

# this.updatePath_callback = (result)->
# 	checkError(result)

# --- delete path --- #

# this.deletePath = (rpath)->
# 	Dajaxice.draw.deletePath(deletePath_callback,{ pk:rpath.pk })

# this.deletePath_callback = (result)->
# 	if checkError(result)
# 		g.chatSocket.emit( "delete path", result.pk )

# --- check box --- #

# this.boxFromPoints = (rectangle)->
# 	# remove margin to ignore intersections of paths which are close to the edges

# 	planet = pointToObj( projectToPlanet(rectangle.topLeft) )

# 	tlOnPlanet = projectToPosOnPlanet(rectangle.topLeft, planet)
# 	brOnPlanet = projectToPosOnPlanet(rectangle.bottomRight, planet)

# 	points = []
# 	points.push(pointToArray(tlOnPlanet))
# 	points.push(pointToArray(projectToPosOnPlanet(rectangle.topRight, planet)))
# 	points.push(pointToArray(brOnPlanet))
# 	points.push(pointToArray(projectToPosOnPlanet(rectangle.bottomLeft, planet)))
# 	points.push(pointToArray(tlOnPlanet))

# 	return { points:points, planet: pointToObj(planet), tl: tlOnPlanet, br: brOnPlanet }

# this.boxOverlapsTwoPlanets = (box) ->
# 	limit = getLimit()

# 	if ( box.left < limit.x && box.right > limit.x ) || ( box.top < limit.y && box.bottom > limit.y )
# 		romanesco_alert("You can not add anything in between two planets, this is not yet supported.", "info")
# 		return true
# 	return false

# # --- save div --- #

# this.saveDiv = (rectangle, object_type, message, name, url) ->

# 	if boxOverlapsTwoPlanets(rectangle)
# 		return

# 	if object_type == 'text' or object_type == 'media'
# 		Dajaxice.draw.saveDiv( saveDiv_callback, { 'box':boxFromPoints(rectangle), 'object_type': object_type, 'url': url } )
# 	else if object_type == 'lock' or object_type == 'link'
# 		Dajaxice.draw.saveBox( saveDiv_callback, { 'box':boxFromPoints(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url } )

# this.saveDiv_callback = (result, owner=true)->
	
# 	if not checkError(result)
# 		return

# 	tl = posOnPlanetToProject(result.box.tl, result.box.planet)
# 	br = posOnPlanetToProject(result.box.br, result.box.planet)

# 	div = null
# 	if result.object_type == 'text'
# 		div = new RText(tl, br.subtract(tl), result.owner, result.pk, result.message, result.fillColor, result.strokeColor, result.strokeWidth)
# 	else if result.object_type == 'media'
# 		div = new RMedia(tl, br.subtract(tl), result.owner, result.pk, result.url, result.fillColor, result.strokeColor, result.strokeWidth)
# 	else if result.object_type == 'lock'
# 		div = new RLock(tl, br.subtract(tl), result.owner, result.pk, result.message, true, result.fillColor, result.strokeColor, result.strokeWidth)
# 	else if result.object_type == 'link'
# 		div = new RLink(tl, br.subtract(tl), result.owner, result.pk, result.message, result.name, result.url, result.fillColor, result.strokeColor, result.strokeWidth)
	
# 	if owner
# 		g.chatSocket.emit( "createDiv", result)
# 		div.select()

# # --- update div --- #

# this.updateDiv = (div) ->
# 	if not div?
# 		div = g.divToUpdate
# 		if not div?
# 			return
# 	divJ = div.divJ

# 	if not div.bottomRight?
# 		console.log div
# 		console.log "error"
# 		return

# 	tl = div.position
# 	br = div.bottomRight()
	
# 	if boxOverlapsTwoPlanets(tl,br)
# 		return
	
# 	data = 
# 		box: boxFromPoints(tl,br)
# 		pk: div.pk
# 		object_type: div.object_type
# 		message: div.message
# 		url: div.url
# 		fillColor: div.fillColor
# 		strokeColor: div.strokeColor
# 		strokeWidth: div.strokeWidth
# 		data: JSON.stringify(div.data)

# 	if div.object_type == 'text' or div.object_type == 'media' 
# 		Dajaxice.draw.updateDiv( updateDiv_callback, data )
# 	else if div.object_type == 'lock' or div.object_type == 'link' 
# 		data.name = div.name
# 		Dajaxice.draw.updateBox( updateDiv_callback, data )

# 	if g.me? # todo: refactor: projectToPlanet(tl), projectToPlanet(br) was viewToPlanetJson(tl) it is not working anymore.
# 		g.chatSocket.emit( "updateDiv", g.me, div.pk, projectToPlanet(tl), projectToPlanet(br), data.name, data.message, data.url, data.fillColor, data.strokeColor, data.strokeWidth )

# this.updateDiv_callback = (result)->
# 	checkError(result)

# this.deleteDiv = (div)->
# 	if div.object_type == 'text' or div.object_type == 'media'
# 		Dajaxice.draw.deleteDiv( deleteDiv_callback, { 'pk': div.pk } )
# 	else if div.object_type == 'lock' or div.object_type == 'link'
# 		Dajaxice.draw.deleteBox( deleteDiv_callback, { 'pk': div.pk } )

# this.deleteDiv_callback = (result)->
# 	if checkError(result)
# 		g.chatSocket.emit( "delete div", result.pk )

# --- update box --- #

# this.updateBox = (tl, br, message, pk, name="", url="") ->
# 	if boxOverlapsTwoPlanets(tl,br)
# 		return
# 	bb = { tl: pointToObj(viewToScreen(tl)), br: pointToObj(viewToScreen(br)) }
# 	Dajaxice.draw.updateBox( saveBox_callback, { 'box':boxFromPoints(tl,br), 'bb': bb, 'object_type': g.selectedTool.name, 'message': message, 'pk': pk , 'name':name, 'url': url} )

# this.deleteBox = (pk)->	
# 	Dajaxice.draw.deleteBox( checkError, { 'pk': pk } )


# this.saveBox = (tl, br, message, name="", url="") ->
# 	if boxOverlapsTwoPlanets(tl,br)
# 		return
# 	bb = { tl: pointToObj(viewToScreen(tl)), br: pointToObj(viewToScreen(br)) }
# 	Dajaxice.draw.saveBox( saveBox_callback, { 'box':boxFromPoints(tl,br), 'bb': bb, 'object_type': g.selectedTool.name, 'message': message, 'name':name, 'url': url } )

# this.saveBox_callback = (result)->
# 	checkError(result)

# 	planet = extractPlanet(result.planet)
# 	coordinates = if result.box.hasOwnProperty("coordinates") then result.box.coordinates[0] else result.box[0]
# 	tl = posOnPlanetAToView(coordinates[0], planet)
# 	br = posOnPlanetAToView(coordinates[2], planet)
	
# 	# tl = screenToView(result.bb.tl)
# 	# br = screenToView(result.bb.br)
	
# 	lock = null
# 	if result.object_type == 'link'
# 		addLink(tl, br, result.url, result.name, result.message, result.owner, result.pk, result.modified)
# 	else if result.object_type == 'lock'
# 		lock = new RLock(tl, br.subtract(tl), result.owner, result.pk, result.message)
# 		# addLock(tl, br, result.message, result.owner, result.pk, result.modified)		
# 		g.medias.push(lock.divJ)
