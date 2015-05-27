define [
	'utils', 'coffee', 'ace', 'aceTools', 'jquery', 'typeahead'
], (utils, CoffeeScript) ->

	if not ace?
		require ['ace'], ()->
			console.log "ace: " + ace
			return

	g = utils.g()

	# --- Code editor --- #

	# todo: bug when modifying (click edit btn) a module existing in DB: the editor do not show the code.
	g.codeEditor = {}
	ce = g.codeEditor
	ce.module = null
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

		ce.setSourceFromServer = (result)->
			if not g.checkError(result) then return
			module = JSON.parse(result.module)
			if module.lock?
				module.lock = g.items[module.lock.$oid]
			if not module.lock?
				g.romanesco_alert "The module is linked with a lock, but the lock is not loaded.", "warning"
			ce.setSource(module)
			return

		ce.setSource = (module)->
			ce.editor.getSession().setValue( module.source )
			ce.module = module
			g.codeEditor.pushRequestBtnJ.text('Push request (update "' + module.name + '" module)')
			return

		ce.initializeNewModuleFromName = (moduleName='NewPath', lock=null)->
			if not lock?
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
				source += "tool = new g.PathTool(#{moduleName}, true)"
			else
				source = ""
			ce.editor.getSession().setValue( source )
			ce.module = null
			if lock?
				ce.module = type: 'lock', lock: lock, newModule: true
			g.codeEditor.pushRequestBtnJ.text('Push request (create new module)')
			return

		input.keyup (event)->
			if event.which == 13 # return key
				input.typeahead('close')
			return

		input.on 'typeahead:closed', ()->
			moduleName = input.val()
			if moduleName == '' then return

			if ce.moduleNameValue == moduleName 	# the module exists
				if g.modules[moduleName]?
					ce.setSource(g.modules[moduleName])
				else
					Dajaxice.draw.getModuleSource(ce.setSourceFromServer, name: moduleName)
			else 							# the module does not exist
				ce.initializeNewModuleFromName(moduleName)
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

	ce.loadModule = (event)->
		moduleName = $(this).attr("data-name")
		if g.modules[moduleName]?
			if g.modules[moduleName].source?
				g.codeEditor.setSource(g.modules[moduleName], false)
			else
				Dajaxice.draw.getModuleSource(ce.setSourceFromServer, name: moduleName)
		else
			owner = $(this).attr("data-owner")
			jqxhr = $.get "https://api.github.com/repos/" + owner + "/" + moduleName + "/contents/main.coffee", (data)->
				if data.content?
					source = atob(data.content)
					g.codeEditor.setSource( { name: moduleName, source: source, githubURL: data.html_url }, false)
				return
		g.RModal.hide()
		return

	ce.createModuleEditorModal = (result)->
		if not g.checkError(result) then return

		modules = JSON.parse(result.modules)
		acceptedGithubURLs = []

		for module in modules
			g.modules[module.name] = module
			acceptedGithubURLs.push(module.githubURL)

		g.createModuleModal("Romanesco modules", ce.loadModule)

		# window.XMLHttpRequest = RXMLHttpRequest
		jqxhr = $.get "https://api.github.com/search/repositories?q=romanesco+module", (data)->
			console.log "success"
			console.log data
			for item in data.items
				if item.html_url in acceptedGithubURLs then continue
				module =
					name: item.name
					owner: item.owner.login
					githubURL: item.html_url
					accepted: no
				g.addModuleToModal(item.name, module, g.RModal.modalJ.find('tbody'), ce.loadModule)
			# window.XMLHttpRequest = g.DajaxiceXMLHttpRequest
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
		ce.openModalBtnJ = ce.editorJ.find(".open-modal")

		ce.openModalBtnJ.click (event)->
			Dajaxice.draw.getModuleList(ce.createModuleEditorModal)
			return

		# initialize ace editor
		# ace.require("ace/ext/language_modules")

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
				ce.consoleJ.removeClass("highlight")
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

		# todo: try compile at each change, see if name is in DB to determine if it's a update or a new module and make notice to user
		# ce.editor.getSession().on 'change', (e)->
		# 	newModuleName = compileSource()
		# 	if newModuleName != 'error'
		# 		pushRequestBtnJ
		# 	return

		# editor.setOptions( maxLines: 300 )
		# submitBtnJ = ce.editorJ.find("button.submit.module")
		# submitBtnJ.click (event)->
		# 	g.addModule()
		# 	return

		# initialize run button handler
		runBtnJ = ce.editorJ.find("button.submit.run")
		runBtnJ.click (event)->
			g.runScript()	# compile and run the script in code editor
			return

		ce.pushRequest = (data)->
			if ce.module?.coreModule
				g.RModal.alert("Use the main <a href='https://github.com/RomanescoModules/Romanesco'>Romanesco repository</a> to update core modules.")
				return

			module = g.compileSource()

			if module?

				hasName = module.name? and module.name != ''
				hasDescription = module.description? and module.description != ''

				callback = (results)->
					if not g.checkError(results)
						return
					g.RModal.modalJ.find(".modal-footer").show()
					g.RModal.initialize("Success")
					g.RModal.hideOnSubmit = true
					g.RModal.addText(results.message)
					textInputJ = g.RModal.addTextInput('githubURL', null, null, null, 'Github repository URL')
					textInputJ.find('input').val(results.githubURL).select().focus()
					g.RModal.show()
					ce.module.lock.addModule(results.modulePk)
					return

				submit = (data)->
					args =
						name: ce.module?.name or module.name or data.name
						source: module.source
						compiledSource: module.compiledSource
						iconURL: module.iconURL
						description: module.description or data.description
						commitDescription: data?.commitDescription
						githubURL: ce.module.githubURL
						category: data.category
						type: ce.module.type
						lockPk: ce.module.lock.pk
					Dajaxice.draw.addOrUpdateModule(callback, args)

					g.RModal.initialize("Loading")
					g.RModal.addText("Your request is being processed...")
					g.RModal.modalJ.find(".modal-footer").hide()
					return

				newModule = not ce.module? or ce.module.newModule
				if ( newModule and ( not hasName or not hasDescription ) ) or not newModule
					title = if newModule then 'Push new module' else 'Commit changes'
					g.RModal.initialize(title, submit, null, false)
					if newModule
						if not hasName
							g.RModal.addTextInput('name', 'Module name', null, null, 'Name', null, null, true)
						if not hasDescription
							g.RModal.addTextInput('description', 'Describe your module', null, null, 'Description', null, null, true)
					categoryJ = g.RModal.addTextInput('category', 'Optional category', null, null, 'Category')
					if ce.module?.category?
						categoryJ.text(ce.module.category)
					defaultCommitDescription = if newModule then 'initial commit' else 'Describe your changes'
					g.RModal.addTextInput('commitDescription', defaultCommitDescription, null, null, 'Commit description', null, null, not newModule)

					# radioButtons = [
					# 	{ value: 'button', checked: true, label: 'Button - A button will be created to execute the module.', submitShortcut: true }
					# 	{ value: 'lock', checked: false, label: 'Lock - The module will be executed when the lock is loaded.' }
					# 	{ value: 'initializer', checked: false, label: 'Initializer - The module will be executed when Romanesco loads.' }
					# ]

					# g.RModal.addRadioGroup('moduleType', radioButtons)

					g.RModal.show()
				else
					submit()


				# if ce.editor.newModule
				# 	args.isModule = module.isModule
				# 	Dajaxice.draw.addModule(g.checkError, args)
				# else
				# 	# ajaxPost '/updateModule', { 'name': module.name, 'className': module.className, 'source': module.source, 'compiledSource': module.compiledSource }, moduleUpdateCallback
				# 	Dajaxice.draw.updateModule(g.checkError, args)
			return

		# push request button handler: compile source and add or update module
		ce.pushRequestBtnJ.click (event)->
			ce.pushRequest()
			return

		# close button handler: hide code editor and reset default console.log and console.error functions
		closeBtnJ = ce.editorJ.find("button.close-editor")
		closeBtnJ.click (event)->
			ce.editorJ.hide()
			ce.editorJ.removeClass('visible')
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
			if ce.consoleJ.hasClass("closed")
				ce.consoleJ.addClass("highlight")
			# ce.openConsole()
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

		return

	# Compile source code:
	# - extract className and rname and determine whether it is a simple script or a path class
	# @return [{ name: String, className: String, source: String, compiledSource: String, isModule: Boolean }] the compiled script in an object with the source, compiled source, class name, etc.

	g.compileSource = (source, name)->

		source ?= ce.editor.getValue()
		className = ''
		compiledJS = ''
		name ?= ce.moduleInputJ.val()
		description = ''
		iconURL = ''

		try
			# extract className and rname and determine whether it is a simple script or a path class

			# a nice regex module can be found here: http://regex101.com/r/zT9iI1/1
			# allRegExp = /class {1}(\w+) extends {1}(PrecisePath|SpeedPath){1}\n\s+@rname = {1}(\'.*)\n{1}[\s\S]*(drawBegin: \(\)->|drawUpdate: \(length\)->|drawEnd: \(\)->)[\s\S]*/
			# result = allRegExp.exec(source)

			firstLineResult = /class ([A-Z]\w+) extends g.(PrecisePath|SpeedPath|RShape)\n/.exec(source)
			if firstLineResult? and firstLineResult.length>2
				className = firstLineResult[1]
				superClass = firstLineResult[2]
				# source += "\ntool = new g.PathTool(#{className}, true)"

			iconResult = /@?iconURL = (\'|\"|\"\"\")(.*)(\'|\"|\"\"\")/.exec(source)

			if iconResult? and iconResult.length>=2
				iconURL = iconResult[2]

			descriptionResult = /@?rdescription = (\'|\"|\"\"\")(.*)(\'|\"|\"\"\")/.exec(source)

			if descriptionResult? and descriptionResult.length>=2
				description = descriptionResult[2]

			nameResult = /@?rname = (\'|\"|\"\"\")(.*)(\'|\"|\"\"\")/.exec(source)

			if nameResult? and nameResult.length>=2
				name = nameResult[2]


			compiledJS = CoffeeScript.compile source, bare: on 			# compile coffeescript to javascript

		catch {location, message} 	# compilation error, or className was not found: log & display error
			if location?
				errorMessage = "Error on line #{location.first_line + 1}: #{message}"
				if message == "unmatched OUTDENT"
					errorMessage += "\nThis error is generally due to indention problem or unbalanced parenthesis/brackets/braces."
			console.error errorMessage
			return null

		return  { name: name, className: className, source: source, compiledSource: compiledJS, description: description, iconURL: iconURL }

	# this.addModule = (module)->
	# 	justCreated = not module?
	# 	module ?= compileSource()
	# 	if module?
	# 		# Eval the compiled js.
	# 		try

	# 			eval module.compiledSource
	# 			if g.modules[module.rname]?
	# 				g.modules[module.rname].remove()
	# 				delete this[module.className]
	# 			newModule = new PathModule(this[module.className], justCreated)
	# 			newModule.constructor.source = module.source
	# 			if justCreated then newModule.select()
	# 		catch error
	# 			console.error error
	# 			return null
	# 	return module

	# run script and create path module if script is a path class
	# if *script* is not provided, the content of the code editor is compiled and taken as the script
	# called by the run button in the code editor (then the content of the code editor is compiled and taken as the script)
	# and when loading modules from database (then the script is given with its compiled version)
	# @return [{ name: String, className: String, source: String, compiledSource: String, isModule: Boolean }] the compiled
	#			script in an object with the source, compiled source, class name, etc.
	g.runScript = (script)->
		# justCreated = not script?
		script ?= g.compileSource()
		if script?
			# Eval the compiled js.
			try
				result = eval script.compiledSource
				try
					console.log result
				catch error
					console.log error

				if g.lastPathCreated?
					g.lastPathCreated.source = script.source
					g.lastPathCreated = null
				# # model = window[script.compiledSource] # Use square brackets instead?
				# if script.isModule 							# if the script is a module (or more exactly a path class)
				# 	if g.modules[script.rname]? 				# remove the module with the same name if exists, create the new Path module and select it
				# 		g.modules[script.rname].remove()
				# 		delete this[script.className]
				# 	className = null
				# 	if script.originalClassName? and script.originalClassName.length>0
				# 		className = script.originalClassName
				# 	else
				# 		className = script.className
				# 	newModule = new g.PathModule(this[className], justCreated)
				# 	newModule.RPath.source = script.source
				# 	# newModule.constructor.source = script.source
				# 	if justCreated then newModule.select()
			catch error 									# display and throw error if any
				console.error error
				throw error
				return null
		return script

	g.compileAndRunModule = (module)->
		g.runModule(g.compileSource(module.source, module.name))
		return

	g.runModule = (module)->
		try
			console.log eval module.compiledSource

			if g.lastPathCreated?
				g.lastPathCreated.source = module.source
				g.lastPathCreated = null

		catch error

			console.error error
			throw error
			return null

		return

	g.initializeEditor = ()->
		ce.editorJ.show()
		ce.editorJ.addClass('visible')
		console.log = g.logMessage
		console.error = g.logError
		return

	# show the module editor (and set code editor content)
	# @param [RPath constructor] optional: set RPath.source as the content of the code editor if not null, set the example source otherwise
	g.showEditor = (RItem)->
		ce = g.codeEditor
		if RItem?
			ce.setSource(g.modules[RItem.rname])
		else
			if not ce.editorJ.hasClass('visible')
				ce.initializeNewModuleFromName(g.codeExample)
		if not ce.editorJ.hasClass('visible')
			g.initializeEditor()
		return

	ce.setLockModule = (lock)->
		ce = g.codeEditor
		if lock.modulePk?
			Dajaxice.draw.getModuleSource(ce.setSourceFromServer, pk: lock.modulePk)
		else
			ce.initializeNewModuleFromName("MyLockModule", lock)
		g.initializeEditor()
		return

	return