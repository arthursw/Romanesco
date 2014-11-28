
this.checkError = (result)->
	if result.state == 'not_logged_in'
		romanesco_alert("You must be logged in to update drawings to the database.", "info")
	if result.state == 'error'
			if result.message == 'invalid_url'
				romanesco_alert("Your URL is invalid or does not point to an existing page.", "error")
			else
				romanesco_alert("Error: " + result.message, "error")
	else if result.state == 'system_error'
		console.log result.message

# load callback
this.load_callback = (results)->
	checkError(results)
	if results.hasOwnProperty('message') && results.message == 'no_paths'
		return

	g.me = results.user

	for p in results.paths
		for path in JSON.parse(p)

			if g.loadedPaths.indexOf(path._id.$oid)!=-1
				continue

			g.loadedPaths.push(path._id.$oid)
			planet = extractPlanet(path.planet)

			# g.selectedTool = g.tools[path.object_type]
			if path.object_type == 'brush'
				p = new Path()
				for point in path.points.coordinates
					p.add( posOnPlanetAToView(point, planet) )
			else if path.object_type == 'rectangle'
				tl = posOnPlanetAToView( path.points.coordinates[0], planet )
				br = posOnPlanetAToView( path.points.coordinates[2], planet )
				p = new Path.Rectangle(tl,br)
			else if path.object_type == 'circle'
				p1 = posOnPlanetAToView( path.points.coordinates[0], planet )
				p2 = posOnPlanetAToView( path.points.coordinates[2], planet )
				mid = midPoint(p1,p2)
				p = new Path.Circle(mid,Math.abs(p2.x-p1.x)*0.5)


			p.strokeColor = path.strokeColor
			p.strokeWidth = path.strokeWidth
			p.fillColor = path.fillColor
			p.pID = path._id.$oid
			g.paths[path._id.$oid] = p

	for b in results.boxes
		for box in JSON.parse(b)
			if box.box.coordinates[0].length<5
					console.log "Error: link has less than 5 points"
			
			planet = extractPlanet(box.planet)
			
			tl = posOnPlanetAToView(box.box.coordinates[0][0], planet)
			br = posOnPlanetAToView(box.box.coordinates[0][2], planet)

			# tl = screenToView(box.bb.tl)
			# br = screenToView(box.bb.br)
			
			if box.object_type == 'link'
				addLink(tl, br, box.url, box.name, box.message, box.owner, box._id.$oid)
			else if box.object_type == 'lock'
				addLock(tl, br, box.message, box.owner, box._id.$oid)

	view.draw()

this.savePaths_callback = (result)->
	checkError(result)
	for pID, i in result.pIDs
		g.paths[result.pks[i]] = g.paths[pID]
		delete g.paths[pID]

this.saveBoxes_callback = (result)->
	checkError(result)

	planet = extractPlanet(result.planet)
	coordinates = if result.box.hasOwnProperty("coordinates") then result.box.coordinates[0] else result.box[0]
	tl = posOnPlanetAToView(coordinates[0], planet)
	br = posOnPlanetAToView(coordinates[2], planet)
	
	# tl = screenToView(result.bb.tl)
	# br = screenToView(result.bb.br)
	
	if result.object_type == 'link'
		addLink(tl, br, result.url, result.name, result.message, result.owner, result.pk, result.modified)
	else if result.object_type == 'lock'
		addLock(tl, br, result.message, result.owner, result.pk, result.modified)
		
this.delete_callback = (result)->
	deletedLines = JSON.parse(result.deletedLines)
	newLines = JSON.parse(result.newLines)
	for deletedLine,i in deletedLines
		g.paths[deletedLine].remove()
	load_callback(newLines)

this.areaIsLoaded = (pos,planet) ->
	for area in g.loadedAreas
		if area.planet.x == planet.x && area.planet.y == planet.y
			if area.pos.x == pos.x && area.pos.y == pos.y
				return true
	return false

this.load = () ->
	[tlX, tlY, brX, brY] = screenBox()

	# add areas to load
	areasToLoad = new Array()
	for xi in [tlX .. brX]
		for yi in [tlY .. brY]
			x = xi*g.scale
			y = yi*g.scale
			planet = screenToPlanet(new Point(x,y))
			pos = screenToPosOnPlanet(new Point(x,y))
			if not areaIsLoaded(pos, planet)
				area = { pos: pointToObj(pos), planet: pointToObj(planet) }
				# console.log "load planet.x:" + area.planet.x + ", planet.y:" + area.planet.y + ", pos.x:" + area.pos.x + ", pos.y:" + area.pos.y
				areasToLoad.push(area)
				g.loadedAreas.push(area)

	# unload
	unloadDist = 2
	
	limitTL = worldAToView( [ tlX-(unloadDist-1), tlY-(unloadDist-1) ] )
	limitBR = worldAToView( [ brX+unloadDist, brY+unloadDist ] )
	limit = new Rectangle(limitTL, limitBR)

	for own pk, path of g.paths
		if not path.strokeBounds?.intersects(limit)
			# console.log "unload: " + pk
			g.removeItem(g.loadedPaths, pk)
			delete g.paths[pk]

	i = g.locks.length
	while i--
		lock = g.locks[i]
		pos = lock.position()
		lockRect = new Rectangle(pos.left, pos.top, lock.width(), lock.height())
		if not lockRect.intersects(limit)
			pk = lock.attr("data-pk")
			lock.remove()
			g.locks.splice(i,1)
			g.removeItem(g.loadedPaths, pk)


	# remove loaded areas which where unloaded
	i = g.loadedAreas.length
	while i--
		loadedArea = g.loadedAreas[i]
		pos = posOnPlanetToScreen(loadedArea.pos, loadedArea.planet)
		wpos = [ pos.x / g.scale, pos.y / g.scale ]


		if wpos[0] <= tlX-unloadDist || wpos[0] >= brX+unloadDist || wpos[1] <= tlY-unloadDist || wpos[1] >= brY+unloadDist
			area = g.loadedAreas[i]

			# for la in g.loadedAreas
			# 	console.log "loaded: planet.x:" + la.planet.x + ", planet.y:" + la.planet.y + ", pos.x:" + la.pos.x + ", pos.y:" + la.pos.y

			# console.log "unloaded wpos[0]:" + wpos[0] + ", wpos[1]:" + wpos[1] + ", tl, br: " + tlX + ", " + tlY + ", " + brX + ", " + brY
			# console.log "unloaded planet.x:" + area.planet.x + ", planet.y:" + area.planet.y + ", pos.x:" + area.pos.x + ", pos.y:" + area.pos.y

			g.loadedAreas.splice(i,1)

	if areasToLoad.length<=0
		return

	args = new Object()
	args.areasToLoad = areasToLoad
	Dajaxice.draw.load(load_callback,args)

this.splitPath = (path) ->
	limit = getLimit()

	limitPath = null
	if limit.x>0 && limit.x<view.size.width
		limitPath = new Path()
		limitPath.add(limit.x,0)
		limitPath.add(limit.x,view.size.height)

	if limit.y>0 && limit.y<view.size.height		
		if not limitPath?
			limitPath = new Path()
		else
			limitPath.add(0, view.size.height)
		limitPath.add(0, limit.y)
		limitPath.add(view.size.width, limit.y)

	if limitPath?
		# limitPath.strokeWidth = 5
		# limitPath.strokeColor = "#FF00FF"

		# setTimeout( (()->limitPath.remove()) , 500)

		intersections = path.getIntersections(limitPath)
		
		paths = new Array()
		# cs = []
		for intersection in intersections

			romanesco_alert("You can not add line in between two planets, this is not yet supported.", "info")
			return

			# cs.push( new Path.Circle(center: intersection.point, radius: 5, fillColor: '#009dec'))
			nextPath = path.split(intersection.offset)
			paths.push(path)
			path = nextPath

			path.pID = g.id
			g.paths[g.id] = path
			g.id--


		# setTimeout( (()-> c.remove() for c in cs ) , 500)
		paths.push(path)
		limitPath.remove()
	else
		paths = [path]

	return paths

this.savePath = (path) ->

	if path.segments.length<2 # User want to add a single point
		p0 = path.segments[0].point
		path.add( new Point(p0.x+1, p0.y) )

	paperPaths = splitPath(path)

	if not paperPaths? or paperPaths.length==0 # error in split: interesects planet boundaries
		return

	paths = new Array()

	for path in paperPaths
		points = new Array()

		if path.segments.length<2
			console.log "Error: path.segments has less than 2 points."
			continue
		# path has at least two points
		p0 = path.segments[0].point
		p1 = path.segments[1].point
		midPoint = new Point( (p0.x+p1.x)*0.5, (p0.y+p1.y)*0.5 )
		planet = viewToPlanet( midPoint )

		for segment in path.segments
			p = viewToPosOnPlanetA(segment.point)
			points.push( p )
		paths.push( { points: points, planet: pointToObj(planet), pID: path.pID } )

	Dajaxice.draw.savePaths( savePaths_callback, {'paths':paths, 'fillColor': path.fillColor?.toCSS(true), 'strokeColor': path.strokeColor.toCSS(true), 'strokeWidth': path.strokeWidth, 'object_type': g.selectedTool.name } )
	
this.boxFromPoints = (tl, br)->
	planet = viewToPlanet(tl)
	points = new Array()
	points.push(viewToPosOnPlanetA(tl))
	points.push(viewToPosOnPlanetA(new Point(br.x, tl.y)))
	points.push(viewToPosOnPlanetA(br))
	points.push(viewToPosOnPlanetA(new Point(tl.x, br.y)))
	points.push(viewToPosOnPlanetA(tl))
	return { points:points, planet: pointToObj(planet) }

this.checkPosition = (tl,br) ->
	box = new Rectangle(tl,br)

	limit = getLimit()

	if box.contains(limit) || ( box.left < limit.x && box.right > limit.x ) || ( box.top < limit.y && box.bottom > limit.y )
		romanesco_alert("You can not add any lock or link in between two planets, this is not yet supported.", "info")
		return false
	return true

this.splitBox = (box) ->

	boxPath = Path.Rectangle(box)

	# boxPath.strokeColor = "#FF00FF"
	# boxPath.strokeWidth = 3
	# setTimeout( (()-> boxPath.remove()) , 500)

	limit = getLimit()

	boxes = new Array()
	
	if box.contains(limit) || ( box.left < limit.x && box.right > limit.x ) || ( box.top < limit.y && box.bottom > limit.y )
		romanesco_alert("You can not add any lock or link in between two planets, this is not yet supported.", "info")
		return
	else
		boxes.push( boxFromPoints(box.topLeft, box.bottomRight) )

	# if box.contains(limit)

	# 	bp1 = Path.Rectangle( { from: box.topLeft, to: limit, strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp1.remove()) , 500)
	# 	bp2 = Path.Rectangle( { from: new Point(limit.x,box.y), to: new Point(box.right, limit.y), strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp2.remove()) , 500)
	# 	bp3 = Path.Rectangle( { from: new Point(box.x,limit.y), to: new Point(limit.x, box.bottom), strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp3.remove()) , 500)
	# 	bp4 = Path.Rectangle( { from: limit, to: box.bottomRight, strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp4.remove()) , 500)

	# 	boxes.push( boxFromPoints(box.topLeft, limit) )
	# 	boxes.push( boxFromPoints( new Point(limit.x,box.y), new Point(box.right, limit.y) ) )
	# 	boxes.push( boxFromPoints( new Point(box.x,limit.y), new Point(limit.x, box.bottom) ) )
	# 	boxes.push( boxFromPoints( limit, box.bottomRight ) )

	# else if box.left < limit.x && box.right > limit.x

	# 	bp1 = Path.Rectangle( { from: box.topLeft, to: new Point(limit.x, box.bottom), strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp1.remove()) , 500)
	# 	bp2 = Path.Rectangle( { from: new Point(limit.x,box.y), to: box.bottomRight, strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp2.remove()) , 500)

	# 	boxes.push( boxFromPoints( box.topLeft, new Point(limit.x, box.bottom) ) )
	# 	boxes.push( boxFromPoints( new Point(limit.x,box.y), box.bottomRight ) )
	# else if box.top < limit.y && box.bottom > limit.y

	# 	bp1 = Path.Rectangle( { from: box.topLeft, to: new Point(box.right, limit.y), strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp1.remove()) , 500)
	# 	bp2 = Path.Rectangle( { from: new Point(box.x,limit.y), to: box.bottomRight, strokeColor: "#00FFFF", strokeWidth: 2 } )
	# 	setTimeout( (()-> bp2.remove()) , 500)

	# 	boxes.push( boxFromPoints( box.topLeft, new Point(box.right, limit.y) ) )
	# 	boxes.push( boxFromPoints( new Point(box.x,limit.y), box.bottomRight ) )
	# else
	# 	boxes.push( boxFromPoints(box.topLeft, box.bottomRight) )

	return boxes

this.saveBox = (tl, br, message, name="", url="", modify=false, pk=null) ->
	boxes = splitBox( new Rectangle(tl, br) )
	if boxes.length == 0 # box intersect planet boundaries
		return
	bb = { tl: pointToObj(viewToScreen(tl)), br: pointToObj(viewToScreen(br)) }
	Dajaxice.draw.saveBoxes( saveBoxes_callback, { 'boxes':boxes, 'bb': bb, 'object_type': g.selectedTool.name, 'message': message, 'name':name, 'url': url, 'modify': modify, 'pk': pk } )
