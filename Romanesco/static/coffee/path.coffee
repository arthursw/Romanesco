# todo: Actions, undo & redo...
# todo: strokeWidth min = 0?
# todo change bounding box selection
# todo/bug?: if @data? but not @data.id? then @id is not initialized, causing a bug when saving..
# todo: have a selectPath (simplified version of group to test selection)instead of the group ?
# todo: replace smooth by rsmooth and rdata in general.

# important todo: pass args in deffered exec to update 'points' or 'data'

# RPath: mother of all romanesco paths
# A romanesco path (RPath) is a path made of the following items:
# - a control path, with which users will interact
# - a drawing group (the drawing) containing all visible items built around the control path (it must follow the control path)
# - a selection group (containing a selection path) when the RPath is selected; it enables user to scale and rotate the RPath
# - a group (main group or *group*) which contains all of the previous items

# There are three main RPaths:
# - PrecisePath adds control handles to the control path (which can be hidden): one can edit, add or remove points, to precisely shape the curve.
# - SpeedPath which extends PrecisePath to add speed functionnalities: 
#    - the speed at which the user has drawn the path is stored and has influence on the drawing,
#    - the speed values are displayed as normals of the path, and can be edited thanks to handles
#    - when the user drags a handle, it will also influence surrounding speed values depending on how far from the normal the user drags the handle (with a gaussian attenuation)
#    - the speed path and handles are added to a speed group, which is added to the main group
#    - the speed group can be shown or hidden
# - RShape defined by a rectangle in which the drawing should be included (the user draws the rectangle with the mouse)

# Those three RPaths (PrecisePath, SpeedPath and RShape) provide drawing functionnalities and are meant to be overridden to generate some advanced paths:
# - in PrecisePath and SpeedPath, three methods are meant to be overridden: drawBegin, drawUpdate and drawEnd, 
#   see {PrecisePath} to see how those methods are called while drawing.
# - in RShape, {RShape#createShape} is meant to be overloaded

# Parameters:
# - parameters are defined as in RTools
# - all data related to the parameters (and state) of the RPath is stored under the @data property
# - dy default, when a parameter is chanegd in the gui, onParameterChange is called

# tododoc: loadPath will call create begin, update, end
# todo-doc: explain userAction?
# todo-doc: explain ID?

# Notable differences between RPath:
# - in regular path: when transforming a path, the points of the control path are resaved with their new positions; no transform information is stored
# - in RShape: the rectangle  is never changed with transformations; instead the rotation and scale are stored in @data and taken into account at each draw

class RPath
	@rname = 'Pen' 										# the name used in the gui (to create the button and for the tooltip/popover)
	@rdescription = "The classic and basic pen tool" 	# the path description
	@cursorPosition = { x: 24, y: 0 } 					# the position of the cursor image (relative to the cursor position)
	@cursorDefault = "crosshair" 						# the cursor to use with this path

	# Paper hitOptions for hitTest function to check which items (corresponding to those criterias) are under a point
	@hitOptions =
		segments: true
		stroke: true
		fill: true
		selected: true
		tolerance: 5

	@constructor.secureDistance = 2 					# the points of the flattened path must not be 5 pixels away from the recorded points

	# parameters are defined as in {RTool}
	# The following parameters are reserved for romanesco: id, polygonMode, points, planet, step, smooth, speeds, showSpeeds
	@parameters: ()->
		return parameters =
			'General': 
				# zoom: g.parameters.zoom
				# displayGrid: g.parameters.displayGrid
				# snap: g.parameters.snap 
				align: g.parameters.align 				# common parameters are defined in g.parameters
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

	# Create the RPath and initialize the drawing creation if a user is creating it, or draw if the path is being loaded
	# When user creates a path, the path is given an identifier (@id); when the path is saved, the servers returns a primary key (@pk) and @id will not be used anymore
	# @param date [Date] (optional) the date at which the path has been crated (will be used as z-index in further versions)
	# @param data [Object] (optional) the data containing information about parameters and state of RPath
	# @param pk [ID] (optional) the primary key of the path in the database
	# @param points [Array of Point] (optional) the points of the controlPath, the points must fit on the control path (the control path is stored in @data.points)
	constructor: (@date=null, @data=null, @pk=null, points=null) ->
		@selectedSegment = null
		
		@id = if @data? then @data.id else Math.random() 	# temporary id used until the server sends back the primary key (@pk)

		g.paths[@id] = @ 									# adds the path to the map of all RItems. key is @id for now, it will be replaced with @pk when server responds

		if not @data? 				# if not @data then set @data to the values of the controllers in the gui
			@data = new Object()
			@data.id = @id
			for name, folder of g.gui.__folders
				if name=='General' then continue
				for controller in folder.__controllers
					@data[controller.property] = controller.rValue() 	# rValue returns the value of the controller, and custom information (in case of color: must return null if checkbox is uncheck)
		
		# if the RPath is being loaded: directly set pk and load path
		if @pk?
			@setPK(@pk, false)
		if points?
			@loadPath(points)
		return
	
	# common to all RItems
	# construct a new RPath and save it
	# @return [RPath] the copy
	duplicate: ()->
		copy = new @constructor(new Date(), @getData(), null, @pathOnPlanet())
		copy.save()
		return copy

	# returns the maximum width of the RPath arround control path
	# the drawing can not exeed the limit of *@pathWidth()* around the contorl path
	# path width is used for example for hit tests and to determine is the RPath overlaps on an RLock
	pathWidth: ()->
		return @data.strokeWidth

	# common to all RItems
	# return [Rectangle] the bounds of the control path (should fit the drawing entirely since the stroke width is pathWidth)
	getBounds: ()->
		return @controlPath.strokeBounds

	# common to all RItems
	# @return [Array<{x: x, y: y}>] the list of areas on which the item lies
	getAreas: ()->
		bounds = @getBounds()
		t = Math.floor(bounds.top / g.scale)
		l = Math.floor(bounds.left / g.scale)
		b = Math.floor(bounds.bottom / g.scale)
		r = Math.floor(bounds.right / g.scale)
		areas = {}
		for x in [l .. r]
			for y in [t .. b]
				areas[x] ?= {}
				areas[x][y] = true
		return areas

	# common to all RItems
	# move the RPath by *delta* and update if *userAction*
	# @param delta [Point] the amount by which moving the path
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	moveBy: (delta, userAction)->
		@group.position.x += delta.x
		@group.position.y += delta.y
		if userAction
			g.defferedExecution(@update, @getPk())
			# if g.me? and userAction then g.chatSocket.emit( "double click", g.me, @pk, g.eventToObject(event))
		return

	# common to all RItems
	# move the RPath to *position* and update if *userAction*
	# @param position [Point] the new position of the path
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	# @return [Paper point] the new position
	moveTo: (position, userAction)->
		bounds = @getBounds()
		delta = @group.position.subtract(bounds.center)
		@group.position = position.add(delta)
		if userAction
			g.defferedExecution(@update, @getPk())
			# if g.me? and userAction then g.chatSocket.emit( "double click", g.me, @pk, g.eventToObject(event))
		return position.add(delta)

	# convert a point from project coordinate system to raster coordinate system
	# @param point [Paper point] point to convert
	# @return [Paper point] resulting point
	projectToRaster: (point)->
		return point.subtract(@canvasRaster.bounds.topLeft)

	# set path items (control path, drawing, etc.) to the right state before performing hitTest
	# store the current state of items, and change their state (the original states will be restored in @finishHitTest())
	# @param fullySelected [Boolean] (optional) whether the control path must be fully selected before performing the hit test (it must be if we want to test over control path handles)
	# @param strokeWidth [Number] (optional) contorl path width will be set to *strokeWidth* if it is provided
	prepareHitTest: (fullySelected=true, strokeWidth)->
		console.log "prepareHitTest"
		@hitTestSelected = @controlPath.selected  				# store control path select state

		if fullySelected 										# select control path
			@hitTestFullySelected = @controlPath.fullySelected
			@controlPath.fullySelected = true
		else
			@controlPath.selected = true

		# set control path and drawing to visible
		# improvement: hide drawing to speed up the hitTest?
		@hitTestControlPathVisible = @controlPath.visible
		@controlPath.visible = true
		# @hitTestGroupVisible = @drawing?.visible
		# @drawing?.visible = true
		
		@hitTestStrokeWidth = @controlPath.strokeWidth
		if strokeWidth then @controlPath.strokeWidth = strokeWidth

		# hide raster and canvas raster
		# @raster?.visible = false
		# @canvasRaster?.visible = false
		return

	# restore path items orginial states (same as before @prepareHitTest())
	# @param fullySelected [Boolean] (optional) whether the control path must be fully selected before performing the hit test (it must be if we want to test over control path handles)
	finishHitTest: (fullySelected=true)->
		console.log "finishHitTest"
		if fullySelected then @controlPath.fullySelected = @hitTestFullySelected
		@controlPath.selected = @hitTestSelected
		@controlPath.visible = @hitTestControlPathVisible
		# @drawing?.visible = @hitTestGroupVisible
		@controlPath.strokeWidth = @hitTestStrokeWidth
		# @raster?.visible = true
		# @canvasRaster?.visible = true
		return

	# perform hit test to check if the point hits the selection rectangle  
	# @param point [Point] the point to test
	# @param hitOptions [Object] the [paper hit test options](http://paperjs.org/reference/item/#hittest-point)
	hitTest: (point, hitOptions)->
		return @selectionRectangle.hitTest(point)

	# when hit through websocket, must be (fully)Selected to hitTest
	# perform hit test on control path and selection rectangle with a stroke width of 1
	# to manipulate points on the control path or selection rectangle
	# since @hitTest() will be overridden by children RPath, it is necessary to @prepareHitTest() and @finishHitTest()
	# @param point [Point] the point to test
	# @param hitOptions [Object] the [paper hit test options](http://paperjs.org/reference/item/#hittest-point)
	# @param fullySelected [Boolean] (optional) whether the control path must be fully selected before performing the hit test (it must be if we want to test over control path handles)
	# @return [Paper HitResult] the paper hit result
	performHitTest: (point, hitOptions, fullySelected=true)->
		@prepareHitTest(fullySelected, 1)
		hitResult = @hitTest(point, hitOptions)
		@finishHitTest(fullySelected)
		return hitResult

	# add or update the selection rectangle (path used to rotate and scale the RPath)
	# redefined by RShape
	updateSelectionRectangle: ()->
		# reset the selection rectangle (and use contorl path bounds as rectangle) if the control path has default transformation (rotation==0 and scaling==(1, 1))
		reset = not @selectionRectangleBounds? or @controlPath.rotation==0 and @controlPath.scaling.x == 1 and @controlPath.scaling.y == 1
		if reset
			@selectionRectangleBounds = @controlPath.bounds.clone()

		# expand the selection rectangle to fit the entire drawing, and to avoid interference (overlapping) between control path and selection rectangle
		bounds = @selectionRectangleBounds.clone().expand(10+@pathWidth()/2)
		@selectionRectangle?.remove()

		# create the selection rectangle: rectangle path + handle at the top used for rotations
		@selectionRectangle = new Path.Rectangle(bounds)
		@group.addChild(@selectionRectangle)
		@selectionRectangle.name = "selection rectangle"
		@selectionRectangle.pivot = @selectionRectangle.bounds.center
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top-25))
		@selectionRectangle.insert(2, new Point(bounds.center.x, bounds.top))
		if not reset 				# restore transformations if not reset
			@selectionRectangle.position = @controlPath.position
			@selectionRectangle.rotation = @controlPath.rotation
			@selectionRectangle.scaling = @controlPath.scaling
		@selectionRectangle.selected = true
		@selectionRectangle.controller = @
		@controlPath.pivot = @selectionRectangle.pivot 	# set contol path pivot to the selection rectangle pivot, otherwise they are not the same because of the handle
		return

	# common to all RItems
	# select the RPath: (only if it has a control path but no selection rectangle i.e. already selected)
	# - create or update the selection rectangle, 
	# - create or update the global selection group (i.e. add this RPath to the grouop)
	# - (optionally) update controller in the gui accordingly
	# @param updateOptions [Boolean] whether to update controllers in gui or not
	select: (updateOptions=true)->
		if not @controlPath? then return
		if @selectionRectangle? then return
		console.log "select"

		# create or update the selection rectangle
		@selectionRectangleRotation = null
		@selectionRectangleScale = null
		@updateSelectionRectangle()

		# create or update the global selection group (i.e. add this RPath to the grouop)
		g.selectionGroup ?= new Group()
		g.selectionGroup.name = 'selection group'
		g.selectionGroup.addChild(@group)

		# create or update the global selection group
		if updateOptions then g.updateParameters( { tool: @constructor, item: @ } , true)
		# debug:
		g.s = @
		return

	# deselect: remove the selection rectangle (and rasterize)
	deselect: ()->
		console.log "deselect"
		if not @selectionRectangle? then return
		@selectionRectangle?.remove()
		@selectionRectangle = null
		@rasterize()
		return

	# called when user deselects, after a not simplified draw or once the user finished creating the path
	# this is suppose to convert all the group to a raster to speed up paper.js operations, but it does not drastically improve speed, so it is just commented out
	rasterize: ()->
		# if @raster? or not @drawing? then return
		# @raster = @drawing.rasterize()
		# @group.addChild(@raster)
		# @drawing.visible = false
		return

	# perform a hit test and initialize the selection
	# called by @selectBegin()
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	# @return [String] string describing how will the path change during the selection process. The string can be 'rotation', 'scale', 'segment', 'move' or null (if nothing must be changed)
	# 				   *change* is also used as soon as something changes before the update (for example when a parameter is changed, it is set to the name of the parameter)
	hitTestAndInitSelection: (event, userAction)->
		hitResult = @performHitTest(event.point, @constructor.hitOptions)
		if not hitResult? then return null
		return @initSelection(event, hitResult, userAction)

	# intialize the selection: 
	# determine which action to perform depending on the the *hitResult* (move by default, edit point if segment from contorl path, etc.)
	# set @selectedSegment, @selectionRectangleRotation or @selectionRectangleScale which will be used during the selection process (select begin, update, end)
	# @param event [Paper event] the mouse event
	# @param hitResult [Paper HitResult] [paper hit result](http://paperjs.org/reference/hitresult/) form the hit test
	# @param userAction [Boolean] (optional) whether this is an action from *g.me* or another user 
	# redefined by {PrecisePath}, only used as is by {RShape}
	# the transformation is not intialized the same way for PrecisePath and for RShape
	# @return [String] string describing how will the path change during the selection process. The string can be 'rotation', 'scale', 'segment' or 'move';
	# 				   *change* is also used as soon as something changes before the update (for example when a parameter is changed, it is set to the name of the parameter)
	initSelection: (event, hitResult, userAction=true) ->
		# @selectionRectangleRotation and @selectionRectangleScale store the position of the mouse relatively to the selection rectangle, 
		# they will be used for transformation in @selectUpdate() but they are not initialized in the same way for PrecisePath and RShape

		change = 'move' 				# change is 'move' by default
		if hitResult.type == 'segment' 						# if user hit a segment which belongs to the control path: this segment will be moved
			if hitResult.item == @controlPath
				@selectedSegment = hitResult.segment
				change = 'segment'
			else if hitResult.item == @selectionRectangle 	# if the segment belongs to the selection rectangle: initialize rotation or scaling
				if hitResult.segment.index >= 2 and hitResult.segment.index <= 4
					@selectionRectangleRotation = event.point.subtract(@selectionRectangle.bounds.center)
					change = 'rotation'
				else
					@selectionRectangleScale = event.point.subtract(@selectionRectangle.bounds.center).length #/@controlPath.scaling.x
					change = 'scale'
		return change

	# common to all RItems
	# begin select action:
	# - initialize selection (reset selection state)
	# - select if *userAction*
	# - hit test and initilize selection
	# - hide other path if in fast mode
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	# @return [String] string describing how will the path change during the selection process. The string can be 'rotation', 'scale', 'segment' or 'move';
	# 				   *change* is also used as soon as something changes before the update (for example when a parameter is changed, it is set to the name of the parameter)
	selectBegin: (event, userAction=true) ->
		# if not userAction and @changed
		# 	romanesco_alert("This path is already being modified.", "error")
		# 	return
		console.log "selectBegin"
		
		# initialize selection (reset selection state)
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
		
		if g.fastMode and change != 'move' # hide other path if in fast mode
			g.hideOthers(@)

		# if g.me? and userAction then g.chatSocket.emit( "select begin", g.me, @pk, g.eventToObject(event))

		return change

	# common to all RItems
	# update select action
	# to be redefined by children classes
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	selectUpdate: (event, userAction=true)->
		console.log "selectUpdate"
		return

	# common to all RItems
	# end select action
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	selectEnd: (event, userAction=true)->
		console.log "selectEnd"
		@selectionRectangleRotation = null
		@selectionRectangleScale = null
		if userAction and @changed?
			@update('point')
			# if g.me? and userAction then g.chatSocket.emit( "select end", g.me, @pk, g.eventToObject(event))
		@changed = null

		if g.fastMode
			g.showAll(@)
		return

	# double click action
	# to be redefined in children classes
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	doubleClick: (event, userAction=true)->
		return

	# redraw the skeleton (controlPath) of the path, 
	# called only when loading a path
	# redefined in PrecisePath, extended by shape (for security checks)
	# @param points [Array of Point] (optional) the points of the controlPath
	loadPath: (points)->
		for point, i in points
			if i==0
				@createBegin(point, null, true)
			else
				@createUpdate(point, null, true)
		if points.length>0
			@createEnd(points.last(), null, true)
		@draw(null, true)
		return

	# common to all RItems
	# called when a parameter is changed:
	# - from user action (parameter.onChange) (update = true)
	# - from websocket (another user changed the parameter) (update = false)
	# @param update [Boolean] (optional, default is true) whether to update the RPath in database
	parameterChanged: (update=true)->
		if not @drawing then g.updateView()
		@previousBoundingBox ?= @getBounds()
		@draw()		# if draw in simple mode, then how to see the change of parameters which matter?
		if update then g.defferedExecution(@update, @getPk())
		return

	# add a path to the drawing group:
	# - create the path
	# - initilize it (stroke width, and colors) with @data
	# - add to the drawing group
	# @param path [Paper path] (optional) the path to add to drawing, create an empty one if not provided
	# @return [Paper path] the resulting path
	addPath: (path)->
		path ?= new Path()
		path.name = 'group path'
		path.controller = @
		path.strokeColor = @data.strokeColor
		path.strokeWidth = @data.strokeWidth
		path.fillColor = @data.fillColor
		@drawing.addChild(path)
		return path

	# initialize the drawing group before drawing:
	# - create drawing group and initialize it with @data (add it to group)
	# - optionally create a child canvas to draw on it (drawn in a raster, add it to group)
	#   - this child canvas is used to speed up drawing operations (bypass paper.js drawing tools) when heavy drawing operations are required
	#   - the advantage is speed, the drawback is that we loose the great benefits of paper.js (ease of use, export to SVG)
	#   - the image drawn on the child canvas can not be exported in svg since it is not taken into account by paper.js
	#   - if there is no control path yet (meaning the user did not even start drawing the RPath, mouse was just pressed)
	#     - create the canvas at the size of the view
	#     else
	#     - create canvas to the dimensions of the control path
	# @param createCanvas [Boolean] (optional, default to true) whether to create a child canavs *@canverRaster*
	initializeDrawing: (createCanvas=false)->
		
		@raster?.remove()
		@raster = null

		@controlPath.strokeWidth = @pathWidth()

		# create drawing group and initialize it with @data
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

		# optionally create a child canvas to draw on it
		if createCanvas
			canvas = document.createElement("canvas")

			# if their is no control path yet (meaning the user did not even start drawing the RPath, mouse was just pressed)
			if @controlPath.length<=1
				# create the canvas at the size of the view
				canvas.width = view.size.width
				canvas.height = view.size.height
				position = view.center
			else
				# create canvas to the dimensions of the bounds
				bounds = @getBounds()
				canvas.width = bounds.width
				canvas.height = bounds.height
				position = bounds.center

			@canvasRaster?.remove()
			@canvasRaster = new Raster(canvas, position)
			@group.addChild(@canvasRaster)
			@context = @canvasRaster.canvas.getContext("2d")
			@context.strokeStyle = @data.strokeColor
			@context.fillStyle = @data.fillColor
			@context.lineWidth = @data.strokeWidth
		return

	# set animated: push/remove RPath to/from g.animatedItems
	# @param animated [Boolean] whether to set the path as animated or not animated
	setAnimated: (animated)->
		if animated
			@registerAnimation()
		else
			@deregisterAnimation()
		return

	# register animation: push RPath to g.animatedItems
	registerAnimation: ()->
		i = g.animatedItems.indexOf(@)
		if i<0 then g.animatedItems.push(@)
		return

	# deregister animation: remove RPath from g.animatedItems
	deregisterAnimation: ()->
		i = g.animatedItems.indexOf(@)
		if i>=0 then g.animatedItems.splice(i, 1)
		return
	
	# update the appearance of the path (the drawing group)
	# called anytime the path is modified:
	# by createBegin/Update/End, selectUpdate/End, parameterChanged, deletePoint, changePoint etc. and loadPath
	# must be redefined in children RPath
	# because the path are rendered on rasters, path are not drawn on load unless they are animated
	# @param simplified [Boolean] whether to draw in simplified mode or not (much faster)
	# @param loading [Boolean] whether the path is being loaded or drawn by a user
	draw: (simplified=fasle, loading=fasle)->
		return

	# called once after createEnd to initialize the path (add it to a game, or to the animated paths)
	# must be redefined in children RPath
	initialize: ()->
		return

	# createBegin, createUpdate, createEnd
	# called from loadPath (draw the skeleton when path is loaded), then *event* is null
	# called from PathTool.begin, PathTool.update and PathTool.end (when the user draws something), then *event* is the Paper mouse event
	# @param point [Point] point to peform the action
	# @param event [Paper event of REvent] the mouse event
	createBegin: (point, event) ->
		return

	# see createBegin
	createUpdate: (point, event) ->
		return

	# see createBegin
	createEnd: (point, event) ->
		@initialize()
		return

	# update the z index (to be used in further version) i.e. move the path to the right position
	# - RPath are kept sorted by z-index in *g.sortedPath*
	# - z-index are initialize to the current date (this is a way to provide a global z index even with RPath which are not loaded)
	# to be updated
	updateZIndex: ()->
		if @date?
			#insert path at the right place
			if g.sortedPaths.length==0
				g.sortedPaths.push(@)
			for path, i in g.sortedPaths
				if @date > path.date
					g.sortedPaths.splice(i+1, 0, @)
					@insertAbove(path)
		return

	# insert above given *path*
	# @param path [RPath] path on which to insert this
	# to be updated
	insertAbove: (path)->
		@controlPath.insertAbove(path.controlPath)
		@drawing?.insertBelow(@controlPath)
		return

	# common to all RItems
	# get data, usually to save the RPath (some information must be added to data)
	getData: ()->
		return @data
	
	# common to all RItems
	# @return [String] the stringified data
	getStringifiedData: ()->
		return JSON.stringify(@getData())

	# @return [Point] the planet on which the RPath lies
	planet: ()->
		return projectToPlanet( @controlPath.segments[0].point )

	# check that the path does not lie between two planets before update
	# @return [Boolean] whether we can update the RPath or not (is contained in one planet or not)
	prepareUpdate: ()->
		path = @controlPath

		if path.segments.length<2 					# ~deprecated: if the user want to add a single point: make another point beside to make is GeoJson valid
			p0 = path.segments[0].point
			path.add( new Point(p0.x+1, p0.y) )

		if g.pathOverlapsTwoPlanets(path)
			romanesco_alert("You can not create nor update a line in between two planets, this is not yet supported.", "info")
			return false

		return true

	# save RPath to server
	save: ()->
		if not @controlPath? then return
		if not @prepareUpdate() then return
		# ajaxPost '/savePath', {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData() } , @save_callback
		
		# rectangle = @getBounds()
		# if not @data?.animate
		# 	extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)

		Dajaxice.draw.savePath( @save_callback, {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData(), 'areas': @getAreas() } )
		# Dajaxice.draw.savePath( @save_callback, {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData(), 'rasterData': extraction.dataURL, 'rasterPosition': rectangle.topLeft, 'areasNotRasterized': extraction.areasNotRasterized } )
		
		if not @data?.animate
			g.updateRasters(@getBounds())
		# rectangle = @getBounds()
		# if not @data?.animate
		# 	extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)
		# 	Dajaxice.draw.updateRasters( g.checkError, { 'data': extraction.dataURL, 'rectangle': rectangle, 'areasNotExtracted': extraction.areasNotExtracted } )
		return

	# check if the save was successful and set @pk if it is
	save_callback: (result)=>
		g.checkError(result)
		@setPK(result.pk)
		return

	# update the RPath in the database
	# often called after the RPath has changed, in a *g.defferedExecution(@update)*
	# @param type [String] type of change to consider (in further version, could send only the required information to the server to make the update to improve performances)
	update: (type)=>
		console.log "update: " + @pk
		if not @pk? then return 	# null when was deleted (update could be called on selectEnd)
		if not @prepareUpdate() then return

		Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData(), 'areas': @getAreas() } )
		
		if not @data?.animate
			
			if not @drawing?
				@draw()

			selectionHighlightVisible = @selectionHighlight?.visible
			@selectionHighlight?.visible = false
			speedGroupVisible = @speedGroup?.visible
			@speedGroup?.visible = false

			rectangle = @getBounds()

			if @previousBoundingBox?
				union = rectangle.unite(@previousBoundingBox)
				if rectangle.intersects(@previousBoundingBox) and union.area < @previousBoundingBox.area*2
					g.updateRasters(union)
				else
					g.updateRasters(rectangle)
					g.updateRasters(@previousBoundingBox)

				@previousBoundingBox = null
			else
				g.updateRasters(rectangle)

			@selectionHighlight?.visible = selectionHighlightVisible
			@speedGroup?.visible = speedGroupVisible
		# if type == 'points'
		# 	# ajaxPost '/updatePath', {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() }, @updatePath_callback
		# 	Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() } )
		# else
		# 	# ajaxPost '/updatePath', {'pk': @pk, 'data': @getStringifiedData() } , @updatePath_callback
		# 	Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'data': @getStringifiedData() } )

		@changed = null
		return

	# check if update was successful
	updatePath_callback: (result)->
		g.checkError(result)
		return

	# get the database primary key (@pk) or @id if it is not saved yet
	# @return [ID] @pk or @id
	getPk: ()->
		return if @pk? then @pk else @id

	# set @pk, update g.items and emit @pk to other users
	# @param pk [ID] the new pk
	# @param updateRoom [updateRoom] (optional) whether to emit @pk to other users in the room
	setPK: (pk, updateRoom=true)->
		@pk = pk
		g.paths[pk] = @
		g.items[pk] = @
		delete g.paths[@id]
		if updateRoom
			g.chatSocket.emit( "setPathPK", g.me, @id, @pk)
		return
	
	# common to all RItems
	# called by @delete() and to update users view through websockets
	# @delete() removes the path and delete it in the database
	# @remove() just removes visually
	remove: ()->
		@deselect()
		@deregisterAnimation()
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
		return

	# common to all RItems
	# @delete() removes the path, update rasters and delete it in the database
	# @remove() just removes visually
	delete: ()->
		@group.visible = false
		if not @drawing then g.updateView()
		g.updateRasters(@getBounds())
		@remove()
		if not @pk? then return
		console.log @pk
		# ajaxPost '/deletePath', { pk: @pk } , @deletePath_callback
		Dajaxice.draw.deletePath(@deletePath_callback, { pk: @pk })

		@pk = null
		return

	# check if delete was successful and emit "delete path" to other users if so
	deletePath_callback: (result)->
		if g.checkError(result)
			g.chatSocket.emit( "delete path", result.pk )
		return

	# @param controlSegments [Array<Paper Segment>] the control path segments to convert in planet coordinates
	# return [Array of Paper point] a list of point from the control path converted in the planet coordinate system
	pathOnPlanet: (controlSegments=@controlPath.segments)->
		points = []
		planet = @planet()
		for segment in controlSegments
			p = projectToPosOnPlanet(segment.point, planet)
			points.push( pointToArray(p) )
		return points

@RPath = RPath

# PrecisePath extends RPath to add precise editing functionalities
# PrecisePath adds control handles to the control path (which can be hidden): 
# one can edit, add or remove points, to precisely shape the curve.
# The user can edit the curve with the 'Edit Curve' folder of the gui

# Points of a PrecisePath can have three states:
# - smooth (default): the handles of the point are always aligned, they are not necessarly of the same size (although they are equal if the user presses the shift key)
# - corner: the handles of the point are independent, giving the possibility to make sharp corners
# - point: the point has no handles, it is simple to manipulate

# A precise path has two modes:
# - the default mode: handles are editable
# - the smooth mode: handles are not editable and the control path is [smoothed](http://paperjs.org/reference/path/#smooth)

# A precise path has two creation modes:
# - the default mode: a point is added to the control path when the user drags the mouse (at each drag event), resulting in many close points
# - the polygon mode: a point is added to the control path when the user clicks the mouse, and the last handle is modified when the user drags the mouse

# # The drawing

# The drawing is performed as follows:
# - the control path is divided into a number of steps of fixed size (giving points along the control path at regular intervals)
# - the drawing is updated at each of those points
# - to have better results, the remaining step (which is shorter) is split in half and distributed among the first and last step
# - the size of the steps is data.step, and can be added in the gui
# - during the drawing process, the *offset* property corresponds to the current position along the control path where the drawing must be updated 
#   (offset can be seen as the length of the drawing along the path)

# For example the simplest precise path is as a set of points regularly distributed along the control path;
# a more complexe precise path would also be function of the normal and the tangent of the control point at each point.

# The drawing is performed with three methods:
# - drawBegin() called to initialize the drawing,
# - drawUpdate() called at each update,
# - drawEnd() called at the end of the drawing.

# There are two cases where precise path is created:
# - when the user creates the path with the mouse:
#     - each time a new point is added to the control path:
#       drawUpdate() is called to continue the drawing along the control path until *offset* (the length of the drawing) equals the control path length (minus the remaining step)
#       this process takes place in {PrecisePath#checkUpdateDrawing} (it is overridden by {SpeedPath#checkUpdateDrawing})
#       it is part of the createBegin/Update/End() process
# - when the path is loaded (or when the control path exists):
#     - the remaining step (which is shorter) is split in half and distributed among the first and last step
#     - drawUpdate() is called in a loop to draw the whole drawing along the control path at once, in {PrecisePath#draw}

class PrecisePath extends RPath
	@rname = 'Precise path'
	@rdescription = "This path offers precise controls, one can modify points along with their handles and their type."
	@iconUrl = 'static/images/icons/inverted/editCurve.png'
	@iconAlt = 'edit curve'

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

	# overload {RPath#constructor}
	constructor: (@date=null, @data=null, @pk=null, points=null) ->
		super(@date, @data, @pk, points)
		@data.polygonMode = g.polygonMode
		return

	# redefine {RPath#loadPath}
	# load control path from @data.points and check if *points* fit to the created control path
	loadPath: (points)->
		# load control path from @data.points
		@createBegin(posOnPlanetToProject(@data.points[0], @data.planet), null, true)
		for point, i in @data.points by 4
			if i>0 then @controlPath.add(posOnPlanetToProject(point, @data.planet))
			@controlPath.lastSegment.handleIn = new Point(@data.points[i+1])
			@controlPath.lastSegment.handleOut = new Point(@data.points[i+2])
			@controlPath.lastSegment.rtype = @data.points[i+3]
		if points.length == 2 then @controlPath.add(points[1])
		@createEnd(posOnPlanetToProject(@data.points[@data.points.length-4], @data.planet), null, true)

		time = Date.now()

		# check if points fit to the newly created control path:
		# - flatten a copy of the control path, as it was flattened when the path was saved
		# - check if *points* correspond to the points on this flattened path
		flattenedPath = @controlPath.copyTo(project)
		flattenedPath.flatten(@constructor.secureStep)
		distanceMax = @constructor.secureDistance*@constructor.secureDistance

		# only check 10 random points to speed up security check
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
		return

	# redefine hit test to test not only on the selection rectangle, but also on the control path
	# @param point [Point] the point to test
	# @param hitOptions [Object] the [paper hit test options](http://paperjs.org/reference/item/#hittest-point)
	hitTest: (point, hitOptions)->
		if @speedGroup?.visible then hitResult = @handleGroup?.hitTest(point)
		hitResult ?= @selectionRectangle.hitTest(point)
		hitResult ?= @controlPath.hitTest(point, hitOptions)
		return hitResult

	# initialize drawing
	# @param createCanvas [Boolean] (optional, default to true) whether to create a child canavs *@canverRaster*
	initializeDrawing: (createCanvas=false)->
		@data.step ?= 20 	# developers do not need to put @data.step in the parameters, but there must be a default value
		@offset = 0
		super(createCanvas)
		return

	# default drawBegin function, will be redefined by children PrecisePath
	# @param createCanvas [Boolean] (optional, default to true) whether to create a child canavs *@canverRaster*
	drawBegin: (createCanvas=false)->
		console.log "drawBegin"
		@initializeDrawing(createCanvas)
		@path = @addPath()
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	# default drawUpdate function, will be redefined by children PrecisePath
	# @param offset [Number] the offset along the control path to begin drawing
	drawUpdate: (offset)->
		console.log "drawUpdate"
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	# default drawEnd function, will be redefined by children PrecisePath
	drawEnd: ()->
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	# continue drawing the path along the control path if necessary:
	# - the drawing is performed every *@data.step* along the control path
	# - each time the user adds a point to the control path (either by moving the mouse in normal mode, or by clicking in polygon mode)
	#   *checkUpdateDrawing* check by how long the control path was extended, and calls @drawUpdate() if some draw step must be performed
	# called only when creating the path (not when we load it) (by createUpdate and finishPath)
	# @param event [Event] the mouse event
	checkUpdateDrawing: (event)->
		step = @data.step
		controlPathLength = @controlPath.length

		while @offset+step<controlPathLength
			@offset += step
			@drawUpdate(@offset)
		return

	# initialize the main group and the control path
	# @param point [Point] the first point of the path
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

	# redefine {RPath#createBegin}
	# begin create action:
	# initialize the control path and draw begin
	# called when user press mouse down, or on loading
	# @param point [Point] the point to add
	# @param event [Event] the mouse event
	# @param loading [Boolean] (optional) whether the path is being loaded or being created by user
	createBegin: (point, event, loading=false)->
		# todo: better handle lock area
		super()
		if loading
			@initializeControlPath(point)
		else
			if RLock.intersectPoint(point) then	return

			if not @data.polygonMode 				# in normal mode: just initialize the control path and begin drawing
				@initializeControlPath(point)
				@drawBegin()
			else 									# in polygon mode:
				if not @controlPath?					# if the user just started the creation (first point, on mouse down)
					@initializeControlPath(point)		# 	initialize the control path, add the point and begin drawing
					@controlPath.add(point)
					@drawBegin()
				else 									# if the user already added some points: just add the point to the control path
					@controlPath.add(point)
				@controlPath.lastSegment.rtype = 'point'
		return

	# redefine {RPath#createUpdate}
	# update create action:
	# in normal mode:
	# - check if path is not in an RLock
	# - add point
	# - @checkUpdateDrawing(event) (i.e. continue the draw steps to fit the control path)
	# in polygon mode:
	# - update the [handleIn](http://paperjs.org/reference/segment/#handlein) and handleOut of the last segment
	# - draw in simplified (quick) mode
	# called on mouse drag
	# @param point [Point] the point to add
	# @param event [Event] the mouse event
	# @param loading [Boolean] (optional and deprecated) whether the path is being loaded or being created by user
	createUpdate: (point, event, loading=false)->

		if not @data.polygonMode
			
			if @inLockedArea
				return
			if RLock.intersectPoint(point) 		# check if path is not in an RLock
				@inLockedArea = true
				@save()
				return

			@controlPath.add(point)

			# loading is never true in this case, createUpdate is not called in @loadPath() (but @createBegin() and @createEnd() are called)
			if not loading then @checkUpdateDrawing(event)
		else
			# update the [handleIn](http://paperjs.org/reference/segment/#handlein) and handleOut of the last segment
			lastSegment = @controlPath.lastSegment
			previousSegment = lastSegment.previous
			previousSegment.rtype = 'smooth'
			previousSegment.handleOut = point.subtract(previousSegment.point)
			if lastSegment != @controlPath.firstSegment
				previousSegment.handleIn = previousSegment.handleOut.multiply(-1)
			lastSegment.handleIn = lastSegment.handleOut = null
			lastSegment.point = point
			@draw(true) 		# draw in simplified (quick) mode
		return

	# update create action: only used when in polygon mode
	# move the last point of the control path to the mouse position and draw in simple/quick mode
	# called on mouse move
	# @param event [Event] the mouse event
	createMove: (event)->
		@controlPath.lastSegment.point = event.point
		@draw(true)
		return

	# redefine {RPath#createEnd}
	# end create action: 
	# - in polygon mode: just finish the path (@finiPath())
	# - in normal mode: compute speed, simplify path and update speed (necessary for SpeedPath) and finish path
	# @param point [Point] the point to add
	# @param event [Event] the mouse event
	# @param loading [Boolean] (optional) whether the path is being loaded or being created by user
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

	# finish path creation:
	# @param loading [Boolean] (optional) whether the path is being loaded or being created by user
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
			@checkUpdateDrawing()
			@drawEnd()
			@offset = 0
		@draw(false, loading) 	# enable to have the correct @canvasRaster size and to have the exact same result after a load or a change
		@rasterize()
		return

	# in simplified mode, the path is drawn quickly, with less details
	# all parameters which are critical in terms of drawing time are set to *parameter.simplified*
	simplifiedModeOn: ()->
		@previousData = {}
		for folderName, folder of @constructor.parameters()
			for name, parameter of folder
				if parameter.simplified? and @data[name]?
					@previousData[name] = @data[name]
					@data[name] = parameter.simplified
		return

	# retrieve parameters values we had before drawing in simplified mode
	simplifiedModeOff: ()->
		for folderName, folder of @constructor.parameters()
			for name, parameter of folder
				if parameter.simplified? and @data[name]? and @previousData[name]?
					@data[name] = @previousData[name]
					delete @previousData[name]
		return

	# update the appearance of the path (the drawing group)
	# called anytime the path is modified:
	# by createBegin/Update/End, selectUpdate/End, parameterChanged, deletePoint, changePoint etc. and loadPath
	# - begin drawing (@drawBegin())
	# - update drawing (@drawUpdate()) every *step* along the control path
	# - end drawing (@drawEnd())
	# because the path are rendered on rasters, path are not drawn on load unless they are animated
	# @param simplified [Boolean] whether to draw in simplified mode or not (much faster)
	# @param loading [Boolean] whether the path is being loaded or drawn by a user
	draw: (simplified=false, loading=false)->
		if loading and not @data?.animate then return

		if @controlPath.segments.length < 2 then return
	
		if simplified then @simplifiedModeOn()
		
		# initialize dawing along control path 
		# the control path is divided into n steps of fixed length, the last step will be smaller than others
		# to have a better result, the last (shorter) step is split in half and set as the first and the last step
		step = @data.step
		controlPathLength = @controlPath.length
		nf = controlPathLength/step
		nIteration  = Math.floor(nf)
		reminder = nf-nIteration
		offset = reminder*step/2

		try 	# catch errors to log them in the code editor console (if user is making a script)

			@drawBegin()

			# update drawing (@drawUpdate()) every *step* along the control path
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

	# @return [Array of Paper point] a list of point from the control path converted in the planet coordinate system 
	pathOnPlanet: ()->
		flatennedPath = @controlPath.copyTo(project)
		flatennedPath.flatten(@constructor.secureStep)
		flatennedPath.remove()
		return super(flatennedPath.segments)

	# get data, usually to save the RPath (some information must be added to data) 
	# the control path is stored in @data.points and @data.planet
	getData: ()->
		@data.planet = projectToPlanet(@controlPath.segments[0].point)
		@data.points = []
		for segment in @controlPath.segments
			@data.points.push(projectToPosOnPlanet(segment.point))
			@data.points.push(g.pointToObj(segment.handleIn))
			@data.points.push(g.pointToObj(segment.handleOut))
			@data.points.push(segment.rtype)
		return @data

	# @see RPath.select
	# - bring control path to front and select it
	# - call RPath.select
	# @param updateOptions [Boolean] whether to update gui parameters with this RPath or not
	select: (updateOptions=true)->
		if not @controlPath? then return
		if @selectionRectangle? then return
		@index = @controlPath.index
		@controlPath.bringToFront()
		@controlPath.selected = true
		super(updateOptions)
		if not @data.smooth then @controlPath.fullySelected = true
		return

	# @see RPath.deselect
	# deselect control path, remove selection highlight (@see PrecisePath.highlightSelectedPoint) and call RPath.deselect
	deselect: ()->
		# g.project.activeLayer.insertChild(@index, @controlPath)
		@controlPath.selected = false
		@selectionHighlight?.remove()
		@selectionHighlight = null
		super()
		return

	# highlight selection path point:
	# draw a shape behind the selected point to be able to move and modify it
	# the shape is a circle if point is 'smooth', a square if point is a 'corner' and a triangle otherwise
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

	# redefine {RPath#initSelection}
	# Same functionnalities as {RPath#initSelection} (determine which action to perform depending on the the *hitResult*) but:
	# - adds handle selection initialization, and highlight selected points if any
	# - properly initialize transformation (rotation and scale) for PrecisePath
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

	# redefine {RPath#selectUpdate}
	# depending on the selected item, selectUpdate will:
	# - move the selected handle,
	# - move the selected point,
	# - rotate the group,
	# - scale the group,
	# - or move the group.
	# the selection rectangle must be updated if the curve is changed
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	selectUpdate: (event, userAction=true)->
		console.log "selectUpdate"
		
		# the previous bounding box is used to update the raster at this position
		# should not be put in selectBegin() since it is not called when moving multiple items (selectBegin() is called only on the first item)
		@previousBoundingBox ?= @getBounds()

		if not @drawing then g.updateView()

		if @selectedHandle? 									# move the selected handle

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
		else if @selectedSegment?								# move the selected point
			@selectedSegment.point.x += event.delta.x
			@selectedSegment.point.y += event.delta.y
			@updateSelectionRectangle()
			@draw(true)
			@changed = 'moved point'
		else if @selectionRectangleRotation?					# rotate the group
			# @selectionRectangleRotation is 0 if we initialized rotation, null otherwise. 
			# The angle will be determined with the angle between the vector (cursor -> selection rectangle center) and the x axis
			rotation = event.point.subtract(@selectionRectangle.bounds.center).angle + 90
			@controlPath.rotation = rotation
			@selectionRectangle.rotation = rotation
			@draw(true)
			@changed = 'rotated'
		else if @selectionRectangleScale?						# scale the group
			# let *L* be the length between the mouse and the selection rectangle center 
			# @selectionRectangleScale = *L* / current scaling, @selectionRectangleScale is the *intial scale*
			# the ratio between the current length *L* and the *initial scale* gives the new scaling
			ratio = event.point.subtract(@selectionRectangle.bounds.center).length/@selectionRectangleScale
			scaling = new Point(ratio, ratio)
			@controlPath.scaling = scaling
			@selectionRectangle.scaling = scaling
			@draw(true)
			@changed = 'scaled'
		else													# move the group
			@group.position.x += event.delta.x
			@group.position.y += event.delta.y
			@updateSelectionRectangle()
			# to optimize the move, the position of @drawing is updated at the end
			# @drawing.position.x += event.delta.x
			# @drawing.position.y += event.delta.y
			if not @drawing then @draw(false)
			@changed = 'moved'

		console.log @changed

		# @updateSelectionRectangle()

		# @drawing.selected = false

		if userAction or @selectionRectangle? then @selectionHighlight?.position = @selectedSegment.point

		# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventToObject(event))
		return


	# overload {RPath#selectUpdate} 
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
		return

	# smooth the point of *segment*, i.e. align the handles with the tangent at this point
	# @param segment [Paper Segment] the segment to smooth
	# @param offset [Number] (optional) the location of the segment (default is segment.location.offset)
	smoothPoint: (segment, offset)->
		segment.rtype = 'smooth'
		segment.linear = false
		
		offset ?= segment.location.offset
		tangent = segment.path.getTangentAt(offset)
		if segment.previous? then segment.handleIn = tangent.multiply(-0.25)
		if segment.next? then segment.handleOut = tangent.multiply(+0.25)

		# a second version of the smooth
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
		return

	# double click event handler: 
	# if we click on a point:
	# - roll over the three point modes (a 'smooth' point will become 'corner', a 'corner' will become 'point', and a 'point' will be deleted)
	# else if we clicked on the control path:
	# - create a point at *event* position
	# @param event [jQuery event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	doubleClick: (event, userAction=true)->
		# warning: event is a jQuery event, not a paper event
		
		specialKey = g.specialKey(event)
		
		point = if userAction then view.viewToProject(new Point(event.pageX, event.pageY)) else event.point

		hitResult = @performHitTest(point, @constructor.hitOptions)

		if not hitResult?
			return

		hitCurve = hitResult.type == 'stroke' or hitResult.type == 'curve'

		if hitResult.type == 'segment' 											# if we click on a point: roll over the three point modes 
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

		else if hitCurve and not specialKey  									# else if we clicked on the control path: create a point at *event* position
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
				# if g.me? and userAction then g.chatSocket.emit( "double click", g.me, @pk, g.eventToObject(event))
		return

	# delete the point of *segment* (from curve) and delete curve if there are no points anymore
	# @param segment [Paper Segment] the segment to delete
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
		return

	# delete the selected point (from curve) and delete curve if there are no points anymore
	# emit the action to websocket
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	deleteSelectedPoint: (userAction=true)->
		@deletePoint(@selectedSegment)
		if g.me? and userAction then g.chatSocket.emit( "parameter change", g.me, @pk, "deleteSelectedPoint", null, "rFunction")
		return

	# - set selected point mode to *value*: 'smooth', 'corner' or 'point'
	# - update the selected point highlight 
	# - emit action to websocket
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	# @param value [String] new mode of the point: can be 'smooth', 'corner' or 'point'
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

	# overload {RPath#parameterChanged}, but update the control path state if 'smooth' was changed
	# called when a parameter is changed
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

	# overload {RPath#remove}, but in addition: remove the selected point highlight and the canvas raster
	remove: ()->
		@selectionHighlight?.remove()
		@selectionHighlight = null
		@canvasRaster?.remove()
		@canvasRaster =  null
		super()

@PrecisePath = PrecisePath

@pathClasses = []
@pathClasses.push(@PrecisePath)

# SpeedPath extends PrecisePath to add speed functionnalities: 
#  - the speed at which the user has drawn the path is stored and has influence on the drawing,
#  - the speed values are displayed as normals of the path, and can be edited thanks to handles,
#  - when the user drags a handle, it will also influence surrounding speed values depending on how far from the normal the user drags the handle (with a gaussian attenuation)
#  - the speed path and handles are added to a speed group, which is added to the main group
#  - the speed group can be shown or hidden through the folder 'Edit curve' in the gui
class SpeedPath extends PrecisePath
	@rname = 'Speed path'
	@rdescription = "This path offers speed."
	@iconUrl = null
	@iconAlt = null

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

	# overloads {PrecisePath#loadPath}
	loadPath: (points)->
		@data ?= {}
		@speeds = @data.speeds or []
		super(points)
		return

	# redefine {PrecisePath#checkUpdateDrawing} to update speed while drawing
	checkUpdateDrawing: (event)->
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
	# overload {PrecisePath#createBegin} and add speed initialization
	createBegin: (point, event, loading=false)->
		if not loading then @speeds = (if g.polygonMode then [0] else [@constructor.speedMax/3])
		super(point, event, loading)
		return

	# overload {PrecisePath#createEnd} and add speed initialization
	createEnd: (point, event, loading=false)->
		if not @data.polygonMode and not loading then @speeds = []
		super(point, event, loading)
		return

	# compute the speed (deduced from the space between each point of the control path)
	# the speed values are sampeled on regular intervals along the control path (same machanism as the drawing points)
	# the distance between each sample is defined in @constructor.speedStep
	# an average speed must be computed at each sample
	computeSpeed: ()->

		# 1. create an array *distances* containing speed values at regular intervals over the control path + speed values at the control path points
		# the speed values computed between the control path points are interpolated from the two closest points
		# the speed values of the points are equal to the length of the segment (distance between current and previous point)
		# this array will be converted to real speed values in a second step, i.e. all values in the regular intervals will be summed up/integrated

		# initialize variables
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
		
		# we have a line with oddly distributed points:  |------|-------|--||-|-----------|--------|  ('|' represents the points, the speed at those point corresponds to the distance of the previous segment)
		# we want to add values on regular intervals:    I---I--|I---I--|I-||I|--I---I---I|--I---I-| ('I' have been added every three units, the corresponding speeds are interpolated)
		# (the last interval is shorter than the others)
		# in a second step, we will integrate the values on those regular intervals

		for segment, i in @controlPath.segments 		# loop over control path points
			if i==0 then continue

			point = segment.point
			previousDistance = distance
			distance = point.getDistance(segment.previous.point)
			previousPointOffset = pointOffset
			pointOffset += distance

			while pointOffset > currentOffset 							# while we can add more sample on this segment, add them (values are interpolation)
				f = (currentOffset-previousPointOffset)/distance
				interpolation = previousDistance * (1-f) + distance * f
				distances.push({speed: interpolation, offset: currentOffset})
				currentOffset += step
			
			distances.push({speed: distance, offset: pointOffset})

		distances.push({speed: distance, offset: currentOffset}) 		# push last point

		# 2. intergate the values of the regular intervals to obtain final speed values

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

	# update the speed group (curve and handles to visualize and edit the speeds)
	updateSpeed: ()->
		@speedGroup?.visible = @data.showSpeed
		
		if not @speeds? or not @data.showSpeed then return

		step = @constructor.speedStep
		
		# create the speed group if it does not exist (add it to the main group)
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

		# for all speed values: draw or update the corresponding curve point and handle
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

		# remove speed curve point and handles which are not on the control path anymore (if the curve path has been shrinked)
		if offset > controlPathLength and i+1 <= speedHandles.length-1
			speedHandlesLengthM1 = speedHandles.length-1
			for j in [i+1 .. speedHandlesLengthM1]
				speedHandle = @handleGroup.lastChild
				speedHandle.rsegment.remove()
				speedHandle.remove()
				speedCurve.lastSegment.remove()

		return

	# get the speed at *offset*
	# @param offset [Number] the offset along the control path at which getting the speed
	# @return [Number] the computed speed:
	# - the value is interpolated from the two closest speed values
	# - if speeds are not computed yet: return half of the max speed
	speedAt: (offset)->
		f = offset%@constructor.speedStep
		i = (offset-f) / @constructor.speedStep
		f /= @constructor.speedStep
		if @speeds?
			if i<@speeds.length-1
				return @speeds[i]*(1-f)+@speeds[i+1]*f
			else
				return @speeds.last()
		else
			@constructor.speedMax/2

	# overload {PrecisePath#draw} and add speed update when *loading* is false
	draw: (simplified=false, loading=false)->
		super(simplified, loading)
		if not loading then @updateSpeed()
		return

	# overload {PrecisePath#getData} and adds the speeds in @data.speeds (unused speed values are not stored)
	getData: ()->
		data = jQuery.extend({}, super())
		data.speeds = if @speeds? and @handleGroup? then @speeds.slice(0, @handleGroup.children.length+1) else @speeds
		return data

	# overload {PrecisePath#select}, update speeds and show speed group
	select: (updateOptions=true)->
		if @selectionRectangle? then return
		super(updateOptions)
		@updateSpeed()
		if @data.showSpeed then @speedGroup?.visible = true

	# overload {PrecisePath#deselect} and hide speed group
	deselect: ()->
		@speedGroup?.visible = false
		super()

	# overload {PrecisePath#initSelection} but add the possibility to select speed handles
	initSelection: (event, hitResult, userAction=true) ->
		@speedSelectionHighlight?.remove()
		@speedSelectionHighlight = null

		if hitResult.item.name == "speed handle"
			@selectedSpeedHandle = hitResult.item
			change = 'speed handle'
			return change

		return super(event, hitResult, userAction)

	# overload {PrecisePath#selectUpdate} but add the possibility to modify speed handles
	selectUpdate: (event, userAction=true)->

		# the previous bounding box is used to update the raster at this position
		# should not be put in selectBegin() since it is not called when moving multiple items (selectBegin() is called only on the first item)
		@previousBoundingBox ?= @getBounds()

		if not @drawing then g.updateView()

		if not @selectedSpeedHandle?
			super(event, userAction)
		else
			@speedSelectionHighlight?.remove()

			speedMax = @constructor.speedMax
			
			# initialize a line between the mouse and the handle, orthogonal to the normal
			# the length of this line determines how much influence the change will have over the neighbour handles
			@speedSelectionHighlight = new Path() 
			@speedSelectionHighlight.name = 'speed selection highlight'
			@speedSelectionHighlight.strokeWidth = 1
			@speedSelectionHighlight.strokeColor = 'blue'
			@speedGroup.addChild(@speedSelectionHighlight)

			handle = @selectedSpeedHandle
			handlePosition = handle.bounds.center

			handleToPoint = event.point.subtract(handlePosition)
			projection = handleToPoint.project(handle.rnormal)
			projectionLength = projection.length

			# compute the new speed value
			sign = Math.sign(projection.x) == Math.sign(handle.rnormal.x) and Math.sign(projection.y) == Math.sign(handle.rnormal.y)
			sign = if sign then 1 else -1
			
			@speeds[handle.rindex] += sign * projectionLength

			if @speeds[handle.rindex] < 0
				@speeds[handle.rindex] = 0
			else if @speeds[handle.rindex] > speedMax
				@speeds[handle.rindex] = speedMax

			newHandleToPoint = event.point.subtract(handle.position.add(projection))
			influenceFactor = newHandleToPoint.length/(@constructor.speedStep*3)
			
			# spread the influence of this new speed value
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
			
			# create the line between the mouse and the handle, orthogonal to the normal
			@speedSelectionHighlight.strokeColor.hue -= Math.min(240*(influenceFactor/10), 240)
			@speedSelectionHighlight.add(handle.position.add(projection))
			@speedSelectionHighlight.add(event.point)

			@draw(true)

			@changed = 'speed handle moved'

			if userAction or @selectionRectangle? then @selectionHighlight?.position = @selectedSegment.point
			# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventToObject(event))
		return

	# overload {PrecisePath#selectEnd} and reset speed handles
	selectEnd: (event, userAction=true)->
		@selectedSpeedHandle = null
		@speedSelectionHighlight?.remove()
		@speedSelectionHighlight = null
		super(event, userAction)

	# overload {PrecisePath#remove} and remove speed group
	remove: ()->
		@speedGroup?.remove()
		@speedGroup = null
		super()

@SpeedPath = SpeedPath

# The thickness pass demonstrates a simple use of the speed path: it draws a stroke which is thick where the user draws quickly, and thin elsewhere
# The stroke width can be changed with the speed handles at any time
class ThicknessPath extends SpeedPath
	@rname = 'Thickness path'
	@rdescription = "The stroke width is function of the drawing speed: the faster the wider."
	@iconUrl = 'static/images/icons/inverted/rollerBrush.png'
	@iconAlt = 'roller brush'

	# The thickness path adds two parameters in the options bar:
	# step: a number which defines the size of the steps along the control path (@data.step is already defined in precise path, this will bind it to the options bar)
	# trackWidth: a number to control the stroke width (factor of the speed)
	@parameters: ()->
		parameters = super()

		# override the default parameters, we do not need a stroke width, a stroke color and a fill color
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
		# get point, normal and speed at current position
		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		speed = @speedAt(offset)

		# create two points at each side of the control path (separated by a length function of the speed)
		delta = normal.multiply(speed*@data.trackWidth/2)
		top = point.add(delta)
		bottom = point.subtract(delta)

		# add the two points at the beginning and the end of the path
		@path.add(top)
		@path.insert(0, bottom)
		@path.smooth()

		return

	drawEnd: ()->
		# add the last segment, close and smooth the path
		@path.add(@controlPath.lastSegment.point)
		@path.closed = true
		@path.smooth()
		@path.selected = false 		# @path would be selected because we added the last point of the control path which is selected
		return

@ThicknessPath = ThicknessPath
@pathClasses.push(@ThicknessPath)

# Meander makes use of both the tangent and the normal of the control path to draw a spiral at each step
# Many different versions can be derived from this one (some inspiration can be found here: http://www.dreamstime.com/photos-images/meander-wave-ancient-greek-ornament.html )
class Meander extends PrecisePath
	@rname = 'Meander'
	@rdescription = 'As Karl Kerenyi pointed out, "the meander is the figure of a labyrinth in linear form". \nA meander or meandros (Greek: Μαίανδρος) is a decorative border constructed from a continuous line, shaped into a repeated motif.\nSuch a design is also called the Greek fret or Greek key design, although these are modern designations.\n(source: http://en.wikipedia.org/wiki/Meander_(art))'
	@iconUrl = 'static/images/icons/inverted/squareSpiral.png'
	@iconAlt = 'square spiral'

	# The thickness path adds 3 parameters in the options bar:
	# step: a number which defines the size of the steps along the control path (@data.step is already defined in precise path, this will bind it to the options bar)
	# thickness: the thickness of the spirals
	# rsmooth: whether the path is smoothed or not (not that @data.smooth is already used to define if one can edit the control path handles or if they are automatically set)
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
	
	pathWidth: ()->
		return 3 * ( @data.thickness + @data.step + 2*@data.strokeWidth )

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

# line spiral
#	|	|				
#	0   0---------------1		
#	|					|
#	|	9-----------8	|
#	|	|			|	|
#	|	|	4---5	|	|
#	|	|	|	|	|	|
#	|	|	|	6---7	|
#	|	|	|			|
#	|	|	3-----------2
#	|	|				
#	0   0---------------1						
#	|					|	
#	|	9-----------8	|	
#	|	|			|	|
#	|	|	4---5	|	|	
#	|	|	|	|	|	|	
#	|	|	|	6---7	|	
#	|	|	|			|	
#	|	|	3-----------2	
#	|	|
#	0   0---------------1					
#	|					|	

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

@Meander = Meander
@pathClasses.push(@Meander)

# The grid path is similar to the thickness path, but draws a grid along the path
class GridPath extends SpeedPath
	@rname = 'Grid path'
	@rdescription = "Draws a grid along the path, the thickness of the grid being function of the speed of the drawing."

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
			default: 5
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
			# create the required number of paths, and add them to the 'lines' array
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

		# add a point at 'offset'
		addPoint = (offset, speed)=>
			point = @controlPath.getPointAt(offset)
			normal = @controlPath.getNormalAt(offset).normalize()

			# set the width of the step
			if @data.speedForWidth
				width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.speedMax		# map the speed to [@data.minWidth, @data.maxWidth]
			else
				width = @data.minWidth

			# add the tangent lines (parallel or following the path)
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

			# add the orthogonal lines
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

		# if @data.speedForLength: the drawing is not updated at each step, but the step length is function of the speed
		if not @data.speedForLength
			addPoint(offset, speed)
		else 	# @data.speedForLength

			# map 'speed' to the interval [@data.minSpeed, @data.maxSpeed]
			speed = @data.minSpeed + (speed / @constructor.speedMax) * (@data.maxSpeed - @data.minSpeed)
			
			# check when we must update the path (if the current position if greater than the last position we updated + speed)
			stepOffset = offset-@lastOffset

			if stepOffset>speed
				midOffset = (offset+@lastOffset)/2
				addPoint(midOffset, speed)
				@lastOffset = offset

		return

	drawEnd: ()->
		return

@GridPath = GridPath
@pathClasses.push(@GridPath)

# The geometric lines path draws a line between pair of points which are close enough
# This means that hundreds of lines will be drawn at each update.
# To improve drawing efficiency (and because we do not need any complexe editing functionnality for those lines), we use a child canvas for the drawing.
# We must convert the points in canvas coordinates, draw with the @context of the canvas (and use the native html5 canvas drawing functions, unless we load an external library)
class GeometricLines extends PrecisePath
	@rname = 'Geometric lines'
	@rdescription = "Draws a line between pair of points which are close enough."
	@iconUrl = 'static/images/icons/inverted/links.png'
	@iconAlt = 'links'

	@parameters: ()->
		parameters = super()
		# override the default color function, since we get better results with a very transparent color
		parameters['Style'].strokeColor.defaultFunction = ()-> return "rgba(39, 158, 224, 0.21)"
		delete parameters['Style'].fillColor 	# remove the fill color, we do not need it

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 5
			max: 100
			default: 11
			simplified: 20
			step: 1
		parameters['Parameters'].distance = 	# the maximum distance between two linked points
			type: 'slider'
			label: 'Distance'
			min: 5
			max: 250
			default: 150
			simplified: 100

		return parameters

	drawBegin: ()->
		@initializeDrawing(true)
		@points = [] 							# will contain the points to check distances
		return

	drawUpdate: (offset)->

		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		point = @projectToRaster(point) 		#  convert the points from project to canvas coordinates
		@points.push(point)
		
		distMax = @data.distance*@data.distance

		# for all points: check if current point is close enough
		for pt in @points

			if point.getDistance(pt, true) < distMax 	# if points are close enough: draw a line between them
				@context.beginPath()
				@context.moveTo(point.x,point.y)
				@context.lineTo(pt.x,pt.y)
				@context.stroke()
		
		return

	drawEnd: ()->
		return

@GeometricLines = GeometricLines
@pathClasses.push(@GeometricLines)

# The shape path draw a rectangle or an ellipse along the control path
class ShapePath extends SpeedPath
	@rname = 'Shape path'
	@rdescription = "Draws rectangles or ellipses along the path. The size of the shapes is function of the drawing speed."

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
		parameters['Parameters'].ellipse =
			type: 'checkbox'
			label: 'Ellipse'
			default: false
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

		# add a shape at 'offset'
		addShape = (offset, height, speed)=>
			point = @controlPath.getPointAt(offset)
			normal = @controlPath.getNormalAt(offset)

			width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.speedMax
			rectangle = new Rectangle(point.subtract(new Point(width/2, height/2)), new Size(width, height))
			if not @data.ellipse
				shape = @addPath(new Path.Rectangle(rectangle))
			else
				shape = @addPath(new Path.Ellipse(rectangle))
			shape.rotation = normal.angle
			return

		# if @data.speedForLength: the drawing is not updated at each step, but the step length is function of the speed
		if not @data.speedForLength
			addShape(offset, @data.step, speed)
		else 	# @data.speedForLength

			# map 'speed' to the interval [@data.minSpeed, @data.maxSpeed]
			speed = @data.minSpeed + (speed / @constructor.speedMax) * (@data.maxSpeed - @data.minSpeed)
			
			# check when we must update the path (if the current position if greater than the last position we updated + speed)
			stepOffset = offset-@lastOffset
			if stepOffset>speed
				midOffset = (offset+@lastOffset)/2
				addShape(midOffset, stepOffset, speed)
				@lastOffset = offset

		return

	drawEnd: ()->
		return

@ShapePath = ShapePath
@pathClasses.push(@ShapePath)

# An RShape is defined by a rectangle in which the drawing should be included
# during the creation, the user draw the rectangle with the mouse
class RShape extends RPath
	@Shape = paper.Path.Rectangle
	@rname = 'Shape'
	@rdescription = "Base shape class"
	@squareByDefault = true 				# whether the shape will be square by default (user must press the shift key to make it rectangle) or not
	@centerByDefault = false 				# whether the shape will be centered on the first point by default 
											# (user must press the special key - command on a mac, control otherwise - to use the first point as the first corner of the shape) or not

	# todo: check that control path always fit to rectangle: this is necessary for the getBounds method

	# overload {RPath#prepareHitTest} + fill control path
	prepareHitTest: (fullySelected=true, strokeWidth)->
		@controlPath.fillColor = 'red'
		return super(fullySelected, strokeWidth)

	# overload {RPath#finishHitTest} + remove control path fill
	finishHitTest: (fullySelected=true)->
		@controlPath.fillColor = null
		return super(fullySelected)

	# redefine {RPath#loadPath}
	# - load the shape rectangle from @data.rectangle
	# - initialize the control path
	# - draw
	# - check that the points in the database correspond to the new control path
	loadPath: (points)->
		if not @data.rectangle? then console.log 'Error loading shape ' + @pk + ': invalid rectangle.'
		@rectangle = if @data.rectangle? then new Rectangle(@data.rectangle.x, @data.rectangle.y, @data.rectangle.width, @data.rectangle.height) else new Rectangle()
		@initializeControlPath(@rectangle.topLeft, @rectangle.bottomRight, false, false, true)
		@draw(null, true)
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

	# overload {RPath#moveBy} + update rectangle position
	moveBy: (delta)-> 
		@rectangle.center.x += delta.x
		@rectangle.center.y += delta.y
		super(delta)
		return

	# overload {RPath#moveTo} + update rectangle position
	moveTo: (position)-> 
		@rectangle.center = position
		super(position)
		return

	# redefine {RPath#updateSelectionRectangle}
	# the selection rectangle is slightly different for a shape since it is never reset (rotation and scale are stored in database)
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
		return

	# redefine {RPath#selectUpdate}
	# depending on the selected item, selectUpdate will:
	# - rotate the group,
	# - scale the group,
	# - or move the group.
	# the shape is redrawn when scaled or rotated
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	selectUpdate: (event, userAction=true)->
		console.log "selectUpdate"

		# the previous bounding box is used to update the raster at this position
		# should not be put in selectBegin() since it is not called when moving multiple items (selectBegin() is called only on the first item)
		@previousBoundingBox ?= @getBounds()

		if not @drawing then g.updateView()

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
			if not @drawing then @draw(false)
			@changed = 'moved'

		# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventToObject(event))
		return

	# overload {RPath.pathWidth}
	pathWidth: ()->
		return @data.strokeWidth

	# draw the shape
	# the drawing logic goes here
	# this is the main method that developer will redefine
	createShape: ()->
		@shape = @addPath(new @constructor.Shape(@rectangle))
		return

	# redefine {RPath#draw}
	# initialize the drawing and draw the shape
	draw: (simplified=false, loading=false)->
		if loading and not @data?.animate then return
		try 							# catch errors to log them in console (if the user has code editor open)
			@initializeDrawing()
			@createShape()
			@drawing.rotation = @data.rotation
			@rasterize()
		catch error
			console.error error
			throw error
		return

	# initialize the control path
	# create the rectangle from the two points and create the control path
	# @param pointA [Paper point] the top left or bottom right corner of the rectangle
	# @param pointB [Paper point] the top left or bottom right corner of the rectangle (opposite of point A)
	# @param shift [Boolean] whether shift is pressed
	# @param specialKey [Boolean] whether the special key is pressed (command on a mac, control otherwise)
	# @param load [Boolean] whether the shape is being loaded
	initializeControlPath: (pointA, pointB, shift, specialKey, load)->
		@group = new Group()
		@group.name = "group"
		@group.controller = @

		# create the rectangle from the two points
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
		
		# create the control path
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

	# overload {RPath#createBegin} + initialize the control path and draw
	createBegin: (point, event, loading) ->
		super()
		@downPoint = point
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		if not loading then @draw()
		return

	# redefine {RPath#createUpdate}: 
	# initialize the control path and draw
	createUpdate: (point, event, loading) ->
		# console.log " event.modifiers.command"
		# console.log event.modifiers.command
		# console.log g.specialKey(event)
		# console.log event?.modifiers?.shift
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		if not loading then @draw()
		return

	# overload {RPath#createEnd} + initialize the control path and draw
	createEnd: (point, event, loading) ->
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		@draw(null, loading)
		super()
		return

	# overload {RPath#getData} and add rectangle to @data
	getData: ()->
		data = jQuery.extend({}, @data)
		data.rectangle = { x: @rectangle.x, y: @rectangle.y, width: @rectangle.width, height: @rectangle.height }
		return data

@RShape = RShape

# Simple rectangle shape
class RectangleShape extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Rectangle'
	@rdescription = "Simple rectangle, square by default (use shift key to draw a rectangle) which can have rounded corners.\nUse special key (command on a mac, control otherwise) to center the shape on the first point."
	@iconUrl = 'static/images/icons/inverted/rectangle.png'
	@iconAlt = 'rectangle'

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
		@shape = @addPath(new @constructor.Shape(@rectangle, @data.cornerRadius)) 			# @constructor.Shape is a Path.Rectangle
		return

@RectangleShape = RectangleShape
@pathClasses.push(@RectangleShape)

# The ellipse path does not even override any function, the RShape.createShape draws the shape defined in @constructor.Shape by default
class EllipseShape extends RShape
	@Shape = paper.Path.Ellipse 			# the shape to draw
	@rname = 'Ellipse'
	@rdescription = "Simple ellipse, circle by default (use shift key to draw an ellipse).\nUse special key (command on a mac, control otherwise) to avoid the shape to be centered on the first point."

	@iconUrl = 'static/images/icons/inverted/circle.png'
	@iconAlt = 'circle'
	@squareByDefault = true
	@centerByDefault = true

@EllipseShape = EllipseShape
@pathClasses.push(@EllipseShape)

# The star shape can be animated
class StarShape extends RShape
	@Shape = paper.Path.Star
	@rname = 'Star'
	@rdescription = "Draws a star which can be animated (the color changes and it rotates)."
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

	# animted paths must be initialized
	initialize: ()->
		@setAnimated(@data.animate)
		return

	createShape: ()->
		rectangle = @rectangle
		# make sure that the shape does not exceed the area defined by @rectangle
		if @data.internalRadius>-100
			externalRadius = rectangle.width/2
			internalRadius = externalRadius*@data.internalRadius/100
		else
			internalRadius = rectangle.width/2
			externalRadius = internalRadius*100/@data.internalRadius
		# draw the star
		@shape = @addPath(new @constructor.Shape(rectangle.center, @data.nPoints, externalRadius, internalRadius))
		# optionally smooth it
		if @data.rsmooth then @shape.smooth()
		return

	# called at each frame event
	# this is the place where animated paths should be updated
	onFrame: (event)=>
		# very simple example of path animation
		@shape.strokeColor.hue += 1
		@shape.rotation += 1
		return

@StarShape = StarShape
@pathClasses.push(@StarShape)

# The spiral shape can have an intern radius, and a custom number of sides
# A smooth spiral could be drawn with less points and with handles, that could be more efficient
class SpiralShape extends RShape
	@Shape = paper.Path.Ellipse
	@rname = 'Spiral'
	@rdescription = "The spiral shape can have an intern radius, and a custom number of sides."
	@iconUrl = 'static/images/icons/inverted/spiral.png'
	@iconAlt = 'spiral'

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

	# animted paths must be initialized
	initialize: ()->
		@setAnimated(@data.animate)
		return

	createShape: ()->
		@shape = @addPath()

		# drawing a spiral (as a set of straight lines) is like drawing a circle, but changing the radius of the circle at each step
		# to draw a circle, we would do somehting like this: for each point: addPoint( radius*Math.cos(angle), radius*Math.sin(angle) )
		# the same things applies for a spiral, except that radius decreases at each step
		# ellipses are similar except the radius is different on the x axis and on the y axis

		rectangle = @rectangle
		hw = rectangle.width/2
		hh = rectangle.height/2
		c = rectangle.center
		angle = 0

		angleStep = 360.0/@data.nSides
		spiralWidth = hw-hw*@data.minRadius/100.0
		spiralHeight = hh-hh*@data.minRadius/100.0
		radiusStepX = (spiralWidth / @data.nTurns) / @data.nSides 		# the amount by which decreasing the x radius at each step
		radiusStepY = (spiralHeight / @data.nTurns) / @data.nSides 		# the amount by which decreasing the y radius at each step
		for i in [0..@data.nTurns-1]
			for step in [0..@data.nSides-1]
				@shape.add(new Point(c.x+hw*Math.cos(angle), c.y+hh*Math.sin(angle)))
				angle += (2.0*Math.PI*angleStep/360.0)
				hw -= radiusStepX
				hh -= radiusStepY
		@shape.add(new Point(c.x+hw*Math.cos(angle), c.y+hh*Math.sin(angle)))
		@shape.pivot = @rectangle.center
		return

	# called at each frame event
	# this is the place where animated paths should be updated
	onFrame: (event)=>
		# very simple example of path animation
		@shape.strokeColor.hue += 1
		@shape.rotation += @data.rotationSpeed
		return

@SpiralShape = SpiralShape
@pathClasses.push(@SpiralShape)

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
@pathClasses.push(@FaceShape)

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

# Checkpoint is a video game element:
# if placed on a video game area, it will be registered in it
class Checkpoint extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Checkpoint'
	@rdescription = "Draw checkpoints on a video game area to create a race (the players must go through each checkpoint as fast as possible, with the car tool)."
	@squareByDefault = false
	
	@parameters: ()->
		return {} 		# we do not need any parameter

	# register the checkpoint if we are on a video game
	initialize: ()->
		@game = g.gameAt(@rectangle.center)
		if @game?
			if @game.checkpoints.indexOf(@)<0 then @game.checkpoints.push(@)
			@data.checkpointNumber ?= @game.checkpoints.indexOf(@)
		return

	# just draw a red rectangle with the text 'Checkpoint N' N being the number of the checkpoint in the videogame
	# we could also prevent users to draw outside a video game
	createShape: ()->
		@data.strokeColor = 'rgb(150,30,30)'
		@data.fillColor = null
		@shape = @addPath(new Path.Rectangle(@rectangle))
		@text = @addPath(new PointText(@rectangle.center.add(0,4)))
		@text.content = if @data.checkpointNumber? then 'Checkpoint ' + @data.checkpointNumber else 'Checkpoint'
		@text.justification = 'center'
		return

	# checks if the checkpoints contains the point, used by the video game to test collisions between the car and the checkpoint
	contains: (point)->
		delta = point.subtract(@rectangle.center)
		delta.rotation = -@data.rotation
		return @rectangle.contains(@rectangle.center.add(delta))

	# we must unregister the checkpoint before removing it
	remove: ()->
		@game?.checkpoints.remove(@)
		super()
		return

@Checkpoint = Checkpoint
@pathClasses.push(@Checkpoint)


class StripeAnimation extends RShape
	@Shape = paper.Path.Rectangle
	@rname = 'Stripe animation'
	@rdescription = "Creates a stripe animation from a set sequence of image."
	@squareByDefault = false
	
	@parameters: ()->
		parameters = super()

		parameters['Parameters'] ?= {} 
		parameters['Parameters'].stripeWidth =
			type: 'slider'
			label: 'Stripe width'
			min: 1
			max: 100
			default: 10

		return parameters

	# animted paths must be initialized
	initialize: ()->
		@setAnimated(@data.animate)
		
		modalJ = $('#customModal')
		modalBodyJ = modalJ.find('.modal-body')
		modalInputJ = $("""<input id="stripeAnimationModalURL" type="url" class="url form-control submit-shortcut" placeholder="http://">""")
		modalAddImageButtonJ = $("""<button type="button" class="btn btn-default">Add image</button>""")
		modalContentJ = $("""
			<div class="form-group url-group">
                <label for="stripeAnimationModalURL">Add your images</label>
            </div>
            """)
		modalContentJ.append(modalInputJ.clone()).append(modalInputJ.clone()).append(modalAddImageButtonJ)
		modalBodyJ.append(modalContentJ)
		
		modalAddImageButtonJ.click (event)->
			modalContentJ.append(modalInputJ.clone())
			return

		modalJ.modal('show')

		size = rasters[0].size
		result = new Raster()
		result.size = size
		stripes = new Raster()
		stripes.size = size
		n = rasters.length
		width = 10
		black = new Color(0, 0, 0)
		transparent = new Color(0, 0, 0, 0)
		for x in [0 .. size.width-1]
			for y in [0 .. size.height-1]
				i = g.roundToLowerMultiple(x, width) % n
				result.setPixel(x, y, rasters[i].getPixel(x, y))
				stripes.setPixel(x, y, if i==0 then transparent else black)
		return

	createShape: ()->

		return

	# called at each frame event
	# this is the place where animated paths should be updated
	onFrame: (event)=>
		# very simple example of path animation
		stripes.position.x -= 1
		if stripes.position.x < 0
			stripes.position.x = stripes.width
		return

@StripeAnimation = StripeAnimation
