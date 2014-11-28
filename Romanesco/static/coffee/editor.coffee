# --- Code editor --- #

# todo: bug when modifying (click edit btn) a tool existing in DB: the editor do not show the code.

this.initCodeEditor = ()->

	# editor
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

	g.sourceSelectorJ.append($("<option>").append(PrecisePath.name))
	g.sourceSelectorJ.append($("<option>").append(RectangleShape.name))
	g.sourceSelectorJ.append($("<option>").append(SpiralShape.name))
	g.sourceSelectorJ.append($("<option>").append(SketchPath.name))
	g.sourceSelectorJ.append($("<option>").append(SpiralPath.name))
	g.sourceSelectorJ.append($("<option>").append(ShapePath.name))
	g.sourceSelectorJ.append($("<option>").append(StarShape.name))
	g.sourceSelectorJ.append($("<option>").append(EllipseShape.name))
	g.sourceSelectorJ.append($("<option>").append(RollerPath.name))
	g.sourceSelectorJ.append($("<option>").append(FuzzyPath.name))

	if localStorage.romanescoCode? and localStorage.romanescoCode.length>0
		for name, source of JSON.parse(localStorage.romanescoCode)
			g.sourceSelectorJ.append($("<option>").append("saved - " + name))

	g.sourceSelectorJ.change ()->
		source = ""
		if this.value.indexOf("saved - ")>=0
			source = JSON.parse(localStorage.romanescoCode)[this.value.replace("saved - ", "")]
		if g[this.value]?
			source = g[this.value].source
		if source.length>0 then g.editor.getSession().setValue( source )
		return

	g.editor = ace.edit("codeEditorContent")
	g.editor.setTheme("ace/theme/monokai")
	# g.editor.setShowInvisibles(true)
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

		  drawUpdate: (length)->

		    point = @controlPath.getPointAt(length)
		    @path.add(point)
		    return

		  drawEnd: ()->
		    return

		""", 1)

	saveChanges = ()->
		romanescoCode = if localStorage.romanescoCode? and localStorage.romanescoCode.length>0 then JSON.parse(localStorage.romanescoCode) else {}

		source = g.editor.getValue()
		className = ''

		firstLineRegExp = /class {1}([A-Z]\w+) extends {1}(PrecisePath|SpeedPath|RShape){1}\n/
		firstLineResult = firstLineRegExp.exec(source)
		if firstLineResult? and firstLineResult.length >= 2
			className = firstLineResult[1]
		else
			return
		
		if not g[className]? or source == g[className].source
			return

		romanescoCode[className] = source
		localStorage.romanescoCode = JSON.stringify(romanescoCode)

		return

	# save the code in localStorage
	g.editor.getSession().on 'change', (e)->
		g.defferedExecution(saveChanges, 1000)
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

	runBtnJ = g.editorJ.find("button.submit.run")
	runBtnJ.click (event)->
		g.runScript()
		return

	toolUpdate_callback = (result)=>
		g.checkError(result)
		return

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

	closeBtnJ = g.editorJ.find("button.close-editor")
	closeBtnJ.click (event)-> 
		g.editorJ.hide()
		console.log = console.olog
		console.error = console.oerror
		return

	closeMessageBoxBtnJ = g.editorJ.find("button.close-message-box")
	closeMessageBoxBtnJ.click (event)-> 
		g.messageBoxJ.hide()
		g.codeEditorContentJ.removeClass 'message'
		return

	# log in div console
	if typeof console  != 'undefined'
		console.olog = console.log or ()->return
		console.oerror = console.error or ()->return
		# console.odebug = console.debug or ()->return
		# console.oinfo = console.info or ()->return

	g.logMessage = (message)->
		console.olog(message)
		g.messageBoxContentJ.append( $("<p>").append(message) )
		g.messageBoxContentJ.scrollTop(g.messageBoxContentJ[0].scrollHeight)
		g.messageBoxJ.show()
		return

	g.logError = (message)->
		# console.oerror(message)
		g.messageBoxContentJ.append( $("<p>").append(message).addClass("error") )
		g.messageBoxContentJ.scrollTop(g.messageBoxContentJ[0].scrollHeight)
		g.messageBoxJ.show()
		romanesco_alert "An error occured, you can open the debug console (Command + Option + I) to have more information about the problem.", "info"
		return

	g.log = console.log

this.compileSource = ()->
	
	# g.editor.getSession().setTabSize(4)
	# http://regex101.com/r/zT9iI1/1

	source = g.editor.getValue()
	className = ''
	compiledJS = ''
	rname = ''
	isTool = false

	try
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
					Your script can be either a normal script or a tool class.
					A normal script must begin with 'scriptName = "yourScriptName"'.
					A tool class must begin with "class YourToolName extends SuperClass".\nSuperClass can be "PrecisePath", "SpeedPath" or "RShape".
					There must not be any comment or white character after the first line.
					"""

		# if /(drawBegin: \(\)->|drawUpdate: \(length\)->|drawEnd: \(\)->)/.exec(source).length==0
		# 	throw { 1, 'The methods drawBegin, drawUpdate or drawEnd must be defined.' }

		compiledJS = CoffeeScript.compile source, bare: on

		g.messageBoxJ.removeClass 'error'
		g.messageBoxJ.hide()
		g.codeEditorContentJ.removeClass 'message'

	catch {location, message}
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

this.runScript = (script)->
	justCreated = not script?
	script ?= compileSource()
	if script?
		# Eval the compiled js.
		try
			eval script.compiledSource
			if script.isTool
				if g.tools[script.rname]?
					g.tools[script.rname].remove()
					delete this[script.className]
				className = if script.originalClassName? and script.originalClassName.length>0 then script.originalClassName else script.className
				newTool = new PathTool(this[className], justCreated)
				newTool.RPath.source = script.source
				# newTool.constructor.source = script.source
				if justCreated then newTool.select()
		catch error 
			console.error error
			throw error
			return null
	return script

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
	
this.acceptTool = (tool)->
	acceptTool_callback = (result)-> g.checkError(result)
	# ajaxPost '/acceptTool', { 'name':tool.name }, acceptTool_callback
	Dajaxice.draw.acceptTool( acceptTool_callback, { 'name': tool.name } )
	return

this.getWaitingTools = (value)->

	getWaitingTools_callback = (result)->
		if g.checkError(result)
			g.waitingTools = JSON.parse(result.tools)
			console.log g.waitingTools
		return

	# ajaxPost '/getWaitingTools', { }, getWaitingTools_callback
	Dajaxice.draw.getWaitingTools( getWaitingTools_callback, {} )
	return
