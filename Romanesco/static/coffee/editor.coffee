# --- Code editor --- #

# todo: bug when modifying (click edit btn) a tool existing in DB: the editor do not show the code.

# initialize code editor
this.initCodeEditor = ()->

	# initialiaze jQuery elements
	g.editorJ = $(document.body).find("#codeEditor")
	g.sourceSelectorJ = g.editorJ.find(".source-selector")
	g.messageBoxJ = g.editorJ.find(".message-box")
	g.messageBoxContentJ = g.messageBoxJ.find(".content")
	g.codeEditorContentJ = g.editorJ.find("#codeEditorContent")
	g.pushRequestBtnJ = g.editorJ.find("button.request")
	g.codeEditorHandle = g.editorJ.find("div.handle")
	g.codeEditorHandle.mousedown ()->
		g.draggingEditor = true
		return

	# initialize source selector
	for pathClass in pathClasses
		g.sourceSelectorJ.append($("<option>").append(pathClass.name))

	# g.sourceSelectorJ.append($("<option>").append(PrecisePath.name))
	# g.sourceSelectorJ.append($("<option>").append(RectangleShape.name))
	# g.sourceSelectorJ.append($("<option>").append(SpiralShape.name))
	# g.sourceSelectorJ.append($("<option>").append(SketchPath.name))
	# g.sourceSelectorJ.append($("<option>").append(SpiralPath.name))
	# g.sourceSelectorJ.append($("<option>").append(ShapePath.name))
	# g.sourceSelectorJ.append($("<option>").append(StarShape.name))
	# g.sourceSelectorJ.append($("<option>").append(EllipseShape.name))
	# g.sourceSelectorJ.append($("<option>").append(ThicknessPath.name))
	# g.sourceSelectorJ.append($("<option>").append(FuzzyPath.name))

	# add saved sources to source selector
	if localStorage.romanescoCode? and localStorage.romanescoCode.length>0 
		for name, source of JSON.parse(localStorage.romanescoCode)
			g.sourceSelectorJ.append($("<option>").append("saved - " + name))

	# set code editor value to selected source when source selection changed
	g.sourceSelectorJ.change ()->
		source = ""
		if this.value.indexOf("saved - ")>=0	# if selected option starts with 'saved': read source from localStorage
			source = JSON.parse(localStorage.romanescoCode)[this.value.replace("saved - ", "")]
		if g[this.value]?						# if selected option is an property of 'g': take source from g[this.value]
			source = g[this.value].source
		if source.length>0 then g.editor.getSession().setValue( source ) 		# set code editor value to selected source
		return

	# initialize ace editor
	g.editor = ace.edit("codeEditorContent")
	g.editor.setTheme("ace/theme/monokai")
	# g.editor.setShowInvisibles(true)
	# g.editor.getSession().setTabSize(4)
	g.editor.getSession().setUseSoftTabs(false)
	g.editor.getSession().setMode("ace/mode/coffee")
	g.editor.getSession().setValue("""
		class TestPath extends PrecisePath
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

	# save code changes 1 second after user modifies the source
	# extract class name and update localStorage.romanescoCode record
	# This is a poor and dirty implementation which must be updated
	saveChanges = ()->
		# romanescoCode is a map of className -> source code, it is JSON stringified/parsed when read/written from/to localStorage
		romanescoCode = if localStorage.romanescoCode? and localStorage.romanescoCode.length>0 then JSON.parse(localStorage.romanescoCode) else {}

		source = g.editor.getValue() 	# get source

		# extract class name
		className = ''

		# try to extract className when the code is a class
		firstLineRegExp = /class {1}([A-Z]\w+) extends {1}(PrecisePath|SpeedPath|RShape){1}\n/
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
		
		if not g[className]? or source == g[className].source then return 		# return if source did not change or if className is not known (do not save)

		romanescoCode[className] = source 										# update romanescoCode
		localStorage.romanescoCode = JSON.stringify(romanescoCode) 				# save stringified version to local storage

		return

	# save the code in localStorage after 1 second
	g.editor.getSession().on 'change', (e)->
		g.deferredExecution(saveChanges, 1000)
		return

	# todo: try compile at each change, see if name is in DB to determine if it's a update or a new tool and make notice to user
	# g.editor.getSession().on 'change', (e)->
	# 	newToolName = compileSource()
	# 	if newToolName != 'error'
	# 		pushRequestBtnJ
	# 	return

	# editor.setOptions( maxLines: 300 )
	# submitBtnJ = g.editorJ.find("button.submit.tool")
	# submitBtnJ.click (event)->
	# 	g.addTool()
	# 	return

	# initialize run button handler
	runBtnJ = g.editorJ.find("button.submit.run")
	runBtnJ.click (event)->
		g.runScript()	# compile and run the script in code editor
		return

	# just check for an error message on tool update callback
	toolUpdate_callback = (result)=>
		g.checkError(result)
		return

	# push request button handler: compile source and add or update tool
	g.pushRequestBtnJ.click (event)->
		tool = compileSource()
		if tool?
			if g.editorJ.rNewtool
				# ajaxPost '/addTool', { 'name': tool.name, 'className': tool.className, 'source': tool.source, 'compiledSource': tool.compiledSource }, toolUpdate_callback
				Dajaxice.draw.addTool( toolUpdate_callback, { 'name': tool.name, 'className': tool.className, 'source': tool.source, 'compiledSource': tool.compiledSource, 'isTool': tool.isTool } )
			else
				# ajaxPost '/updateTool', { 'name': tool.name, 'className': tool.className, 'source': tool.source, 'compiledSource': tool.compiledSource }, toolUpdate_callback
				Dajaxice.draw.updateTool( toolUpdate_callback, { 'name': tool.name, 'className': tool.className, 'source': tool.source, 'compiledSource': tool.compiledSource } )
		return

	# close button handler: hide code editor and reset default console.log and console.error functions
	closeBtnJ = g.editorJ.find("button.close-editor")
	closeBtnJ.click (event)-> 
		g.editorJ.hide()
		console.log = console.olog
		console.error = console.oerror
		return

	# close console button handler: hide message box
	closeMessageBoxBtnJ = g.editorJ.find("button.close-message-box")
	closeMessageBoxBtnJ.click (event)-> 
		g.messageBoxJ.hide()
		g.codeEditorContentJ.removeClass 'message'
		return

	# get the default console.log and console.error functions, to log in a div (have console message displayed on a div in the document)
	if typeof console  != 'undefined'
		console.olog = console.log or ()->return
		console.oerror = console.error or ()->return

	# custom log function: log to the console and to the console div
	g.logMessage = (message)->
		console.olog(message)
		g.messageBoxContentJ.append( $("<p>").append(message) )
		g.messageBoxContentJ.scrollTop(g.messageBoxContentJ[0].scrollHeight)
		g.messageBoxJ.show()
		return

	# custom error function: log to the console and to the console div
	g.logError = (message)->
		# console.oerror(message)
		g.messageBoxContentJ.append( $("<p>").append(message).addClass("error") )
		g.messageBoxContentJ.scrollTop(g.messageBoxContentJ[0].scrollHeight)
		g.messageBoxJ.show()
		romanesco_alert "An error occured, you can open the debug console (Command + Option + I) to have more information about the problem.", "info"
		return

	# console.log and console.error will be set to the custom g.logMessage and g.logError when code editor will be shown, like so:
	# console.log = g.logMessage
	# console.error = g.logError
	# this means that all logs and errors will be displayed both in the console and in the console div when code editor is opened

	g.log = console.log 	# log is a shortcut/synonym to console.log

# Compile source code:
# - extract className and rname and determine whether it is a simple script or a path class
# @return [{ name: String, className: String, source: String, compiledSource: String, isTool: Boolean }] the compiled script in an object with the source, compiled source, class name, etc.
this.compileSource = ()->
	
	source = g.editor.getValue()
	className = ''
	compiledJS = ''
	rname = ''
	isTool = false

	try
		# extract className and rname and determine whether it is a simple script or a path class

		# a nice regex tool can be found here: http://regex101.com/r/zT9iI1/1
		# allRegExp = /class {1}(\w+) extends {1}(PrecisePath|SpeedPath){1}\n\s+@rname = {1}(\'.*)\n{1}[\s\S]*(drawBegin: \(\)->|drawUpdate: \(length\)->|drawEnd: \(\)->)[\s\S]*/
		# result = allRegExp.exec(source)

		firstLineRegExp = /class {1}([A-Z]\w+) extends {1}(PrecisePath|SpeedPath|RShape){1}\n/

		firstLineResult = firstLineRegExp.exec(source)

		isTool = firstLineResult? and firstLineResult.length >= 2

		if isTool
			className = firstLineResult[1]
			superClass = firstLineResult[2]
			source += "\n@" + className + " = " + className
		# else
		# 	throw { location: 1, message: 'The code must begin with "class YourToolName extends SuperClass".\nSuperClass can be "PrecisePath", "SpeedPath" or "RShape".\n"YourToolName" can be any word starting with a captial letter.' }

			rnameResult = /@rname = {1}(\'.*)/.exec(source)
			if rnameResult? and rnameResult.length>=1
				rname = rnameResult[1]
			else
				throw { location: 'NA', message: '@rname is not correctly set. There must be something like @rname = "your path name"' }
		else
			firstLineRegExp = /scriptName = {1}(("|')\w+("|'))\n/
			firstLineResult = firstLineRegExp.exec(source)
			if firstLineResult? and firstLineResult.length>=1
				rname = firstLineResult[1]
				className = rname
			else
				throw
					location: 'NA', 
					message: """scriptName or class name is not correctly set.
					Your script can be either a general script or a path script.
					A general script must begin with 'scriptName = "yourScriptName"'.
					A path script must begin with "class YourPathName extends SuperClass".\nSuperClass can be "PrecisePath", "SpeedPath" or "RShape".
					There must not be any comment or white character at the end of the first line.
					"""

		# if /(drawBegin: \(\)->|drawUpdate: \(length\)->|drawEnd: \(\)->)/.exec(source).length==0
		# 	throw { 1, 'The methods drawBegin, drawUpdate or drawEnd must be defined.' }

		compiledJS = CoffeeScript.compile source, bare: on 			# compile coffeescript to javascript

		# update ui: hide console div
		g.messageBoxJ.removeClass 'error'
		g.messageBoxJ.hide()
		g.codeEditorContentJ.removeClass 'message'

	catch {location, message} 	# compilation error, or className was not found: log & display error
		if location?
			errorMessage = "Error on line #{location.first_line + 1}: #{message}"
			if message == "unmatched OUTDENT"
				errorMessage += "\nThis error is generally due to indention problem or unbalanced parenthesis/brackets/braces."
		console.error errorMessage
		return null
	
	return  { name: rname, className: className, source: source, compiledSource: compiledJS, isTool: isTool }

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
# @return [{ name: String, className: String, source: String, compiledSource: String, isTool: Boolean }] the compiled script in an object with the source, compiled source, class name, etc.
this.runScript = (script)->
	justCreated = not script?
	script ?= compileSource()
	if script?
		# Eval the compiled js.
		try
			eval script.compiledSource
			# model = window[script.compiledSource] # Use square brackets instead?
			if script.isTool 							# if the script is a tool (or more exactly a path class)
				if g.tools[script.rname]? 				# remove the tool with the same name if exists, create the new path tool and select it
					g.tools[script.rname].remove()
					delete this[script.className]
				className = if script.originalClassName? and script.originalClassName.length>0 then script.originalClassName else script.className
				newTool = new PathTool(this[className], justCreated)
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
this.toolEditor = (RPath)->
	g.editor.getSession().setValue(if RPath? then RPath.source else g.codeExample)
	g.editorJ.show()
	console.log = g.logMessage
	console.error = g.logError
	g.editorJ.rNewtool = not RPath?
	if RPath?
		g.pushRequestBtnJ.text('Push request (update "' + RPath.rname + '" tool)')
	else
		g.pushRequestBtnJ.text('Push request (create new tool)')
	return

## Administration functions to test and accept tools (which are not validated yet)

# set tool as accepted in the database
this.acceptTool = (tool)->
	acceptTool_callback = (result)-> g.checkError(result)
	# ajaxPost '/acceptTool', { 'name':tool.name }, acceptTool_callback
	Dajaxice.draw.acceptTool( acceptTool_callback, { 'name': tool.name } )
	return

# get tools which are not accepted yet, and put them in g.waitingTools
this.getWaitingTools = (value)->

	getWaitingTools_callback = (result)->
		if g.checkError(result)
			g.waitingTools = JSON.parse(result.tools)
			console.log g.waitingTools
		return

	# ajaxPost '/getWaitingTools', { }, getWaitingTools_callback
	Dajaxice.draw.getWaitingTools( getWaitingTools_callback, {} )
	return
