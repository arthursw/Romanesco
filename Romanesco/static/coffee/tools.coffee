define [
	'utils', 'zeroClipboard', 'item', 'lock', 'div', 'path', 'jquery', 'paper', 'bootstrap'
], (utils, ZeroClipboard) ->

	g = utils.g()

	# todo: replace update by drag

	# An RTool can be selected from the sidebar, or with special shortcuts.
	# once selected, a tool will usually react to user events (mouse and keyboard events)

	# Here are all types of tools:
	# - MoveTool to scroll the view in the project space
	# - SelectTool to select RItems
	# - TextTool to add RText (editable text box)
	# - MediaTool to add RMedia (can be an image, video, shadertoy, or anything embeddable)
	# - LockTool to add RLock (a locked area)
	# - CodeTool to open code editor and create a script
	# - ScreenshotTool to take a screenshot
	# - CarTool to have a car and travel in the world with arrow key (and play video games)
	# - PathTool the mother class of all drawing tools

	# The mother class of all RTools
	class RTool

		# parameters must return an object listing all parameters specific to the tool
		# those parameters will be accessible to the users from the options bar
		###
		parameters =
			'First folder':
				firstParameter:
					type: 'slider' 									# type is only required when adding a color (then it must be 'color') or a string input (then it must be 'string')
																	# if type is 'string' and there is no onChange nor onFinishChange callback:
																	# the default onChange callback will be called on onFinishChange since we often want to update only when the change is finished
																	# to override this behaviour, 'fireOnEveryChange' can be set to true or onChange and onFinishChange can be defined
					label: 'Name of the parameter'					# label of the controller (name displayed in the gui)
					value: 0										# value (deprecated)
					default: 0 										# default value
					step: 5 										# values will be incremented/decremented by step
					min: 0 											# minimum value
					max: 100 										# maximum value
					simplified: 0 									# value during the simplified mode (useful to quickly draw an RPath, for example when modifying a curve)
					defaultFunction: () -> 							# called to get a default value
					addController: true 							# if true: adds the dat.gui controller to the item or the selected tool
					onChange: (value)->  							# called when controller changes
					onFinishChange: (value)-> 						# called when controller finishes change
					setValue: (value, item)-> 						# called on set value of controller
					permanent: true									# if true: the controller is never removed (always says in dat.gui)
					defaultCheck: true 								# checked/activated by default or not
					initializeController: (controller, item)->		# called just after controller is added to dat.gui, enables to customize the gui and add functionalities
					fireOnEveryChange: false 						# if true and *type* is input: the default onChange callback will be called on everychange
				secondParameter:
					type: 'slider'
					label: 'Second parameter'
					value: 1
					min: 0
					max: 10
			'Second folder':
				thirdParameter:
					type: 'slider'
					label: 'Third parameter'
					value: 1
					min: 0
					max: 10
		###
		# to be overloaded by children classes, must return the parameters to display when the tool is selected
		@parameters: ()->
			return {}

		# RTool constructor:
		# - find the corresponding button in the sidebar: look for a <li> tag with an attribute 'data-name' equal to @name
		# - add a click handler to select the tool and extract the cursor name from the attribute 'data-cursor'
		# - initialize the popover (help tooltip)
		constructor: (@name, @cursorPosition = { x: 0, y: 0 }, @cursorDefault="default") ->
			g.tools[@name] = @

			# find or create the corresponding button in the sidebar
			@btnJ ?= g.toolsJ.find('li[data-name="'+@name+'"]')

			@cursorName = @btnJ.attr("data-cursor")
			@btnJ.click( () => @select() )

			# initialize the popover (help tooltip)
			popoverOptions =
				placement: 'right'
				container: 'body'
				trigger: 'hover'
				delay:
					show: 500
					hide: 100

			description = @description()
			if not description?
				popoverOptions.content = @name
			else
				popoverOptions.title = @name
				popoverOptions.content = description

			@btnJ.popover( popoverOptions )
			return

		# @return [string] the description of the tool
		description: ()->
			return null

		# Select the tool:
		# - deselect selected tool
		# - deselect all RItems (if deselectItems)
		# - update cursor
		# - update parameters
		# @param [RTool constructor] the constructor used to update gui parameters (@constructor.parameters)
		# @param [RItem] selected item to update gui parameters
		# @param [Boolean] deselected selected items (false when selecting MoveTool or SelectTool)
		select: (constructor=@constructor, selectedItem=null, deselectItems=true)->
			# check if new tool is defferent from previous
			differentTool = g.previousTool != g.selectedTool

			if @ != g.selectedTool
				g.previousTool = g.selectedTool

			g.selectedTool?.deselect()
			g.selectedTool = @


			if @cursorName?
				g.stageJ.css('cursor', 'url(static/images/cursors/'+@cursorName+'.png) '+@cursorPosition.x+' '+@cursorPosition.y+','+@cursorDefault)
			else
				g.stageJ.css('cursor', @cursorDefault)

			if deselectItems
				g.deselectAll()

			g.cancelCallNextFrame('updateParametersForSelectedItems')
			g.updateParameters({ tool: constructor, item: selectedItem }, differentTool)
			return

		# Deselect current tool
		deselect: ()->
			return

		# Begin tool action (usually called on mouse down event)
		begin: (event) ->
			return

		# Update tool action (usually called on mouse drag event)
		update: (event) ->
			return

		# Move tool action (usually called on mouse move event)
		move: (event) ->
			return

		# End tool action (usually called on mouse up event)
		end: (event) ->
			return

		# @return [Boolean] whether snap should be disabled when this tool is  selected or not
		disableSnap: ()->
			return false

	g.RTool = RTool

	# CodeTool is just used as a button to open the code editor, the remaining code is in editor.coffee
	class CodeTool extends RTool

		constructor: ()->
			super("Script")
			return

		# show code editor on select
		select: ()->
			super()
			g.showEditor()
			return

	g.CodeTool = CodeTool

	# --- Move & select tools --- #

	# MoveTool to scroll the view in the project space
	class MoveTool extends RTool

		constructor: () ->
			super("Move", { x: 32, y: 32 }, "move")
			@prevPoint = { x: 0, y: 0 } 	# the previous point the mouse was at
			@dragging = false 				# a boolean to see if user is dragging mouse
			return

		# Select tool and disable RDiv interactions (to be able to scroll even when user clicks on them, for exmaple disable textarea default behaviour)
		select: ()->
			super(@constructor, null, false)
			g.stageJ.addClass("moveTool")
			for div in g.divs
				div.disableInteraction()
			return

		# Reactivate RDiv interactions
		deselect: ()->
			super()
			g.stageJ.removeClass("moveTool")
			for div in g.divs
				div.enableInteraction()
			return

		begin: (event) ->
			# @dragging = true
			return

		update: (event) ->
			# if @dragging
			# 	g.RMoveBy(event.delta)
			return

		end: (moved) ->
			# if moved
			# 	g.commandManager.add(new MoveViewCommand())
			# @dragging = false
			return

		# begin with jQuery event
		# note: we could use g.eventToObject to convert the Native event into Paper.ToolEvent, however onMouseDown/Drag/Up also fire begin/update/end
		beginNative: (event) ->
			@dragging = true
			@initialPosition = { x: event.pageX, y: event.pageY }
			@prevPoint = { x: event.pageX, y: event.pageY }
			return

		# update with jQuery event
		updateNative: (event) ->
			if @dragging
				g.RMoveBy({ x: (@prevPoint.x-event.pageX)/view.zoom, y: (@prevPoint.y-event.pageY)/view.zoom })
				@prevPoint = { x: event.pageX, y: event.pageY }
			return

		# end with jQuery event
		endNative: (event) ->
			# if @initialPosition? and ( @initialPosition.x != event.pageX or @initialPosition.y != event.pageY )
			# 	g.commandManager.add(new MoveViewCommand())
			@dragging = false
			return

	g.MoveTool = MoveTool

	# CarTool gives a car to travel in the world with arrow key (and play video games)
	class CarTool extends RTool

		@parameters: ()->
			parameters =
				'Car':
					speed: 							# the speed of the car, just used as an indicator. Updated in @onFrame
						type: 'string'
						label: 'Speed'
						value: '0'
						addController: true
						onChange: ()-> return 		# disable the default callback
					volume: 						# volume of the car sound
						type: 'slider'
						label: 'Volume'
						value: 1
						min: 0
						max: 10
						onChange: (value)-> 		# set volume of the car, stop the sound if volume==0 and restart otherwise
							if g.selectedTool.constructor.name == "CarTool"
								if value>0
									if not g.sound.isPlaying
										g.sound.play()
										g.sound.setLoopStart(3.26)
										g.sound.setLoopEnd(5.22)
									g.sound.setVolume(0.1*value)
								else
									g.sound.stop()
							return
			return parameters

		constructor: () ->
			super("Car") 		# no cursor when car is selected (might change)
			return

		# Select car tool
		# load the car image, and initialize the car and the sound
		select: ()->
			super()

			# create Paper raster and initialize car parameters
			@car = new Raster("/static/images/car.png")
			g.carLayer.addChild(@car)
			@car.position = view.center
			@speed = 0
			@direction = new Point(0, -1)
			@car.onLoad = ()->
				console.log 'car loaded'
				return

			@previousSpeed = 0

			# initialize sound
			g.sound.setVolume(0.1)
			g.sound.play(0)
			g.sound.setLoopStart(3.26)
			g.sound.setLoopEnd(5.22)

			@lastUpdate = Date.now()

			return

		# Deselect tool: remove car and stop sound
		deselect: ()->
			super()
			@car.remove()
			@car = null
			g.sound.stop()
			return

		# on frame event:
		# - update car position, speed and direction according to user inputs
		# - update sound rate
		onFrame: ()->
			if not @car? then return

			# update car position, speed and direction according to user inputs
			minSpeed = 0.05
			maxSpeed = 100

			if Key.isDown('right')
				@direction.angle += 5
			if Key.isDown('left')
				@direction.angle -= 5
			if Key.isDown('up')
				if @speed<maxSpeed then @speed++
			else if Key.isDown('down')
				if @speed>-maxSpeed then @speed--
			else
				@speed *= 0.9
				if Math.abs(@speed) < minSpeed
					@speed = 0

			# update sound rate
			minRate = 0.25
			maxRate = 3
			rate = minRate+Math.abs(@speed)/maxSpeed*(maxRate-minRate)
			# console.log rate
			g.sound.setRate(rate)

			# acc = @speed-@previousSpeed

			# if @speed > 0 and @speed < maxSpeed
			# 	if acc > 0 and not g.sound.plays('acc')
			# 		console.log 'acc'
			# 		g.sound.playAt('acc', Math.abs(@speed/maxSpeed))
			# 	else if acc < 0 and not g.sound.plays('dec')
			# 		console.log 'dec:' + g.sound.pos()
			# 		g.sound.playAt('dec', 0) #1.0-Math.abs(@speed/maxSpeed))
			# else if Math.abs(@speed) == maxSpeed and not g.sound.plays('max')
			# 	console.log 'max'
			# 	g.sound.stop()
			# 	g.sound.spriteName = 'max'
			# 	g.sound.play('max')
			# else if @speed == 0 and not g.sound.plays('idle')
			# 	console.log 'idle'
			# 	g.sound.stop()
			# 	g.sound.spriteName = 'idle'
			# 	g.sound.play('idle')
			# else if @speed < 0 and Math.abs(@speed) < maxSpeed
			# 	if acc < 0 and not g.sound.plays('acc')
			# 		console.log '-acc'
			# 		g.sound.playAt('acc', Math.abs(@speed/maxSpeed))
			# 	else if acc > 0 and not g.sound.plays('dec')
			# 		console.log '-dec'
			# 		g.sound.playAt('dec', 1.0-Math.abs(@speed/maxSpeed))

			@previousSpeed = @speed

			@parameterControllers?['speed']?.setValue(@speed.toFixed(2))

			@car.rotation = @direction.angle+90

			if Math.abs(@speed) > minSpeed
				@car.position = @car.position.add(@direction.multiply(@speed))
				g.RMoveTo(@car.position)

			g.gameAt(@car.position)?.updateGame(@)

			if Date.now()-@lastUpdate>150 			# emit car position every 150 milliseconds
				if g.me? then g.chatSocket.emit "car move", g.me, @car.position, @car.rotation, @speed
				@lastUpdate = Date.now()

			#project.view.center = @car.position
			return

	g.CarTool = CarTool

	# Enables to select RItems
	class SelectTool extends RTool

		# Paper hitOptions for hitTest function to check which items (corresponding to those criterias) are under a point
		hitOptions =
			stroke: true
			fill: true
			handles: true
			segments: true
			curves: true
			selected: true
			tolerance: 5

		constructor: () ->
			super("Select")
			@selectedItem = null 		# should be deprecated
			return

		select: ()->
			g.rasterizer.drawItems()
			@selectedItem = g.selectedItems.first()
			super(@selectedItem?.constructor or @constructor, @selectedItem, false)
			return

		# Create selection rectangle path (remove if existed)
		# @param [Paper event] event containing down and current positions to draw the rectangle
		createSelectionRectangle: (event)->
			rectangle = new Rectangle(event.downPoint, event.point)

			if g.currentPaths[g.me]?
				g.updatePathRectangle(g.currentPaths[g.me], rectangle)
			else
				# g.currentPaths[g.me] = new Group()
				rectanglePath = new Path.Rectangle(rectangle)
				rectanglePath.name = 'select tool selection rectangle'
				rectanglePath.strokeColor = g.selectionBlue
				rectanglePath.strokeScaling = false
				rectanglePath.dashArray = [10, 4]
				# g.currentPaths[g.me].addChild(rectanglePath)

				g.selectionLayer.addChild(rectanglePath)
				g.currentPaths[g.me] = rectanglePath

			itemsToHighlight = []

			# Add all items which have bounds intersecting with the selection rectangle (1st version)
			for name, item of g.items
				item.unhighlight()
				bounds = item.getBounds()
				if bounds.intersects(rectangle)
					item.highlight()
					console.log item.highlightRectangle.index
					# rectanglePath = new Path.Rectangle(bounds)
					# rectanglePath.name = 'select tool selection rectangle highlight'
					# rectanglePath.strokeColor = 'red'
					# rectanglePath.dashArray = [10, 4]
					# g.currentPaths[g.me].addChild(rectanglePath)
				# if the user just clicked (not dragged a selection rectangle): just select the first item
				if rectangle.area == 0
					break
			return

		# Begin selection:
		# - perform hit test to see if there is any item under the mouse
		# - if user hits a path (not in selection group): begin select action (deselect other items by default (= remove selection group), or add to selection if shift pressed)
		# - otherwise: deselect other items (= remove selection group) and create selection rectangle
		# must be reshaped (right not impossible to add a group of RItems to the current selection group)
		begin: (event) ->
			if event.event.which == 2 then return 		# if the wheel button was clicked: return

			console.log 'begin select'
			g.logElapsedTime()

			# perform hit test to see if there is any item under the mouse
			path.prepareHitTest() for name, path of g.paths
			hitResult = g.project.hitTest(event.point, hitOptions)
			path.finishHitTest() for name, path of g.paths


			if hitResult and hitResult.item.controller? 		# if user hits a path: select it
				@selectedItem = hitResult.item.controller

				if not event.modifiers.shift 	# if shift is not pressed: deselect previous items
					if g.selectedItems.length>0
						if g.selectedItems.indexOf(hitResult.item?.controller)<0
							g.commandManager.add(new g.DeselectCommand(), true)
					# else
					# 	if g.selectedDivs.length>0 then g.deselectAll()

				hitResult.item.controller.beginSelect?(event)
			else 												# otherwise: remove selection group and create selection rectangle
				g.deselectAll()
				@createSelectionRectangle(event)

			g.logElapsedTime()

			return

		# Update selection:
		# - update selected RItems if there is no selection rectangle
		# - update selection rectangle if there is one
		update: (event) ->
			if not g.currentPaths[g.me] 			# update selected RItems if there is no selection rectangle
				@selectedItem.updateSelect(event)
				# selectedItems = g.selectedItems
				# if selectedItems.length == 1
				# 	selectedItems[0].updateSelect(event)
				# else
				# 	for item in selectedItems
				# 		item.updateMoveBy?(event)
			else 									# update selection rectangle if there is one
				@createSelectionRectangle(event)
			return

		# End selection:
		# - end selection action on selected RItems if there is no selection rectangle
		# - create selection group is there is a selection rectangle
		#   update parameters from selected RItems and remove selection rectangle
		end: (event) ->
			if not g.currentPaths[g.me] 		# end selection action on selected RItems if there is no selection rectangle
				# selectedItems = g.selectedItems
				# if selectedItems.length == 1
				@selectedItem.endSelect(event)
				@selectedItem = null
			else 								# create selection group is there is a selection rectangle

				rectangle = new Rectangle(event.downPoint, event.point)

				itemsToSelect = []
				locksToSelect = []

				# Add all items which have bounds intersecting with the selection rectangle (1st version)
				for name, item of g.items
					if item.getBounds().intersects(rectangle)
						if g.RLock.prototype.isPrototypeOf(item)
							locksToSelect.push(item)
						else
							itemsToSelect.push(item)

				if itemsToSelect.length == 0
					itemsToSelect = locksToSelect

				if itemsToSelect.length > 0

					# check if items all have the same parent
					itemsAreSiblings = true
					parent = itemsToSelect.first().group.parent
					for item in itemsToSelect
						if item.group.parent != parent
							itemsAreSiblings = false
							break

					# if items have different parents, remove children from itemsToSelect and add locks
					if not itemsAreSiblings
						# remove all lock children from itemsToSelect
						for lock in locksToSelect
							for child in lock.children()
								itemsToSelect.remove(child)

						# add locks to itemsToSelect
						itemsToSelect = itemsToSelect.concat(locksToSelect)

					# if the user just clicked (not dragged a selection rectangle): just select the first item
					if rectangle.area == 0 then itemsToSelect = [itemsToSelect.first()]

					g.commandManager.add(new g.SelectCommand(itemsToSelect), true)

					i = itemsToSelect.length-1
					while i>=0
						item = itemsToSelect[i]
						if not item.isSelected()
							itemsToSelect.remove(item)
						i--

				# Add all items which intersect with the selection rectangle (2nd version)

				# for item in project.activeLayer.children
				# 	bounds = item.bounds
				# 	if item.controller? and (rectangle.contains(bounds) or ( rectangle.intersects(bounds) and item.controller.controlPath?.getIntersections(g.currentPaths[g.me]).length>0 ))
				# 	# if item.controller? and rectangle.intersects(bounds)
				# 		g.pushIfAbsent(itemsToSelect, item.controller)

				# for item in itemsToSelect
				# 	item.select(false)

				# # update parameters
				# itemsToSelect = itemsToSelect.map( (item)-> return { tool: item.constructor, item: item } )
				# g.updateParameters(itemsToSelect)

				# for div in g.divs
				# 	if div.getBounds().intersects(rectangle)
				# 		div.select()

				# remove selection rectangle
				g.currentPaths[g.me].remove()
				delete g.currentPaths[g.me]
				for name, item of g.items
					item.unhighlight()

			console.log 'end select'
			g.logElapsedTime()
			return

		# Double click handler: send event to selected RItems
		doubleClick: (event) ->
			for item in g.selectedItems
				item.doubleClick?(event)
			return

		# Disable snap while drawnig a selection rectangle
		disableSnap: ()->
			return g.currentPaths[g.me]?

	g.SelectTool = SelectTool


	# --- Path tool --- #

	# PathTool: the mother class of all drawing tools
	# doctodo: Path are created with three steps:
	# - begin: initialize RPath: create the group, controlPath etc., and initialize the drawing
	# - update: update the drawing
	# - end: finish the drawing and finish RPath initialization
	# doctodo: explain polygon mode
	# begin, update, and end handlers are called by onMouseDown handler (then from == g.me, data == null) and by socket.on "begin" signal (then from == author of the signal, data == RItem initial data)
	# begin, update, and end handlers emit the events to websocket
	class PathTool extends RTool

		# Find or create a button for the tool in the sidebar (if the button is created, add it default or favorite tool list depending on the user settings stored in local storage, and whether the tool was just created in a newly created script)
		# set its name and icon if an icon url is provided, or create an icon with the letters of the name otherwise
		# the icon will be made with the first two letters of the name if the name is in one word, or the first letter of each words of the name otherwise
		# @param [RPath constructor] the RPath which will be created by this tool
		# @param [Boolean] whether the tool was just created (with the code editor) or not
		constructor: (@RPath, justCreated=false) ->
			@name = @RPath.rname

			# delete tool if it already exists (when user creates a tool)
			if justCreated and g.tools[@name]?
				g[@RPath.constructor.name] = @RPath
				g.tools[@name].remove()
				delete g.tools[@name]
				g.lastPathCreated = @RPath

			# check if a button already exists (when created fom a module)
			@btnJ = g.allToolsJ.find('li[data-name="'+@name+'"]')

			if @btnJ.length==0
				favorite = justCreated or g.favoriteTools?.indexOf(@name)>=0
				@btnJ = g.createToolButton(@name, @RPath.iconURL, favorite, @RPath.category)
			else
				@btnJ.off("click")

			# must remove the icon of precise path otherwise all children class will inherit the same icon
			if @name == 'Precise path' then @RPath.iconURL = null

			super(@RPath.rname, @RPath.cursorPosition, @RPath.cursorDefault, @RPath.options)

			if justCreated
				@select()

			return

		# @return [String] tool description
		description: ()->
			return @RPath.rdescription

		# Remove tool button, useful when user create a tool which already existed (overwrite the tool)
		remove: () ->
			@btnJ.remove()
			return

		# Select: add the mouse move listener on the tool (userful when creating a path in polygon mode)
		# todo: move this to main, have a global onMouseMove handler like other handlers
		select: ()->

			g.rasterizer.drawItems()

			super(@RPath)

			g.tool.onMouseMove = (event) ->
				event = g.snap(event)
				g.selectedTool.move(event)
				return
			return

		# Deselect: remove the mouse move listener
		deselect: ()->
			super()
			@finish()
			g.tool.onMouseMove = null
			return

		# Begin path action:
		# - deselect all and create new Path in all case except in polygonMode (add path to g.currentPaths)
		# - emit event on websocket (if user is the author of the event)
		# @param [Paper event or REvent] (usually) mouse down event
		# @param [String] author (username) of the event
		# @param [Object] RItem initial data (strokeWidth, strokeColor, etc.)
		# begin, update, and end handlers are called by onMouseDown handler (then from == g.me, data == null) and by socket.on "begin" signal (then from == author of the signal, data == RItem initial data)
		begin: (event, from=g.me, data=null) ->
			if event.event.which == 2 then return 			# if middle mouse button (wheel) pressed: return

			if 100 * view.zoom < 10
				g.romanesco_alert("You can not draw path at a zoom smaller than 10.", "Info")
				return

			# deselect all and create new Path in all case except in polygonMode
			if not (g.currentPaths[from]? and g.currentPaths[from].data?.polygonMode) 	# if not in polygon mode
				g.deselectAll()
				g.currentPaths[from] = new @RPath(Date.now(), data)
				# g.currentPaths[from].select(false, false)

			g.currentPaths[from].beginCreate(event.point, event, false)

			# emit event on websocket (if user is the author of the event)
			# if g.me? and from==g.me then g.chatSocket.emit( "begin", g.me, g.eventToObject(event), @name, g.currentPaths[from].data )

			if g.me? and from==g.me
				data = g.currentPaths[from].data
				data.id = g.currentPaths[from].id
				g.chatSocket.emit "bounce", tool: @name, function: "begin", arguments: [event, g.me, data]
			return

		# Update path action:
		# update path action and emit event on websocket (if user is the author of the event)
		# @param [Paper event or REvent] (usually) mouse drag event
		# @param [String] author (username) of the event
		update: (event, from=g.me) ->
			g.currentPaths[from].updateCreate(event.point, event, false)
			# g.currentPaths[from].group.visible = true
			# if g.me? and from==g.me then g.chatSocket.emit( "update", g.me, g.eventToObject(event), @name)
			if g.me? and from==g.me then g.chatSocket.emit "bounce", tool: @name, function: "update", arguments: [event, g.me]
			return

		# Update path action (usually from a mouse move event, necessary for the polygon mode):
		# @param [Paper event or REvent] (usually) mouse move event
		move: (event) ->
			if g.currentPaths[g.me]?.data?.polygonMode then g.currentPaths[g.me].createMove?(event)
			return

		createPath: (event, from)->
			path = g.currentPaths[from]

			if g.me? and from==g.me 						# if user is the author of the event: select and save path and emit event on websocket

				if path.rectangle.area == 0
					path.remove()
					delete g.currentPaths[from]
					return

				bounds = path.getBounds()
				locks = g.RLock.getLocksWhichIntersect(bounds)
				for lock in locks
					if lock.rectangle.contains(bounds)
						if lock.owner == g.me
							lock.addItem(path)
						else
							g.romanesco_alert("The path intersects with a lock", "Warning")
							path.remove()
							delete g.currentPaths[from]
							return
				if path.getDrawingBounds().area > g.rasterizer.maxArea()
					g.romanesco_alert("The path is too big", "Warning")
					path.remove()
					delete g.currentPaths[from]
					return

				if g.me? and from==g.me then g.chatSocket.emit "bounce", tool: @name, function: "createPath", arguments: [event, g.me]

				path.save(true)
				path.select(false)
			else
				path.endCreate(event.point, event)
			delete g.currentPaths[from]
			return

		# End path action:
		# - end path action
		# - if not in polygon mode: select and save path and emit event on websocket (if user is the author of the event), (remove path from g.currentPaths)
		# @param [Paper event or REvent] (usually) mouse up event
		# @param [String] author (username) of the event
		end: (event, from=g.me) ->
			path = g.currentPaths[from]

			if not path.data?.polygonMode
				path.endCreate(event.point, event, false)
				@createPath(event, from)
			else
				path.endCreate(event.point, event, false)
			return

		# Finish path action (necessary in polygon mode):
		# - check that we are in polygon mode (return otherwise)
		# - end path action
		# - select and save path and emit event on websocket (if user is the author of the event), (remove path from g.currentPaths)
		# @param [String] author (username) of the event
		finish: (from=g.me)->
			if not g.currentPaths[g.me]?.data?.polygonMode then return false
			g.currentPaths[from].finish()
			@createPath(event, from)
			return true

	g.PathTool = PathTool

	# --- Link & lock tools --- #

	# ItemTool: mother class of all RDiv creation tools (this will create a new div on top of the canvas, with custom content, and often resizable)
	# User will create a selection rectangle
	# once the mouse is released, the box will be validated by RDiv.end() (check that the RDiv does not overlap two planets, and does not intersects with an RLock)
	# children classes will use RDiv.end() to check if it is valid and:
	# - initialize a modal to ask the user more info about the RDiv
	# - or directly save the RDiv
	# the RDiv will be created on server response
	# begin, update, and end handlers are called by onMouseDown handler (then from == g.me, data == null) and by socket.on "begin" signal (then from == author of the signal, data == RItem initial data)
	# begin, update, and end handlers emit the events to websocket
	class ItemTool extends RTool

		constructor: (@name, @RItem) ->
			super(@name, { x: 24, y: 0 }, "crosshair")
			# test: @isDiv = true
			return

		select: ()->
			g.rasterizer.drawItems()
			super(@RItem)
			return

		# Begin div action:
		# - create new selection rectangle
		# - emit event on websocket (if user is the author of the event)
		# @param [Paper event or REvent] (usually) mouse down event
		# @param [String] author (username) of the event
		# begin, update, and end handlers are called by onMouseDown handler (then from == g.me, data == null) and by socket.on "begin" signal (then from == author of the signal, data == RItem initial data)
		begin: (event, from=g.me) ->
			point = event.point

			g.deselectAll()

			g.currentPaths[from] = new Path.Rectangle(point, point)
			g.currentPaths[from].name = 'div tool rectangle'
			g.currentPaths[from].dashArray = [4, 10]
			g.currentPaths[from].strokeColor = 'black'
			g.selectionLayer.addChild(g.currentPaths[from])

			# if g.me? and from==g.me then g.chatSocket.emit( "begin", g.me, g.eventToObject(event), @name, g.currentPaths[from].data )
			if g.me? and from==g.me then g.chatSocket.emit "bounce", tool: @name, function: "begin", arguments: [event, g.me, g.currentPaths[from].data]
			return

		# Update div action:
		# - update selection rectangle
		# - emit event on websocket (if user is the author of the event)
		# @param [Paper event or REvent] (usually) mouse down event
		# @param [String] author (username) of the event
		update: (event, from=g.me) ->
			point = event.point

			g.currentPaths[from].segments[2].point = point
			g.currentPaths[from].segments[1].point.x = point.x
			g.currentPaths[from].segments[3].point.y = point.y
			g.currentPaths[from].fillColor = null

			bounds = g.currentPaths[from].bounds
			locks = g.RLock.getLocksWhichIntersect(bounds)
			for lock in locks
				if lock.owner != g.me or (@name != 'Lock' and not lock.rectangle.contains(bounds))
					g.currentPaths[from].fillColor = 'red'

			if g.rectangleOverlapsTwoPlanets(bounds)
				g.currentPaths[from].fillColor = 'red'

			# if g.me? and from==g.me then g.chatSocket.emit( "update", g.me, point, @name )
			if g.me? and from==g.me then g.chatSocket.emit "bounce", tool: @name, function: "update", arguments: [event, g.me]
			return

		# End div action:
		# - remove selection rectangle
		# - check if div if valid (does not overlap two planets, and does not intersects with an RLock), return false otherwise
		# - resize div to 10x10 if area if lower than 100
		# - emit event on websocket (if user is the author of the event)
		# @param [Paper event or REvent] (usually) mouse down event
		# @param [String] author (username) of the event
		end: (event, from=g.me) ->
			if from != g.me 					# if event come from websocket (another user in the room is creating the RDiv): just remove the selection rectangle
				g.currentPaths[from].remove()
				delete g.currentPaths[from]
				return false

			point = event.point

			g.currentPaths[from].remove()

			bounds = g.currentPaths[from].bounds
			locks = g.RLock.getLocksWhichIntersect(bounds)
			for lock in locks
				if lock.owner != g.me or (@name != 'Lock' and not lock.rectangle.contains(bounds))
					g.romanesco_alert 'Your item intersects with a locked area.', 'error'
					return false

			# check if div if valid (does not overlap two planets, and does not intersects with an RLock), return false otherwise
			if g.rectangleOverlapsTwoPlanets(bounds)
				g.romanesco_alert 'Your item overlaps with two planets.', 'error'
				return false

			if g.currentPaths[from].bounds.area < 100 			# resize div to 10x10 if area if lower than 100
				g.currentPaths[from].width = 10
				g.currentPaths[from].height = 10

			# if g.me? and from==g.me then g.chatSocket.emit( "end", g.me, point, @name )
			if g.me? and from==g.me then g.chatSocket.emit "bounce", tool: @name, function: "end", arguments: [event, g.me]

			return true

	g.ItemTool = ItemTool

	# RLock creation tool
	class LockTool extends ItemTool

		constructor: () ->
			super("Lock", g.RLock)
			@textItem = null
			return

		# Update lock action:
		# - display lock cost (in romanescoins) in selection rectangle
		# @param [Paper event or REvent] (usually) mouse move event
		# @param [String] author (username) of the event
		update: (event, from=g.me) ->
			point = event.point

			cost = g.currentPaths[from].bounds.area/1000.0

			@textItem?.remove()
			@textItem = new PointText(point)
			@textItem.justification = 'right'
			@textItem.fillColor = 'black'
			@textItem.content = '' + cost + ' romanescoins'
			super(event, from)
			return

		# End lock action:
		# - remove lock cost and init RLock modal if it is valid (does not overlap two planets, and does not intersects with an RLock)
		# the RLock modal window will ask the user some information about the lock he wants to create, the RLock will be saved once the user submits and created on server response
		# @param [Paper event or REvent] (usually) mouse up event
		# @param [String] author (username) of the event
		end: (event, from=g.me) ->
			@textItem?.remove()
			if super(event, from)
				g.RLock.initialize(g.currentPaths[from].bounds)
				delete g.currentPaths[from]
			return

	g.LockTool = LockTool


	# class LinkTool extends ItemTool

	# 	constructor: () ->
	# 		super("Link", RLink)
	# 		@textItem = null

	# 	update: (event, from=g.me) ->
	# 		point = event.point
	# 		cost = g.currentPaths[from].bounds.area

	# 		@textItem?.remove()
	# 		@textItem = new PointText(point)
	# 		@textItem.justification = 'right'
	# 		@textItem.fillColor = 'black'
	# 		@textItem.content = '' + cost + ' romanescoins'
	# 		super(event, from)


	# 	end: (event, from=g.me) ->
	# 		@textItem?.remove()
	# 		if super(event, from)
	# 			RLink.initModal(g.currentPaths[from].bounds)
	# 			delete g.currentPaths[from]

	# @LinkTool = LinkTool

	# RText creation tool
	class TextTool extends ItemTool

		constructor: () ->
			super("Text", g.RText)
			return

		# End RText action:
		# - save RText if it is valid (does not overlap two planets, and does not intersects with an RLock)
		# the RText will be created on server response
		# @param [Paper event or REvent] (usually) mouse up event
		# @param [String] author (username) of the event
		end: (event, from=g.me) ->
			if super(event, from)
				text = new g.RText(g.currentPaths[from].bounds)
				text.addToParent()
				text.select()
				text.save(true)
				delete g.currentPaths[from]
			return

	g.TextTool = TextTool

	# RMedia creation tool
	class MediaTool extends ItemTool

		constructor: () ->
			super("Media", g.RMedia)
			return

		# End RMedia action:
		# - init RMedia modal if it is valid (does not overlap two planets, and does not intersects with an RLock)
		# the RMedia modal window will ask the user some information about the media he wants to create, the RMedia will be saved once the user submits and created on server response
		# @param [Paper event or REvent] (usually) mouse up event
		# @param [String] author (username) of the event
		end: (event, from=g.me) ->
			if super(event, from)
				g.RMedia.initialize(g.currentPaths[from].bounds)
				delete g.currentPaths[from]
			return

	g.MediaTool = MediaTool

	# todo: ZeroClipboard.destroy()
	# ScreenshotTool to take a screenshot and save it or publish it on different social platforms (facebook, pinterest or twitter)
	# - the user will create a selection rectangle with the mouse
	# - when the user release the mouse, a special (temporary) resizable RDiv (RSelectionRectangle) is created so that the user can adjust the screenshot box to fit his needs (this must be imporved, with better visibility and the possibility to better snap the box to the grid)
	# - once the user adjusted the box, he can take the screenshot by clicking the "Take screenshot" button at the center of the RSelectionRectangle
	# - a modal window asks the user how to exploit the newly created image (copy it, save it, or publish it on facebook, twitter or pinterest)
	class ScreenshotTool extends RTool

		# Initialize screenshot modal (init button click event handlers)
		constructor: () ->
			super('Screenshot', { x: 24, y: 0 }, "crosshair")
			@modalJ = $("#screenshotModal")
			# @modalJ.find('button[name="copy-data-url"]').click( ()=> @copyDataUrl() )
			@modalJ.find('button[name="publish-on-facebook"]').click( ()=> @publishOnFacebook() )
			@modalJ.find('button[name="publish-on-facebook-photo"]').click( ()=> @publishOnFacebookAsPhoto() )
			@modalJ.find('button[name="download-png"]').click( ()=> @downloadPNG() )
			@modalJ.find('button[name="download-svg"]').click( ()=> @downloadSVG() )
			@modalJ.find('button[name="publish-on-pinterest"]').click ()=>@publishOnPinterest()
			@descriptionJ = @modalJ.find('input[name="message"]')
			@descriptionJ.change ()=>
				@modalJ.find('a[name="publish-on-twitter"]').attr("data-text", @getDescription())
				return

			ZeroClipboard.config( swfPath: g.romanescoURL + "static/libs/ZeroClipboard/ZeroClipboard.swf" )
			# ZeroClipboard.destroy()
			return

		# Get description input value, or default description: "Artwork made with Romanesco: http://romanesc.co/#0.0,0.0"
		getDescription: ()->
			return if @descriptionJ.val().length>0 then @descriptionJ.val() else "Artwork made with Romanesco: " + @locationURL

		select: ()->
			super()
			g.rasterizer.drawItems()
			g.rasterizer.clearRasters()
			return

		deselect: ()->
			super()
			g.rasterizer.rasterizeView()
			return

		# create selection rectangle
		begin: (event) ->
			from = g.me
			g.currentPaths[from] = new Path.Rectangle(event.point, event.point)
			g.currentPaths[from].name = 'screenshot tool selection rectangle'
			g.currentPaths[from].dashArray = [4, 10]
			g.currentPaths[from].strokeColor = 'black'
			g.currentPaths[from].strokeWidth = 1
			g.selectionLayer.addChild(g.currentPaths[from])
			return

		# update selection rectangle
		update: (event) ->
			from = g.me
			g.currentPaths[from].lastSegment.point = event.point
			g.currentPaths[from].lastSegment.next.point.y = event.point.y
			g.currentPaths[from].lastSegment.previous.point.x = event.point.x
			return

		# - remove selection rectangle
		# - return if rectangle is too small
		# - create the RSelectionRectangle (so that the user can adjust the screenshot box to fit his needs)
		end: (event) ->
			from = g.me
			# remove selection rectangle
			g.currentPaths[from].remove()
			delete g.currentPaths[from]
			g.view.update()

			# return if rectangle is too small
			r = new Rectangle(event.downPoint, event.point)
			if r.area<100
				return

			@div = new g.RSelectionRectangle(new Rectangle(event.downPoint, event.point), @extractImage)

			return

		# Extract image and initialize & display modal (so that the user can choose what to do with it)
		# todo: use something like [rasterizeHTML.js](http://cburgmer.github.io/rasterizeHTML.js/) to render RDivs in the image
		extractImage: ()=>
			# extract the image (create a temporaty canvas, html5 only, no paper.js)
			@rectangle = @div.getBounds()
			@dataURL = g.areaToImageDataUrl(@rectangle)

			@div.remove()

			@locationURL = g.romanescoURL + location.hash

			@descriptionJ.attr('placeholder', 'Artwork made with Romanesco: ' + @locationURL)
			# initialize modal (data url and image)
			copyDataBtnJ = @modalJ.find('button[name="copy-data-url"]')
			copyDataBtnJ.attr("data-clipboard-text", @dataURL)
			imgJ = @modalJ.find("img.png")
			imgJ.attr("src", @dataURL)
			maxHeight = window.innerHeight - 220
			imgJ.css( 'max-height': maxHeight + "px" )
			@modalJ.find("a.png").attr("href", @dataURL)

			# initialize twitter button
			twitterLinkJ = @modalJ.find('a[name="publish-on-twitter"]')
			twitterLinkJ.empty().text("Publish on Twitter")
			twitterLinkJ.attr "data-url", @locationURL
			twitterScriptJ = $("""<script type="text/javascript">
				window.twttr=(function(d,s,id){var t,js,fjs=d.getElementsByTagName(s)[0];
				if(d.getElementById(id)){return}js=d.createElement(s);
				js.id=id;js.src="https://platform.twitter.com/widgets.js";
				fjs.parentNode.insertBefore(js,fjs);
				return window.twttr||(t={_e:[],ready:function(f){t._e.push(f)}})}(document,"script","twitter-wjs"));
			</script>""")
			twitterLinkJ.append(twitterScriptJ)

			# show modal, and initialize ZeroClipboard once it is on screen (ZeroClipboard enables users to copy the image data in the clipboard)
			@modalJ.modal('show')
			@modalJ.on 'shown.bs.modal', (e)->
				client = new ZeroClipboard( copyDataBtnJ )
				client.on "ready", (readyEvent)->
					console.log "ZeroClipboard SWF is ready!"
					client.on "aftercopy", (event)->
						# `this` === `client`
						# `event.target` === the element that was clicked
						# event.target.style.display = "none"
						g.romanesco_alert("Image data url was successfully copied into the clipboard!", "success")
						this.destroy()
						return
					return
				return
			return

		# copyDataUrl: ()=>
		# 	@modalJ.modal('hide')
		# 	return

		# Some actions require to upload the image on the server
		# makes an ajax request to save the image
		saveImage: (callback)->
			# ajaxPost '/saveImage', {'image': @dataURL } , callback
			Dajaxice.draw.saveImage( callback, {'image': @dataURL } )
			g.romanesco_alert "Your image is being uploaded...", "info"
			return

		# Save image and call publish on facebook callback
		publishOnFacebook: ()=>
			@saveImage(@publishOnFacebookCallback)
			return

		# (Called once the image is uploaded) add a facebook dialog box in which user can add more info and publish the image
		# todo: check if upload was successful?
		publishOnFacebookCallback: (result)=>
			g.romanesco_alert "Your image was successfully uploaded to Romanesco, posting to Facebook...", "info"
			caption = @getDescription()
			FB.ui(
				method: "feed"
				name: "Romanesco"
				caption: caption
				description: ("Romanesco is an infinite collaborative drawing app.")
				link: @locationURL
				picture: g.romanescoURL + result.url
			, (response) ->
				if response and response.post_id
					g.romanesco_alert "Your Post was successfully published!", "success"
				else
					g.romanesco_alert "An error occured. Your post was not published.", "error"
				return
			)

			# @modalJ.modal('hide')

			# imageData = 'data:image/png;base64,'+result.image
			# image = new Image()
			# image.src = imageData
			# g.canvasJ[0].getContext("2d").drawImage(image, 300, 300)

			# # FB.login( () ->
			# # 	if (response.session) {
			# # 		if (response.perms) {
			# # 			# // user is logged in and granted some permissions.
			# # 			# // perms is a comma separated list of granted permissions
			# # 		} else {
			# # 			# // user is logged in, but did not grant any permissions
			# # 		}
			# # 	} else {
			# # 		# // user is not logged in
			# # 	}
			# # }, {perms:'read_stream,publish_stream,offline_access'})

			# FB.api(
			# 	"/me/photos",
			# 	"POST",
			# 	{
			# 		"object": {
			# 			"url": result.url
			# 		}
			# 	},
			# 	(response) ->
			# 		# if (response && !response.error)
			# 			# handle response
			# 		return
			# )
			return

		# - log in to facebook (if not already logged in)
		# - save image to publish photo when/if logged in
		publishOnFacebookAsPhoto: ()=>
			if not g.loggedIntoFacebook
				FB.login( (response)=>
					if response and !response.error
						@saveImage(@publishOnFacebookAsPhotoCallback)
					else
						g.romanesco_alert "An error occured when trying to log you into facebook.", "error"
					return
				)
			else
				@saveImage(@publishOnFacebookAsPhotoCallback)
			return

		# (Called once the image is uploaded) directly publish the image
		# todo: check if upload was successful?
		publishOnFacebookAsPhotoCallback: (result)=>
			g.romanesco_alert "Your image was successfully uploaded to Romanesco, posting to Facebook...", "info"
			caption = @getDescription()
			FB.api(
				"/me/photos",
				"POST",
				{
					"url": g.romanescoURL + result.url
					"message": caption
				},
				(response)->
					if response and !response.error
						g.romanesco_alert "Your Post was successfully published!", "success"
					else
						g.romanesco_alert("An error occured. Your post was not published.", "error")
						console.log response.error
					return
			)
			return

		# Save image and call publish on pinterest callback
		publishOnPinterest: ()=>
			@saveImage(@publishOnPinterestCallback)
			return

		# (Called once the image is uploaded) add a modal dialog to publish the image on pinterest (the pinterest button must link to an image already existing on the server)
		# todo: check if upload was successful?
		publishOnPinterestCallback: (result)=>
			g.romanesco_alert "Your image was successfully uploaded to Romanesco...", "info"

			# initialize pinterest modal
			pinterestModalJ = $("#customModal")
			pinterestModalJ.modal('show')
			pinterestModalJ.addClass("pinterest-modal")
			pinterestModalJ.find(".modal-title").text("Publish on Pinterest")
			# siteUrl = encodeURI('http://romanesc.co/')
			siteUrl = encodeURI(g.romanescoURL)
			imageUrl = siteUrl+result.url
			caption = @getDescription()
			description = encodeURI(caption)

			linkJ = $("<a>")
			linkJ.addClass("image")
			linkJ.attr("href", "http://pinterest.com/pin/create/button/?url="+siteUrl+"&media="+imageUrl+"&description="+description)
			linkJcopy = linkJ.clone()

			imgJ = $('<img>')
			imgJ.attr( 'src', siteUrl+result.url )
			linkJ.append(imgJ)

			buttonJ = pinterestModalJ.find('button[name="submit"]')
			linkJcopy.addClass("btn btn-primary").text("Pin it!").insertBefore(buttonJ)
			buttonJ.hide()

			submit = ()->
				pinterestModalJ.modal('hide')
				return
			linkJ.click(submit)
			pinterestModalJ.find(".modal-body").empty().append(linkJ)

			pinterestModalJ.on 'hide.bs.modal', (event)->
				pinterestModalJ.removeClass("pinterest-modal")
				linkJcopy.remove()
				pinterestModalJ.off 'hide.bs.modal'
				return

			return

		# publishOnTwitter: ()=>
		# 	linkJ = $('<a name="publish-on-twitter" class="twitter-share-button" href="https://twitter.com/share" data-text="Artwork made on Romanesco" data-size="large" data-count="none">Publish on Twitter</a>')
		# 	linkJ.attr "data-url", "http://romanesc.co/" + location.hash
		# 	scriptJ = $('<script type="text/javascript">window.twttr=(function(d,s,id){var t,js,fjs=d.getElementsByTagName(s)[0];if(d.getElementById(id)){return}js=d.createElement(s);js.id=id;js.src="https://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);return window.twttr||(t={_e:[],ready:function(f){t._e.push(f)}})}(document,"script","twitter-wjs"));</script>')
		# 	$("div.temporary").append(linkJ)
		# 	$("div.temporary").append(scriptJ)
		# 	linkJ.click()
		# 	return

		# on download png button click: simulate a click on the image link
		# (chrome will open the save image dialog, other browsers will open the image in a new window/tab for the user to be able to save it)
		downloadPNG: ()=>
			@modalJ.find("a.png")[0].click()
			@modalJ.modal('hide')
			return

		# on download svg button click: extract svg from the paper project (in the selected rectangle) and click on resulting svg image link
		# (chrome will open the save image dialog, other browsers will open the image in a new window/tab for the user to be able to save it)
		downloadSVG: ()=>
			# get rectangle and retrieve items in this rectangle
			rectanglePath = new Path.Rectangle(@rectangle)

			itemsToSave = []
			for item in project.activeLayer.children
				bounds = item.bounds
				if item.controller?
					controlPath = item.controller.controlPath
					if @rectangle.contains(bounds) or ( @rectangle.intersects(bounds) and controlPath?.getIntersections(rectanglePath).length>0 )
						g.pushIfAbsent(itemsToSave, item.controller)

			# put the retrieved items in a group
			svgGroup = new Group()

			# draw items which were not drawn
			for item in itemsToSave
				if not item.drawing? then item.draw()

			view.update()

			# add items to svg group
			for item in itemsToSave
				svgGroup.addChild(item.drawing.clone())

			# create a new paper project and add the new Group (fit group and project positions and dimensions according to the selected rectangle)
			rectanglePath.remove()
			position = svgGroup.position.subtract(@rectangle.topLeft)
			fileName = "image.svg"

			canvasTemp = document.createElement('canvas')
			canvasTemp.width = @rectangle.width
			canvasTemp.height = @rectangle.height

			tempProject = new Project(canvasTemp)
			svgGroup.position = position
			tempProject.addChild(svgGroup)

			# export new Project to svg, remove the new Project
			svg = tempProject.exportSVG( asString: true )
			tempProject.remove()
			paper.projects.first().activate()

			# create an svg image, create a link to download the image, and click it
			blob = new Blob([svg], {type: 'image/svg+xml'})
			url = URL.createObjectURL(blob)
			link = document.createElement("a")
			link.download = fileName
			link.href = url
			link.click()

			@modalJ.modal('hide')
			return

		# nothing to do here: ZeroClipboard handles it
		copyURL: ()->
			return

	g.ScreenshotTool = ScreenshotTool

	return