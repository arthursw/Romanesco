class Command

	constructor: (@name)->
		@liJ = $("<li>").text(@name)
		@liJ.click(@click)
		return

	do: ()->
		@done = true
		@liJ.addClass('done')
		return

	undo: ()->
		@done = false
		@liJ.removeClass('done')
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
		@done = true
		@liJ.addClass('done')
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
		super("Resize item", item)
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

	end: ()->
		@newRectangle = @item.rectangle
		if @newRectangle == @previousRectangle then return false
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

	end: ()->
		@newRotation = @item.rotation
		if @newRotation == @previousRotation then return false
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
		item.moveBy(@newPosition.subtract(@previousPosition), true) for item in @items
		super()
		return

	undo: ()->
		item.moveBy(@previousPosition.subtract(@newPosition), true) for item in @items
		super()
		return

	update: (event)->
		item.updateMoveBy(event) for item in @items
		return

	end: ()->
		@newPosition = @item.rectangle.center
		if @newPosition.equals(@previousPosition) then return false
		# item.endMoveBy() for item in @items
		args = []
		for item in @items
			args.push( function: item.getUpdateFunction(), arguments: item.getUpdateArguments('position') )
		Dajaxice.draw.multipleCalls( @update_callback, functionsAndArguments: args)
		super()
		return true

	update_callback: (results)->
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
		@item.modifySegment(@segment, @position, @handleIn, @handleOut)
		super()
		return

	undo: ()->
		@item.modifySegment(@segment, @previousPosition, @previousHandleIn, @previousHandleOut)
		super()
		return

	update: (event)->
		@item.updateModifySegment(event)
		return

	end: ()->
		@position = new Point(@segment.point)
		@handleIn = new Point(@segment.handleIn)
		@handleOut = new Point(@segment.handleOut)
		if @position.equals(@previousPosition) and @previousHandleIn.equals(@handleIn) and @previousHandleOut.equals(@handleOut) then return false
		@item.endModifySegment()
		super()
		return true

@ModifyPointCommand = ModifyPointCommand

class ModifySpeedCommand extends Command

	constructor: (@item)->
		@previousSpeeds = @item.speeds.slice()
		super('Change speed')
		return

	do: ()->
		@item.speeds = @speeds
		@item.updateSpeed()
		@item.draw()
		super()
		return
	
	undo: ()->
		@speeds = @item.speeds.slice()
		@item.speeds = @previousSpeeds
		@item.updateSpeed()
		@item.draw()
		super()
		return

	update: (event)->
		@item.updateModifySpeed(event)
		return

	end: ()->
		# @speeds = speeds.splice()
		@item.endModifySpeed()
		super()
		return true

@ModifySpeedCommand = ModifySpeedCommand

class ChangeParameterCommand extends Command
	constructor: (@item, args)->
		@parameterName = args[0]
		@previousValue = @item.data[@parameterName]
		super('Change item parameter "' + @parameterName + '"')
		return

	do: ()->
		@item.changeParameter(@parameterName, @value, true, true)
		super()
		return

	undo: ()->
		@item.changeParameter(@parameterName, @previousValue, true, true)
		super()
		return

	update: (name, value)->
		@item.changeParameter(name, value)
		return

	end: ()->
		@value = @item.data[@parameterName]
		if @value == @previousValue then return false
		@item.update(@parameterName)
		super()
		return true

@ChangeParameterCommand = ChangeParameterCommand

# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #

class MoveViewCommand extends Command
	constructor: (@previousPosition, @newPosition)->
		super("Move view")
		@done = true
		@liJ.addClass('done')
		return

	updateCommandItems: ()=>
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
	constructor: (@items, @updateParameters)->
		super("Select item")
		@previouslySelectedItems = g.previouslySelectedItems.slice()
		# console.log 'INIT:'
		# console.log 'previous items'
		# for item in @previouslySelectedItems
		# 	console.log item.constructor.rname + ', ' + item.pk
		# console.log 'items'
		# for item in @items
		# 	console.log item.constructor.rname + ', ' + item.pk
		return

	do: ()->
		# console.log 'DO:'
		# console.log 'deselect previous items'
		# for item in @previouslySelectedItems
		# 	console.log item.constructor.rname + ', ' + item.pk
		# console.log 'select items'
		# for item in @items
		# 	console.log item.constructor.rname + ', ' + item.pk
		g.previouslySelectedItems = @previouslySelectedItems
		for item in @previouslySelectedItems
			item.deselect(false)
		for item in @items
			item.select(false)
		super()
		return

	undo: ()->
		# console.log 'UNDO:'
		# console.log 'deselect items'
		# for item in @items
		# 	console.log item.constructor.rname + ', ' + item.pk
		# console.log 'select previous items'
		# for item in @previouslySelectedItems
		# 	console.log item.constructor.rname + ', ' + item.pk
		g.previouslySelectedItems = g.selectedItems.slice()
		for item in @items
			item.deselect(false)
		for item in @previouslySelectedItems
			item.select(false)
		super()
		return

@SelectCommand = SelectCommand

class CreateItemCommand extends Command
	constructor: (@item, name=null)->
		@itemConstructor = @item.constructor
		super(name)
		@done = true
		@liJ.addClass('done')
		return

	duplicateItem: ()->
		for command in g.commandManager.history
			if command == @ then continue
			if command.item? and command.item == @itemPk then command.item = @item
			if command.items?
				for item, i in command.items
					if item == @itemPk then command.items[i] = @item
		@item.select()
		return

	deleteItem: ()->
		@data = @item.getData()
		for command in g.commandManager.history
			if command == @ then continue
			if command.item? and command.item == @item then command.item = @item.pk or @item.id
			if command.items?
				for item, i in command.items
					if item == @item then command.items[i] = @item.pk or @item.id
		@itemPk = @item.pk or @item.id
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

class CreatePathCommand extends CreateItemCommand
	constructor: (item, name=null)->
		name ?= "Create path" 	# if name is not define: it is a create path command
		super(item, name)
		return

	duplicateItem: ()->
		@item = @itemConstructor.duplicate(@data, @controlPathSegments)
		super()
		return

	deleteItem: ()->
		clone = @item.controlPath.clone()
		@controlPathSegments = clone.segments
		clone.remove()
		super()
		return

@CreatePathCommand = CreatePathCommand

class DeletePathCommand extends CreatePathCommand
	constructor: (item)-> super(item, 'Delete path', true)

	do: ()->
		@deleteItem()
		@constructor.__super__.constructor.__super__.constructor.__super__["do"].call(this)
		return

	undo: ()->
		@duplicateItem()
		@constructor.__super__.constructor.__super__.constructor.__super__["undo"].call(this)
		return

@DeletePathCommand = DeletePathCommand

class CreateDivCommand extends CreateItemCommand
	constructor: (item, name=null)->
		name ?= "Create div" 	# if name is not define: it is a create path command
		super(item, name)
		return
	
	duplicateItem: ()->
		@item = @itemConstructor.duplicate(@rectangle, @data)
		super()
		return

	deleteItem: ()->
		@rectangle = @item.rectangle
		@data = @item.getData()
		super()
		return

	do: ()->
		super()
		return RMedia.prototype.isPrototypeOf(@item) 	# deferred if item is an RMedia

@CreateDivCommand = CreateDivCommand

class DeleteDivCommand extends CreateDivCommand
	constructor: (item, name=null)-> 
		super(item, name or 'Delete div', true)
		return
	
	do: ()->
		@deleteItem()
		@constructor.__super__.constructor.__super__.constructor.__super__["do"].call(this)
		return

	undo: ()->
		@duplicateItem()
		@constructor.__super__.constructor.__super__.constructor.__super__["undo"].call(this)
		return RMedia.prototype.isPrototypeOf(@item) 	# deferred if item is an RMedia

@DeleteDivCommand = DeleteDivCommand

class CreateLockCommand extends CreateDivCommand
	constructor: (item, name)->
		super(item, name or 'Create lock')

	# never return true: it is never deferred
	do: ()->
		super()
		return

@CreateLockCommand = CreateLockCommand

class DeleteLockCommand extends DeleteDivCommand
	constructor: (item)->
		super(item, 'Delete lock')

	# never return true: it is never deferred
	undo: ()->
		super()
		return

@DeleteLockCommand = DeleteLockCommand

class AddPointCommand extends Command
	constructor: (@item, @location, name=null)->
		super(if not name? then 'Add point on item' else name)
		return

	addPoint: (update=true)->
		@segment = @item.addPoint(@location, true, update)
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
		@selectionState = {}
		@selectionState.segment = @item.selectionState.segment
		@previousPosition = new Point(@selectionState.segment.point)
		@previousHandleIn = new Point(@selectionState.segment.handleIn)
		@previousHandleOut = new Point(@selectionState.segment.handleOut)
		@deletePoint()
		@constructor.__super__.constructor.__super__["do"].call(this)
		return

	undo: ()->
		@addPoint(false)
		@item.selectionState.segment = @segment
		@item.changeSelectedSegment(@previousPosition, @previousHandleIn, @previousHandleOut)
		@constructor.__super__.constructor.__super__["undo"].call(this)
		return

@DeletePointCommand = DeletePointCommand

class ChangeSelectedPointTypeCommand extends Command
	
	constructor: (@item, @rtype)->
		@selectionState = {}
		@selectionState.segment = @item.selectionState.segment
		@previousRType = @selectionState.segment.rtype
		@previousPosition = new Point(@selectionState.segment.point)
		@previousHandleIn = new Point(@selectionState.segment.handleIn)
		@previousHandleOut = new Point(@selectionState.segment.handleOut)
		super('Change point type on item')
		return

	do: ()->
		@item.selectionState.segment = @selectionState.segment
		@item.changeSelectedPointType(@rtype)
		super()
		return

	undo: ()->
		@item.selectionState.segment = @selectionState.segment
		@item.changeSelectedPointType(@previousRType, true, false)
		@item.changeSelectedSegment(@previousPosition, @previousHandleIn, @previousHandleOut)
		super()
		return

@ChangeSelectedPointTypeCommand = ChangeSelectedPointTypeCommand

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
		if @currentCommand == @commandIndex then return
		
		document.removeEventListener('command executed', @toggleCurrentCommand)
		
		deferred = @history[@currentCommand+@offset].toggle()
		@currentCommand += @direction

		if deferred
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
