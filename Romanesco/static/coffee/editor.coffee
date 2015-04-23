define [
	'utils', 'coffee', 'ace', 'aceTools', 'jquery', 'typeahead'
], (utils, CoffeeScript) ->

	if not ace?
		require ['ace'], ()->
			debugger
			return

	g = utils.g()

	# --- Code editor --- #

	# todo: bug when modifying (click edit btn) a tool existing in DB: the editor do not show the code.
	g.codeEditor = {}
	ce = g.codeEditor
	ce.MAX_COMMANDS = 50
	ce.commandQueue = []
	ce.commandIndex = -1

	ce.initializeModuleInput = ()->

		input = ce.moduleInputJ
		ce.moduleNameValue = null

		input.typeahead(
			{ hint: true, highlight: true, minLength: 1 },
			{ valueKey: 'value', displayKey: 'value', source: g.typeaheadModuleEngine.ttAdapter() }
		)

		input.on 'typeahead:opened', ()->
			# dropDown = typeaheadJ.find(".tt-dropdown-menu")
			# dropDown.insertAfter(typeaheadJ.parents('.cr:first'))
			# dropDown.css(position: 'relative', display: 'inline-block', right:0)
			return

		getSource = (result)->
			ce.editor.getSession().setValue( source )
			ce.editor.newTool = false
			return

		initializeNewModuleFromName = (moduleName)->
			source = "class #{moduleName} extends g.PrecisePath\n"
			source += "\t@rname = '#{moduleName}'\n"
			source += "\t@rdescription = '#{moduleName}'\n"
			source += """
			\t
				drawBegin: ()->

					@initializeDrawing(false)

					@path = @addPath()
					return

				drawUpdateStep: (length)->

					point = @controlPath.getPointAt(length)
					@path.add(point)
					return

				drawEnd: ()->
					return

			"""
			ce.editor.getSession().setValue( source )
			ce.editor.newTool = true
			return

		input.on 'typeahead:closed', ()->
			moduleName = input.val()
			if moduleName == '' then return
			if ce.moduleNameValue == moduleName 	# the module exists
				Dajaxice.draw.getSource(getSource, moduleName: moduleName)
			else 							# the module does not exist
				initializeNewModuleFromName(moduleName)
			return

		input.on 'typeahead:cursorchanged', (event, suggestions, name)->
			ce.moduleNameValue = input.val()
			return

		input.on 'typeahead:selected', (event, suggestions, name)->
			ce.moduleNameValue = input.val()
			return

		input.on 'typeahead:autocompleted', (event, suggestions, name)->
			ce.moduleNameValue = input.val()
			return

		return

	# initialize code editor
	g.initCodeEditor = ()->

		# initialiaze jQuery elements
		ce.editorJ = $(document.body).find("#codeEditor")
		ce.sourceSelectorJ = ce.editorJ.find(".source-selector")
		ce.moduleInputJ = ce.editorJ.find(".header .search input")
		ce.consoleJ = ce.editorJ.find(".console")
		ce.consoleContentJ = ce.consoleJ.find(".content")
		ce.codeJ = ce.editorJ.find(".code")
		ce.pushRequestBtnJ = ce.editorJ.find("button.request")
		ce.handleJ = ce.editorJ.find(".editor-handle")
		ce.consoleHandleJ = ce.editorJ.find(".console-handle")
		ce.consoleCloseBtnJ = ce.consoleHandleJ.find(".close")
		ce.footerJ = ce.editorJ.find(".footer")

		# initialize ace editor

		# ace.require("ace/ext/language_tools")

		ce.editor = ace.edit(ce.codeJ[0])
		ce.editor.$blockScrolling = Infinity
		ce.editor.setOptions(
			enableBasicAutocompletion: true
			enableSnippets: true
			enableLiveAutocompletion: false
		)
		ce.editor.setTheme("ace/theme/monokai")
		# ce.editor.setShowInvisibles(true)
		# ce.editor.getSession().setTabSize(4)
		ce.editor.getSession().setUseSoftTabs(false)
		ce.editor.getSession().setMode("ace/mode/coffee")

		ce.editor.getSession().setValue("""
			class TestPath extends g.PrecisePath
			  @rname = 'Test path'
			  @rdescription = "Test path."

			  drawBegin: ()->

			    @initializeDrawing(false)

			    @path = @addPath()
			    return

			  drawUpdateStep: (length)->

			    point = @controlPath.getPointAt(length)
			    @path.add(point)
			    return

			  drawEnd: ()->
			    return

			""", 1)

		ce.editor.commands.addCommand(
			name: 'execute'
			bindKey:
				win: 'Ctrl-Shift-Enter'
				mac: 'Command-Shift-Enter'
				sender: 'editor|cli'
			exec: (env, args, request)->
				g.runScript()
				return
		)

		ce.addCommand = (command)->
			ce.commandQueue.push(command)
			if ce.commandQueue.length>ce.MAX_COMMANDS
				ce.commandQueue.shift()
			ce.commandIndex = ce.commandQueue.length
			return

		ce.editor.commands.addCommand(
			name: 'execute-command'
			bindKey:
				win: 'Ctrl-Enter'
				mac: 'Command-Enter'
				sender: 'editor|cli'
			exec: (env, args, request)->
				command = ce.editor.getValue()
				if command.length == 0 then return
				ce.addCommand(command)
				g.runScript()
				ce.editor.setValue('')
				return
		)

		# ce.editorJ.keyup (event)->
		# 	switch g.specialKeys[event.keyCode]
		# 		when 'up'
		# 			if g.specialKey(event) and

		# 		when 'down'

		# 	return

		ce.editor.commands.addCommand(
			name: 'previous-command'
			bindKey:
				win: 'Ctrl-Up'
				mac: 'Command-Up'
				sender: 'editor|cli'
			exec: (env, args, request)->
				cursorPosition = ce.editor.getCursorPosition()
				if cursorPosition.row == 0 and cursorPosition.column == 0
					if ce.commandIndex == ce.commandQueue.length
						command = ce.editor.getValue()
						if command.length > 0
							ce.addCommand(command)
							ce.commandIndex--
					if ce.commandIndex > 0
						ce.commandIndex--
						ce.editor.setValue(ce.commandQueue[ce.commandIndex])
				else
					ce.editor.gotoLine(0,0)
				return
		)
		ce.editor.commands.addCommand(
			name: 'next-command'
			bindKey:
				win: 'Ctrl-Down'
				mac: 'Command-Down'
				sender: 'editor|cli'
			exec: (env, args, request)->
				cursorPosition = ce.editor.getCursorPosition()
				lastRow = ce.editor.getSession().getLength()-1
				lastColumn = ce.editor.getSession().getLine(lastRow).length
				if cursorPosition.row == lastRow and cursorPosition.column == lastColumn
					if ce.commandIndex < ce.commandQueue.length - 1
						ce.commandIndex++
						ce.editor.setValue(ce.commandQueue[ce.commandIndex])
				else
					ce.editor.gotoLine(lastRow+1, lastColumn+1)
				return
		)

		ce.handleJ.mousedown ()->
			ce.draggingEditor = true
			$("body").css( 'user-select': 'none' )
			return
		ce.consoleHandleJ.mousedown ()->
			ce.draggingConsole = true
			$("body").css( 'user-select': 'none' )
			return
		ce.consoleHeight = 200

		ce.closeConsole = (consoleHeight=null)->
			ce.consoleHeight = consoleHeight or ce.consoleJ.height()
			ce.consoleJ.css( height: 0 ).addClass('closed')
			ce.consoleCloseBtnJ.find('.glyphicon').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-up')
			ce.editor.resize()
			return

		ce.openConsole = (consoleHeight=null)->
			if ce.consoleJ.hasClass('closed')
				ce.consoleJ.css( height: consoleHeight or ce.consoleHeight ).removeClass('closed')
				ce.consoleCloseBtnJ.find('.glyphicon').removeClass('glyphicon-chevron-up').addClass('glyphicon-chevron-down')
				ce.editor.resize()
			return

		ce.consoleCloseBtnJ.click ()->
			if ce.consoleJ.hasClass('closed')
				ce.openConsole()
			else
				ce.closeConsole()
			return

		ce.mousemove = (event)->
			if ce.draggingEditor
					ce.editorJ.css( right: window.innerWidth-event.pageX)
				if ce.draggingConsole
					footerHeight = ce.footerJ.outerHeight()
					bottom = ce.editorJ.outerHeight() - footerHeight
					height = Math.min(bottom - event.pageY, window.innerHeight - footerHeight )
					ce.consoleJ.css( height: height )
					minHeight = 20
					if ce.consoleJ.hasClass('closed') 			# the console is closed
						if height > minHeight 						# user manually opened it
							ce.openConsole(height)
					else 										# the console is opened
						if height <= minHeight 						# user manually closed it
							ce.closeConsole(200)

			return

		ce.editorJ.bind "transitionend webkitTransitionEnd oTransitionEnd MSTransitionEnd", ()->
			g.codeEditor.editor.resize()
			return

		ce.mouseup = (event)->
			if ce.draggingEditor or ce.draggingConsole
				g.codeEditor.editor.resize()
			ce.draggingEditor = false
			ce.draggingConsole = false
			$("body").css('user-select': 'text')
			return

		# ce.consoleJ.css( height: ce.codeJ.offset().top + ce.codeJ.outerHeight() )

		# initialize source selector
		for pathClass in g.pathClasses
			ce.sourceSelectorJ.append($("<option>").append(pathClass.name))

		# ce.sourceSelectorJ.append($("<option>").append(PrecisePath.name))
		# ce.sourceSelectorJ.append($("<option>").append(RectangleShape.name))
		# ce.sourceSelectorJ.append($("<option>").append(SpiralShape.name))
		# ce.sourceSelectorJ.append($("<option>").append(SketchPath.name))
		# ce.sourceSelectorJ.append($("<option>").append(SpiralPath.name))
		# ce.sourceSelectorJ.append($("<option>").append(ShapePath.name))
		# ce.sourceSelectorJ.append($("<option>").append(StarShape.name))
		# ce.sourceSelectorJ.append($("<option>").append(EllipseShape.name))
		# ce.sourceSelectorJ.append($("<option>").append(ThicknessPath.name))
		# ce.sourceSelectorJ.append($("<option>").append(FuzzyPath.name))

		# add saved sources to source selector
		if localStorage.romanescoCode? and localStorage.romanescoCode.length>0
			for name, source of JSON.parse(localStorage.romanescoCode)
				ce.sourceSelectorJ.append($("<option>").append("saved - " + name))

		# set code editor value to selected source when source selection changed
		ce.sourceSelectorJ.change ()->
			source = ""
			if this.value.indexOf("saved - ")>=0	# if selected option starts with 'saved': read source from localStorage
				source = JSON.parse(localStorage.romanescoCode)[this.value.replace("saved - ", "")]
			if g[this.value]?						# if selected option is an property of 'g': take source from g[this.value]
				source = g[this.value].source
			if source.length>0 then ce.editor.getSession().setValue( source ) 		# set code editor value to selected source
			return

		# save code changes 1 second after user modifies the source
		# extract class name and update localStorage.romanescoCode record
		# This is a poor and dirty implementation which must be updated
		saveChanges = ()->
			# romanescoCode is a map of className -> source code, it is JSON stringified/parsed when read/written from/to localStorage
			romanescoCode = {}
			if localStorage.romanescoCode? and localStorage.romanescoCode.length>0
				romanescoCode = JSON.parse(localStorage.romanescoCode)

			source = ce.editor.getValue() 	# get source

			# extract class name
			className = ''

			# try to extract className when the code is a class
			firstLineRegExp = /class {1}([A-Z]\w+) extends g.{1}(PrecisePath|SpeedPath|RShape){1}\n/
			firstLineResult = firstLineRegExp.exec(source)
			if firstLineResult? and firstLineResult.length >= 2
				className = firstLineResult[1]
			else
				# try to extract className when it is a script
				firstLineRegExp = /scriptName = {1}(("|')\w+("|'))\n/
				firstLineResult = firstLineRegExp.exec(source)
				if firstLineResult? and firstLineResult.length>=1
					className = firstLineResult[1]
				else 	# if no className: return (we do not save)
					return

			# return if source did not change or if className is not known (do not save)
			if not g[className]? or source == g[className].source then return

			# update romanescoCode
			romanescoCode[className] = source
			# save stringified version to local storage
			localStorage.romanescoCode = JSON.stringify(romanescoCode)

			return

		# save the code in localStorage after 1 second
		ce.editor.getSession().on 'change', (e)->
			g.deferredExecution(saveChanges, 'saveChanges', 1000)
			return

		# todo: try compile at each change, see if name is in DB to determine if it's a update or a new tool and make notice to user
		# ce.editor.getSession().on 'change', (e)->
		# 	newToolName = compileSource()
		# 	if newToolName != 'error'
		# 		pushRequestBtnJ
		# 	return

		# editor.setOptions( maxLines: 300 )
		# submitBtnJ = ce.editorJ.find("button.submit.tool")
		# submitBtnJ.click (event)->
		# 	g.addTool()
		# 	return

		# initialize run button handler
		runBtnJ = ce.editorJ.find("button.submit.run")
		runBtnJ.click (event)->
			g.runScript()	# compile and run the script in code editor
			return

		ce.pushRequest = ()->
			tool = g.compileSource()
			if not tool.name? or tool.name == ''
				g.romanesco_alert "You must set a name for the module."
				return
			if tool?
				args =
					name: tool.name
					className: tool.className
					source: tool.source
					compiledSource: tool.compiledSource
					iconURL: tool.iconURL
				Dajaxice.draw.addOrUpdateModule(g.checkError, args)
				# if ce.editor.newTool
				# 	args.isTool = tool.isTool
				# 	Dajaxice.draw.addModule(g.checkError, args)
				# else
				# 	# ajaxPost '/updateTool', { 'name': tool.name, 'className': tool.className, 'source': tool.source, 'compiledSource': tool.compiledSource }, toolUpdateCallback
				# 	Dajaxice.draw.updateModule(g.checkError, args)
			return

		# push request button handler: compile source and add or update tool
		ce.pushRequestBtnJ.click (event)->
			ce.pushRequest()
			return

		# close button handler: hide code editor and reset default console.log and console.error functions
		closeBtnJ = ce.editorJ.find("button.close-editor")
		closeBtnJ.click (event)->
			ce.editorJ.hide()
			console.log = console.olog
			console.error = console.oerror
			return

		# get the default console.log and console.error functions, to log in a div (have console message displayed on a div in the document)
		if typeof console != 'undefined'
			console.olog = console.log or ()->return
			console.oerror = console.error or ()->return

		# custom log function: log to the console and to the console div
		g.logMessage = (message)->
			if typeof message != 'string' or not message instanceof String
				message = JSON.stringify(message)
			ce.consoleContentJ.append( $("<p>").append(message) )
			ce.consoleContentJ.scrollTop(ce.consoleContentJ[0].scrollHeight)
			ce.openConsole()
			return

		# custom error function: log to the console and to the console div
		g.logError = (message)->
			ce.consoleContentJ.append( $("<p>").append(message).addClass("error") )
			ce.consoleContentJ.scrollTop(ce.consoleContentJ[0].scrollHeight)
			ce.openConsole()
			message = "An error occured, you can open the debug console (Command + Option + I)"
			message += " to have more information about the problem."
			g.romanesco_alert message, "info"
			return

		# console.log and console.error will be set to the custom g.logMessage and g.logError when code editor will be shown, like so:
		# console.log = g.logMessage
		# console.error = g.logError
		# this means that all logs and errors will be displayed both in the console and in the console div when code editor is opened

		g.log = console.log 	# log is a shortcut/synonym to console.log


	# Compile source code:
	# - extract className and rname and determine whether it is a simple script or a path class
	# @return [{ name: String, className: String, source: String, compiledSource: String, isTool: Boolean }] the compiled script in an object with the source, compiled source, class name, etc.

	g.compileSource = ()->

		source = ce.editor.getValue()
		className = ''
		compiledJS = ''
		rname = ce.moduleInputJ.val()
		iconURL = ''
		isTool = false

		try
			# extract className and rname and determine whether it is a simple script or a path class

			# a nice regex tool can be found here: http://regex101.com/r/zT9iI1/1
			# allRegExp = /class {1}(\w+) extends {1}(PrecisePath|SpeedPath){1}\n\s+@rname = {1}(\'.*)\n{1}[\s\S]*(drawBegin: \(\)->|drawUpdate: \(length\)->|drawEnd: \(\)->)[\s\S]*/
			# result = allRegExp.exec(source)

			firstLineRegExp = /class {1}([A-Z]\w+) extends g.{1}(PrecisePath|SpeedPath|RShape){1}\n/

			firstLineResult = firstLineRegExp.exec(source)

			isTool = firstLineResult? and firstLineResult.length >= 2

			iconResult = /@?iconURL = {1}((\'|\"|\"\"\").*(\'|\"|\"\"\"))/.exec(source)

			if iconResult? and iconResult.length>=1
				iconURL = iconResult[1]

			if isTool
				className = firstLineResult[1]
				superClass = firstLineResult[2]
				source += "\ng." + className + " = " + className
			# else
				# throw { location: 1, message: 'The code must begin with "class YourToolName extends SuperClass".\nSuperClass can be
				# "PrecisePath", "SpeedPath" or "RShape".\n"YourToolName" can be any word starting with a captial letter.' }

				rnameResult = /@rname = {1}(\'.*)/.exec(source)
				if rnameResult? and rnameResult.length>=1
					rname = rnameResult[1]
				else
					message = '@rname is not correctly set. There must be something like @rname = "your path name"'
					throw location: 'NA', message: message
			# else
			# 	firstLineRegExp = /scriptName = {1}(("|')\w+("|'))\n/
			# 	firstLineResult = firstLineRegExp.exec(source)
			# 	if firstLineResult? and firstLineResult.length>=1
			# 		rname = firstLineResult[1]
			# 		className = rname
			# 	else
			# 		throw
			# 			location: 'NA',
			# 			message: """scriptName or class name is not correctly set.
			# 			Your script can be either a general script or a path script.
			# 			A general script must begin with 'scriptName = "yourScriptName"'.
			# 			A path script must begin with "class YourPathName extends g.SuperClass".
			# 			SuperClass can be "PrecisePath", "SpeedPath" or "RShape".
			# 			There must not be any comment or white character at the end of the first line.
			# 			"""

			# if /(drawBegin: \(\)->|drawUpdate: \(length\)->|drawEnd: \(\)->)/.exec(source).length==0
			# 	throw { 1, 'The methods drawBegin, drawUpdate or drawEnd must be defined.' }

			compiledJS = CoffeeScript.compile source, bare: on 			# compile coffeescript to javascript

			# update ui: hide console div
			# ce.consoleJ.removeClass 'error'
			# ce.codeJ.removeClass 'message'

		catch {location, message} 	# compilation error, or className was not found: log & display error
			if location?
				errorMessage = "Error on line #{location.first_line + 1}: #{message}"
				if message == "unmatched OUTDENT"
					errorMessage += "\nThis error is generally due to indention problem or unbalanced parenthesis/brackets/braces."
			console.error errorMessage
			return null

		return  { name: rname, className: className, source: source, compiledSource: compiledJS, isTool: isTool, iconURL: iconURL }

	# this.addTool = (tool)->
	# 	justCreated = not tool?
	# 	tool ?= compileSource()
	# 	if tool?
	# 		# Eval the compiled js.
	# 		try

	# 			eval tool.compiledSource
	# 			if g.tools[tool.rname]?
	# 				g.tools[tool.rname].remove()
	# 				delete this[tool.className]
	# 			newTool = new PathTool(this[tool.className], justCreated)
	# 			newTool.constructor.source = tool.source
	# 			if justCreated then newTool.select()
	# 		catch error
	# 			console.error error
	# 			return null
	# 	return tool

	# run script and create path tool if script is a path class
	# if *script* is not provided, the content of the code editor is compiled and taken as the script
	# called by the run button in the code editor (then the content of the code editor is compiled and taken as the script)
	# and when loading tools from database (then the script is given with its compiled version)
	# @return [{ name: String, className: String, source: String, compiledSource: String, isTool: Boolean }] the compiled
	#			script in an object with the source, compiled source, class name, etc.
	g.runScript = (script)->
		justCreated = not script?
		script ?= g.compileSource()
		if script?
			# Eval the compiled js.
			try
				console.log eval script.compiledSource
				# model = window[script.compiledSource] # Use square brackets instead?
				if script.isTool 							# if the script is a tool (or more exactly a path class)
					if g.tools[script.rname]? 				# remove the tool with the same name if exists, create the new Path tool and select it
						g.tools[script.rname].remove()
						delete this[script.className]
					className = null
					if script.originalClassName? and script.originalClassName.length>0
						className = script.originalClassName
					else
						className = script.className
					newTool = new g.PathTool(this[className], justCreated)
					newTool.RPath.source = script.source
					# newTool.constructor.source = script.source
					if justCreated then newTool.select()
			catch error 									# display and throw error if any
				console.error error
				throw error
				return null
		return script

	# show the tool editor (and set code editor content)
	# @param [RPath constructor] optionnal: set RPath.source as the content of the code editor if not null, set the example source otherwise
	g.toolEditor = (RPath)->
		ce.editor.getSession().setValue(if RPath? then RPath.source else g.codeExample)
		editorJ = ce.editorJ
		editorJ.show()
		console.log = g.logMessage
		console.error = g.logError
		editorJ.rNewtool = not RPath?
		if RPath?
			g.codeEditor.pushRequestBtnJ.text('Push request (update "' + RPath.rname + '" tool)')
		else
			g.codeEditor.pushRequestBtnJ.text('Push request (create new tool)')
		return

	## Administration functions to test and accept tools (which are not validated yet)

	# set tool as accepted in the database
	g.acceptTool = (tool)->
		acceptToolCallback = (result)-> g.checkError(result)
		# ajaxPost '/acceptTool', { 'name':tool.name }, acceptToolCallback
		Dajaxice.draw.acceptTool( acceptToolCallback, { 'name': tool.name } )
		return

	# get tools which are not accepted yet, and put them in g.waitingTools
	g.getWaitingTools = (value)->

		getWaitingToolsCallback = (result)->
			if g.checkError(result)
				g.waitingTools = JSON.parse(result.tools)
				console.log g.waitingTools
			return

		# ajaxPost '/getWaitingTools', { }, getWaitingToolsCallback
		Dajaxice.draw.getWaitingTools( getWaitingToolsCallback, {} )
		return

	return