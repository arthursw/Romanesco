class RItem

	@indexToName =
		0: 'bottomLeft'
		1: 'left'
		2: 'topLeft'
		3: 'top'
		4: 'topRight'
		5: 'right'
		6: 'bottomRight'
		7: 'bottom'
	
	@oppositeName = 
		'top': 'bottom'
		'bottom': 'top'
		'left': 'right'
		'right': 'left'
		'topLeft': 'bottomRight'
		'topRight':  'bottomLeft'
		'bottomRight':  'topLeft'
		'bottomLeft':  'topRight'

	@cornerNames = ['topLeft', 'topRight', 'bottomRight', 'bottomLeft']

	@valueFromName = (point, name)->
		switch name
			when 'left', 'right'
				return point.x
			when 'top', 'bottom'
				return point.y
			else
				return point

	# Paper hitOptions for hitTest function to check which items (corresponding to those criterias) are under a point
	@hitOptions =
		segments: true
		stroke: true
		fill: true
		selected: true
		tolerance: 5

	@parameters: ()->

		parameters =
			'General':
				align: g.parameters.align
				distribute: g.parameters.distribute
				delete: g.parameters.delete
			'Style':
				strokeWidth: g.parameters.strokeWidth
				strokeColor: g.parameters.strokeColor
				fillColor: g.parameters.fillColor

		return parameters

	constructor: (@data, @pk)->
		
		# if the RPath is being loaded: directly set pk and load path
		if @pk?
			@setPK(@pk, false)
		else
			@id = if @data?.id? then @data.id else Math.random() 	# temporary id used until the server sends back the primary key (@pk)
			g.items[@id] = @

		# creation of a new object by the user: set @data to g.gui values
		@data ?= new Object()
		for name, folder of g.gui.__folders
			if name=='General' then continue
			for controller in folder.__controllers
				@data[controller.property] ?= controller.rValue()
		
		@rectangle ?= null

		@selectionState = null
		@selectionRectangle = null

		@group = new Group()
		@group.name = "group"
		@group.controller = @

		return

	changeParameterCommand: (name, value)->
		@deferredAction(ChangeParameterCommand, name, value)
		# if @data[name] == value then return
		# @setCurrentCommand(new ChangeParameterCommand(@, name))
		# @changeParameter(name, value)
		# g.deferredExecution(@addCurrentCommand, 'addCurrentCommand-' + (@id or @pk) )
		return

	# @param name [String] the name of the value to change
	# @param value [Anything] the new value
	# @param updateGUI [Boolean] (optional, default is false) whether to update the GUI (parameters bar), true when called from ChangeParameterCommand
	changeParameter: (name, value, updateGUI, update)->
		@data[name] = value
		@changed = name
		if update then @update(name)
		if updateGUI then g.setControllerValueByName(name, value, @)
		return

	# set path items (control path, drawing, etc.) to the right state before performing hitTest
	# store the current state of items, and change their state (the original states will be restored in @finishHitTest())
	# @param fullySelected [Boolean] (optional) whether the control path must be fully selected before performing the hit test (it must be if we want to test over control path handles)
	# @param strokeWidth [Number] (optional) contorl path width will be set to *strokeWidth* if it is provided
	prepareHitTest: (fullySelected=true, strokeWidth)->
		return

	# restore path items orginial states (same as before @prepareHitTest())
	# @param fullySelected [Boolean] (optional) whether the control path must be fully selected before performing the hit test (it must be if we want to test over control path handles)
	finishHitTest: (fullySelected=true)->
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

	# intialize the selection: 
	# determine which action to perform depending on the the *hitResult* (move by default, edit point if segment from contorl path, etc.)
	# set @selectionState which will be used during the selection process (select begin, update, end)
	# @param event [Paper event] the mouse event
	# @param hitResult [Paper HitResult] [paper hit result](http://paperjs.org/reference/hitresult/) form the hit test
	initializeSelection: (event, hitResult) ->
		if hitResult?.type == 'segment'
			if hitResult.item == @selectionRectangle 			# if the segment belongs to the selection rectangle: initialize rotation or scaling
				@selectionState = resize: { index: hitResult.segment.index }
		return

	# begin select action:
	# - initialize selection (reset selection state)
	# - select
	# - hit test and initialize selection
	# @param event [Paper event] the mouse event
	beginSelect: (event) ->
		
		@selectionState = move: true
		if not @isSelected()
			g.commandManager.add(new SelectCommand([@]), true)
		else
			hitResult = @performHitTest(event.point, @constructor.hitOptions)
			if hitResult? then @initializeSelection(event, hitResult)
		
		if @selectionState.move?
			@beginAction(new MoveCommand(@))
		else if @selectionState.resize?
			@beginAction(new ResizeCommand(@))

		return

	# depending on the selected item, updateSelect will:
	# - rotate the group,
	# - scale the group,
	# - or move the group.
	# @param event [Paper event] the mouse event
	updateSelect: (event)->
		@updateAction(event)
		return

	# end the selection action:
	# - nullify selectionState
	# - redraw in normal mode (not fast mode)
	# - update select command
	endSelect: (event)->
		@endAction()
		return

	beginAction: (command)->
		if @currentCommand
			@endAction()
			clearTimeout(g.updateTimeout['addCurrentCommand-' + (@id or @pk)])
		@currentCommand = command
		return

	updateAction: ()->
		@currentCommand.update.apply(@currentCommand, arguments)
		return

	endAction: ()=>
		commandChanged = @currentCommand.end()
		if g.validatePosition(@)
			if commandChanged then g.commandManager.add(@currentCommand)
		else
			@currentCommand.undo()
		@currentCommand = null
		return

	deferredAction: (ActionCommand, args...)->
		if not ActionCommand.prototype.isPrototypeOf(@currentCommand)
			@beginAction(new ActionCommand(@, args))
		@updateAction.apply(@, args)
		g.deferredExecution(@endAction, 'addCurrentCommand-' + (@id or @pk) )
		return

	doAction: (ActionCommand, args)->
		@beginAction(new ActionCommand(@))
		@updateAction.apply(@, args)
		@endAction()
		return

	# create the selection rectangle (path used to rotate and scale the RPath)
	# @param bounds [Paper Rectangle] the bounds of the selection rectangle
	createSelectionRectangle: (bounds)->
		@selectionRectangle.insert(1, new Point(bounds.left, bounds.center.y))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(5, new Point(bounds.right, bounds.center.y))
		@selectionRectangle.insert(7, new Point(bounds.center.x, bounds.bottom))
		return

	# add or update the selection rectangle (path used to rotate and scale the RPath)
	# redefined by RShape# the selection rectangle is slightly different for a shape since it is never reset (rotation and scale are stored in database)
	updateSelectionRectangle: ()->
		bounds = @rectangle.clone().expand(10)

		# create the selection rectangle: rectangle path + handle at the top used for rotations
		@selectionRectangle?.remove()
		@selectionRectangle = new Path.Rectangle(bounds)
		@group.addChild(@selectionRectangle)
		@selectionRectangle.name = "selection rectangle"
		@selectionRectangle.pivot = bounds.center
		
		@createSelectionRectangle(bounds)

		@selectionRectangle.selected = true
		@selectionRectangle.controller = @

		return

	setRectangle: (rectangle, update=false)->
		@rectangle = rectangle
		@updateSelectionRectangle()
		if update then @update('rectangle')
		return
	
	updateSetRectangle: (event)->
		rotation = @rotation or 0
		rectangle = @rectangle.clone()
		delta = event.point.subtract(@rectangle.center)
		x = new Point(1,0)
		x.angle += rotation
		dx = x.dot(delta)
		y = new Point(0,1)
		y.angle += rotation
		dy = y.dot(delta)

		index = @selectionState.resize.index
		name = @constructor.indexToName[index]

		# if shift is not pressed and a corner is selected: keep aspect ratio (rectangle must have width and height greater than 0 to keep aspect ratio)
		if not event.modifiers.shift and name in @constructor.cornerNames and rectangle.width > 0 and rectangle.height > 0
			if Math.abs(dx / rectangle.width) > Math.abs(dy / rectangle.height)
				dx = g.sign(dx) * Math.abs(rectangle.width * dy / rectangle.height)
			else
				dy = g.sign(dy) * Math.abs(rectangle.height * dx / rectangle.width)

		center = rectangle.center.clone()
		rectangle[name] = @constructor.valueFromName(center.add(dx, dy), name)

		if not g.specialKey(event) 
			rectangle[@constructor.oppositeName[name]] = @constructor.valueFromName(center.subtract(dx, dy), name)
		else
			# the center of the rectangle changes when moving only one side
			# the center must be repositionned with the previous center as pivot point (necessary when rotation > 0)
			rectangle.center = center.add(rectangle.center.subtract(center).rotate(rotation))

		if rectangle.width < 0
			rectangle.width = Math.abs(rectangle.width)
			rectangle.center.x = center.x
		if rectangle.height < 0
			rectangle.height = Math.abs(rectangle.height)
			rectangle.center.y = center.y
		
		@setRectangle(rectangle)
		g.highlightValidity(@)
		return

	endSetRectangle: ()->
		@update('rectangle')
		return

	moveTo: (position, update)->
		delta = position.subtract(@rectangle.center)
		@rectangle.center = position
		@group.translate(delta)
		if update then @update('position')
		return

	moveBy: (delta, update)->
		@moveTo(@rectangle.center.add(delta), update)
		return

	updateMoveBy: (event)->
		@moveBy(event.delta)
		g.highlightValidity(@)
		return

	endMoveBy: ()->
		@update('position')
		return

	moveToCommand: (position)->
		g.commandManager.add(new MoveCommand(@, position), true)
		return

	moveByCommand: (delta)->
		@moveToCommand(@rectangle.center.add(delta), true)
		return

	# @return [Object] @data along with @rectangle and @rotation
	getData: ()->
		data = jQuery.extend({}, @data)
		data.rectangle = @rectangle.toJSON()
		data.rotation = @rotation
		return data

	# @return [String] the stringified data
	getStringifiedData: ()->
		return JSON.stringify(@getData())

	getBounds: ()->
		return @rectangle

	# highlight this RItem by drawing a blue rectangle around it
	highlight: ()->
		@highlightRectangle = new Path.Rectangle(@getBounds())
		@highlightRectangle.strokeColor = g.selectionBlue
		@highlightRectangle.dashArray = [4, 10]
		@group?.addChild(@highlightRectangle)
		@highlightRectangle.bringToFront()
		return

	# common to all RItems
	# hide highlight rectangle
	unhighlight: ()->
		if not @highlightRectangle? then return
		@highlightRectangle.remove()
		@highlightRectangle = null
		return

	setPK: (@pk)->
		g.items[pk] = @
		delete g.items[@id]
		return

	# @return true if RItem is selected
	isSelected: ()->
		return @selectionRectangle?
	
	# select the RItem: (only if it has no selection rectangle i.e. not already selected)
	# - update the selection rectangle, 
	# - (optionally) update controller in the gui accordingly
	# @param updateOptions [Boolean] whether to update controllers in gui or not
	# @return whether the ritem was selected or not
	select: (updateOptions=true)->
		if @selectionRectangle? then return false

		g.previouslySelectedItems = g.selectedItems.slice()
		
		@lock?.deselect()
		
		# create or update the selection rectangle
		@selectionState = move: true
		@updateSelectionRectangle(true)

		# create or update the global selection group
		if updateOptions then g.updateParameters( { tool: @constructor, item: @ } , true)

		g.s = @
		g.selectedItems.push(@)
		return true

	deselect: (updatePreviouslySelectedItems=true)->
		if not @selectionRectangle? then return false
		
		if updatePreviouslySelectedItems then g.previouslySelectedItems = g.selectedItems.slice()

		@selectionRectangle?.remove()
		@selectionRectangle = null
		g.selectedItems.remove(@)
	
		return true

	remove: ()->
		@deselect()
		@group.remove()
		@group = null
		@highlightRectangle?.remove()
		if @pk?
			delete g.items[@pk]
		else
			delete g.items[@id]
		return

	deleteCommand: ()->
		g.commandManager.add(new DeleteCommand(@), true)
		return

@RItem = RItem

class RContent extends RItem

	@indexToName =
		0: 'bottomLeft'
		1: 'left'
		2: 'topLeft'
		3: 'top'
		4: 'rotation-handle'
		5: 'top'
		6: 'topRight'
		7: 'right'
		8: 'bottomRight'
		9: 'bottom'

	@parameters: ()->
		parameters = super()
		parameters['General'].duplicate = g.parameters.duplicate
		return parameters

	constructor: (@data, @pk, @date, itemListJ, @sortedItems)->
		super(@data, @pk)
		@date ?= Date.now()

		@rotation = @data.rotation or 0
		
		@liJ = $("<li>")
		@setZindexLabel()
		@liJ.attr("data-pk", @pk)
		@liJ.click (event)=>
			if not event.shiftKey
				g.deselectAll()
			@select()
			return
		@liJ.mouseover (event)=>
			@highlight()
			return
		@liJ.mouseout (event)=>
			@unhighlight()
			return
		@liJ.rItem = @
		itemListJ.prepend(@liJ)
		$("#RItems .mCustomScrollbar").mCustomScrollbar("scrollTo", "bottom")

		@updateZIndex()
		return

	setZindexLabel: ()->
		dateLabel = '' + @date
		dateLabel = dateLabel.substring(dateLabel.length-7, dateLabel.length-3)
		zindexLabel = @constructor.rname
		if dateLabel.length>0 then zindexLabel += ' - ' + dateLabel
		@liJ.text(zindexLabel)
		return

	initializeSelection: (event, hitResult) ->
		super(event, hitResult)

		if hitResult?.type == 'segment'
			if hitResult.item == @selectionRectangle 			# if the segment belongs to the selection rectangle: initialize rotation or scaling
				if @constructor.indexToName[hitResult.segment.index] == 'rotation-handle'
					@selectionState = rotation: true
		return

	# begin select action:
	# - initialize selection (reset selection state)
	# - select
	# - hit test and initialize selection
	# @param event [Paper event] the mouse event
	beginSelect: (event) ->
		super(event)
		if @selectionState.rotation?
			@beginAction(new RotationCommand(@))
		return

	# @param bounds [Paper Rectangle] the bounds of the selection rectangle
	createSelectionRectangle: (bounds)->
		@selectionRectangle.insert(1, new Point(bounds.left, bounds.center.y))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top-25))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(7, new Point(bounds.right, bounds.center.y))
		@selectionRectangle.insert(9, new Point(bounds.center.x, bounds.bottom))
		return

	updateSelectionRectangle: ()->
		super()
		@selectionRectangle.rotation = @rotation
		return

	setRotation: (rotation, update)->
		previousRotation = @rotation
		@group.pivot = @rectangle.center
		@rotation = rotation
		@group.rotate(rotation-previousRotation)
		# @rotation = rotation
		# @selectionRectangle.rotation = rotation
		if update then @update('rotation')
		return

	updateSetRotation: (event)->
		rotation = event.point.subtract(@rectangle.center).angle + 90
		@setRotation(rotation)
		g.highlightValidity(@)
		return

	endSetRotation: ()->
		@update('rotation')
		return

	# @return [Object] @data along with @rectangle and @rotation
	getData: ()->
		data = jQuery.extend({}, super())
		data.rotation = @rotation
		return data

	getBounds: ()->
		if @rotation == 0 then return @rectangle
		return g.getRotatedBounds(@rectangle, @rotation)

	# highlight this RItem by drawing a blue rectangle around it
	highlight: ()->
		@highlightRectangle = new Path.Rectangle(@getBounds())
		@highlightRectangle.strokeColor = g.selectionBlue
		@highlightRectangle.dashArray = [4, 10]
		@group?.addChild(@highlightRectangle)
		return

	# common to all RItems
	# hide highlight rectangle
	unhighlight: ()->
		if not @highlightRectangle? then return
		@highlightRectangle.remove()
		@highlightRectangle = null
		return

	# update the z index (i.e. move the item to the right position)
	# - RItems are kept sorted by z-index in *g.sortedPaths* and *g.sortedDivs*
	# - z-index are initialized to the current date (this is a way to provide a global z index even with RItems which are not loaded)
	updateZIndex: ()->
		if not @date? then return

		if @sortedItems.length==0 
			@sortedItems.push(@)
			return

		#insert item at the right place
		found = false
		for item, i in @sortedItems
			if @date < item.date
				@insertBelow(item, i)
				found = true
				break

		if not found then @insertAbove(@sortedItems.last())

		return

	# insert above given *item*
	# @param item [RItem] item on which to insert this
	# @param index [Number] the index at which to add the item in @sortedItems
	insertAbove: (item, index=null, update=false)->
		@group.insertAbove(item.group)
		if not index
			@sortedItems.remove(@)
			index = @sortedItems.indexOf(item) + 1
		@sortedItems.splice(index, 0, @)
		@liJ.insertBefore(item.liJ)
		if update
			if not @sortedItems[index+1]?
				@date = Date.now()
			else
				previousDate = @sortedItems[index-1].date
				nextDate = @sortedItems[index+1].date
				@date = (previousDate + nextDate) / 2
			@update('z-index')
		@setZindexLabel()
		return

	# insert below given *item*
	# @param item [RItem] item under which to insert this
	# @param index [Number] the index at which to add the item in @sortedItems
	insertBelow: (item, index=null, update=false)->
		@group.insertBelow(item.group)
		if not index
			@sortedItems.remove(@)
			index = @sortedItems.indexOf(item)
		@sortedItems.splice(index, 0, @)
		@liJ.insertAfter(item.liJ)
		if update
			if not @sortedItems[index-1]?
				@date = @sortedItems[index+1].date - 1000
			else
				previousDate = @sortedItems[index-1].date
				nextDate = @sortedItems[index+1].date
				@date = (previousDate + nextDate) / 2
			@update('z-index')
		@setZindexLabel()
		return

	setPK: (pk)->
		super(pk)
		@liJ?.attr("data-pk", @pk)
		return

	# select the RItem: (only if it has no selection rectangle i.e. not already selected)
	# - update the selection rectangle, 
	# - (optionally) update controller in the gui accordingly
	# @param updateOptions [Boolean] whether to update controllers in gui or not
	# @return whether the ritem was selected or not
	select: (updateOptions=true)->
		if not super(updateOptions) then return false

		@liJ.addClass('selected')

		# update the global selection group (i.e. add this RPath to the group)
		if @group.parent != g.selectionLayer then @zindex = @group.index
		g.selectionLayer.addChild(@group)

		return true

	deselect: ()->
		if not super() then return false
		
		@liJ.removeClass('selected')

		if not @lock
			g.mainLayer.insertChild(@zindex, @group)
		else
			@lock.group.insertChild(@zindex, @group)

		return true

	remove: ()->
		super()
		@sortedItems?.remove(@)
		@liJ?.remove()
		return
	
	update: ()->
		return

@RContent = RContent
