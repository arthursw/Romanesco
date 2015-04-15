class Command

	constructor: (@name)->
		@liJ = $("<li>").text(@name)
		@liJ.click(@click)
		return

	superDo: ()->
		@done = true
		@liJ.addClass('done')
		return

	superUndo: ()->
		@done = false
		@liJ.removeClass('done')
		return

	do: ()->
		@superDo()
		return

	undo: ()->
		@superUndo()
		return

	click: ()=>
		g.commandManager.commandClicked(@)
		return

	toggle: ()->
		return if @done then @undo() else @do()

	delete: ()->
		@liJ.remove()
		return

	update: ()->
		return

	end: ()->
		@superDo()
		return

@Command = Command

# class DuplicateCommand extends Command
# 	constructor: (@item)->
# 		super("Duplicate item")
# 		return

# 	do: ()->
# 		@copy = @item.duplicate()
# 		super()
# 		return

# 	undo: ()->
# 		@copy.delete()
# 		super()
# 		return

# @DuplicateCommand = DuplicateCommand

class ResizeCommand extends Command
	constructor: (@item, @newRectangle)->
		super("Resize item", @item)
		@previousRectangle = @item.rectangle
		return

	do: ()->
		@item.setRectangle(@newRectangle, true)
		super()
		return

	undo: ()->
		@item.setRectangle(@previousRectangle, true)
		super()
		return

	update: (event)->
		@item.updateSetRectangle(event)
		return

	end: (valid)->
		@newRectangle = @item.rectangle
		if @newRectangle == @previousRectangle then return false
		if not valid then return false
		@item.endSetRectangle()
		super()
		return true

@ResizeCommand = ResizeCommand

class RotationCommand extends Command
	constructor: (@item, @newRotation)->
		super("Rotate item")
		@previousRotation = @item.rotation
		return

	do: ()->
		@item.setRotation(@newRotation, true)
		super()
		return

	undo: ()->
		@item.setRotation(@previousRotation, true)
		super()
		return

	update: (event)->
		@item.updateSetRotation(event)
		return

	end: (valid)->
		@newRotation = @item.rotation
		if @newRotation == @previousRotation then return false
		if not valid then return false
		@item.endSetRotation()
		super()
		return true

@RotationCommand = RotationCommand

class MoveCommand extends Command
	constructor: (@item, @newPosition)->
		super("Move item")
		@previousPosition = @item.rectangle.center
		@items = g.selectedItems.slice()
		return

	do: ()->
		# areas = []
		for item in @items
			# area = item.getDrawingBounds()
			# if area.area < g.rasterizer.maxArea() then areas.push(area)
			item.moveBy(@newPosition.subtract(@previousPosition), true)
		# g.rasterizer.rasterize(@items, false, areas)
		super()
		return

	undo: ()->
		# areas = []
		for item in @items
			# area = item.getDrawingBounds()
			# if area.area < g.rasterizer.maxArea() then areas.push(area)
			item.moveBy(@previousPosition.subtract(@newPosition), true)
		# g.rasterizer.rasterize(@items, false, areas)
		super()
		return

	update: (event)->
		item.updateMove(event) for item in @items
		return

	end: (valid)->
		@newPosition = @item.rectangle.center
		if @newPosition.equals(@previousPosition) then return false
		if not valid then return false
		# item.endMoveBy() for item in @items
		if @items.length==1
			@items[0].endMove(true)
		else
			args = []
			for item in @items
				item.endMove(false)
				if RLock.prototype.isPrototypeOf(item)
					item.update('position')
				else
					args.push( function: item.getUpdateFunction(), arguments: item.getUpdateArguments('position') )
			Dajaxice.draw.multipleCalls( @updateCallback, functionsAndArguments: args)
		# g.rasterizer.rasterize(@items)
		super()
		return true

	updateCallback: (results)->
		for result in results
			g.checkError(result)
		return

@MoveCommand = MoveCommand

class ModifyPointCommand extends Command

	constructor: (@item)->
		@segment = @item.selectionState.segment
		@previousPosition = new Point(@segment.point)
		@previousHandleIn = new Point(@segment.handleIn)
		@previousHandleOut = new Point(@segment.handleOut)
		super('Modify point')
		return

	do: ()->
		@item.modifyPoint(@segment, @position, @handleIn, @handleOut)
		super()
		return

	undo: ()->
		@item.modifyPoint(@segment, @previousPosition, @previousHandleIn, @previousHandleOut)
		super()
		return

	update: (event)->
		@item.updateModifyPoint(event)
		return

	end: (valid)->
		@position = @segment.point.clone()
		@handleIn = @segment.handleIn.clone()
		@handleOut = @segment.handleOut.clone()
		if not valid then return
		positionNotChanged = @position.equals(@previousPosition)
		handleInNotChanged = @previousHandleIn.equals(@handleIn)
		handleOutNotChanged = @previousHandleOut.equals(@handleOut)
		if positionNotChanged and handleInNotChanged and handleOutNotChanged then return false
		@item.endModifyPoint()
		super()
		return true

@ModifyPointCommand = ModifyPointCommand

class ModifySpeedCommand extends Command

	constructor: (@item)->
		@previousSpeeds = @item.speeds.slice()
		super('Change speed')
		return

	do: ()->
		@item.modifySpeed(@speeds, true)
		super()
		return

	undo: ()->
		@speeds = @item.speeds.slice()
		@item.modifySpeed(@previousSpeeds, true)
		super()
		return

	update: (event)->
		@item.updateModifySpeed(event)
		return

	end: (valid)->
		if not valid then return
		# @speeds = speeds.splice()
		@item.endModifySpeed()
		super()
		return true

@ModifySpeedCommand = ModifySpeedCommand

class SetParameterCommand extends Command
	constructor: (@item, args)->
		@parameterName = args[0]
		@previousValue = @item.data[@parameterName]
		super('Change item parameter "' + @parameterName + '"')
		return

	do: ()->
		@item.setParameter(@parameterName, @value, true, true)
		super()
		return

	undo: ()->
		@item.setParameter(@parameterName, @previousValue, true, true)
		super()
		return

	update: (name, value)->
		@item.setParameter(name, value)
		return

	end: (valid)->
		@value = @item.data[@parameterName]
		if @value == @previousValue then return false
		if not valid then return
		@item.update(@parameterName)
		super()
		return true

@SetParameterCommand = SetParameterCommand

# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #

class AddPointCommand extends Command
	constructor: (@item, @location, name=null)->
		super(if not name? then 'Add point on item' else name)
		return

	addPoint: (update=true)->
		@segment = @item.addPointAt(@location, update)
		return

	deletePoint: ()->
		@location = @item.deletePoint(@segment)
		return

	do: ()->
		@addPoint()
		super()
		return

	undo: ()->
		@deletePoint()
		super()
		return

@AddPointCommand = AddPointCommand

class DeletePointCommand extends AddPointCommand
	constructor: (@item, @segment)-> super(@item, @segment, 'Delete point on item')

	do: ()->
		@previousPosition = new Point(@segment.point)
		@previousHandleIn = new Point(@segment.handleIn)
		@previousHandleOut = new Point(@segment.handleOut)
		@deletePoint()
		@superDo()
		return

	undo: ()->
		@addPoint(false)
		@item.modifyPoint(@segment, @previousPosition, @previousHandleIn, @previousHandleOut)
		@superUndo()
		return

@DeletePointCommand = DeletePointCommand

class ModifyPointTypeCommand extends Command

	constructor: (@item, @segment, @rtype)->
		@previousRType = @segment.rtype
		@previousPosition = new Point(@segment.point)
		@previousHandleIn = new Point(@segment.handleIn)
		@previousHandleOut = new Point(@segment.handleOut)
		super('Change point type on item')
		return

	do: ()->
		@item.modifyPointType(@segment, @rtype)
		super()
		return

	undo: ()->
		@item.modifyPointType(@segment, @previousRType, true, false)
		@item.changeSegment(@segment, @previousPosition, @previousHandleIn, @previousHandleOut)
		super()
		return

@ModifyPointTypeCommand = ModifyPointTypeCommand


class MoveViewCommand extends Command
	constructor: (@previousPosition, @newPosition)->
		super("Move view")
		@superDo()
		# if not @previousPosition? or not @newPosition?
		# 	debugger
		return

	updateCommandItems: ()=>
		console.log "updateCommandItems"
		document.removeEventListener('command executed', @updateCommandItems)
		for command in g.commandManager.history
			if command.item?
				if not command.item.group? and g.items[command.item.pk or command.item.id]
					command.item = g.items[command.item.pk or command.item.id]
			if command.items?
				for item, i in command.items
					if not item.group? and g.items[item.pk or item.id]
						command.items[i] = g.items[item.pk or item.id]
		return

	do: ()->
		somethingToLoad = g.RMoveBy(@newPosition.subtract(@previousPosition), false)
		if somethingToLoad then document.addEventListener('command executed', @updateCommandItems)
		super()
		return somethingToLoad

	undo: ()->
		somethingToLoad = g.RMoveBy(@previousPosition.subtract(@newPosition), false)
		if somethingToLoad then document.addEventListener('command executed', @updateCommandItems)
		super()
		return somethingToLoad

@MoveViewCommand = MoveViewCommand

# class MoveCommand extends Command
# 	constructor: (@item, @newPosition=null)->
# 		super("Move item", @newPosition?)
# 		@previousPosition = @item.rectangle.center
# 		return

# 	do: ()->
# 		@item.moveTo(@newPosition, true)
# 		super()
# 		return

# 	undo: ()->
# 		@item.moveTo(@previousPosition, true)
# 		super()
# 		return

# 	end: ()->
# 		@newPosition = @item.rectangle.center
# 		return

# @MoveCommand = MoveCommand

class SelectCommand extends Command
	constructor: (@items, name)->
		super(name or "Select items")
		return

	selectItems: ()->
		for item in @items
			item.select()
		g.updateParametersForSelectedItems()
		return

	deselectItems: ()->
		for item in @items
			item.deselect()
		g.updateParametersForSelectedItems()
		return

	do: ()->
		@selectItems()
		super()
		return

	undo: ()->
		@deselectItems()
		super()
		return

@SelectCommand = SelectCommand

class DeselectCommand extends SelectCommand

	constructor: (items)->
		super(items or g.selectedItems.slice(), 'Deselect items')
		return

	do: ()->
		@deselectItems()
		@superDo()
		return

	undo: ()->
		@selectItems()
		@superUndo()
		return

@DeselectCommand = DeselectCommand

# class SelectCommand extends Command
# 	constructor: (@items, @updateParameters, name)->
# 		super(name or "Select item")
# 		@previouslySelectedItems = g.previouslySelectedItems.slice()
# 		return

# 	deselectSelect: (itemsToDeselect=[], itemsToSelect=[], dontRasterizeItems=false)->
# 		for item in itemsToDeselect
# 			item.deselect(false)

# 		for item in itemsToSelect
# 			item.select(false)

# 		g.rasterizer.rasterize(itemsToSelect, dontRasterizeItems)

# 		items = itemsToSelect.map( (item)-> return { tool: item.constructor, item: item } )
# 		g.updateParameters(items, true)
# 		g.selectedItems = itemsToSelect.slice()
# 		return

# 	selectItems: ()->
# 		g.previouslySelectedItems = @previouslySelectedItems
# 		@deselectSelect(@previouslySelectedItems, @items, true)
# 		return

# 	deselectItems: ()->
# 		g.previouslySelectedItems = g.selectedItems.slice()
# 		@deselectSelect(@items, @previouslySelectedItems)
# 		return

# 	do: ()->
# 		@selectedItems()
# 		super()
# 		return

# 	undo: ()->
# 		@deselectItems()
# 		super()
# 		return

# @SelectCommand = SelectCommand

# class DeselectCommand extends SelectCommand

# 	constructor: (items, updateParameters)->
# 		super(items, updateParameters, 'Deselect items')
# 		return

# 	do: ()->
# 		@deselectSelect(@items)
# 		@superDo()
# 		return

# 	undo: ()->
# 		@selectedItems()
# 		@superUndo()
# 		return

# @DeselectCommand = DeselectCommand

class CreateItemCommand extends Command
	constructor: (@item, name=null)->
		@itemConstructor = @item.constructor
		super(name)
		@superDo()
		return

	setDuplicatedItemToCommands: ()->
		for command in g.commandManager.history
			if command == @ then continue
			if command.item? and command.item == @itemPk then command.item = @item
			if command.items?
				for item, i in command.items
					if item == @itemPk then command.items[i] = @item
		return

	removeDeleteItemFromCommands: ()->
		for command in g.commandManager.history
			if command == @ then continue
			if command.item? and command.item == @item then command.item = @item.pk or @item.id
			if command.items?
				for item, i in command.items
					if item == @item then command.items[i] = @item.pk or @item.id
		@itemPk = @item.pk or @item.id
		return

	duplicateItem: ()->
		@item = @itemConstructor.create(@duplicateData)
		@setDuplicatedItemToCommands()
		@item.select()
		return

	deleteItem: ()->
		@removeDeleteItemFromCommands()

		@duplicateData = @item.getDuplicateData()
		@item.delete()

		@item = null
		return

	do: ()->
		@duplicateItem()
		super()
		return

	undo: ()->
		@deleteItem()
		super()
		return

@CreateItemCommand = CreateItemCommand

class DeleteItemCommand extends CreateItemCommand
	constructor: (item)-> super(item, 'Delete item')

	do: ()->
		@deleteItem()
		@superDo()
		return

	undo: ()->
		@duplicateItem()
		@superUndo()
		return

@DeleteItemCommand = DeleteItemCommand

class DuplicateItemCommand extends CreateItemCommand
	constructor: (item)->
		@duplicateData = item.getDuplicateData()
		super(item, 'Duplicate item')

@DuplicateItemCommand = DuplicateItemCommand

# class CreatePathCommand extends CreateItemCommand
# 	constructor: (item, name=null)->
# 		name ?= "Create path" 	# if name is not define: it is a create path command
# 		super(item, name)
# 		return

# 	duplicateItem: ()->
# 		@item = @itemConstructor.duplicate(@data, @controlPathSegments)
# 		super()
# 		return

# 	deleteItem: ()->
# 		clone = @item.controlPath.clone()
# 		@controlPathSegments = clone.segments
# 		clone.remove()
# 		super()
# 		return

# @CreatePathCommand = CreatePathCommand

# class DeletePathCommand extends CreatePathCommand
# 	constructor: (item)-> super(item, 'Delete path', true)

# 	do: ()->
# 		@deleteItem()
# 		@superDo()
# 		return

# 	undo: ()->
# 		@duplicateItem()
# 		@superUndo()
# 		return

# @DeletePathCommand = DeletePathCommand

# class CreateDivCommand extends CreateItemCommand
# 	constructor: (item, name=null)->
# 		name ?= "Create div" 	# if name is not define: it is a create path command
# 		super(item, name)
# 		return

# 	duplicateItem: ()->
# 		@item = @itemConstructor.duplicate(@rectangle, @data)
# 		super()
# 		return

# 	deleteItem: ()->
# 		@rectangle = @item.rectangle
# 		@data = @item.getData()
# 		super()
# 		return

# 	do: ()->
# 		super()
# 		return RMedia.prototype.isPrototypeOf(@item) 	# deferred if item is an RMedia

# @CreateDivCommand = CreateDivCommand

# class DeleteDivCommand extends CreateDivCommand
# 	constructor: (item, name=null)->
# 		super(item, name or 'Delete div', true)
# 		return

# 	do: ()->
# 		@deleteItem()
# 		@superDo()
# 		return

# 	undo: ()->
# 		@duplicateItem()
# 		@superUndo()
# 		return RMedia.prototype.isPrototypeOf(@item) 	# deferred if item is an RMedia

# @DeleteDivCommand = DeleteDivCommand

# class CreateLockCommand extends CreateDivCommand
# 	constructor: (item, name)->
# 		super(item, name or 'Create lock')

# @CreateLockCommand = CreateLockCommand

# class DeleteLockCommand extends DeleteDivCommand
# 	constructor: (item)->
# 		super(item, 'Delete lock')
# 		return

# @DeleteLockCommand = DeleteLockCommand

# class RotationCommand extends Command

# 	constructor: (@item)->
# 		@previousRotation = @item.rotation
# 		super('Rotate item', false)
# 		return

# 	do: ()->
# 		@item.select()
# 		@item.setRotation(@rotation)
# 		super()
# 		return

# 	undo: ()->
# 		@item.select()
# 		@item.setRotation(@previousRotation)
# 		super()
# 		return

# 	end: ()->
# 		@rotation = @item.rotation
# 		@item.update('rotation')
# 		return

# @RotationCommand = RotationCommand

# class ResizeCommand extends Command

# 	constructor: (@item)->
# 		@previousRectangle = @item.rectangle
# 		super('Resize item', false)
# 		return

# 	do: ()->
# 		@item.select()
# 		@item.setRectangle(@rectangle)
# 		super()
# 		return

# 	undo: ()->
# 		@item.select()
# 		@item.setRectangle(@previousRectangle)
# 		super()
# 		return

# 	end: ()->
# 		@rectangle = @item.rectangle
# 		@item.update('rectangle')
# 		return

# @ResizeCommand = ResizeCommand

class CommandManager
	@maxCommandNumber = 20

	constructor: ()->
		@history = []
		@currentCommand = -1
		@historyJ = $("#History ul.history")
		return

	add: (command, execute=false)->
		if @currentCommand >= @constructor.maxCommandNumber - 1
			firstCommand = @history.shift()
			firstCommand.delete()
			@currentCommand--
		currentLiJ = @history[@currentCommand]?.liJ
		currentLiJ?.nextAll().remove()
		@historyJ.append(command.liJ)
		$("#History .mCustomScrollbar").mCustomScrollbar("scrollTo","bottom")
		@currentCommand++
		@history.splice(@currentCommand, @history.length-@currentCommand, command)
		if execute then command.do()
		return

	toggleCurrentCommand: ()=>

		console.log "toggleCurrentCommand"
		$('#loadingMask').css('visibility': 'hidden')
		document.removeEventListener('command executed', @toggleCurrentCommand)

		if @currentCommand == @commandIndex then return

		deferred = @history[@currentCommand+@offset].toggle()
		@currentCommand += @direction

		if deferred
			$('#loadingMask').css('visibility': 'visible')
			document.addEventListener('command executed', @toggleCurrentCommand)
		else
			@toggleCurrentCommand()

		return

	commandClicked: (command)->
		@commandIndex = @getCommandIndex(command)

		if @currentCommand == @commandIndex then return

		if @currentCommand > @commandIndex
			@direction = -1
			@offset = 0
		else
			@direction = 1
			@offset = 1

		@toggleCurrentCommand()
		return

	getCommandIndex: (command)->
		for c, i in @history
			if c == command then return i
		return -1

	getCurrentCommand: ()->
		return @history[@currentCommand]

	clearHistory: ()->
		@historyJ.empty()
		@history = []
		@currentCommand = -1
		@add(new Command("Load Romanesco"), true)
		return

@CommandManager = CommandManager
