# todo: Actions, undo & redo...
# todo: strokeWidth min = 0?
# todo change bounding box selection
# todo/bug?: if @data? but not @data.id? then @id is not initialized, causing a bug when saving..
# todo: have a selectPath (simplified version of group to test selection)instead of the group ?
# todo: replace smooth by rsmooth and rdata in general.

# important todo: pass args in deffered exec to update 'points' or 'data'

class RPath
	@rname = 'Pen'
	@rdescription = "The classic and basic pen tool"
	@cursorPosition = { x: 24, y: 0 }
	@cursorDefault = "crosshair"

	@hitOptions =
		segments: true
		stroke: true
		fill: true
		selected: true
		tolerance: 5

	@constructor.secureDistance = 2 	# the points of the flattened path must not be 5 pixels away from the recorded points

	@parameters: ()->
		return parameters =
			'General': 
				# zoom: g.parameters.zoom
				# displayGrid: g.parameters.displayGrid
				# snap: g.parameters.snap 
				align: g.parameters.align
				distribute: g.parameters.distribute
				duplicate: g.parameters.duplicate
				delete: g.parameters.delete
				editTool:
					type: 'button'
					label: 'Edit tool'
					default: ()=> g.toolEditor(@)
			'Style':
				strokeWidth: $.extend(true, {}, g.parameters.strokeWidth)
				strokeColor: $.extend(true, {}, g.parameters.strokeColor)
				fillColor: $.extend(true, {}, g.parameters.fillColor)

	constructor: (@date=null, @data=null, @pk=null, points=null) ->
		@selectedSegment = null
		
		@id = if @data? then @data.id else Math.random()

		g.paths[@id] = @

		if not @data?
			@data = new Object()
			@data.id = @id
			for name, folder of g.gui.__folders
				if name=='General' then continue
				for controller in folder.__controllers
					@data[controller.property] = controller.rValue()
		if @pk?
			@setPK(@pk, false)
		if points?
			@loadPath(points)
	
	duplicate: ()->
		copy = new @constructor(new Date(), @getData(), null, @pathOnPlanet())
		copy.save()
		return copy

	# todo: doc
	pathWidth: ()->
		return @data.strokeWidth

	getBounds: ()->
		return @controlPath.strokeBounds

	moveBy: (delta, userAction)->
		@group.position.x += delta.x
		@group.position.y += delta.y
		if userAction
			g.defferedExecution(@update, @getPk())
			# if g.me? and userAction then g.chatSocket.emit( "double click", g.me, @pk, g.eventObj(event))
		return

	moveTo: (position, userAction)->
		bounds = @getBounds()
		delta = @group.position.subtract(bounds.center)
		@group.position = position.add(delta)
		if userAction
			g.defferedExecution(@update, @getPk())
			# if g.me? and userAction then g.chatSocket.emit( "double click", g.me, @pk, g.eventObj(event))
		return position.add(delta)

	projectToRaster: (point)->
		return point.subtract(@canvasRaster.bounds.topLeft)

	prepareHitTest: (fullySelected=true, strokeWidth)->
		console.log "prepareHitTest"
		@hitTestSelected = @controlPath.selected

		if fullySelected
			@hitTestFullySelected = @controlPath.fullySelected
			@controlPath.fullySelected = true
		else
			@controlPath.selected = true

		@hitTestControlPathVisible = @controlPath.visible
		@controlPath.visible = true
		@hitTestGroupVisible = @drawing.visible
		@drawing.visible = true
		
		@hitTestStrokeWidth = @controlPath.strokeWidth
		if strokeWidth then @controlPath.strokeWidth = strokeWidth

		@raster?.visible = false
		@canvasRaster?.visible = false

	finishHitTest: (fullySelected=true)->
		console.log "finishHitTest"
		if fullySelected then @controlPath.fullySelected = @hitTestFullySelected
		@controlPath.selected = @hitTestSelected
		@controlPath.visible = @hitTestControlPathVisible
		@drawing.visible = @hitTestGroupVisible
		@controlPath.strokeWidth = @hitTestStrokeWidth

		@raster?.visible = true
		@canvasRaster?.visible = true

	hitTest: (point, hitOptions)->
		return @selectionRectangle.hitTest(point)

	# when hit through websocket, must be (fully)Selected to hitTest
	performeHitTest: (point, hitOptions, fullySelected=true)->
		@prepareHitTest(fullySelected, 1)
		hitResult = @hitTest(point, hitOptions)
		@finishHitTest(fullySelected)
		return hitResult

	updateSelectionRectangle: ()->
		reset = not @selectionRectangleBounds? or @controlPath.rotation==0 and @controlPath.scaling.x == 1 and @controlPath.scaling.y == 1
		if reset
			@selectionRectangleBounds = @controlPath.bounds.clone()
		bounds = @selectionRectangleBounds.clone().expand(10+@pathWidth()/2)
		@selectionRectangle?.remove()
		@selectionRectangle = new Path.Rectangle(bounds)
		@group.addChild(@selectionRectangle)
		@selectionRectangle.name = "selection rectangle"
		@selectionRectangle.pivot = @selectionRectangle.bounds.center
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top-25))
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top))
		if not reset 
			@selectionRectangle.position = @controlPath.position
			@selectionRectangle.rotation = @controlPath.rotation
			@selectionRectangle.scaling = @controlPath.scaling
		@selectionRectangle.selected = true
		@selectionRectangle.controller = @
		@controlPath.pivot = @selectionRectangle.pivot

	select: (updateOptions=true)->
		if not @controlPath? then return
		if @selectionRectangle? then return
		console.log "select"
		@selectionRectangleRotation = null
		@selectionRectangleScale = null
		@updateSelectionRectangle()

		g.selectionGroup ?= new Group()
		g.selectionGroup.name = 'selection group'
		g.selectionGroup.addChild(@group)

		if updateOptions then g.updateParameters( { tool: @constructor, item: @ } , true)
		# debug:
		g.s = @

	deselect: ()->
		console.log "deselect"
		if not @selectionRectangle? then return
		@selectionRectangle?.remove()
		@selectionRectangle = null
		@rasterize()

	# called when user deselects
	rasterize: ()->
		# if @raster? or not @drawing? then return
		# @raster = @drawing.rasterize()
		# @group.addChild(@raster)
		# @drawing.visible = false
		return

	hitTestAndInitSelection: (event, userAction)->
		hitResult = @performeHitTest(event.point, @constructor.hitOptions)
		if not hitResult? then return null
		return @initSelection(event, hitResult, userAction)

	# c: overloaded by path, good for shape
	initSelection: (event, hitResult, userAction=true) ->
		change = 'move'
		if hitResult.type == 'segment'
			if hitResult.item == @controlPath
				@selectedSegment = hitResult.segment
				change = 'segment'
			else if hitResult.item == @selectionRectangle
				if hitResult.segment.index >= 2 and hitResult.segment.index <= 4
					@selectionRectangleRotation = event.point.subtract(@selectionRectangle.bounds.center)
					change = 'rotation'
				else
					@selectionRectangleScale = event.point.subtract(@selectionRectangle.bounds.center).length #/@controlPath.scaling.x
					change = 'scale'
		return change

	selectBegin: (event, userAction=true) ->
		# if not userAction and @changed
		# 	romanesco_alert("This path is already being modified.", "error")
		# 	return
		console.log "selectBegin"

		@changed = null

		if @selectedSegment? then @selectedSegment = null
		if @selectedHandle? then @selectedHandle = null
		@selectionHighlight?.remove()
		@selectionHighlight = null
		@selectionRectangleRotation = null
		@selectionRectangleScale = null

		if userAction
			@select()

		change = @hitTestAndInitSelection(event, userAction)
		
		if g.fastMode and change != 'move'
			g.hideOthers(@)

		# if g.me? and userAction then g.chatSocket.emit( "select begin", g.me, @pk, g.eventObj(event))

		return change

	selectUpdate: (event, userAction=true)->
		console.log "selectUpdate"
		return

	selectEnd: (event, userAction=true)->
		console.log "selectEnd"
		@selectionRectangleRotation = null
		@selectionRectangleScale = null
		if userAction and @changed?
			@update('point')
			# if g.me? and userAction then g.chatSocket.emit( "select end", g.me, @pk, g.eventObj(event))
		@changed = null

		if g.fastMode
			g.showAll(@)

	doubleClick: (event, userAction=true)->
		return

	# redraw the skeleton (controlPath) of the path, 
	# called only when loading a path (in load_callback)
	# overloaded by PreciseBrush, extended by shape (for security checks)
	loadPath: (points)->
		for point, i in points
			if i==0
				@createBegin(point, null, true)
			else
				@createUpdate(point, null, true)
		if points.length>0
			@createEnd(points.last(), null, true)
		@draw()

	# common in rpath and rdiv
	# called from parameter.onChange (update = true)
	# called from websocket after parameter.onChange (update = false)
	parameterChanged: (update=true)->
		@draw()		# if draw in simple mode, then how to see the change of parameters which matter?
		if update then g.defferedExecution(@update, @getPk())

	addPath: (path)->
		path ?= new Path()
		path.name = 'group path'
		path.controller = @
		path.strokeColor = @data.strokeColor
		path.strokeWidth = @data.strokeWidth
		path.fillColor = @data.fillColor
		@drawing.addChild(path)
		return path

	# todo: improve createCanvas
	initializeDrawing: (createCanvas=false)->
		
		@raster?.remove()
		@raster = null

		@controlPath.strokeWidth = @pathWidth()

		@drawing?.remove()
		@drawing = new Group()
		@drawing.name = "drawing"
		@drawing.strokeColor = @data.strokeColor
		@drawing.strokeWidth = @data.strokeWidth
		@drawing.fillColor = @data.fillColor
		@drawing.insertBelow(@controlPath)
		@drawing.controlPath = @controlPath
		@drawing.controller = @
		@group.addChild(@drawing)

		if createCanvas
			canvas = document.createElement("canvas")

			if @controlPath.length<=1
				canvas.width = view.size.width
				canvas.height = view.size.height
				position = view.center
			else
				canvas.width = @controlPath.strokeBounds.width
				canvas.height = @controlPath.strokeBounds.height
				position = @controlPath.strokeBounds.center

			@canvasRaster?.remove()
			@canvasRaster = new Raster(canvas, position)
			@group.addChild(@canvasRaster)
			@context = @canvasRaster.canvas.getContext("2d")
			@context.strokeStyle = @data.strokeColor
			@context.fillStyle = @data.fillColor
			@context.lineWidth = @data.strokeWidth

		return

	initializeAnimation: (animate)->
		if animate
			if g.animatedItems.indexOf(@)<0 then g.animatedItems.push(@)
		else
			if g.animatedItems.indexOf(@)>=0 then g.animatedItems.splice(@, 1)
		return
	
	# update the appearance (group) of the path
	# called by parameterChanged
	# called by createBegin/Update/End, selectUpdate/End, parameterChanged, parameterUpdaters (deletePoint, changePoint etc.) and loadPath
	draw: ()->
		return

	# called once after createEnd to initialize the path (add it to a game, or to the animated paths)
	initialize: ()->
		return

	# createBegin, createUpdate, createEnd
	# Begin, update and end the shape
	# called from loadPath (draw the skeleton when path is loaded in load_callback), event is null
	# called from PathTool.begin, PathTool.update and PathTool.end (when the user draws something), event is the event
	createBegin: (event, point) ->
		return

	# see createBegin
	createUpdate: (point, event) ->
		return

	# see createBegin
	createEnd: (event, point) ->
		@initialize()
		return

	updateZIndex: ()->
		if @date?
			#insert path at the right place
			if g.sortedPaths.length==0
				g.sortedPaths.push(@)
			for path, i in g.sortedPaths
				if @date > path.date
					g.sortedPaths.splice(i+1, 0, @)
					@insertAbove(path)

	insertAbove: (path)->
		@controlPath.insertAbove(path.controlPath)
		@drawing.insertBelow(@controlPath)

	getData: ()->
		return @data

	getStringifiedData: ()->
		return JSON.stringify(@getData())

	planet: ()->
		return projectToPlanet( @controlPath.segments[0].point )

	prepareUpdate: ()->
		path = @controlPath

		if path.segments.length<2 # User want to add a single point
			p0 = path.segments[0].point
			path.add( new Point(p0.x+1, p0.y) )

		if g.pathOverlapsTwoPlanets(path)
			romanesco_alert("You can not create nor update a line in between two planets, this is not yet supported.", "info")
			return false

		return true

	save: ()->
		if not @controlPath? then return
		if not @prepareUpdate() then return
		# ajaxPost '/savePath', {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData() } , @save_callback
		Dajaxice.draw.savePath( @save_callback, {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData() } )
		return

	save_callback: (result)=>
		g.checkError(result)
		@setPK(result.pk)

	update: (type)=>
		console.log "update: " + @pk
		if not @pk? then return 	# null when was deleted (update could be called on selectEnd)
		if not @prepareUpdate() then return

		Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() } )
		
		# if type == 'points'
		# 	# ajaxPost '/updatePath', {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() }, @updatePath_callback
		# 	Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() } )
		# else
		# 	# ajaxPost '/updatePath', {'pk': @pk, 'data': @getStringifiedData() } , @updatePath_callback
		# 	Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'data': @getStringifiedData() } )

		@changed = null
		return

	updatePath_callback: (result)->
		g.checkError(result)
		return

	getPk: ()->
		return if @pk? then @pk else @id

	setPK: (pk, updateRoom=true)->
		@pk = pk
		g.paths[pk] = @
		g.items[pk] = @
		delete g.paths[@id]
		if updateRoom
			g.chatSocket.emit( "setPathPK", g.me, @id, @pk)
		return
	
	# common in rpath and rdiv
	# called by delete and to update users view through websockets
	# delete() removes the path and delete it in the database
	# remove() just removes visually
	remove: ()->
		@deselect()
		@group.remove()
		@controlPath = null
		@drawing = null
		@raster ?= null
		@canvasRaster ?= null
		@group = null
		g.sortedPaths.remove(@)
		if @pk?
			delete g.paths[@pk]
			delete g.items[@pk]
		else
			delete g.paths[@id]

	# common in rpath and rdiv
	# delete() removes the path and delete it in the database
	# remove() just removes visually
	delete: ()->
		@remove()
		if not @pk? then return
		console.log @pk
		# ajaxPost '/deletePath', { pk: @pk } , @deletePath_callback
		Dajaxice.draw.deletePath(@deletePath_callback, { pk: @pk })
		@pk = null

	deletePath_callback: (result)->
		if g.checkError(result)
			g.chatSocket.emit( "delete path", result.pk )

	planet: ()->
		return projectToPlanet(@controlPath.segments[0].point)

	pathOnPlanet: (controlSegments=@controlPath.segments)->
		points = []
		planet = @planet()
		for segment in controlSegments
			p = projectToPosOnPlanet(segment.point, planet)
			points.push( pointToArray(p) )
		return points

@RPath = RPath

class PrecisePath extends RPath
	@rname = 'Precise path'
	# @iconUrl = '/static/images/icons/inverted/editCurve.png'
	# @iconAlt = 'edit curve'
	@rdescription = "This path offers precise controls, one can modify points along with their handles and their type."

	@hitOptions =
		segments: true
		stroke: true
		fill: true
		selected: true
		curves: true
		handles: true
		tolerance: 5

	@secureStep = 25

	@parameters: ()->

		parameters = super()

		parameters['General'].polygonMode =
			type: 'checkbox'
			label: 'Polygon mode'
			default: g.polygonMode
			onChange: (value)-> g.polygonMode = value

		parameters['Edit curve'] =			
			smooth:
				type: 'checkbox'
				label: 'Smooth'
				default: false
			pointType:
				type: 'dropdown'
				label: 'Point type'
				values: ['smooth', 'corner', 'point']
				default: 'smooth'
				addController: true
				onChange: (value)-> item.changeSelectedPoint?(true, value) for item in g.selectedItems(); return
			deletePoint: 
				type: 'button'
				label: 'Delete point'
				default: ()-> item.deleteSelectedPoint?() for item in g.selectedItems(); return
			simplify: 
				type: 'button'
				label: 'Simplify'
				default: ()-> 
					for item in g.selectedItems()
						item.controlPath?.simplify()
						item.draw()
						item.update()
					return

		return parameters

	constructor: (@date=null, @data=null, @pk=null, points=null) ->
		super(@date, @data, @pk, points)
		@data.polygonMode = g.polygonMode

	# todo: improve secure check just testing distance between point and getPointAt(realStep*index)
	loadPath: (points)->
		@createBegin(posOnPlanetToProject(@data.points[0], @data.planet), null, true)
		for point, i in @data.points by 4
			if i>0 then @controlPath.add(posOnPlanetToProject(point, @data.planet))
			@controlPath.lastSegment.handleIn = new Point(@data.points[i+1])
			@controlPath.lastSegment.handleOut = new Point(@data.points[i+2])
			@controlPath.lastSegment.rtype = @data.points[i+3]
		if points.length == 2 then @controlPath.add(points[1])
		@createEnd(posOnPlanetToProject(@data.points[@data.points.length-4], @data.planet), null, true)

		time = Date.now()

		flattenedPath = @controlPath.copyTo(project)
		flattenedPath.flatten(@constructor.secureStep)
		distanceMax = @constructor.secureDistance*@constructor.secureDistance

		for i in [1 .. 10]
			index = Math.floor(Math.random()*points.length)
			recordedPoint = points[index]
			resultingPoint = flattenedPath.segments[index].point
			if recordedPoint.getDistance(resultingPoint, true)>distanceMax
				# @remove()
				flattenedPath.strokeColor = 'red'
				view.center = flattenedPath.bounds.center
				console.log "Error: invalid path"
				return
		
		flattenedPath.remove()
		console.log "Time to secure the path: " + ((Date.now()-time)/1000) + " sec."

	hitTest: (point, hitOptions)->
		if @speedGroup?.visible then hitResult = @handleGroup?.hitTest(point)
		hitResult ?= @selectionRectangle.hitTest(point)
		hitResult ?= @controlPath.hitTest(point, hitOptions)
		return hitResult

	initializeDrawing: (createCanvas=false)->
		@data.step ?= 20 	# developers do not need to put @data.step in the parameters, but there must be a default value
		@offset = 0
		super(createCanvas)
		return

	drawBegin: (createCanvas=false)->
		console.log "drawBegin"
		@initializeDrawing(createCanvas)
		@path = @addPath()
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	drawUpdate: (offset)->
		console.log "drawUpdate"
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	drawEnd: ()->
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	checkUpdateBrush: (event)->
		step = @data.step
		controlPathLength = @controlPath.length

		while @offset+step<controlPathLength
			@offset += step
			@drawUpdate(@offset)
		return

	initializeControlPath: (point)->
		@group = new Group()
		@group.name = "group"
		@group.controller = @

		@controlPath = new Path()
		@group.addChild(@controlPath)
		@controlPath.name = "controlPath"
		@controlPath.controller = @
		@controlPath.strokeWidth = @pathWidth()
		@controlPath.strokeColor = 'black'
		@controlPath.visible = false
		@controlPath.add(point)

		return

	# todo: better handle lock area
	createBegin: (point, event, loading=false)->
		super()
		if loading
			@initializeControlPath(point)
		else
			if RLock.intersectPoint(point) then	return

			if not @data.polygonMode
				@initializeControlPath(point)
				@drawBegin()
			else
				if not @controlPath?
					@initializeControlPath(point)
					@controlPath.add(point)
					@drawBegin()
				else
					@controlPath.add(point)
				@controlPath.lastSegment.rtype = 'point'
		return

	createUpdate: (point, event, loading=false)->

		if not @data.polygonMode
			
			if @inLockedArea
				return
			if RLock.intersectPoint(point)
				@inLockedArea = true
				@save()
				return

			@controlPath.add(point)

			# loading is never true in this case
			if not loading then @checkUpdateBrush(event)
		else
			lastSegment = @controlPath.lastSegment
			previousSegment = lastSegment.previous
			previousSegment.rtype = 'smooth'
			previousSegment.handleOut = point.subtract(previousSegment.point)
			if lastSegment != @controlPath.firstSegment
				previousSegment.handleIn = previousSegment.handleOut.multiply(-1)
			lastSegment.handleIn = lastSegment.handleOut = null
			lastSegment.point = point
			@draw(true)
		return

	createMove: (event)->
		@controlPath.lastSegment.point = event.point
		@draw(true)
		return

	createEnd: (point, event, loading=false)->
		if @data.polygonMode 
			if loading then @finishPath(loading)
		else
			@inLockedArea = false
			if not loading and @controlPath.segments.length>=2
				if @speeds? then @computeSpeed()
				@controlPath.simplify()
				if @speeds? then @updateSpeed()
			@finishPath(loading)
		super()
		return

	finishPath: (loading=false)->
		if @data.polygonMode and not loading
			@controlPath.lastSegment.remove()
			@controlPath.lastSegment.handleOut = null

		if @controlPath.segments.length<2
			@remove()
			return

		# todo: uncomment update z index:
		# @updateZIndex()
		if @data.smooth then @controlPath.smooth()
		if not loading
			@checkUpdateBrush()
			@drawEnd()
			@offset = 0
		@draw(false, loading) 	# enable to have the correct @canvasRaster size and to have the exact same result after a load or a change
		@rasterize()
		return

	simplifiedModeOn: ()->
		@previousData = {}
		for folderName, folder of @constructor.parameters()
			for name, parameter of folder
				if parameter.simplified? and @data[name]?
					@previousData[name] = @data[name]
					@data[name] = parameter.simplified
		return

	simplifiedModeOff: ()->
		for folderName, folder of @constructor.parameters()
			for name, parameter of folder
				if parameter.simplified? and @data[name]? and @previousData[name]?
					@data[name] = @previousData[name]
					delete @previousData[name]
		return

	draw: (simplified=false, loading=false)->

		if @controlPath.segments.length < 2 then return
	
		if simplified then @simplifiedModeOn()
		
		step = @data.step
		controlPathLength = @controlPath.length
		nf = controlPathLength/step
		nIteration  = Math.floor(nf)
		reminder = nf-nIteration
		offset = reminder*step/2

		try

			@drawBegin()

			# n=0
			while offset<controlPathLength

				@drawUpdate(offset)
				offset += step

				# if n%10==0 then g.updateLoadingBar(offset/controlPathLength)
				# n++

			@drawEnd()

		catch error
			console.error error
			throw error

		if simplified 
			@simplifiedModeOff()
		else
			@rasterize()

		return

	pathOnPlanet: ()->
		flatennedPath = @controlPath.copyTo(project)
		flatennedPath.flatten(@constructor.secureStep)
		flatennedPath.remove()
		return super(flatennedPath.segments)

	getData: ()->
		@data.planet = projectToPlanet(@controlPath.segments[0].point)
		@data.points = []
		for segment in @controlPath.segments
			@data.points.push(projectToPosOnPlanet(segment.point))
			@data.points.push(g.pointToObj(segment.handleIn))
			@data.points.push(g.pointToObj(segment.handleOut))
			@data.points.push(segment.rtype)
		return @data

	select: (updateOptions=true)->
		if not @controlPath? then return
		if @selectionRectangle? then return
		@index = @controlPath.index
		@controlPath.bringToFront()
		@controlPath.selected = true
		super(updateOptions)
		if not @data.smooth then @controlPath.fullySelected = true

	deselect: ()->
		# g.project.activeLayer.insertChild(@index, @controlPath)
		@controlPath.selected = false
		@selectionHighlight?.remove()
		@selectionHighlight = null
		super()

	highlightSelectedPoint: ()->
		if not @controlPath.selected then return
		@selectionHighlight?.remove()
		@selectionHighlight = null
		if not @selectedSegment? then return
		point = @selectedSegment.point
		@selectedSegment.rtype ?= 'smooth'
		switch @selectedSegment.rtype
			when 'smooth'
				@selectionHighlight = new Path.Circle(point, 5)
			when 'corner'
				offset = new Point(5, 5)
				@selectionHighlight = new Path.Rectangle(point.subtract(offset), point.add(offset))
			when 'point'
				@selectionHighlight = new Path.RegularPolygon(point, 3, 5)
		@selectionHighlight.name = 'selection highlight'
		@selectionHighlight.controller = @
		@selectionHighlight.strokeColor = g.selectionBlue
		@selectionHighlight.strokeWidth = 1
		@group.addChild(@selectionHighlight)
		if @parameterControllers?.pointType? then g.setControllerValue(@parameterControllers.pointType, null, @selectedSegment.rtype, @)
		return

	initSelection: (event, hitResult, userAction=true) ->
		specialKey = g.specialKey(event)

		@selectedSegment = null
		@selectedHandle = null
		@selectionHighlight?.remove()
		@selectionHighlight = null
		change = 'move'

		if hitResult.type == 'segment'

			if specialKey
				hitResult.segment.remove()
				@changed = change = 'deleted point'
			else
				if hitResult.item == @controlPath
					@selectedSegment = hitResult.segment
					change = 'segment'
				else if hitResult.item == @selectionRectangle
					if hitResult.segment.index >= 2 and hitResult.segment.index <= 4
						@selectionRectangleRotation = 0
						change = 'rotation'
					else
						@selectionRectangleScale = event.point.subtract(@selectionRectangle.bounds.center).length/@controlPath.scaling.x
						change = 'scale'

		if not @data.smooth
			if hitResult.type is "handle-in"
				@selectedHandle = hitResult.segment.handleIn
				@selectedSegment = hitResult.segment
				change = 'handle-in'
			else if hitResult.type is "handle-out"
				@selectedHandle = hitResult.segment.handleOut
				@selectedSegment = hitResult.segment
				change = 'handle-out'

		if userAction then @highlightSelectedPoint()

		return change

	# segment.rtype == null or 'smooth': handles are aligned, and have the same length if shit
	# segment.rtype == 'corner': handles are not equal
	# segment.rtype == 'point': no handles
	selectUpdate: (event, userAction=true)->
		console.log "selectUpdate"
		if @selectedHandle?

			# when segment.rtype == 'smooth' or 'corner'

			# @selectedHandle = @selectedHandle.add(event.delta) # does not work
			@selectedHandle.x += event.delta.x
			@selectedHandle.y += event.delta.y

			if @selectedSegment.rtype == 'smooth' or not @selectedSegment.rtype?
				if @selectedHandle == @selectedSegment.handleOut and not @selectedSegment.handleIn.isZero()
					@selectedSegment.handleIn = if not event.modifiers.shift then @selectedSegment.handleOut.normalize().multiply(-@selectedSegment.handleIn.length) else @selectedSegment.handleOut.multiply(-1)
				if @selectedHandle == @selectedSegment.handleIn and not @selectedSegment.handleOut.isZero()
					@selectedSegment.handleOut = if not event.modifiers.shift then @selectedSegment.handleIn.normalize().multiply(-@selectedSegment.handleOut.length) else @selectedSegment.handleIn.multiply(-1)		
			@updateSelectionRectangle()
			@draw(true)
			@changed = 'moved handle'
		else if @selectedSegment?
			@selectedSegment.point.x += event.delta.x
			@selectedSegment.point.y += event.delta.y
			@updateSelectionRectangle()
			@draw(true)
			@changed = 'moved point'
		else if @selectionRectangleRotation?
			rotation = event.point.subtract(@selectionRectangle.bounds.center).angle + 90
			@controlPath.rotation = rotation
			@selectionRectangle.rotation = rotation
			@draw(true)
			@changed = 'rotated'
		else if @selectionRectangleScale?
			ratio = event.point.subtract(@selectionRectangle.bounds.center).length/@selectionRectangleScale
			scaling = new Point(ratio, ratio)
			@controlPath.scaling = scaling
			@selectionRectangle.scaling = scaling
			@draw(true)
			@changed = 'scaled'
		else
			@group.position.x += event.delta.x
			@group.position.y += event.delta.y
			@updateSelectionRectangle()
			# to optimize the move, the position of @drawing is updated at the end
			# @drawing.position.x += event.delta.x
			# @drawing.position.y += event.delta.y
			@changed = 'moved'
		console.log @changed

		# @updateSelectionRectangle()

		# @drawing.selected = false

		if userAction or @selectionRectangle? then @selectionHighlight?.position = @selectedSegment.point

		# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventObj(event))

	selectEnd: (event, userAction=true)->
		console.log "selectEnd"
		# @updateSelectionRectangle()
		if userAction or @selectionRectangle? then @selectionHighlight?.position = @selectedSegment.point
		
		# @drawing.position = @controlPath.position
		
		@selectedHandle = null

		if @data.smooth then @controlPath.smooth()
		if @changed? and @changed != 'moved' then @draw() # to update the curve when user add or remove points
		# @changed = null in super()
		super(event, userAction)

	smoothPoint: (segment, offset)->
		segment.rtype = 'smooth'
		segment.linear = false
		
		offset ?= segment.location.offset
		tangent = segment.path.getTangentAt(offset)
		if segment.previous? then segment.handleIn = tangent.multiply(-0.25)
		if segment.next? then segment.handleOut = tangent.multiply(+0.25)

		# if segment.previous? and segment.next?
		# 	delta = segment.next.point.subtract(segment.previous.point)
		# 	deltaN = delta.normalize()
		# 	previousToSegment = segment.point.subtract(segment.previous.point)
		# 	h = 0.5*deltaN.dot(previousToSegment)/delta.length
		# 	segment.handleIn = delta.multiply(-h)
		# 	segment.handleOut = delta.multiply(0.5-h)
		# else if segment.previous?
		# 	previousToSegment = segment.point.subtract(segment.previous.point)
		# 	segment.handleIn = previousToSegment.multiply(0.5)
		# else if segment.next?
		# 	nextToSegment = segment.point.subtract(segment.next.point)
		# 	segment.handleOut = nextToSegment.multiply(-0.5)

	doubleClick: (event, userAction=true)->
		# warning: event is a jQuery event, not a paper event
		
		specialKey = g.specialKey(event)
		
		point = if userAction then view.viewToProject(new Point(event.pageX, event.pageY)) else event.point

		hitResult = @performeHitTest(point, @constructor.hitOptions)

		if not hitResult?
			return

		hitCurve = hitResult.type == 'stroke' or hitResult.type == 'curve'
		if hitResult.type == 'segment'
			segment = hitResult.segment
			@selectedSegment = segment

			switch segment.rtype
				when 'smooth', null, undefined
					segment.rtype = 'corner'
				when 'corner'
					segment.rtype = 'point'
					segment.linear = true
					@draw()
				when 'point'
					@deletePoint(segment)
				else
					console.log "segment.rtype not known."

		else if hitCurve and not specialKey
			location = hitResult.location
			segment = hitResult.item.insert(location.index + 1, point)
			
			if userAction and not @data.smooth then segment.selected = true
			@selectedSegment = segment
			
			@smoothPoint(segment, location.offset)

		if userAction then @highlightSelectedPoint()

		if hitResult.type == 'segment' or (hitCurve and not specialKey)
			if @data.smooth then @controlPath.smooth()
			if userAction
				@update('point')
				# if g.me? and userAction then g.chatSocket.emit( "double click", g.me, @pk, g.eventObj(event))
		return

	deletePoint: (segment)->
		if not segment then return
		@selectedSegment = if segment.next? then segment.next else segment.previous
		if @selectedSegment then @selectionHighlight.position = @selectedSegment.point
		segment.remove()
		if @controlPath.segments.length <= 1
			@delete()
			return
		if @data.smooth then @controlPath.smooth()
		@draw()
		view.draw()

	deleteSelectedPoint: (userAction=true)->
		@deletePoint(@selectedSegment)
		if g.me? and userAction then g.chatSocket.emit( "parameter change", g.me, @pk, "deleteSelectedPoint", null, "rFunction")

	changeSelectedPoint: (userAction=true, value)->
		if not @selectedSegment? then return
		if @data.smooth then return
		@selectedSegment.rtype = value
		switch value
			when 'corner'
				if @selectedSegment.linear = true
					@selectedSegment.linear = false
					@selectedSegment.handleIn = @selectedSegment.previous.point.subtract(@selectedSegment.point).multiply(0.5)
					@selectedSegment.handleOut = @selectedSegment.next.point.subtract(@selectedSegment.point).multiply(0.5)
			when 'point'
				@selectedSegment.linear = true
			when 'smooth'
				@smoothPoint(@selectedSegment)
		@highlightSelectedPoint()
		if g.me? and userAction then g.chatSocket.emit( "parameter change", g.me, @pk, "changeSelectedPoint", value, "rFunction")
		return

	parameterChanged: (update=true)->
		switch @changed
			when 'smooth'
				# todo: add a warning when changing smooth?
				if @data.smooth 		# todo: put this in @draw()? and remove this function? 
					@controlPath.smooth()
					@controlPath.fullySelected = false
					@controlPath.selected = true
					segment.rtype = 'smooth' for segment in @controlPath.segments
				else
					@controlPath.fullySelected = true
		super(update)

	remove: ()->
		@selectionHighlight?.remove()
		@selectionHighlight = null
		@canvasRaster?.remove()
		@canvasRaster =  null
		super()

@PrecisePath = PrecisePath

class SpeedPath extends PrecisePath
	@rname = 'Speed path'
	@rdescription = "This path offers speed."

	@speedMax = 200
	@speedStep = 20
	@secureStep = 25

	@parameters: ()->

		parameters = super()

		parameters['Edit curve'].showSpeed = 
				type: 'checkbox'
				label: 'Show speed'
				value: true

		return parameters

	loadPath: (points)->
		@data ?= {}
		@speeds = @data.speeds or []
		super(points)
		return

	checkUpdateBrush: (event)->
		step = @data.step
		controlPathLength = @controlPath.length
		
		if event?
			delta = event.delta.length
			startOffset = controlPathLength-delta
			lastSpeed = @speeds.last()

		while @offset+step<controlPathLength
			@offset += step

			if event? 	# compute speed
				f = ( delta-(@offset-startOffset) ) / delta
				speed = lastSpeed * (1-f) + delta * f
				@speeds.push(Math.min(speed, @constructor.speedMax))

			# update drawing
			@drawUpdate(@offset)
		return

	# todo: better handle lock area
	createBegin: (point, event, loading=false)->
		if not loading then @speeds = (if g.polygonMode then [0] else [@constructor.speedMax/3])
		super(point, event, loading)

	createEnd: (point, event, loading=false)->
		if not @data.polygonMode and not loading then @speeds = []
		super(point, event, loading)

	computeSpeed: ()->
		
		step = @constructor.speedStep

		distances = []
		controlPathLength = @controlPath.length
		currentOffset = step
		segment = @controlPath.firstSegment
		distance = segment.point.getDistance(segment.next.point)
		distances.push({speed: distance, offset: 0})
		previousDistance = 0

		pointOffset = 0
		previousPointOffset = 0

		for segment, i in @controlPath.segments
			if i==0 then continue

			point = segment.point
			previousDistance = distance
			distance = point.getDistance(segment.previous.point)
			previousPointOffset = pointOffset
			pointOffset += distance

			while pointOffset > currentOffset
				f = (currentOffset-previousPointOffset)/distance
				interpolation = previousDistance * (1-f) + distance * f
				distances.push({speed: interpolation, offset: currentOffset})
				currentOffset += step
			
			distances.push({speed: distance, offset: pointOffset})

		distances.push({speed: distance, offset: currentOffset})

		@speeds = []
		
		nextOffset = step
	
		speed = distances.first().speed
		previousSpeed = speed
		@speeds.push(speed)
		offset = 0
		previousOffset = offset
		currentAverageSpeed = 0

		for distance, i in distances
			if i==0 then continue

			previousSpeed = speed
			speed = distance.speed

			previousOffset = offset
			offset = distance.offset

			currentAverageSpeed += ((speed+previousSpeed)/2.0)*(offset-previousOffset)/step
			
			if offset==nextOffset
				@speeds.push(Math.min(currentAverageSpeed, @constructor.speedMax)) 
				currentAverageSpeed = 0
				nextOffset += step

		return

	updateSpeed: ()->
		@speedGroup?.visible = @data.showSpeed
		
		if not @speeds? or not @data.showSpeed then return

		step = @constructor.speedStep
		alreadyExists = @speedGroup?

		if alreadyExists
			@speedGroup.bringToFront()
			speedCurve = @speedGroup.firstChild
		else
			@speedGroup = new Group()
			@speedGroup.name = "speed group"
			@speedGroup.strokeWidth = 1
			@speedGroup.strokeColor = selectionBlue
			@speedGroup.controller = @
			@group.addChild(@speedGroup)

			speedCurve = new Path()
			speedCurve.name = "speed curve"
			speedCurve.strokeWidth = 1
			speedCurve.strokeColor = selectionBlue
			speedCurve.controller = @
			@speedGroup.addChild(speedCurve)

			@handleGroup = new Group()
			@handleGroup.name = "speed handle group"
			@speedGroup.addChild(@handleGroup)
			
		speedHandles = @handleGroup.children

		offset = 0
		controlPathLength = @controlPath.length

		while (@speeds.length-1)*step < controlPathLength
			@speeds.push(@speeds.last())

		i = 0

		for speed, i in @speeds

			offset = if i>0 then i*step else 0.1
			o = if offset<controlPathLength then offset else controlPathLength - 0.1
			
			point = @controlPath.getPointAt(o)
			normalNormalized = @controlPath.getNormalAt(o).normalize()
			normal = normalNormalized.multiply(@speeds[i])
			handlePoint = point.add(normal)

			if alreadyExists and i<speedCurve.segments.length		# if the speed point (curve, segment and handle) already exists, move it the to correct place

				speedCurve.segments[i].point = handlePoint
				speedHandles[i].position = handlePoint
				speedHandles[i].rsegment.firstSegment.point = point
				speedHandles[i].rsegment.lastSegment.point = handlePoint
				speedHandles[i].rnormal = normalNormalized

			else 											# else (if the speed point does not exist) create it
				speedCurve.add(handlePoint)

				s = new Path()
				s.name = 'speed segment'
				s.strokeWidth = 1
				s.strokeColor = selectionBlue
				s.add(point)
				s.add(handlePoint)
				s.controller = @
				@speedGroup.addChild(s)

				handle = new Path.Rectangle(handlePoint.subtract(2), 4)
				handle.name = 'speed handle'
				handle.strokeWidth = 1
				handle.strokeColor = selectionBlue
				handle.fillColor = 'white'
				handle.rnormal = normalNormalized
				handle.rindex = i
				handle.rsegment = s
				handle.controller = @
				@handleGroup.addChild(handle)

			if offset>controlPathLength
				break

		if offset > controlPathLength and i+1 <= speedHandles.length-1
			speedHandlesLengthM1 = speedHandles.length-1
			for j in [i+1 .. speedHandlesLengthM1]
				speedHandle = @handleGroup.lastChild
				speedHandle.rsegment.remove()
				speedHandle.remove()
				speedCurve.lastSegment.remove()

		return

	speedAt: (offset)->
		f = offset%@constructor.speedStep
		i = (offset-f) / @constructor.speedStep
		f /= @constructor.speedStep
		if @speeds?
			if i<@speeds.length-1
				return @speeds[i]*(1-f)+@speeds[i+1]*f
			if i==@speeds.length-1
				return @speeds[i]
		else
			@constructor.speedMax/2

	draw: (simplified=false, loading=false)->
		super(simplified, loading)
		if not loading then @updateSpeed()
		return

	# todo: change get data, do not return stringified version
	getData: ()->
		data = jQuery.extend({}, super())
		data.speeds = if @speeds? and @handleGroup? then @speeds.slice(0, @handleGroup.children.length+1) else @speeds
		return data

	select: (updateOptions=true)->
		if @selectionRectangle? then return
		super(updateOptions)
		@updateSpeed()
		if @data.showSpeed then @speedGroup?.visible = true

	deselect: ()->
		@speedGroup?.visible = false
		super()

	initSelection: (event, hitResult, userAction=true) ->
		@speedSelectionHighlight?.remove()
		@speedSelectionHighlight = null

		if hitResult.item.name == "speed handle"
			@selectedSpeedHandle = hitResult.item
			change = 'speed handle'
			return change

		return super(event, hitResult, userAction)

	selectUpdate: (event, userAction=true)->
		if not @selectedSpeedHandle?
			super(event, userAction)
		else
			@speedSelectionHighlight?.remove()

			speedMax = @constructor.speedMax

			@speedSelectionHighlight = new Path()
			@speedSelectionHighlight.name = 'speed selection highlight'
			@speedSelectionHighlight.strokeWidth = 1
			@speedSelectionHighlight.strokeColor = 'blue'
			@group.addChild(@speedSelectionHighlight)

			handle = @selectedSpeedHandle
			handlePosition = handle.bounds.center

			handleToPoint = event.point.subtract(handlePosition)
			projection = handleToPoint.project(handle.rnormal)
			projectionLength = projection.length

			sign = Math.sign(projection.x) == Math.sign(handle.rnormal.x) and Math.sign(projection.y) == Math.sign(handle.rnormal.y)
			sign = if sign then 1 else -1
			
			@speeds[handle.rindex] += sign * projectionLength

			if @speeds[handle.rindex] < 0
				@speeds[handle.rindex] = 0
			else if @speeds[handle.rindex] > speedMax
				@speeds[handle.rindex] = speedMax

			newHandleToPoint = event.point.subtract(handle.position.add(projection))
			influenceFactor = newHandleToPoint.length/(@constructor.speedStep*3)
			
			max = g.gaussian(0, influenceFactor, 0)
			i = 1
			influence = 1
			while influence > 0.1 and i<20
				influence = g.gaussian(0, influenceFactor, i)/max
				
				delta = projectionLength*influence

				for n in [-1 .. 1] by 2
					index = handle.rindex+n*i
					if index >= 0 and index < @handleGroup.children.length
						handlei = @handleGroup.children[index]		

						@speeds[index] += sign * delta
						if @speeds[index] < 0
							@speeds[index] = 0
						else if @speeds[index] > speedMax
							@speeds[index] = speedMax
				i++
				
			@speedSelectionHighlight.strokeColor.hue -= Math.min(240*(influenceFactor/10), 240)
			@speedSelectionHighlight.add(handle.position.add(projection))
			@speedSelectionHighlight.add(event.point)

			@draw(true)

			@changed = 'speed handle moved'

			if userAction or @selectionRectangle? then @selectionHighlight?.position = @selectedSegment.point
			# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventObj(event))
		return

	selectEnd: (event, userAction=true)->
		@selectedSpeedHandle = null
		@speedSelectionHighlight?.remove()
		@speedSelectionHighlight = null
		super(event, userAction)

	remove: ()->
		@speedGroup?.remove()
		@speedGroup = null
		super()

@SpeedPath = SpeedPath

class RollerPath extends SpeedPath
	@rname = 'Roller brush'
	@iconUrl = 'static/images/icons/inverted/rollerBrush.png'
	@iconAlt = 'roller brush'
	@rdescription = "The stroke width is function of the speed: the faster the wider."

	@parameters: ()->
		parameters = super()
		parameters['Style'].strokeWidth.default = 0 
		parameters['Style'].strokeColor.defaultCheck = false
		parameters['Style'].fillColor.defaultCheck = true

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 30
			max: 300
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].trackWidth =
			type: 'slider'
			label: 'Track width'
			min: 1
			max: 10
			default: 2
		return parameters

	drawBegin: ()->
		@initializeDrawing(false)
		@path = @addPath()
		@path.add(@controlPath.firstSegment.point)
		return

	drawUpdate: (offset)->

		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		speed = @speedAt(offset)

		delta = normal.multiply(speed*@data.trackWidth/2)
		top = point.add(delta)
		bottom = point.subtract(delta)

		@path.add(top)
		@path.insert(0, bottom)
		return

	drawEnd: ()->
		@path.add(@controlPath.lastSegment.point)
		@path.closed = true
		@path.smooth()
		@path.selected = false
		return

@RollerPath = RollerPath

class SpiralPath extends PrecisePath
	@rname = 'Spiral path'
	@rdescription = "Spiral path."
	@iconUrl = 'static/images/icons/inverted/squareSpiral.png'
	@iconAlt = 'squareSpiral'

	@parameters: ()->
		parameters = super()
		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 10
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].thickness =
			type: 'slider'
			label: 'Thickness'
			min: 1
			max: 30
			default: 5
			step: 1
		parameters['Parameters'].rsmooth =
			type: 'checkbox'
			label: 'Smooth'
			default: false

		return parameters

	drawBegin: ()->
		@initializeDrawing(false)
		@line = @addPath()
		@spiral = @addPath()
		return

	drawUpdate: (offset)->

		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()
		tangent = normal.rotate(90)

		@line.add(point)

		@spiral.add(point.add(normal.multiply(@data.thickness)))

		p1 = point.add(normal.multiply(@data.step))
		@spiral.add(p1)

		p2 = p1.add(tangent.multiply(@data.step-@data.thickness))
		@spiral.add(p2)

		p3 = p2.add(normal.multiply( -(@data.step-2*@data.thickness) ))
		@spiral.add(p3)

		p4 = p3.add(tangent.multiply( -(@data.step-3*@data.thickness) ))
		@spiral.add(p4)

		p5 = p4.add(normal.multiply( @data.thickness ))
		@spiral.add(p5)

		p6 = p5.add(tangent.multiply( @data.step-4*@data.thickness ))
		@spiral.add(p6)

		p7 = p6.add(normal.multiply( @data.step-4*@data.thickness ))
		@spiral.add(p7)

		p8 = p7.add(tangent.multiply( -(@data.step-3*@data.thickness) ))
		@spiral.add(p8)

		p9 = p8.add(normal.multiply( -(@data.step-2*@data.thickness) ))
		@spiral.add(p9)

		return

	drawEnd: ()->
		if @data.rsmooth 
			@spiral.smooth()
			@line.smooth()
		return

@SpiralPath = SpiralPath

class FuzzyPath extends SpeedPath
	@rname = 'Fuzzy brush'
	@rdescription = "Brush with lines poping out of the path."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {} 
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].minWidth =
			type: 'slider'
			label: 'Min width'
			min: 1
			max: 100
			default: 20
		parameters['Parameters'].maxWidth =
			type: 'slider'
			label: 'Max width'
			min: 1
			max: 250
			default: 200
		parameters['Parameters'].minSpeed =
			type: 'slider'
			label: 'Min speed'
			min: 1
			max: 250
			default: 1
		parameters['Parameters'].maxSpeed =
			type: 'slider'
			label: 'Max speed'
			min: 1
			max: 250
			default: 200
		parameters['Parameters'].nLines =
			type: 'slider'
			label: 'N lines'
			min: 1
			max: 5
			default: 2
			simplified: 2
			step: 1
		parameters['Parameters'].symmetric =
			type: 'dropdown'
			label: 'Symmetry'
			values: ['symmetric', 'top', 'bottom']
			default: 'symmetric'
		parameters['Parameters'].speedForWidth =
			type: 'checkbox'
			label: 'Speed for width'
			default: true
		parameters['Parameters'].speedForLength =
			type: 'checkbox'
			label: 'Speed for length'
			default: false
		parameters['Parameters'].orthoLines =
			type: 'checkbox'
			label: 'Orthogonal lines'
			default: true
		parameters['Parameters'].lengthLines =
			type: 'checkbox'
			label: 'Length lines'
			default: true

		return parameters

	drawBegin: ()->
		@initializeDrawing(false)

		if @data.lengthLines
			@lines = []
			nLines = @data.nLines
			if @data.symmetric == 'symmetric' then nLines *= 2
			for i in [1 .. nLines]
				@lines.push( @addPath() )

		@lastOffset = 0

		return

	drawUpdate: (offset)->
		console.log "drawUpdate"

		speed = @speedAt(offset)

		addPoint = (offset, speed)=>
			point = @controlPath.getPointAt(offset)
			normal = @controlPath.getNormalAt(offset).normalize()

			if @data.speedForWidth
				width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.speedMax
			else
				width = @data.minWidth


			if @data.lengthLines
				divisor = if @data.nLines>1 then @data.nLines-1 else 1
				if @data.symmetric == 'symmetric'
					for line, i in @lines by 2
						@lines[i+0].add(point.add(normal.multiply(i*width*0.5/divisor)))
						@lines[i+1].add(point.add(normal.multiply(-i*width*0.5/divisor)))
				else
					if @data.symmetric == 'top'
						line.add(point.add(normal.multiply(i*width/divisor))) for line, i in @lines
					else if @data.symmetric == 'bottom'
						line.add(point.add(normal.multiply(-i*width/divisor))) for line, i in @lines

			if @data.orthoLines
				path = @addPath()
				delta = normal.multiply(width)
				switch @data.symmetric
					when 'symmetric'
						path.add(point.add(delta))
						path.add(point.subtract(delta))
					when 'top'
						path.add(point.add(delta))
						path.add(point)
					when 'bottom'
						path.add(point.subtract(delta))
						path.add(point)
			return

		if not @data.speedForLength
			addPoint(offset, speed)
		else 	# @data.speedForLength
			speed = @data.minSpeed + (speed / @constructor.speedMax) * (@data.maxSpeed - @data.minSpeed)
	
			stepOffset = offset-@lastOffset

			if stepOffset>speed
				midOffset = (offset+@lastOffset)/2
				addPoint(midOffset, speed)
				@lastOffset = offset

		return

	drawEnd: ()->
		return

@FuzzyPath = FuzzyPath

class SketchPath extends PrecisePath
	@rname = 'Sketch brush'
	@rdescription = "Sketch path."
	@iconUrl = 'static/images/icons/inverted/links.png'
	@iconAlt = 'links'

	@parameters: ()->
		parameters = super()
		parameters['Style'].strokeColor.default = "rgba(0, 0, 0, 0.25)"
		delete parameters['Style'].fillColor

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].distance =
			type: 'slider'
			label: 'Distance'
			min: 5
			max: 250
			default: 100
			simplified: 100

		return parameters

	drawBegin: ()->
		@initializeDrawing(true)

		@points = []
		return

	drawUpdate: (offset)->
		console.log "drawUpdate"

		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		point = @projectToRaster(point)
		@points.push(point)
		
		distMax = @data.distance*@data.distance

		for pt in @points

			if point.getDistance(pt, true) < distMax
				@context.beginPath()
				@context.moveTo(point.x,point.y)
				@context.lineTo(pt.x,pt.y)
				@context.stroke()
		
		return

	drawEnd: ()->
		return

@SketchPath = SketchPath

class ShapePath extends SpeedPath
	@rname = 'Shape path'
	@rdescription = "Places shape along the path."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 20
			simplified: 20
			step: 1
		parameters['Parameters'].minWidth =
			type: 'slider'
			label: 'Min width'
			min: 1
			max: 250
			default: 1
		parameters['Parameters'].maxWidth =
			type: 'slider'
			label: 'Max width'
			min: 1
			max: 250
			default: 200
		parameters['Parameters'].speedForLength =
			type: 'checkbox'
			label: 'Speed for length'
			default: false
		parameters['Parameters'].minSpeed =
			type: 'slider'
			label: 'Min speed'
			min: 1
			max: 250
			default: 1
		parameters['Parameters'].maxSpeed =
			type: 'slider'
			label: 'Max speed'
			min: 1
			max: 250
			default: 200

		return parameters


	drawBegin: ()->
		@initializeDrawing(false)
		@lastOffset = 0
		return

	drawUpdate: (offset)->
		console.log "drawUpdate"

		speed = @speedAt(offset)

		addPoint = (offset, height, speed)=>
			point = @controlPath.getPointAt(offset)
			normal = @controlPath.getNormalAt(offset)

			width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.speedMax
			shape = @addPath(new Path.Rectangle(point.subtract(new Point(width/2, height/2)), new Size(width, height)))
			shape.rotation = normal.angle
			return

		if not @data.speedForLength
			addPoint(offset, @data.step, speed)
		else 	# @data.speedForLength
			speed = @data.minSpeed + (speed / @constructor.speedMax) * (@data.maxSpeed - @data.minSpeed)
			
			stepOffset = offset-@lastOffset
			if stepOffset>speed
				midOffset = (offset+@lastOffset)/2
				addPoint(midOffset, stepOffset, speed)
				@lastOffset = offset

		return

	drawEnd: ()->
		return

@ShapePath = ShapePath

class RShape extends RPath
	@Shape = paper.Path.Rectangle
	@rname = 'Shape'
	@rdescription = "Base shape class"
	@squareByDefault = true
	@centerByDefault = false

	loadPath: (points)->
		if not @data.rectangle? then console.log 'Error loading shape ' + @pk + ': invalid rectangle.'
		@rectangle = if @data.rectangle? then new Rectangle(@data.rectangle.x, @data.rectangle.y, @data.rectangle.width, @data.rectangle.height) else new Rectangle()
		@initializeControlPath(@rectangle.topLeft, @rectangle.bottomRight, false, false, true)
		@draw()
		@controlPath.rotation = @data.rotation
		@initialize()
		# Check shape validity
		distanceMax = @constructor.secureDistance*@constructor.secureDistance
		for point, i in points
			@controlPath.segments[i].point == point
			if @controlPath.segments[i].point.getDistance(point, true)>distanceMax
				# @remove()
				@controlPath.strokeColor = 'red'
				view.center = @controlPath.bounds.center
				console.log "Error: invalid shape!"
				return

	moveBy: (delta)-> 
		@rectangle.center.x += delta.x
		@rectangle.center.y += delta.y
		super(delta)
		return

	moveTo: (position)-> 
		@rectangle.center = position
		super(position)
		return

	updateSelectionRectangle: ()->
		bounds = @rectangle.clone().expand(10+@pathWidth()/2)
		@selectionRectangle?.remove()
		@selectionRectangle = new Path.Rectangle(bounds)
		@group.addChild(@selectionRectangle)
		@selectionRectangle.name = 'selection rectangle'
		@selectionRectangle.pivot = @selectionRectangle.bounds.center
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top-25))
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.rotation = @data.rotation
		@selectionRectangle.selected = true
		@selectionRectangle.controller = @
		@controlPath.pivot = @selectionRectangle.pivot

	selectUpdate: (event, userAction=true)->
		console.log "selectUpdate"
		if @selectionRectangleRotation?
			direction = event.point.subtract(@selectionRectangle.bounds.center)
			delta = @selectionRectangleRotation.getDirectedAngle(direction)
			@selectionRectangleRotation = direction
			@data.rotation += delta
			@selectionRectangle.rotation += delta
			@raster?.rotation += delta
			@changed = 'rotated'
			@draw()
		else if @selectionRectangleScale?
			length = event.point.subtract(@selectionRectangle.bounds.center).length
			delta = length/@selectionRectangleScale
			@selectionRectangleScale = length
			@rectangle = @rectangle.scale(delta)
			@selectionRectangle.scale(delta)
			@raster?.scale(delta)
			@changed = 'scaled'
			@draw()
		else
			@group.position.x += event.delta.x
			@group.position.y += event.delta.y

			# @controlPath.position.x += event.delta.x
			# @controlPath.position.y += event.delta.y
			# @raster?.position.x += event.delta.x
			# @raster?.position.y += event.delta.y
			@rectangle.x += event.delta.x
			@rectangle.y += event.delta.y
			# @selectionRectangle.position.x += event.delta.x
			# @selectionRectangle.position.y += event.delta.y
			@changed = 'moved'

		# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventObj(event))

	pathWidth: ()->
		return @data.strokeWidth

	createShape: ()->
		@shape = @addPath(new @constructor.Shape(@rectangle))

	draw: ()->
		try
			@initializeDrawing()
			@createShape()
			@drawing.rotation = @data.rotation
			@rasterize()
		catch error
			console.error error
			throw error

	initializeControlPath: (pointA, pointB, shift, specialKey, load)->
		@group = new Group()
		@group.name = "group"
		@group.controller = @

		if load
			@rectangle = new Rectangle(pointA, pointB)
		else
			square = if @constructor.squareByDefault then (not shift) else shift
			createFromCenter = if @constructor.centerByDefault then (not specialKey) else specialKey
			
			if createFromCenter
				delta = pointB.subtract(pointA)
				@rectangle = new Rectangle(pointA.subtract(delta), pointB)
				# @rectangle = new Rectangle(pointA.subtract(delta), new Size(delta.multiply(2)))
				if square
					center = @rectangle.center
					if @rectangle.width>@rectangle.height
						@rectangle.width = @rectangle.height
					else
						@rectangle.height = @rectangle.width
					@rectangle.center = center
			else
				if not square
					@rectangle = new Rectangle(pointA, pointB)
				else
					width = pointA.x-pointB.x
					height = pointA.y-pointB.y
					min = Math.min(Math.abs(width), Math.abs(height))
					@rectangle = new Rectangle(pointA, pointA.subtract(g.sign(width)*min, g.sign(height)*min))
			
		@controlPath?.remove()
		@controlPath = new Path.Rectangle(@rectangle)
		@group.addChild(@controlPath)
		@controlPath.name = "controlPath"
		@controlPath.controller = @
		@controlPath.strokeWidth = @pathWidth()
		@controlPath.strokeColor = 'black'
		@controlPath.visible = false
		@data.rotation ?= 0
		return

	createBegin: (point, event, loading) ->
		super()
		@downPoint = point
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		if not loading then @draw()

	createUpdate: (point, event, loading) ->
		console.log " event.modifiers.command"
		console.log event.modifiers.command
		console.log g.specialKey(event)
		console.log event?.modifiers?.shift
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		if not loading then @draw()

	createEnd: (point, event, loading) ->
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		@draw()
		super()

	getData: ()->
		data = jQuery.extend({}, @data)
		data.rectangle = { x: @rectangle.x, y: @rectangle.y, width: @rectangle.width, height: @rectangle.height }
		return data

@RShape = RShape

class RectangleShape extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Rectangle'
	# @iconUrl = 'static/images/icons/inverted/rectangle.png'
	# @iconAlt = 'rectangle'
	@rdescription = "Simple rectangle, square by default (use shift key to change to a rectangle). It can have rounded corners."

	@parameters: ()->
		parameters = super()
		parameters['Style'] ?= {} 
		parameters['Style'].cornerRadius =
			type: 'slider'
			label: 'Corner radius'
			min: 0
			max: 100
			default: 0
		return parameters

	createShape: ()->
		@shape = @addPath(new @constructor.Shape(@rectangle, @data.cornerRadius))

@RectangleShape = RectangleShape

class EllipseShape extends RShape
	@Shape = paper.Path.Ellipse
	@rname = 'Ellipse'
	@iconUrl = 'static/images/icons/inverted/circle.png'
	@iconAlt = 'circle'
	@rdescription = "Simple ellipse, circle by default (use shift key to change to an ellipse)."
	@squareByDefault = true
	@centerByDefault = true

@EllipseShape = EllipseShape

class StarShape extends RShape
	@Shape = paper.Path.Star
	@rname = 'Star'
	@rdescription = "Star shape."
	@iconUrl = 'static/images/icons/inverted/star.png'
	@iconAlt = 'star'

	@parameters: ()->
		parameters = super()
		parameters['Style'] ?= {} 
		parameters['Style'].nPoints =
			type: 'slider'
			label: 'N points'
			min: 1
			max: 100
			default: 5
			step: 2
		parameters['Style'].internalRadius =
			type: 'slider'
			label: 'Internal radius'
			min: -200
			max: 100
			default: 37
		parameters['Style'].rsmooth =
			type: 'checkbox'
			label: 'Smooth'
			default: false
		parameters['Style'].animate =
			type: 'checkbox'
			label: 'Animate'
			default: false
		return parameters

	initialize: ()->
		@initializeAnimation(@data.animate)
		return

	createShape: ()->
		rectangle = @rectangle
		if @data.internalRadius>-100
			externalRadius = rectangle.width/2
			internalRadius = externalRadius*@data.internalRadius/100
		else
			internalRadius = rectangle.width/2
			externalRadius = internalRadius*100/@data.internalRadius
		@shape = @addPath(new @constructor.Shape(rectangle.center, @data.nPoints, externalRadius, internalRadius))
		if @data.rsmooth then @shape.smooth()

	onFrame: (event)=>
		@shape.strokeColor.hue += 1
		@shape.rotation += 1
		return

@StarShape = StarShape

class SpiralShape extends RShape
	@Shape = paper.Path.Ellipse
	@rname = 'Spiral'
	# @iconUrl = 'static/images/icons/inverted/spiral.png'
	# @iconAlt = 'spiral'
	@rdescription = "Spiral shape, can have an intern radius, and any number of sides."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {} 
		parameters['Parameters'].minRadius =
			type: 'slider'
			label: 'Minimum radius'
			min: 0
			max: 100
			default: 0
			# onSlide: @radiusMinChanged #optional slide event handler
			# onSlideStop: @radiusMinStopped
		parameters['Parameters'].nTurns =
			type: 'slider'
			label: 'Number of turns'
			min: 1 
			max: 50
			default: 10
		parameters['Parameters'].nSides =
			type: 'slider'
			label: 'Sides'
			min: 3
			max: 100
			default: 50
		parameters['Parameters'].animate =
			type: 'checkbox'
			label: 'Animate'
			default: false
		parameters['Parameters'].rotationSpeed =
			type: 'slider'
			label: 'Rotation speed'
			min: -10
			max: 10
			default: 1

		return parameters

	initialize: ()->
		@initializeAnimation(@data.animate)
		return

	createShape: ()->
		@shape = @addPath()

		rectangle = @rectangle
		hw = rectangle.width/2
		hh = rectangle.height/2
		c = rectangle.center
		angle = 0

		angleStep = 360.0/@data.nSides
		spiralWidth = hw-hw*@data.minRadius/100.0
		spiralHeight = hh-hh*@data.minRadius/100.0
		radiusStepX = (spiralWidth / @data.nTurns) / @data.nSides
		radiusStepY = (spiralHeight / @data.nTurns) / @data.nSides
		for i in [0..@data.nTurns-1]
			for step in [0..@data.nSides-1]
				@shape.add(new Point(c.x+hw*Math.cos(angle), c.y+hh*Math.sin(angle)))
				angle += (2.0*Math.PI*angleStep/360.0)
				hw -= radiusStepX
				hh -= radiusStepY
		@shape.add(new Point(c.x+hw*Math.cos(angle), c.y+hh*Math.sin(angle)))
		return

	onFrame: (event)=>
		@shape.strokeColor.hue += 1
		@shape.rotation += @data.rotationSpeed
		return

@SpiralShape = SpiralShape

class FaceShape extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Face generator'
	# @iconUrl = 'static/images/icons/inverted/spiral.png'
	# @iconAlt = 'spiral'
	@rdescription = "Face generator, inspired by weird faces study by Matthias Dörfelt aka mokafolio."

	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {} 
		parameters['Parameters'].minRadius =
			type: 'slider'
			label: 'Minimum radius'
			min: 0
			max: 100
			default: 0
		parameters['Parameters'].nTurns =
			type: 'slider'
			label: 'Number of turns'
			min: 1 
			max: 50
			default: 10
		parameters['Parameters'].nSides =
			type: 'slider'
			label: 'Sides'
			min: 3
			max: 100
			default: 50

		return parameters

	createShape: ()->
		@headShape = @addPath(new Path.Ellipse(@rectangle.expand(-20,-10)))
		
		@headShape.flatten(50)
		for segment in @headShape.segments
			segment.point.x += Math.random()*20
			segment.point.y += Math.random()*5
			segment.handleIn += Math.random()*5
			segment.handleOut += Math.random()*5
		
		@headShape.smooth()
		
		nozeShape = Math.random()
		
		center = @rectangle.center
		width = @rectangle.width
		height = @rectangle.height
		
		rangeRandMM = (min, max)->
			return min + (max-min)*Math.random()
		
		rangeRandC = (center, amplitude)->
			return center + amplitude*(Math.random()-0.5)
		
		# noze
		if nozeShape < 0.333	# two nostrils
			deltaX = 0.1*width + Math.random()*10
			x = center.x - deltaX
			y = center.y + rangeRandC(0, 5)
			position = center.add(x, y)
			size = new Size(Math.random()*5, Math.random()*5)
			nozeLeft = @addPath(new Path.Ellipse(position, size))
			position += 2*deltaX
			size = new Size(Math.random()*5, Math.random()*5)
			nozeRight = @addPath(new Path.Ellipse(position, size))
		else if nozeShape < 0.666 	# noze toward left
			noze = @addPath()
			noze.add(center)
			noze.add(center.add(Math.random()*15, Math.random()*5))
			noze.add(center.add(0, rangeRandMM(5,10)))
			noze.smooth()
		else				 	# noze toward right
			noze = @addPath()
			noze.add(center)
			noze.add(center.add(-Math.random()*15, Math.random()*5))
			noze.add(center.add(0, rangeRandMM(15,20)))
			noze.smooth()
		
		# eyes
		deltaX = rangeRandC(0, 0.1*width)
		x = center.x - deltaX
		y = @rectangle.top + width/3 + rangeRandC(0, 10)
		position = new Point(x, y)
		size = new Size(Math.max(Math.random()*30,deltaX), Math.random()*30)
		eyeLeft = @addPath(new Path.Ellipse(position, size))
		position.x += 2*deltaX
		
		eyeRight = @addPath(new Path.Ellipse(position, size))
		
		eyeRight.position.x += rangeRandC(0, 5)
		eyeLeft.position.x += rangeRandC(0, 5)
		
		for i in [1 .. eyeLeft.segments.length-1]
			eyeLeft.segments[i].point.x += Math.random()*3
			eyeLeft.segments[i].point.y += Math.random()*3	
			eyeRight.segments[i].point.x += Math.random()*3
			eyeRight.segments[i].point.y += Math.random()*3	
		return


@FaceShape = FaceShape

# class QuantificationPath extends PrecisePath
#   @rname = 'Quantification path'
#   @rdescription = "Quantification path."

#   @parameters: ()->
#     parameters = super()
    
#     parameters['Parameters'] ?= {} 
#     parameters['Parameters'].quantification =
#         type: 'slider'
#         label: 'Quantification'
#         min: 0
#         max: 100
#         default: 10
    
#     return parameters

#   constructor: (@date=null, @data=null, @pk=null, points=null) ->
#     super(@date, @data, @pk, points)

#   drawBegin: ()->

#     @initializeDrawing(false)

#     @path = @addPath()
#     return

#   drawUpdate: (length)->

#     point = @controlPath.getPointAt(length)
#     quantification = @data.quantification
#     point.x = Math.floor(point.x/quantification)*quantification
#     point.y = Math.floor(point.y/quantification)*quantification
#     @path.add(point)
#     return

#   drawEnd: ()->
#     return

# @QuantificationPath = QuantificationPath




# class Brush extends PrecisePath
# 	@rname = 'New path'
# 	@rdescription = "New tool description."

# 	@parameters: ()->
# 		parameters = super()
# 		###
# 		parameters['Parameters'] ?= {} 
# 		parameters['Parameters'].width =
# 			type: 'slider'
# 			label: 'Width'
# 			min: 2
# 			max: 100
# 			default: 10
# 		###
# 		return parameters

# 	drawBegin: ()->
# 		@initializeDrawing(true)
		
# 		width = @data.strokeWidth
		
# 		canvas = document.createElement("canvas")
# 		context = canvas.getContext('2d')
# 		gradient = context.createRadialGradient(width/2, width/2, 0, width/2, width/2, width/2)
# 		gradient.addColorStop(0, '#8ED6FF')
# 		gradient.addColorStop(1, '#004CB3')
# 		context.fillStyle = gradient
# 		context.fill()
# 		@gradientData = context.getImageData(0, 0, width, width)
# 		return

# 	drawUpdate: (length)->
# 		point = @controlPath.getPointAt(length)
# 		point = @projectToRaster(point)
# 		width = @data.strokeWidth
# 		@context.putImageData(@gradientData, point.x-width/2, point.y-width/2)
# 		return

# 	drawEnd: ()->
# 		return

class Checkpoint extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Checkpoint'
	# @iconUrl = 'static/images/icons/inverted/spiral.png'
	# @iconAlt = 'spiral'
	@rdescription = "Checkpoint."
	@squareByDefault = false
	
	constructor: (@date=null, @data=null, @pk=null, points=null) ->
		super(@date, @data, @pk, points)
		return

	initialize: ()->
		@game = g.gameAt(@rectangle.center)
		if @game?
			if @game.checkpoints.indexOf(@)<0 then @game.checkpoints.push(@)
			@data.checkpointNumber ?= @game.checkpoints.indexOf(@)
		return

	createShape: ()->
		@data.strokeColor = 'rgb(150,30,30)'
		@data.fillColor = null
		@shape = @addPath(new Path.Rectangle(@rectangle))
		@text = @addPath(new PointText(@rectangle.center.add(0,4)))
		@text.content = if @data.checkpointNumber? then 'Checkpoint ' + @data.checkpointNumber else 'Checkpoint'
		@text.justification = 'center'
		
		return

	contains: (point)->
		delta = point.subtract(@rectangle.center)
		delta.rotation = -@data.rotation
		return @rectangle.contains(@rectangle.center.add(delta))

	remove: ()->
		@game?.checkpoints.remove(@)
		super()
		return

@Checkpoint = Checkpoint