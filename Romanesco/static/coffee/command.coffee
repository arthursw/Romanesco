class Command

	# @execute: true when the command must be executed:
	#			used to ignore the @do action:
	# 				- when creating the command (for actions which are performed independently of the command like moving a point: 
	# 											 the point is moved anyway, and then the MovePointCommand is updated with the new point position)
	# 				- when the command is not ready to be executed (for example when the server has not responded yet after a createDivCommand
	# 																the command has to way the newly created object to be able to delete it later)
	constructor: (@name, @execute=true)->
		@liJ = $("<li>").text(@name)
		@liJ.click(@click)
		@done = not @execute
		if @done then @liJ.addClass('done')
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

class MoveCommand extends Command
	constructor: (@item, @newPosition, @previousPosition=null, execute=true)->
		super("Move item", execute)
		@previousPosition ?= @item.getPosition()
		return

	do: ()->
		@item.moveTo(@newPosition, true)
		super()
		return

	undo: ()->
		@item.moveTo(@previousPosition, true)
		super()
		return

	update: ()->
		@newPosition = @item.getPosition()
		return

@MoveCommand = MoveCommand

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

class ChangeParameterCommand extends Command
	constructor: (@item, @parameterName)->
		@previousValue = @item.data[@parameterName]
		console.log 'previousValue'
		console.log @previousValue
		super('Change item parameter "' + @parameterName + '"', false)
		return

	do: ()->
		console.log 'change ' + @parameterName + ' , change to ' + @value
		console.log @value
		@item.changeParameter(@parameterName, @value, true, true)
		super()
		return

	undo: ()->
		console.log 'undo change ' + @parameterName + ' , change to ' + @previousValue
		console.log @previousValue
		@item.changeParameter(@parameterName, @previousValue, true, true)
		super()
		return

	update: ()->
		@value = @item.data[@parameterName]
		console.log 'value'
		console.log @value
		return

@ChangeParameterCommand = ChangeParameterCommand

class CreatePathCommand extends Command
	constructor: (@item, name=null, execute=false)->
		name ?= "Create path" 	# if name is not define: it is a create path command
		super(name, execute)
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
		@itemConstructor = @item.constructor
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
	constructor: (@div, name=null, execute=false)->
		name ?= "Create div" 	# if name is not define: it is a create path command
		@update()
		super(name, execute)
		return
	
	duplicate: ()->
		# mechanism to get the new div: give @ to div's constructor (in a dictionnary of <divPK -> CreateDivCommand>) 
		# so that div's constructor update @div when duplicate div is created (in RDiv.save_callback)
		@divConstructor.duplicateCommand ?= {}
		@divConstructor.duplicateCommand[@pk] = @
		@divConstructor.duplicate(@bounds, @object_type, @message, @name, @url, @pk, @data)
		@div = null
		@execute = false
		return

	deleteDiv: ()->
		if not @div
			@execute = false
			return
		@update()
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

	update: ()->
		@bounds = @div.getBounds()
		@object_type = @div.object_type
		@message = @div.message
		@name = @div.name
		@url = @div.url
		@pk = @div.pk
		@data = @div.getData()
		@divConstructor = @div.constructor
		return

	setDiv: (div)->
		@div = div
		@execute = true
		return

	delete: ()->
		delete @divConstructor.duplicateCommand[@pk]
		super()
		return

@CreateDivCommand = CreateDivCommand

class DeleteDivCommand extends CreateDivCommand
	constructor: (@item)-> super(@item, 'Delete div', true)
	
	do: ()->
		@deleteDiv()
		@constructor.__super__.constructor.__super__["do"].call(this)
		return

	undo: ()->
		@duplicate()
		@constructor.__super__.constructor.__super__["undo"].call(this)
		return

@DeleteDivCommand = DeleteDivCommand

class ResizeDivCommand extends Command
	constructor: (@div)->
		@previousPosition = @div.position
		@previousSize = @div.size
		super("Resize div", false)
		return
	
	do: ()->
		@div.resizeTo(@position, @size)
		super()
		return

	undo: ()->
		@div.resizeTo(@previousPosition, @previousSize)
		super()
		return

	update: ()->
		@position = @div.position
		@size = @div.size
		return

@ResizeDivCommand = ResizeDivCommand

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

class ChangeSelectedPointCommand extends Command
	
	constructor: (@item)->
		@selectionState = {}
		@selectionState.segment = @item.selectionState.segment
		@previousPosition = new Point(@selectionState.segment.point)
		@previousHandleIn = new Point(@selectionState.segment.handleIn)
		@previousHandleOut = new Point(@selectionState.segment.handleOut)
		super('Change point on item', false)
		return

	do: ()->
		@item.selectionState.segment = @selectionState.segment
		@item.changeSelectedSegment(@position, @handleIn, @handleOut)
		super()
		return

	undo: ()->
		@item.selectionState.segment = @selectionState.segment
		@item.changeSelectedSegment(@previousPosition, @previousHandleIn, @previousHandleOut)
		super()
		return

	update: ()->
		@position = new Point(@item.selectionState.segment.point)
		@handleIn = new Point(@item.selectionState.segment.handleIn)
		@handleOut = new Point(@item.selectionState.segment.handleOut)
		return

@ChangeSelectedPointCommand = ChangeSelectedPointCommand

class RotationCommand extends Command
	
	constructor: (@item)->
		@previousRotation = @item.rotation
		super('Rotate item', false)
		return

	do: ()->
		@item.select()
		@item.setRotation(@rotation, true)
		super()
		return

	undo: ()->
		@item.select()
		@item.setRotation(@previousRotation, true)
		super()
		return

	update: ()->
		@rotation = @item.rotation
		return

@RotationCommand = RotationCommand

class ScaleCommand extends Command
	
	constructor: (@item)->
		@previousRectangle = @item.rectangle
		super('Scale item', false)
		return

	do: ()->
		@item.select()
		@item.setRectangle(@rectangle, true)
		super()
		return

	undo: ()->
		@item.select()
		@item.setRectangle(@previousRectangle, true)
		super()
		return

	update: ()->
		@rectangle = @item.rectangle
		return

@ScaleCommand = ScaleCommand

class ChangeSpeedCommand extends Command

	constructor: (@item)->
		@previousSpeeds = @item.speeds.slice()
		super('Change speed', false)
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

	update: ()->
		# @speeds = speeds.splice()
		return

@ChangeSpeedCommand = ChangeSpeedCommand

class CommandManager
	@maxCommandNumber = 20
	
	constructor: ()->
		@history = []
		@currentCommand = -1
		@historyJ = $("#History ul.history")
		return

	add: (command)->
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
		if command.execute then command.do() else command.execute = true
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
			if not @history[@currentCommand+offset].execute
				g.romanesco_alert("This action is not feasible yet (server has not responded yet, please wait a few seconds for a response).", "warning")
				break
			else
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
