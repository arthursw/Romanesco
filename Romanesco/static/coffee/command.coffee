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
	constructor: (@item)->
		super("Resize item", item)
		@previousRectangle = @item.rectangle
		return

	do: ()->
		@item.setRectangle(@newRectangle)
		super()
		return

	undo: ()->
		@item.setRectangle(@previousRectangle)
		super()
		return

	update: (event)->
		@item.updateSetRectangle(event)
		return

	end: ()->
		@newRectangle = @item.rectangle
		@item.endSetRectangle()
		return

@ResizeCommand = ResizeCommand

class RotationCommand extends Command
	constructor: (@item)->
		super("Rotate item")
		@previousRotation = @item.rotation
		return

	do: ()->
		@item.setRotation(@newRotation)
		super()
		return

	undo: ()->
		@item.setRotation(@previousRotation)
		super()
		return

	update: (event)->
		@item.updateSetRotation(event)
		return

	end: ()->
		@newRotation = @item.rotation
		@item.endSetRotation()
		return

@RotationCommand = RotationCommand

class MoveCommand extends Command
	constructor: (@item)->
		super("Rotate item")
		@previousPosition = @item.rectangle.center
		return

	do: ()->
		@item.moveTo(@newPosition)
		super()
		return

	undo: ()->
		@item.moveTo(@previousPosition)
		super()
		return

	update: (event)->
		@item.updateMoveBy(event)
		return

	end: ()->
		@newPosition = @item.rectangle.center
		@item.endMoveBy()
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
		@item.endModifySegment()
		return


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
		return

@ModifySpeedCommand = ModifySpeedCommand

class ChangeParameterCommand extends Command
	constructor: (@item, @parameterName)->
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
		@item.update(@parameterName)
		return

@ChangeParameterCommand = ChangeParameterCommand

# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #
# ---- # # ---- # # ---- # # ---- #


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
		@previouslySelectedItems = g.previouslySelectedItems
		return

	do: ()->
		for item in @previouslySelectedItems
			item.deselect()
		for item in @items
			item.select(@updateParameters)
		super()
		return

	undo: ()->
		for item in @items
			item.deselect()
		for item in @previouslySelectedItems
			item.select()
		super()
		return

@SelectCommand = SelectCommand

class CreatePathCommand extends Command
	constructor: (@item, name=null)->
		name ?= "Create path" 	# if name is not define: it is a create path command
		@itemConstructor = @item.constructor
		super(name)
		return

	duplicate: ()->
		@item = @itemConstructor.duplicate(@data, @controlPathSegments)
		@item.select()
		return

	deletePath: ()->
		# the item has to be copied: it is removed in other clients through websockets
		# (it cannot be half removed in other clients since it will not be in the others history for a later delete)
		# @controlPathSegments = @item.controlPath.segments
		clone = @item.controlPath.clone()
		@controlPathSegments = clone.segments
		clone.remove()
		@data = @item.getData()
		@item.delete()
		@item = null
		return

	do: ()->
		@duplicate()
		super()
		return

	undo: ()->
		@deletePath()
		super()
		return

@CreatePathCommand = CreatePathCommand

class DeletePathCommand extends CreatePathCommand
	constructor: (@item)-> super(@item, 'Delete path', true)

	do: ()->
		@deletePath()
		@constructor.__super__.constructor.__super__["do"].call(this)
		return

	undo: ()->
		@duplicate()
		@constructor.__super__.constructor.__super__["undo"].call(this)
		return

@DeletePathCommand = DeletePathCommand

class CreateDivCommand extends Command
	constructor: (@div, name=null)->
		name ?= "Create div" 	# if name is not define: it is a create path command
		super(name)
		return
	
	duplicate: ()->
		@divConstructor.duplicate(@rectangle, @data)
		@div = null
		return

	deleteDiv: ()->
		@end()
		@div.delete()
		@div = null
		return

	do: ()->
		@duplicate()
		super()
		return

	undo: ()->
		@deleteDiv()
		super()
		return

	end: ()->
		@rectangle = @div.rectangle
		@data = @div.getData()
		@divConstructor = @div.constructor
		return

@CreateDivCommand = CreateDivCommand

class DeleteDivCommand extends CreateDivCommand
	constructor: (@div, name=null)-> super(@div, name or 'Delete div', true)
	
	do: ()->
		@deleteDiv()
		@constructor.__super__.constructor.__super__["do"].call(this)
		return

	undo: ()->
		@duplicate()
		@constructor.__super__.constructor.__super__["undo"].call(this)
		return

@DeleteDivCommand = DeleteDivCommand

class CreateLockCommand extends CreateDivCommand
	constructor: (item, name)->
		super(item, 'Create lock')

@CreateLockCommand = CreateLockCommand

class DeleteLockCommand extends DeleteDivCommand
	constructor: (item, name)->
		super(item, 'Delete lock')

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

	commandClicked: (command)->
		commandIndex = @getCommandIndex(command)

		if @currentCommand == commandIndex then return

		if @currentCommand > commandIndex
			direction = -1
			offset = 0
		else
			direction = 1
			offset = 1

		while @currentCommand != commandIndex
			# if not @history[@currentCommand+offset].execute
			# 	g.romanesco_alert("This action is not feasible yet (server has not responded yet, please wait a few seconds for a response).", "warning")
			# 	break
			# else
			@history[@currentCommand+offset].toggle()
			@currentCommand += direction

		return

	getCommandIndex: (command)->
		for c, i in @history
			if c == command then return i
		return -1

	getCurrentCommand: ()->
		return @history[@currentCommand]

@CommandManager = CommandManager
