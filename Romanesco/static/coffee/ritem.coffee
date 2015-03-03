

class RItem

	@indexToName =
		0: 'bottomLeft'
		1: 'left'
		2: 'topLeft'
		3: 'top'
		5: 'top'
		6: 'topRight'
		7: 'right'
		8: 'bottomRight'
		9: 'bottom'

	@oppositeName = 
		'top': 'bottom'
		'bottom': 'top'
		'left': 'right'
		'right': 'left'
		'topLeft': 'bottomRight'
		'topRight':  'bottomLeft'
		'bottomRight':  'topLeft'
		'bottomLeft':  'topRight'

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

	constructor: (itemList, @sortedItems)->
		if RLock.prototype.isPrototypeOf(@) then return
		@liJ = $("<li>").text(@constructor.rname)
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
		itemList.append(@liJ)
		$("#Items .mCustomScrollbar").mCustomScrollbar("scrollTo", "bottom")

		@rectangle = null
		@rotation = 0

		@selectionState = null
		@selectionRectangle = null

		@group = new Group()
		@group.name = "group"
		@group.controller = @
		return

	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #

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
	# @param userAction [Boolean] (optional) whether this is an action from *g.me* or another user 
	initSelection: (event, hitResult, userAction=true) ->
		@selectionState = move: true

		if not hitResult? then return

		if hitResult.type == 'segment'
			if hitResult.item == @selectionRectangle 			# if the segment belongs to the selection rectangle: initialize rotation or scaling
				@selectionState = {}
				if hitResult.segment.index == 4
					@selectionState = rotation: true
				else
					@selectionState = scale: { index: hitResult.segment.index }
		return

	# begin select action:
	# - initialize selection (reset selection state)
	# - select if *userAction*
	# - hit test and initialize selection
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	selectBegin: (event, userAction=true) ->
		
		# initialize selection (reset selection state)
		@changed = null
		@selectionState = null

		if userAction
			if not @isSelected() then g.commandManager.add(new SelectCommand([@], true))

			hitResult = @performHitTest(event.point, @constructor.hitOptions)
			@initSelection(event, hitResult, userAction)
			
			if @selectionState.move?
				@selectCommand = new MoveCommand(@, @getPosition(), @getPosition(), false)
			else if @selectionState.scale?
				@selectCommand = new ScaleCommand(@)
			else if @selectionState.rotation?
				@selectCommand = new RotationCommand(@)

		return

	# depending on the selected item, selectUpdate will:
	# - rotate the group,
	# - scale the group,
	# - or move the group.
	# @param event [Paper event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user
	selectUpdate: (event, userAction=true)->

		if @selectionState?
			if @selectionState.rotation?					# rotate the group
				currentDirection = new Point( length: 1, angle: @rotation - 90 )
				newDirection = event.point.subtract(@selectionRectangle.pivot)
				delta = currentDirection.getDirectedAngle(newDirection)
				@setRotation(@rotation+delta, true)
			else if @selectionState.scale?						# scale the group
				rectangle = @rectangle.clone()
				delta = event.point.subtract(@rectangle.center)
				x = new Point(1,0)
				x.angle += @rotation
				dx = x.dot(delta)
				y = new Point(0,1)
				y.angle += @rotation
				dy = y.dot(delta)

				index = @selectionState.scale.index

				# if shift is not pressed and a corner is selected: keep aspect ratio (rectangle must have width and height greater than 0 to keep aspect ratio)
				if not event.modifiers.shift and index in [0, 2, 6, 8] and rectangle.width > 0 and rectangle.height > 0
					if Math.abs(dx / rectangle.width) > Math.abs(dy / rectangle.height)
						dx = g.sign(dx) * Math.abs(rectangle.width * dy / rectangle.height)
					else
						dy = g.sign(dy) * Math.abs(rectangle.height * dx / rectangle.width)

				name = @constructor.indexToName[index]
				center = rectangle.center.clone()
				rectangle[name] = @constructor.valueFromName(center.add(dx, dy), name)

				if not g.specialKey(event) 
					rectangle[@constructor.oppositeName[name]] = @constructor.valueFromName(center.subtract(dx, dy), name)
				else
					# the center of the rectangle changes when moving only one side
					# the center must be repositionned with the previous center as pivot point (necessary when rotation > 0)
					rectangle.center = center.add(rectangle.center.subtract(center).rotate(@rotation))

				if rectangle.width < 0
					rectangle.width = Math.abs(rectangle.width)
					rectangle.center.x = center.x
				if rectangle.height < 0
					rectangle.height = Math.abs(rectangle.height)
					rectangle.center.y = center.y

				@setRectangle(rectangle, true)
			else if @selectionState.move?									# move the group
				@rectangle.x += event.delta.x
				@rectangle.y += event.delta.y
				@group.position.x += event.delta.x
				@group.position.y += event.delta.y
				@changed = 'moved'

		return

	# end the selection action:
	# - nullify selectionState
	# - redraw in normal mode (not fast mode)
	# - update select command
	selectEnd: (event, userAction=true)->
		
		if @changed?
			
			@selectCommand.update()
			g.commandManager.add(@selectCommand)
			@selectCommand = null
			
			@update('rectangle')
			
		@changed = null

		return

	# create the selection rectangle (path used to rotate and scale the RPath)
	# @param bounds [Paper Rectangle] the bounds of the selection rectangle
	createSelectionRectangle: (bounds)->
		
		# create the selection rectangle: rectangle path + handle at the top used for rotations
		@selectionRectangle?.remove()
		@selectionRectangle = new Path.Rectangle(bounds)
		@group.addChild(@selectionRectangle)
		@selectionRectangle.name = "selection rectangle"
		@selectionRectangle.pivot = bounds.center
		@selectionRectangle.insert(1, new Point(bounds.left, bounds.center.y))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top-25))
		@selectionRectangle.insert(3, new Point(bounds.center.x, bounds.top))
		@selectionRectangle.insert(7, new Point(bounds.right, bounds.center.y))
		@selectionRectangle.insert(9, new Point(bounds.center.x, bounds.bottom))
		@selectionRectangle.selected = true
		@selectionRectangle.controller = @
		
		return

	# add or update the selection rectangle (path used to rotate and scale the RPath)
	# redefined by RShape# the selection rectangle is slightly different for a shape since it is never reset (rotation and scale are stored in database)
	updateSelectionRectangle: ()->
		bounds = @rectangle.clone().expand(10)
		@createSelectionRectangle(bounds)
		@selectionRectangle.rotation = @rotation
		return

	setRectangle: (rectangle)->
		@rectangle = rectangle
		@updateSelectionRectangle()
		return

	setRotation: (rotation)->
		@rotation = rotation
		@selectionRectangle.rotation = rotation
		return

	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #
	# ------------- #

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
		topLeft = @rectangle.topLeft.subtract(@rectangle.center)
		topLeft.angle += @rotation
		bottomRight = @rectangle.bottomRight.subtract(@rectangle.center)
		bottomRight.angle += @rotation
		bottomLeft = @rectangle.bottomLeft.subtract(@rectangle.center)
		bottomLeft.angle += @rotation
		topRight = @rectangle.topRight.subtract(@rectangle.center)
		topRight.angle += @rotation
		bounds = new Rectangle(topLeft, bottomRight)
		bounds = bounds.include(bottomLeft)
		bounds = bounds.include(topRight)
		return bounds

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
		return

	# insert below given *item*
	# @param item [RItem] item under which to insert this
	# @param index [Number] the index at which to add the item in @sortedItems
	insertBelow: (item, index=null, update=false)->
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
		return

	setPK: ()->
		@liJ?.attr("data-pk", @pk)
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
		@liJ?.addClass('selected')

		if @selectionRectangle? then return false

		# create or update the selection rectangle
		@selectionState = null
		@updateSelectionRectangle(true)

		# create or update the global selection group
		if updateOptions then g.updateParameters( { tool: @constructor, item: @ } , true)

		g.s = @
		return true

	deselect: ()->
		@liJ?.removeClass('selected')

		if not @selectionRectangle? then return false
		
		if not @lock
			g.mainLayer.insertChild(@zindex, @group)
		else
			@lock.group.insertChild(@zindex, @group)

		@selectionRectangle?.remove()
		@selectionRectangle = null
	
		return

	remove: ()->
		@sortedItems?.remove(@)
		@highlightRectangle?.remove()
		@liJ?.remove()
		return

@RItem = RItem