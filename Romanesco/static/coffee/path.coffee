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
# todo-doc: explain ID?

# Notable differences between RPath:
# - in regular path: when transforming a path, the points of the control path are resaved with their new positions; no transform information is stored
# - in RShape: the rectangle  is never changed with transformations; instead the rotation and scale are stored in @data and taken into account at each draw

class RPath extends RContent
	@rname = 'Pen' 										# the name used in the gui (to create the button and for the tooltip/popover)
	@rdescription = "The classic and basic pen tool" 	# the path description
	@cursorPosition = { x: 24, y: 0 } 					# the position of the cursor image (relative to the cursor position)+
	@cursorDefault = "crosshair" 						# the cursor to use with this path

	@constructor.secureDistance = 2 					# the points of the flattened path must not be 5 pixels away from the recorded points

	# common to all RItems
	# construct a new RPath and save it
	# create the new RPath from *data* and *controlPathSegments*
	# @param data [Object] the data to duplicate
	# @param controlPathSegments [Array<Paper segments>] the control path segments to duplicate
	# @return copy of the RPath
	@duplicate: (data, controlPathSegments)->
		copy = new @(Date.now(), data, null, controlPathSegments)
		copy.draw()
		copy.save()
		return copy

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
			'Shadow':
				folderIsClosedByDefault: true
				shadowOffsetX:
					type: 'slider'
					label: 'Shadow offset x'
					min: 0
					max: 25
					default: 0
				shadowOffsetY:
					type: 'slider'
					label: 'Shadow offset y'
					min: 0
					max: 25
					default: 0
				shadowBlur:
					type: 'slider'
					label: 'Shadow blur'
					min: 0
					max: 50
					default: 0
				shadowColor:
					type: 'color'
					label: 'Shadow color'
					default: '#000'
					defaultCheck: false

	# Create the RPath and initialize the drawing creation if a user is creating it, or draw if the path is being loaded
	# When user creates a path, the path is given an identifier (@id); when the path is saved, the servers returns a primary key (@pk) and @id will not be used anymore
	# @param date [Date] (optional) the date at which the path has been crated (will be used as z-index in further versions)
	# @param data [Object] (optional) the data containing information about parameters and state of RPath
	# @param pk [ID] (optional) the primary key of the path in the database
	# @param points [Array of Point] (optional) the points of the controlPath, the points must fit on the control path (the control path is stored in @data.points)
	# @param lock [RLock] the lock which contains this RPath (if any)
	constructor: (@date=null, @data=null, @pk=null, points=null, @lock=null) ->
		if not @lock
			super(@data, @pk, @date, g.pathList, g.sortedPaths)
		else
			super(@data, @pk, @date, @lock.itemListsJ.find('.rPath-list'), @lock.sortedPaths)

		@selectionHighlight = null
		
		g.paths[if @pk? then @pk else @id] = @

		if points?
			@loadPath(points)

		@select()
		return
	
	# common to all RItems
	# construct a new RPath and save it
	# if *data* and *controlPathSegments* are provided, create the new RPath from those parameters
	# (used to cancel a delete from DeletePathCommand), otherwise duplicate the exact same RPath as it is (used for the duplicate button)
	# @param data [Object] (optional) the data to duplicate
	# @param controlPathSegments [Array<Paper segments>] (optional) the control path segments to duplicate
	# @return copy of the RPath (depending on the parameters)
	duplicate: (data=null, controlPathSegments=null)->
		data ?= @getData()
		controlPathSegments ?= @pathOnPlanet()
		copy = @constructor.duplicate(data, controlPathOffset)
		return copy

	# duplicate command
	duplicateCommand: ()->
		g.commandManager.add(new CreatePathCommand(@, "Duplicate path"), true)
		return

	# common to all RItems
	# return [Rectangle] the bounds of the control path (does not necessarly fit the drawing entirely, but is centered on it)
	# getBounds: ()->
	# 	return @controlPath.strokeBounds

	# return [Rectangle] the bounds of the drawing group
	getDrawingBounds: ()->
		return @drawing?.strokeBounds

	endSetRectangle: ()->
		super()
		@draw()
		return

	updateSetRectangle: (event)->
		super(event)
		@draw(false)
		return

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
		super(fullySelected, strokeWidth)

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
		@speedGroup?.selected = true
		
		@hitTestStrokeWidth = @controlPath.strokeWidth
		if strokeWidth then @controlPath.strokeWidth = strokeWidth

		# hide raster and canvas raster
		# @raster?.visible = false
		# @canvasRaster?.visible = false
		return

	# restore path items orginial states (same as before @prepareHitTest())
	# @param fullySelected [Boolean] (optional) whether the control path must be fully selected before performing the hit test (it must be if we want to test over control path handles)
	finishHitTest: (fullySelected=true)->
		super(fullySelected)

		if fullySelected then @controlPath.fullySelected = @hitTestFullySelected
		@controlPath.selected = @hitTestSelected
		@controlPath.visible = @hitTestControlPathVisible
		# @drawing?.visible = @hitTestGroupVisible
		@controlPath.strokeWidth = @hitTestStrokeWidth
		@speedGroup?.selected = false
		# @raster?.visible = true
		# @canvasRaster?.visible = true
		return

	# select the RPath: (only if it has a control path but no selection rectangle i.e. already selected)
	# - create or update the selection rectangle, 
	# - create or update the global selection group (i.e. add this RPath to the grouop)
	# - (optionally) update controller in the gui accordingly
	# @param updateOptions [Boolean] whether to update controllers in gui or not
	# @return whether the ritem was selected or not
	select: (updateOptions=true)->
		if not @controlPath? then return false
		if not super(updateOptions) then return false
		return true

	# deselect: remove the selection rectangle (and rasterize)
	deselect: ()->
		if not super() then return false
		@controlPath.visible = false
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

	# common to all RItems
	# update select action
	# to be overloaded by children classes
	# @param event [Paper event] the mouse event
	updateSelect: (event)->
		if not @drawing then g.updateView()
		super(event)
		return

	# double click action
	# to be redefined in children classes
	# @param event [Paper event] the mouse event
	doubleClick: (event)->
		return

	# redraw the skeleton (controlPath) of the path, 
	# called only when loading a path
	# redefined in PrecisePath, extended by shape (for security checks)
	# @param points [Array of Point] (optional) the points of the controlPath
	loadPath: (points)->
		return
	# called when a parameter is changed:
	# - from user action (parameter.onChange)
	# @param name [String] the name of the value to change
	# @param value [Anything] the new value
	# @param updateGUI [Boolean] (optional, default is false) whether to update the GUI (parameters bar), true when called from ChangeParameterCommand
	changeParameter: (name, value, updateGUI)->
		super(name, value)
		if not @drawing then g.updateView() 	# update the view if it was rasterized
		@previousBoundingBox ?= @getDrawingBounds()
		@draw()		# if draw in simple mode, then how to see the change of parameters which matter?
		if updateGUI then g.setControllerValueByName(name, value, @)
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
		path.shadowOffset = new Point(@data.shadowOffsetX, @data.shadowOffsetY)
		path.shadowBlur = @data.shadowBlur
		path.shadowColor = @data.shadowColor
		@drawing.addChild(path)
		return path

	# create the group and the control path
	# @param controlPath [Paper Path] (optional) the control path
	addControlPath: (@controlPath)->
		if @lock then @lock.group.addChild(@group)

		@controlPath ?= new Path()
		@group.addChild(@controlPath)
		@controlPath.name = "controlPath"
		@controlPath.controller = @
		@controlPath.strokeWidth = 10
		@controlPath.strokeColor = g.selectionBlue
		@controlPath.strokeColor.alpha = 0.25
		@controlPath.strokeCap = 'round'
		@controlPath.visible = false
		return

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

		@controlPath.strokeWidth = 10

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
			@drawing.addChild(@canvasRaster)
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
	# by beginCreate/Update/End, updateSelect/End, parameterChanged, deletePoint, changePoint etc. and loadPath
	# must be redefined in children RPath
	# because the path are rendered on rasters, path are not drawn on load unless they are animated
	# @param simplified [Boolean] whether to draw in simplified mode or not (much faster)
	# @param loading [Boolean] whether the path is being loaded or drawn by a user
	draw: (simplified=false, loading=false)->
		return

	# called once after endCreate to initialize the path (add it to a game, or to the animated paths)
	# must be redefined in children RPath
	initialize: ()->
		return

	# beginCreate, updateCreate, endCreate
	# called from loadPath (draw the skeleton when path is loaded), then *event* is null
	# called from PathTool.begin, PathTool.update and PathTool.end (when the user draws something), then *event* is the Paper mouse event
	# @param point [Point] point to peform the action
	# @param event [Paper event of REvent] the mouse event
	beginCreate: (point, event) ->
		return

	# see beginCreate
	updateCreate: (point, event) ->
		return

	# see beginCreate
	endCreate: (point, event) ->
		@initialize()
		return

	# insert above given *path*
	# @param path [RPath] path on which to insert this
	# @param index [Number] the index at which to add the path in g.sortedPath
	insertAbove: (path, index=null, update=false)->
		@group.insertAbove(path.group)
		@zindex = @group.index
		if update and not @drawing then g.updateView()
		super(path, index, update)
		return

	# insert below given *path*
	# @param path [RPath] path under which to insert this
	# @param index [Number] the index at which to add the path in g.sortedPath
	insertBelow: (path, index=null, update=false)->
		@group.insertBelow(path.group)
		@zindex = @group.index
		if update and not @drawing then g.updateView()
		super(path, index, update)
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

	# save RPath to server
	save: ()->
		if not @controlPath? then return

		# ajaxPost '/savePath', {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData() } , @save_callback
		
		# rectangle = @getBounds()
		# if not @data?.animate
		# 	extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)

		Dajaxice.draw.savePath( @save_callback, {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'date': @date, 'data': @getStringifiedData(), 'bounds': @getBounds() } )
		# Dajaxice.draw.savePath( @save_callback, {'points': @pathOnPlanet(), 'pID': @id, 'planet': @planet(), 'object_type': @constructor.rname, 'data': @getStringifiedData(), 'rasterData': extraction.dataURL, 'rasterPosition': rectangle.topLeft, 'areasNotRasterized': extraction.areasNotRasterized } )
		
		# rectangle = @getBounds()
		# if not @data?.animate
		# 	extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)
		# 	Dajaxice.draw.updateRasters( g.checkError, { 'data': extraction.dataURL, 'rectangle': rectangle, 'areasNotExtracted': extraction.areasNotExtracted } )
		return

	# check if the save was successful and set @pk if it is
	save_callback: (result)=>
		g.checkError(result)
		if not result.pk? then return 		# if @pk is null, the path was not saved, do not set pk nor rasterize
		@setPK(result.pk)
		if not @data?.animate
			g.rasterizeArea(@getDrawingBounds())
		if @updateAfterSave?
			@update(@updateAfterSave)
		return

	getUpdateFunction: ()->
		return 'updatePath'

	getUpdateArguments: (type)->
		switch type
			when 'z-index'
				args = pk: @pk, date: @date
			else
				args =
					pk: @pk
					points: @pathOnPlanet()
					planet: @planet()
					data: @getStringifiedData()
		return args

	# update the RPath in the database
	# @param type [String] type of change to consider (in further version, could send only the required information to the server to make the update to improve performances)
	update: (type)=>
		# console.log "update: " + @pk
		if not @pk?
			@updateAfterSave = type
			return
		delete @updateAfterSave

		Dajaxice.draw.updatePath(@updatePath_callback, @getUpdateArguments(type))

		if not @data?.animate
			
			if not @drawing?
				@draw()

			selectionHighlightVisible = @selectionHighlight?.visible
			@selectionHighlight?.visible = false
			speedGroupVisible = @speedGroup?.visible
			@speedGroup?.visible = false

			rectangle = @getDrawingBounds()

			if @previousBoundingBox?
				union = rectangle.unite(@previousBoundingBox)
				if rectangle.intersects(@previousBoundingBox) and union.area < @previousBoundingBox.area*2
					g.rasterizeArea(union)
				else
					g.rasterizeArea(rectangle)
					g.rasterizeArea(@previousBoundingBox)

				@previousBoundingBox = null
			else
				g.rasterizeArea(rectangle)

			@selectionHighlight?.visible = selectionHighlightVisible
			@speedGroup?.visible = speedGroupVisible
		# if type == 'points'
		# 	# ajaxPost '/updatePath', {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() }, @updatePath_callback
		# 	Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'points':@pathOnPlanet(), 'planet': @planet(), 'data': @getStringifiedData() } )
		# else
		# 	# ajaxPost '/updatePath', {'pk': @pk, 'data': @getStringifiedData() } , @updatePath_callback
		# 	Dajaxice.draw.updatePath( @updatePath_callback, {'pk': @pk, 'data': @getStringifiedData() } )

		return

	# check if update was successful
	updatePath_callback: (result)->
		g.checkError(result)
		return

	# set @pk, update g.items and emit @pk to other users
	# @param pk [ID] the new pk
	# @param updateRoom [updateRoom] (optional) whether to emit @pk to other users in the room
	setPK: (pk, updateRoom=true)->
		super(pk)
		g.paths[pk] = @
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
		if @pk?
			delete g.paths[@pk]
		else
			delete g.paths[@id]
		g.updateView()
		super()
		return

	deleteCommand: ()->
		g.commandManager.add(new DeletePathCommand(@), true)
		return

	# common to all RItems
	# @delete() removes the path, update rasters and delete it in the database
	# @remove() just removes visually
	delete: ()->
		@group.visible = false
		bounds = @getDrawingBounds()
		@remove()
		g.rasterizeArea(bounds)
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
#       it is part of the beginCreate/Update/End() process
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
				onChange: (value)-> item.changeSelectedPointTypeCommand?(value) for item in g.selectedItems(); return
			deletePoint: 
				type: 'button'
				label: 'Delete point'
				default: ()-> item.deletePointCommand?() for item in g.selectedItems(); return
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
		@rotation = @data.rotation = 0
		return

	# redefine {RPath#loadPath}
	# load control path from @data.points and check if *points* fit to the created control path
	loadPath: (points)->
		# load control path from @data.points
		@initializeControlPath(posOnPlanetToProject(@data.points[0], @data.planet))
		for point, i in @data.points by 4
			if i>0 then @controlPath.add(posOnPlanetToProject(point, @data.planet))
			@controlPath.lastSegment.handleIn = new Point(@data.points[i+1])
			@controlPath.lastSegment.handleOut = new Point(@data.points[i+2])
			@controlPath.lastSegment.rtype = @data.points[i+3]
		if points.length == 2 then @controlPath.add(points[1])

		@finishPath(true)
		@initialize()

		if @data?.animate 	# only draw if animated thanks to rasterization
			@draw()

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
			recordedPoint = new Point(points[index])
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
		hitResult ?= super(point, hitOptions)
		hitResult ?= @controlPath.hitTest(point, hitOptions)
		return hitResult

	# initialize drawing
	# @param createCanvas [Boolean] (optional, default to true) whether to create a child canavs *@canverRaster*
	initializeDrawing: (createCanvas=false)->
		@data.step ?= 20 	# developers do not need to put @data.step in the parameters, but there must be a default value
		@drawingOffset = 0
		super(createCanvas)
		return

	# default drawBegin function, will be redefined by children PrecisePath
	# @param redrawing [Boolean] (optional) whether the path is being redrawn or the user draws the path (the path is being loaded/updated or the user is drawing it with the mouse)
	drawBegin: (redrawing=false)->
		@initializeDrawing(false)
		@path = @addPath()
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	# default drawUpdate function, will be redefined by children PrecisePath
	# @param offset [Number] the offset along the control path to begin drawing
	# @param step [Boolean] whether it is a key step or not (we must draw something special or not)
	drawUpdate: (offset, step)->
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	# default drawEnd function, will be redefined by children PrecisePath
	# @param redrawing [Boolean] (optional) whether the path is being redrawn or the user draws the path (the path is being loaded/updated or the user is drawing it with the mouse)
	drawEnd: (redrawing=false)->
		@path.segments = @controlPath.segments
		@path.selected = false
		return

	# continue drawing the path along the control path if necessary:
	# - the drawing is performed every *@data.step* along the control path
	# - each time the user adds a point to the control path (either by moving the mouse in normal mode, or by clicking in polygon mode)
	#   *checkUpdateDrawing* check by how long the control path was extended, and calls @drawUpdate() if some draw step must be performed
	# called when creating the path (by @updateCreate() and @finishPath()) and in @draw()
	# @param segment [Paper Segment] the segment on the control path where we want to drawUpdate
	# @param redrawing [Boolean] (optional) whether the path is being redrawn or the user draws the path (the path is being loaded/updated or the user is drawing it with the mouse)
	checkUpdateDrawing: (segment, redrawing=true)->
		step = @data.step
		controlPathOffset = segment.location.offset

		while @drawingOffset+step<controlPathOffset
			@drawingOffset += step
			@drawUpdate(@drawingOffset, true, redrawing)

		if @drawingOffset+step>controlPathOffset 	# we can not make a step between drawingOffset and the controlPathOffset
			@drawUpdate(controlPathOffset, false, redrawing)

		return

	# initialize the main group and the control path
	# @param point [Point] the first point of the path
	initializeControlPath: (point)->
		@addControlPath()
		@controlPath.add(point)
		@rectangle = @controlPath.bounds
		return

	# redefine {RPath#beginCreate}
	# begin create action:
	# initialize the control path and draw begin
	# called when user press mouse down, or on loading
	# @param point [Point] the point to add
	# @param event [Event] the mouse event
	beginCreate: (point, event)->
		super()
		if RLock.intersectPoint(point) then	return

		if not @data.polygonMode 				# in normal mode: just initialize the control path and begin drawing
			@initializeControlPath(point)
			@drawBegin(false)
		else 									# in polygon mode:
			if not @controlPath?					# if the user just started the creation (first point, on mouse down)
				@initializeControlPath(point)		# 	initialize the control path, add the point and begin drawing
				@controlPath.add(point)
				@drawBegin(false)
			else 									# if the user already added some points: just add the point to the control path
				@controlPath.add(point)
			@controlPath.lastSegment.rtype = 'point'
		return

	# redefine {RPath#updateCreate}
	# update create action:
	# in normal mode:
	# - check if path is not in an RLock
	# - add point
	# - @checkUpdateDrawing() (i.e. continue the draw steps to fit the control path)
	# in polygon mode:
	# - update the [handleIn](http://paperjs.org/reference/segment/#handlein) and handleOut of the last segment
	# - draw in simplified (quick) mode
	# called on mouse drag
	# @param point [Point] the point to add
	# @param event [Event] the mouse event
	updateCreate: (point, event)->

		if not @data.polygonMode
			
			if @lock
				return
			@lock = RLock.intersectPoint(point)
			if @lock 		# check if path is not in an RLock
				@save()
				return

			@controlPath.add(point)

			@checkUpdateDrawing(@controlPath.lastSegment, false)
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

	# redefine {RPath#endCreate}
	# end create action: 
	# - in polygon mode: just finish the path (@finiPath())
	# - in normal mode: compute speed, simplify path and update speed (necessary for SpeedPath) and finish path
	# @param point [Point] the point to add
	# @param event [Event] the mouse event
	endCreate: (point, event)->
		if not @data.polygonMode 
			if @controlPath.segments.length>=2
				# if @speeds? then @computeSpeed()
				@controlPath.simplify()
				# if @speeds? then @updateSpeed()
			@finishPath()
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

		if @data.smooth then @controlPath.smooth()
		if not loading
			@drawEnd(loading)
			@drawingOffset = 0
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
	# by beginCreate/Update/End, updateSelect/End, parameterChanged, deletePoint, changePoint etc. and loadPath
	# - begin drawing (@drawBegin())
	# - update drawing (@drawUpdate()) every *step* along the control path
	# - end drawing (@drawEnd())
	# because the path are rendered on rasters, path are not drawn on load unless they are animated
	# @param simplified [Boolean] whether to draw in simplified mode or not (much faster)
	draw: (simplified=false)->

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

		@drawingOffset = 0

		process = ()=>
			@drawBegin(true)

			# # update drawing (@drawUpdate()) every *step* along the control path
			# # n=0
			# while offset<controlPathLength

			# 	@drawUpdate(offset)
			# 	offset += step

			# 	# if n%10==0 then g.updateLoadingBar(offset/controlPathLength)
			# 	# n++

			for segment, i in @controlPath.segments
				if i==0 then continue
				@checkUpdateDrawing(segment, true)

			@drawEnd(true)
			return
		
		if not g.catchErrors
			process()
		else
			try 	# catch errors to log them in the code editor console (if user is making a script)
				process()
			catch error
				console.error error.stack
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
		if not @selectionState.segment? then return
		point = @selectionState.segment.point
		@selectionState.segment.rtype ?= 'smooth'
		switch @selectionState.segment.rtype
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
		if @parameterControllers?.pointType? then g.setControllerValue(@parameterControllers.pointType, null, @selectionState.segment.rtype, @)
		return

	# redefine {RPath#initializeSelection}
	# Same functionnalities as {RPath#initializeSelection} (determine which action to perform depending on the the *hitResult*) but:
	# - adds handle selection initialization, and highlight selected points if any
	# - properly initialize transformation (rotation and scale) for PrecisePath
	initializeSelection: (event, hitResult) ->
		super(event, hitResult)

		specialKey = g.specialKey(event)

		if hitResult.type == 'segment'

			if specialKey and hitResult.item == @controlPath
				@selectionState = segment: hitResult.segment
				@deletePointCommand()
			else
				if hitResult.item == @controlPath
					@selectionState = segment: hitResult.segment

		if not @data.smooth
			if hitResult.type is "handle-in"
				@selectionState = segment: hitResult.segment, handle: hitResult.segment.handleIn
			else if hitResult.type is "handle-out"
				@selectionState = segment: hitResult.segment, handle: hitResult.segment.handleOut

		@highlightSelectedPoint()

		return

	# begin select action
	# @param event [Paper event] the mouse event
	beginSelect: (event) ->

		@selectionHighlight?.remove()
		@selectionHighlight = null
		
		super(event)

		if @selectionState.segment?
			@beginAction(new ModifyPointCommand(@))
		else if @selectionState.speedHandle?
			@beginAction(new ModifySpeedCommand(@))

		return

	updateModifySegment: (event)->
		# segment.rtype == null or 'smooth': handles are aligned, and have the same length if shit
		# segment.rtype == 'corner': handles are not equal
		# segment.rtype == 'point': no handles

		if @selectionState.handle? 									# move the selected handle

			@selectionState.handle.x += event.delta.x
			@selectionState.handle.y += event.delta.y

			if @selectionState.segment.rtype == 'smooth' or not @selectionState.segment.rtype?
				if @selectionState.handle == @selectionState.segment.handleOut and not @selectionState.segment.handleIn.isZero()
					@selectionState.segment.handleIn = if not event.modifiers.shift then @selectionState.segment.handleOut.normalize().multiply(-@selectionState.segment.handleIn.length) else @selectionState.segment.handleOut.multiply(-1)
				if @selectionState.handle == @selectionState.segment.handleIn and not @selectionState.segment.handleOut.isZero()
					@selectionState.segment.handleOut = if not event.modifiers.shift then @selectionState.segment.handleIn.normalize().multiply(-@selectionState.segment.handleOut.length) else @selectionState.segment.handleIn.multiply(-1)		
			
			g.validatePosition(@, null, true)
			@updateSelectionRectangle(true)
			@draw(true)
		else if @selectionState.segment?								# move the selected point
			@selectionState.segment.point.x += event.delta.x
			@selectionState.segment.point.y += event.delta.y
			g.validatePosition(@, null, true)
			@updateSelectionRectangle(true)
			@draw(true)

		if @selectionRectangle? then @selectionHighlight?.position = @selectionState.segment.point

		return

	updateSelect: (event)->
		if not @drawing then g.updateView()
		super(event)
		return

	# add or update the selection rectangle (path used to rotate and scale the RPath)
	# @param reset [Boolean] (optional) true if must reset the selection rectangle (one of the control path segment has been modified)
	updateSelectionRectangle: (reset=false)->
		if reset
			@controlPath.firstSegment.point = @controlPath.firstSegment.point # reset transform matrix to have @controlPath.rotation = 0 and @controlPath.scaling = 1,1
			@rectangle = @controlPath.bounds.clone()
			@rotation = 0

		super()
		@controlPath.pivot = @selectionRectangle.pivot
		
		return

	setRectangle: (rectangle, update)->
		previousRectangle = @rectangle.clone()
		super(rectangle, update)
		@controlPath.pivot = previousRectangle.center
		@controlPath.rotate(-@rotation)
		@controlPath.scale(@rectangle.width/previousRectangle.width, @rectangle.height/previousRectangle.height)
		@controlPath.position = @selectionRectangle.pivot
		@controlPath.pivot = @selectionRectangle.pivot
		@controlPath.rotate(@rotation)
		return

	setRotation: (rotation, update)->
		previousRotation = @rotation
		@drawing.pivot = @rectangle.center
		super(rotation, update)
		@controlPath.rotate(rotation-previousRotation)
		@drawing.rotate(rotation-previousRotation)
		return

	endModifySegment: ()->
		if @data.smooth then @controlPath.smooth()
		@draw()
		@update('points')
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
	# @param event [jQuery or Paper event] the mouse event
	doubleClick: (event)->
		# warning: event can be a jQuery event instead of a paper event
		
		# check if user clicked on the curve
		
		point = view.viewToProject(new Point(event.pageX, event.pageY))

		hitResult = @performHitTest(point, @constructor.hitOptions)

		if not hitResult? 	# return if user did not click on the curve
			return
		
		switch hitResult.type
			when 'segment' 											# if we click on a point: roll over the three point modes 
				
				segment = hitResult.segment
				@selectionState.segment = segment

				switch segment.rtype
					when 'smooth', null, undefined
						@changeSelectedPointType('corner')
					when 'corner'
						@changeSelectedPointType('point')
					when 'point'
						@deletePointCommand()
					else
						console.log "segment.rtype not known."
			
			when 'stroke', 'curve'
				@addPointCommand(hitResult.location)					# else if we clicked on the control path: create a point at *event* position

		return

	addPointCommand: (location)->
		g.commandManager.add(new AddPointCommand(@, location), true)
		return

	# add a point according to *hitResult*
	# @param location [Paper Location] the location where to add the point
	# @param update [Boolean] whether update is required
	# @return the new segment
	addPoint: (location, update=true)->

		segment = @controlPath.insert(location.index + 1, location.point)
		
		if @data.smooth
			@controlPath.smooth()
		else
			@smoothPoint(segment, location.offset)

		segment.selected = true
		@selectionState.segment = segment
		@draw()
		@highlightSelectedPoint()
		if update then @update('point')
		return segment

	deletePointCommand: ()->
		g.commandManager.add(new DeletePointCommand(@, @selectionState.segment), true)
		return

	# delete the point of *segment* (from curve) and delete curve if there are no points anymore
	# @param segment [Paper Segment] the segment to delete
	# @return the location of the deleted point (to be able to re-add it in case of a undo)
	deletePoint: (segment, update=true)->
		if not segment then return
		@selectionState.segment = if segment.next? then segment.next else segment.previous
		if @selectionState.segment then @selectionHighlight.position = @selectionState.segment.point
		curve = segment.location.curve
		location = { index: segment.location.index - 1, point: segment.location.point }
		segment.remove()
		if @controlPath.segments.length <= 1
			@deleteCommand()
			return
		if @data.smooth then @controlPath.smooth()
		@draw()
		if update then @update('point')
		return location

	# delete the selected point (from curve) and delete curve if there are no points anymore
	# emit the action to websocket
	deleteSelectedPoint: ()->
		@deletePoint(@selectionState.segment)
		if g.me? then g.chatSocket.emit( "parameter change", g.me, @pk, "deleteSelectedPoint", null, "rFunction")
		return

	changeSelectedPointTypeCommand: (value)->
		g.commandManager.add(new ChangeSelectedPointTypeCommand(@, value), true)
		return

	modifySegment: (segment, position, handleIn, handleOut, update=true, draw=true)->
		@selectionState = segment: segment
		@changeSelectedSegment(position, handleIn, handleOut, update, draw)
		return

	# change selected segment position and handle position
	# @param position [Paper Point] the new position
	# @param handleIn [Paper Point] the new handle in position
	# @param handleOut [Paper Point] the new handle out position
	# @param update [Boolean] whether we must update the path (for example when it is a command) or not
	# @param draw [Boolean] whether we must draw the path or not
	changeSelectedSegment: (position, handleIn, handleOut, update=true, draw=true)->
		@selectionState.segment.point = position
		@selectionState.segment.handleIn = handleIn
		@selectionState.segment.handleOut = handleOut
		@updateSelectionRectangle(true)
		@highlightSelectedPoint()
		if draw then @draw()
		if update then @update('segment')
		return

	# - set selected point mode to *value*: 'smooth', 'corner' or 'point'
	# - update the selected point highlight 
	# - emit action to websocket
	# @param value [String] new mode of the point: can be 'smooth', 'corner' or 'point'
	# @param update [Boolean] whether update is required
	changeSelectedPointType: (value, update=true)->
		if not @selectionState.segment? then return
		if @data.smooth then return
		@selectionState.segment.rtype = value
		switch value
			when 'corner'
				if @selectionState.segment.linear = true
					@selectionState.segment.linear = false
					@selectionState.segment.handleIn = @selectionState.segment.previous.point.subtract(@selectionState.segment.point).multiply(0.5)
					@selectionState.segment.handleOut = @selectionState.segment.next.point.subtract(@selectionState.segment.point).multiply(0.5)
			when 'point'
				@selectionState.segment.linear = true
			when 'smooth'
				@smoothPoint(@selectionState.segment)
		@draw()
		@highlightSelectedPoint()
		if g.me? then g.chatSocket.emit( "parameter change", g.me, @pk, "changeSelectedPoint", value, "rFunction")
		if update then @update('point')
		return

	# overload {RPath#parameterChanged}, but update the control path state if 'smooth' was changed
	# called when a parameter is changed
	changeParameter: (name, value, updateGUI)->
		super(name, value, updateGUI)
		if name == 'smooth'
			# todo: add a warning when changing smooth?
			if @data.smooth 		# todo: put this in @draw()? and remove this function? 
				@controlPath.smooth()
				@controlPath.fullySelected = false
				@controlPath.selected = true
				segment.rtype = 'smooth' for segment in @controlPath.segments
			else
				@controlPath.fullySelected = true
		return

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

	@maxSpeed = 200
	@speedStep = 20
	@secureStep = 25

	@parameters: ()->

		parameters = super()

		parameters['Edit curve'].showSpeed = 
			type: 'checkbox'
			label: 'Show speed'
			value: true

		if g.wacomPenAPI?
			parameters['Edit curve'].usePenPressure = 
				type: 'checkbox'
				label: 'Pen pressure'
				value: true

		return parameters

	# overloads {PrecisePath#initializeDrawing}
	initializeDrawing: (createCanvas=false)->
		@speedOffset = 0
		super(createCanvas)
		return

	# overloads {PrecisePath#loadPath}
	loadPath: (points)->
		@data ?= {}
		@speeds = @data.speeds or []
		super(points)
		return

	# overloads {PrecisePath#checkUpdateDrawing} to update speed while drawing
	checkUpdateDrawing: (segment, redrawing=false)->
		if redrawing
			super(segment, redrawing)
			return

		step = @data.step
		controlPathOffset = segment.location.offset
		previousControlPathOffset = if segment.previous? then segment.previous.location.offset else 0

		previousSpeed = if @speeds.length>0 then @speeds.pop() else 0

		currentSpeed = if not @data.usePenPressure or g.wacomPointerType[g.wacomPenAPI.pointerType] == 'Mouse' then controlPathOffset - previousControlPathOffset else g.wacomPenAPI.pressure * @constructor.maxSpeed

		while @speedOffset + @constructor.speedStep < controlPathOffset
			@speedOffset += @constructor.speedStep
			f = (@speedOffset-previousControlPathOffset)/currentSpeed
			speed = g.linearInterpolation(previousSpeed, currentSpeed, f)
			@speeds.push(Math.min(speed, @constructor.maxSpeed))

		@speeds.push(Math.min(currentSpeed, @constructor.maxSpeed))

		super(segment, redrawing)

		return

	# todo: better handle lock area
	# overload {PrecisePath#beginCreate} and add speed initialization
	beginCreate: (point, event)->
		@speeds = if @data.polygonMode then [@constructor.maxSpeed/3] else []
		super(point, event)
		return

	# overload {PrecisePath#endCreate} and add speed initialization
	endCreate: (point, event)->
		# if not @data.polygonMode and not loading then @speeds = []
		super(point, event)
		return

	# deprecated
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
				interpolation = g.linearInterpolation(previousDistance, distance, f)
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
				@speeds.push(Math.min(currentAverageSpeed, @constructor.maxSpeed)) 
				currentAverageSpeed = 0
				nextOffset += step

		return

	# show the speed group (called on @select())
	showSpeed: ()->
		@speedGroup?.visible = @data.showSpeed
		if not @speeds? or not @data.showSpeed then return
		@speedGroup?.bringToFront()
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
				return g.linearInterpolation(@speeds[i], @speeds[i+1], f)
			else
				return @speeds.last()
		else
			@constructor.maxSpeed/2
		return

	# overload {PrecisePath#draw} and add speed update when *loading* is false
	draw: (simplified=false, loading=false)->
		@speedOffset = 0
		super(simplified, loading)
		if @controlPath.selected then @updateSpeed()
		return

	# overload {PrecisePath#getData} and adds the speeds in @data.speeds (unused speed values are not stored)
	getData: ()->
		delete @data.usePenPressure 		# there is no need to store whether the pen was used or not
		data = jQuery.extend({}, super())
		data.speeds = if @speeds? and @handleGroup? then @speeds.slice(0, @handleGroup.children.length+1) else @speeds
		return data

	# overload {PrecisePath#select}, update speeds and show speed group
	select: (updateOptions=true)->
		if @selectionRectangle? then return
		super(updateOptions)
		@showSpeed()
		if @data.showSpeed
			if not @speedGroup? then @updateSpeed()
			@speedGroup?.visible = true
		return

	# overload {PrecisePath#deselect} and hide speed group
	deselect: ()->
		@speedGroup?.visible = false
		super()
		return

	# overload {PrecisePath#initializeSelection} but add the possibility to select speed handles
	initializeSelection: (event, hitResult) ->
		@speedSelectionHighlight?.remove()
		@speedSelectionHighlight = null

		if hitResult.item.name == "speed handle"
			@selectionState = speedHandle: hitResult.item
			return
		super(event, hitResult)
		return


	updateModifySpeed: (event)->
		if @selectionState.speedHandle?
			@speedSelectionHighlight?.remove()

			maxSpeed = @constructor.maxSpeed
			
			# initialize a line between the mouse and the handle, orthogonal to the normal
			# the length of this line determines how much influence the change will have over the neighbour handles
			@speedSelectionHighlight = new Path() 
			@speedSelectionHighlight.name = 'speed selection highlight'
			@speedSelectionHighlight.strokeWidth = 1
			@speedSelectionHighlight.strokeColor = 'blue'
			@speedGroup.addChild(@speedSelectionHighlight)

			handle = @selectionState.speedHandle
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
			else if @speeds[handle.rindex] > maxSpeed
				@speeds[handle.rindex] = maxSpeed

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
						else if @speeds[index] > maxSpeed
							@speeds[index] = maxSpeed
				i++
			
			# create the line between the mouse and the handle, orthogonal to the normal
			@speedSelectionHighlight.strokeColor.hue -= Math.min(240*(influenceFactor/10), 240)
			@speedSelectionHighlight.add(handle.position.add(projection))
			@speedSelectionHighlight.add(event.point)

			@draw(true)

			if @selectionRectangle? then @selectionHighlight?.position = @selectionState.segment.point
		return

	endModifySpeed: ()->
		@draw()
		@update('speed')
		@speedSelectionHighlight?.remove()
		@speedSelectionHighlight = null
		return

	# overload {PrecisePath#remove} and remove speed group
	remove: ()->
		@speedGroup?.remove()
		@speedGroup = null
		super()
		return

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
			default: 30
			simplified: 30
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

	drawUpdate: (offset, step)->
		# get point, normal and speed at current position
		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		if not step
			if @path.segments.length<=1 then return
			@path.firstSegment.point = point
			return

		speed = @speedAt(offset)

		# create two points at each side of the control path (separated by a length function of the speed)
		delta = normal.multiply(speed*@data.trackWidth/2)
		top = point.add(delta)
		bottom = point.subtract(delta)

		# add the two points at the beginning and the end of the path
		@path.firstSegment.remove()
		@path.add(top)
		@path.insert(0, bottom)
		@path.insert(0, point)
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
	
	drawBegin: ()->
		@initializeDrawing(false)
		@line = @addPath()
		@spiral = @addPath()
		return

	drawUpdate: (offset, step)->
		if not step then return

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

	drawUpdate: (offset, step)->
		if not step then return

		speed = @speedAt(offset)

		# add a point at 'offset'
		addPoint = (offset, speed)=>
			point = @controlPath.getPointAt(offset)
			normal = @controlPath.getNormalAt(offset).normalize()

			# set the width of the step
			if @data.speedForWidth
				width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.maxSpeed		# map the speed to [@data.minWidth, @data.maxWidth]
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
			speed = @data.minSpeed + (speed / @constructor.maxSpeed) * (@data.maxSpeed - @data.minSpeed)
			
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

# The geometric lines path draws a line between all pair of points which are close enough
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
		parameters['Style'].strokeColor.defaultFunction = null
		parameters['Style'].strokeColor.default = "rgba(39, 158, 224, 0.21)"
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

	drawUpdate: (offset, step)->
		if not step then return

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

class PaintBrush extends PrecisePath
	@rname = 'Paint brush'
	@rdescription = "Paints a thick stroke with customable blur effects."
	@iconUrl = 'static/images/icons/inverted/brush.png'
	@iconAlt = 'brush'

	@parameters: ()->
		parameters = super()
		delete parameters['Style'].fillColor 	# remove the fill color, we do not need it

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 1
			max: 100
			default: 11
			simplified: 20
			step: 1
		parameters['Parameters'].size =
			type: 'slider'
			label: 'Size'
			min: 1
			max: 100
			default: 10
		parameters['Parameters'].blur =
			type: 'slider'
			label: 'Blur'
			min: 0
			max: 100
			default: 20

		return parameters

	drawBegin: ()->
		@initializeDrawing(true)
		point = @controlPath.firstSegment.point
		point = @projectToRaster(point)
		@context.moveTo(point.x, point.y)
		return

	drawUpdate: (offset, step)->
		if not step then return

		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		point = @projectToRaster(point) 		#  convert the points from project to canvas coordinates
		
		innerRadius = @data.size * (1 - @data.blur / 100)
		outerRadius = @data.size

		radialGradient = @context.createRadialGradient(point.x, point.y, innerRadius, point.x, point.y, outerRadius)

		midColor = new Color(@data.strokeColor)
		midColor.alpha = 0.5
		endColor = new Color(@data.strokeColor)
		endColor.alpha = 0
		radialGradient.addColorStop(0, @data.strokeColor)
		radialGradient.addColorStop(0.5, midColor.toCSS())
		radialGradient.addColorStop(1, endColor.toCSS())
		
		@context.fillStyle = radialGradient
		@context.fillRect(point.x-outerRadius, point.y-outerRadius, 2*outerRadius, 2*outerRadius)

		return

	drawEnd: ()->
		return

@PaintBrush = PaintBrush
@pathClasses.push(@PaintBrush)

class PaintGun extends SpeedPath
	@rname = 'Paint gun'
	@rdescription = "The stroke width is function of the drawing speed: the faster the wider."
	# "http://thenounproject.com/term/spray-bottle/7835/"
	# "http://thenounproject.com/term/spray-bottle/93690/"
	# "http://thenounproject.com/term/spray-paint/3533/"
	# "http://thenounproject.com/term/spray-paint/18249/"
	# "http://thenounproject.com/term/spray-paint/18249/"
	# "http://thenounproject.com/term/spray-paint/17918/"

	@parameters: ()->
		parameters = super()
		delete parameters['Style'].fillColor 	# remove the fill color, we do not need it
		parameters['Edit curve'].showSpeed.value = false

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 1
			max: 100
			default: 11
			simplified: 20
			step: 1
		parameters['Parameters'].trackWidth =
			type: 'slider'
			label: 'Track width'
			min: 0.1
			max: 3
			default: 0.25
		parameters['Parameters'].roundEnd =
			type: 'checkbox'
			label: 'Round end'
			default: false
		parameters['Parameters'].inverseThickness =
			type: 'checkbox'
			label: 'Inverse thickness'
			default: false

		return parameters

	drawBegin: ()->
		@initializeDrawing(true)
		point = @controlPath.firstSegment.point
		point = @projectToRaster(point) 		#  convert the points from project to canvas coordinates
		@context.moveTo(point.x, point.y)
		
		@previousTop = point
		@previousBottom = point
		@previousMidTop = point
		@previousMidBottom = point

		@maxSpeed = if @speeds.length>0 then @speeds.max() / 1.5 else @constructor.maxSpeed / 6

		return

	drawStep: (offset, step, end=false)->

		point = @controlPath.getPointAt(offset)
		normal = @controlPath.getNormalAt(offset).normalize()

		speed = @speedAt(offset)

		point = @projectToRaster(point) 		#  convert the points from project to canvas coordinates

		# create two points at each side of the control path (separated by a length function of the speed)
		if not @data.inverseThickness
			delta = normal.multiply(speed * @data.trackWidth / 2)
		else
			delta = normal.multiply(Math.max(@maxSpeed-speed, 0) * @data.trackWidth / 2)

		top = point.add(delta)
		bottom = point.subtract(delta)

		if not end
			midTop = @previousTop.add(top).multiply(0.5)
			midBottom = @previousBottom.add(bottom).multiply(0.5)
		else
			midTop = top
			midBottom = bottom

		@context.fillStyle = @data.strokeColor

		@context.beginPath()

		@context.moveTo(@previousMidTop.x, @previousMidTop.y)
		
		@context.lineTo(@previousMidBottom.x, @previousMidBottom.y)
		@context.quadraticCurveTo(@previousBottom.x, @previousBottom.y, midBottom.x, midBottom.y)
		@context.lineTo(midTop.x, midTop.y)
		@context.quadraticCurveTo(@previousTop.x, @previousTop.y, @previousMidTop.x, @previousMidTop.y,)
		
		@context.fill()
		@context.stroke()
		
		if step
			@previousTop = top
			@previousBottom = bottom
			@previousMidTop = midTop
			@previousMidBottom = midBottom

		return

	drawUpdate: (offset, step)->
		@drawStep(offset, step)
		return

	drawEnd: ()->
		@drawStep(@controlPath.length, false, true)

		if @data.roundEnd
			point = @controlPath.lastSegment.point
			point = @projectToRaster(point)
			@context.beginPath()
			@context.fillStyle = @data.strokeColor
			@context.arc(point.x, point.y, @speeds.last() * @data.trackWidth / 2, 0, 2 * Math.PI)
			@context.fill()
		return

@PaintGun = PaintGun
@pathClasses.push(@PaintGun)

class DynamicBrush extends SpeedPath
	@rname = 'Dynamic brush'
	@rdescription = "The stroke width is function of the drawing speed: the faster the wider."
	# "http://thenounproject.com/term/spray-bottle/7835/"
	# "http://thenounproject.com/term/spray-bottle/93690/"
	# "http://thenounproject.com/term/spray-paint/3533/"
	# "http://thenounproject.com/term/spray-paint/18249/"
	# "http://thenounproject.com/term/spray-paint/18249/"
	# "http://thenounproject.com/term/spray-paint/17918/"

	@parameters: ()->
		parameters = super()
		delete parameters['Style'].fillColor 	# remove the fill color, we do not need it
		parameters['Edit curve'].showSpeed.value = false

		parameters['Parameters'] ?= {}
		parameters['Parameters'].step =
			type: 'slider'
			label: 'Step'
			min: 1
			max: 100
			default: 5
			simplified: 20
			step: 1
		parameters['Parameters'].trackWidth =
			type: 'slider'
			label: 'Track width'
			min: 0.0
			max: 10.0
			default: 0.5
		parameters['Parameters'].mass =
			type: 'slider'
			label: 'Mass'
			min: 1
			max: 200
			default: 40
		parameters['Parameters'].drag =
			type: 'slider'
			label: 'Drag'
			min: 0
			max: 0.4
			default: 0.1
		parameters['Parameters'].maxSpeed =
			type: 'slider'
			label: 'Max speed'
			min: 0
			max: 100
			default: 35
		parameters['Parameters'].roundEnd =
			type: 'checkbox'
			label: 'Round end'
			default: false
		parameters['Parameters'].inverseThickness =
			type: 'checkbox'
			label: 'Inverse thickness'
			default: false
		parameters['Parameters'].fixedAngle =
			type: 'checkbox'
			label: 'Fixed angle'
			default: false
		parameters['Parameters'].simplify =
			type: 'checkbox'
			label: 'Simplify'
			default: true
		parameters['Parameters'].angle =
			type: 'slider'
			label: 'Angle'
			min: 0
			max: 360
			default: 0

		return parameters

	drawBegin: (redrawing=false)->
		@initializeDrawing(true)
	
		@point = @controlPath.firstSegment.point

		@currentPosition = @point
		@previousPosition = @currentPosition
		@previousMidPosition = @currentPosition
		@previousMidDelta = new Point()
		@previousDelta = new Point()

		@context.fillStyle = 'black' 	# @data.fillColor
		@context.strokeStyle = @data.fillColor

		# @path = @addPath()
		# @path.add(@point)
		# @path.strokeWidth = 0
		# @path.strokeColor = null
		# @path.fillColor = @data.strokeColor
		# @path.closed = true

		if not redrawing
			@velocity = new Point()
			@velocities = []
			@controlPathReplacement = @controlPath.clone()

			@setAnimated(true)
		return

	drawSegment: (currentPosition, width, delta=null)->
		# if not @continueDrawing then return

		width = if @data.inverseThickness then width else (@data.maxSpeed-width)

		width *= @data.trackWidth

		if width < 0.1
			width = 0.1

		if @data.fixedAngle
			delta = new Point(1,0)
			delta.angle = @data.angle
		else
			delta = delta.normalize()

		delta = delta.multiply(width)

		midPosition = currentPosition.add(@previousPosition).divide(2)
		midDelta = delta.add(@previousDelta).divide(2)

		# a = @projectToRaster(@previousPosition.add(@previousDelta))
		# b = @projectToRaster(@previousPosition.subtract(@previousDelta))
		# c = @projectToRaster(currentPosition.subtract(delta))
		# d = @projectToRaster(currentPosition.add(delta))

		# @context.fillStyle = @data.strokeColor

		# @context.beginPath()
		# @context.moveTo(a.x, a.y)
		# @context.lineTo(b.x, b.y)
		# @context.stroke()
		# @context.lineTo(c.x, c.y)
		# @context.lineTo(d.x, d.y)
		# @context.fill()

		previousMidTop = @projectToRaster(@previousMidPosition.add(@previousMidDelta))
		previousMidBottom = @projectToRaster(@previousMidPosition.subtract(@previousMidDelta))

		previousTop = @projectToRaster(@previousPosition.add(@previousDelta))
		previousBottom = @projectToRaster(@previousPosition.subtract(@previousDelta))

		midTop = @projectToRaster(midPosition.add(midDelta))
		midBottom = @projectToRaster(midPosition.subtract(midDelta))

		@context.beginPath()
		@context.moveTo(previousMidTop.x, previousMidTop.y)
		@context.lineTo(previousMidBottom.x, previousMidBottom.y)
		@context.quadraticCurveTo(previousBottom.x, previousBottom.y, midBottom.x, midBottom.y)
		@context.lineTo(midTop.x, midTop.y)
		@context.quadraticCurveTo(previousTop.x, previousTop.y, previousMidTop.x, previousMidTop.y,)
		@context.fill()
		@context.stroke()

		@previousDelta = delta
		@previousMidPosition = midPosition
		@previousMidDelta = midDelta
		return

	updateForce: ()->
		# calculate force and acceleration
		force = @point.subtract(@currentPosition)
		if force.length<0.1
			return false

		acceleration = force.divide(@data.mass)

		# calculate new velocity
		@velocity = @velocity.add(acceleration)
		if @velocity.length<0.1
			return false

		# apply drag
		@velocity = @velocity.multiply(1.0-@data.drag)

		# update position
		@previousPosition = @currentPosition
		@currentPosition = @currentPosition.add(@velocity)
		
		return true

	drawStep: ()->
		if @finishedDrawing then return

		continueDrawing = @updateForce()
		if not continueDrawing then return

		v = @velocity.length

		@controlPathReplacement.add(@currentPosition)
		@velocities.push(v)

		@drawSegment(@currentPosition, v, new Point(-@velocity.y, @velocity.x))

		###
		width = if @data.inverseThickness then v else (10-v)
		width *= @data.trackWidth

		if not @data.fixedAngle
			delta = new Point(-@velocity.y, @velocity.x)
		else
			delta = new Point(1,0)
			delta.angle = @data.angle
		delta = delta.normalize().multiply(width)

		a = @projectToRaster(@previousPosition.add(@previousDelta))
		b = @projectToRaster(@previousPosition.subtract(@previousDelta))
		c = @projectToRaster(@currentPosition.subtract(delta))
		d = @projectToRaster(@currentPosition.add(delta))

		# @path.add(c)
		# @path.insert(0, d)
		###
		
		return

	onFrame: ()=>
		for i in [0 .. 2]
			@drawStep()
		return

	drawUpdate: (offset, step, redrawing)->
		@point = @controlPath.getPointAt(offset)
		
		if redrawing
			v = @speedAt(offset)
			
			@drawSegment(@point, v, @controlPath.getNormalAt(offset))

			@previousPosition = @point
			###
			width = if @data.inverseThickness then v else (10-v)
			width *= @data.trackWidth

			if not @data.fixedAngle
				delta = @controlPath.getNormalAt(offset).normalize()
			else
				delta = new Point(1,0)
				delta.angle = @data.angle

			delta = delta.multiply(width)
			top = @point.add(delta)
			bottom = @point.subtract(delta)

			@path.add(top)
			@path.insert(0, bottom)
			###
		return

	drawEnd: (redrawing=false)->
		if not redrawing
			@setAnimated(false)

			@finishedDrawing = true
			# @path.closed = true

			# compute @speeds from @velocities
			length = @controlPathReplacement.length
			offset = 0
			@speeds = []
			
			while offset<length
				location = @controlPathReplacement.getLocationAt(offset)
				i = location.segment.index
				f = location.parameter
				if i<@velocities.length-1
					@speeds.push(g.linearInterpolation(@velocities[i], @velocities[i+1], f))
				else
					@speeds.push(@velocities[i])
				offset += @constructor.speedStep

			@velocities = []
			if @data.simplify then @controlPathReplacement.simplify()
			@controlPathReplacement.insert(0, @controlPathReplacement.firstSegment.point)
			@controlPathReplacement.insert(0, @controlPathReplacement.firstSegment.point)
			@controlPath.segments = @controlPathReplacement.segments
			@controlPathReplacement.remove()
			
		# else
			# if @data.roundEnd
			# 	@path.smooth()
			# @path.selected = false 		# @path would be selected because we added the last point of the control path which is selected

		return

	remove: ()->
		clearInterval(@timerId)
		return

@DynamicBrush = DynamicBrush
@pathClasses.push(@DynamicBrush)

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

	drawUpdate: (offset, step)->
		if not step then return

		speed = @speedAt(offset)

		# add a shape at 'offset'
		addShape = (offset, height, speed)=>
			point = @controlPath.getPointAt(offset)
			normal = @controlPath.getNormalAt(offset)

			width = @data.minWidth + (@data.maxWidth - @data.minWidth) * speed / @constructor.maxSpeed
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
			speed = @data.minSpeed + (speed / @constructor.maxSpeed) * (@data.maxSpeed - @data.minSpeed)
			
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
		@rectangle = if @data.rectangle? then new Rectangle(@data.rectangle) else new Rectangle()
		@initializeControlPath(@rectangle.topLeft, @rectangle.bottomRight, false, false, true)
		@draw(null, true)
		@controlPath.rotation = @rotation
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
		process = ()=>
			@initializeDrawing()
			@createShape()
			@drawing.rotation = @rotation
			@rasterize()
			return
		if not g.catchErrors
			process()
		else
			try 							# catch errors to log them in console (if the user has code editor open)
				process()
			catch error
				console.error error.stack
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
		@rotation ?= 0
		@addControlPath(new Path.Rectangle(@rectangle))
		@controlPath.fillColor = g.selectionBlue
		@controlPath.fillColor.alpha = 0.25
		return

	# overload {RPath#beginCreate} + initialize the control path and draw
	beginCreate: (point, event) ->
		super()
		@downPoint = point
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		@draw()
		return

	# redefine {RPath#updateCreate}: 
	# initialize the control path and draw
	updateCreate: (point, event, loading) ->
		# console.log " event.modifiers.command"
		# console.log event.modifiers.command
		# console.log g.specialKey(event)
		# console.log event?.modifiers?.shift
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		if not loading then @draw()
		return

	# overload {RPath#endCreate} + initialize the control path and draw
	endCreate: (point, event) ->
		@initializeControlPath(@downPoint, point, event?.modifiers?.shift, g.specialKey(event))
		@draw()
		super()
		return

	setRotation: (rotation, update)->
		super(rotation, update)
		@drawing.rotation = rotation
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
		@shape.rotation += @rotationSpeed
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
		delta.rotation = -@rotation
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
			max: 5
			default: 1
		parameters['Parameters'].maskWidth =
			type: 'slider'
			label: 'Mask width'
			min: 1
			max: 4
			default: 1
		parameters['Parameters'].speed =
			type: 'slider'
			label: 'Speed'
			min: 0.01
			max: 1.0
			default: 0.1

		return parameters

	# animted paths must be initialized
	initialize: ()->
		@data.animate = true
		@setAnimated(@data.animate)
		
		@modalJ = $('#customModal')
		modalBodyJ = @modalJ.find('.modal-body')
		modalBodyJ.empty()
		modalContentJ = $("""
			<div id="stripeAnimationContent" class="form-group url-group">
                <label for="stripeAnimationModalURL">Add your images</label>
                <input id="stripeAnimationFileInput" type="file" class="form-control" name="files[]" multiple/>
                <div id="stripeAnimationDropZone">Drop your image files here.</div>
                <div id="stripeAnimationGallery"></div>
            </div>
            """)
		modalBodyJ.append(modalContentJ)

		@modalJ.modal('show')
		# @modalJ.find('.btn-primary').click( (event)=> @modalSubmit() ) 		# submit modal when click submit button
		
		if window.File and window.FileReader and window.FileList and window.Blob
  			#Great success! All the File APIs are supported.
  			console.log 'File upload supported'
		else
			console.log 'File upload not supported'
			romanesco_alert 'File upload not supported', 'error'
		
		handleFileSelect = (evt) =>
			evt.stopPropagation()
			evt.preventDefault()
			files = evt.dataTransfer?.files or evt.target?.files

			# FileList object
			# Loop through the FileList and render image files as thumbnails.

			@nRasterToLoad = files.length
			@nRasterLoaded = 0
			@rasters = []

			i = 0
			f = undefined
			while f = files[i]
				# Only process image files.
				if not f.type.match('image.*')
					i++
					continue
				reader = new FileReader
				# Closure to capture the file information.
				reader.onload = ((theFile, stripeAnimation) ->
					(e) ->
						# Render thumbnail.
						span = document.createElement('span')
						span.innerHTML = [
							'<img class="thumb" src="'
							e.target.result
							'" title="'
							escape(theFile.name)
							'"/>'
						].join('')
						$("#stripeAnimationGallery").append(span)

						stripeAnimation.rasters.push(new Raster(e.target.result))

						stripeAnimation.nRasterLoaded++
						if stripeAnimation.nRasterLoaded == stripeAnimation.nRasterToLoad then stripeAnimation.rasterLoaded()
						
						return
				)(f, @)
				# Read in the image file as a data URL.
				reader.readAsDataURL f
				i++
			return

		$("#stripeAnimationFileInput").change(handleFileSelect)

		handleDragOver = (evt) ->
			evt.stopPropagation()
			evt.preventDefault()
			evt.dataTransfer.dropEffect = 'copy'
			# Explicitly show this is a copy.
			return

		dropZone = document.getElementById('stripeAnimationDropZone')
		dropZone.addEventListener 'dragover', handleDragOver, false
		dropZone.addEventListener 'drop', handleFileSelect, false

		return

	# modalSubmit: ()->
	# 	inputs = @modalJ.find("input.url")
	# 	@nRasterToLoad = inputs.length
	# 	@nRasterLoaded = 0
	# 	@rasters = []
	# 	for input in inputs
	# 		raster = new Raster(input.value)
	# 		raster.onLoad = @rasterOnLoad
	# 		@rasters.push(raster)
	# 	return

	rasterLoaded: ()=>
		if not @rasters? or @rasters.length==0 then return
		if @nRasterLoaded != @nRasterToLoad then return

		@minSize = new Size()
		for raster in @rasters
			if @minSize.width == 0 or raster.width < @minSize.width
				@minSize.width = raster.width
			if @minSize.height == 0 or raster.height < @minSize.height
				@minSize.height = raster.height

		for raster in @rasters
			raster.size = @minSize
		
		size = @rasters[0].size
		
		@result = new Raster()
		@result.position = @rectangle.center
		@result.size = size
		@result.name = 'stripe animation raster'
		@result.controller = @
		@drawing.addChild(@result)

		@stripes = new Raster()
		@stripes.size = new Size(size.width*2, size.height)
		@stripes.position = @rectangle.center
		@stripes.name = 'stripe mask raster'
		@stripes.controller = @
		@drawing.addChild(@stripes)

		n = @rasters.length
		width = @data.stripeWidth

		black = new Color(0, 0, 0)
		transparent = new Color(0, 0, 0, 0)
		
		# for x in [0 .. (2*size.width)-1]
		# 	for y in [0 .. size.height-1]
		# 		i = g.roundToLowerMultiple(x, width) % n
		# 		if x < size.width
		# 			@result.setPixel(x, y, @rasters[i].getPixel(x, y))
		# 		@stripes.setPixel(x, y, if i==0 then transparent else black)

		nStripes = Math.floor(size.width/width)
		for i in [0 .. nStripes]
			stripeData = @rasters[i%n].getImageData(new Rectangle(i*width, 0, width, size.height))
			@result.setImageData(stripeData, new Point(i*width, 0))

		stripesContext = @stripes.canvas.getContext("2d")
		stripesContext.fillStyle = "rgb(0, 0, 0)"
		
		nVisibleFrames = Math.min(@data.maskWidth, n-1)
		blackStripeWidth = width*(n-nVisibleFrames)
		position = nVisibleFrames*width

		while position < @stripes.width
			stripesContext.fillRect(position, 0, blackStripeWidth, size.height)
			position += width*n

		return

	createShape: ()->
		@rasterLoaded()
		return

	# called at each frame event
	# this is the place where animated paths should be updated
	onFrame: (event)=>
		# very simple example of path animation
		if not @stripes? then return
		@stripes.position.x -= @data.speed
		if @stripes.bounds.center.x < @rectangle.left
			@stripes.bounds.center.x = @rectangle.right
		return

@StripeAnimation = StripeAnimation
@pathClasses.push(@StripeAnimation)