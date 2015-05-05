define ['utils', 'editor', 'jquery', 'typeahead'], (utils) ->
	g = utils.g()

	# init tool typeahead
	initModuleTypeahead = (modules)->
		g.typeaheadModuleEngine = new Bloodhound({
			name: 'Modules',
			local: modules,
			datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
			queryTokenizer: Bloodhound.tokenizers.whitespace,
			limit: 15
		})

		g.typeaheadModuleEngine.initialize()
		g.codeEditor.initializeModuleInput()
		return

	g.initializeModule = (result)->
		if not g.checkError(result) then return
		module = JSON.parse(result.module)

		if module.type? == 'lock'
			g.runModule(module)
			return

		g.modules[module.name] = module
		# replace click handler: now we only run the module on click
		btnJ = g.sidebarJ.find('.module-list').find('li[data-name="' + module.name + '"]')
		if btnJ.length==0 then console.log "Error: impossible to find button for module " + module.name
		btnJ.off("click").click ()->
			g.runModule(module)
			return

		# the click handler will be replaced if the module is a tool
		g.runModule(module)

		return

	g.getModule = (moduleName)->
		moduleName ?= $(this).attr('data-name')
		Dajaxice.draw.getModuleSource(g.initializeModule, name: moduleName)
		return

	g.deleteModule = (moduleName, repoName, pk)->
		Dajaxice.draw.deleteModule(g.checkError, { name: moduleName, pk: pk, repoName: repoName } )
		return

	g.showToolBox = ()->
		allModulesJ = g.allToolsJ.parents(".all-tools:first")
		toolBoxJ = allModulesJ.clone()
		g.stageJ.append(toolBoxJ)
		toolBoxJ.addClass('tool-box')
		toolBoxJ.css(position: 'absolute', left: g.mousePosition.x, top: g.mousePosition.y)
		toolBoxJ.find('input').focus()
		ulJ = toolBoxJ.find('ul.all-tool-list').clone()
		scrollBarJ = toolBoxJ.find('.mCustomScrollbar.tree')
		scrollBarJ.empty()
		scrollBarJ.append(ulJ)
		scrollBarJ.mCustomScrollbar()
		toolBoxJ.find('input.search-tool').keyup(g.getSuggestions)
		toolBoxJ.find('h6').click (event)->
			$(this).parent().toggleClass('closed')
			return

		searchModuleBtnJ = toolBoxJ.find(".search-tools button")
		searchModuleBtnJ.click(g.createToolModal)

		for toolBtn in $("#GeneralTools li")
			toolBtnJ = $(toolBtn)
			name = toolBtnJ.attr('data-name')
			iconURL = toolBtnJ.find('img').attr('src')
			g.createToolButton(name, iconURL, false, 'General', ulJ)

		# ulJ.find('li[data-name="General"').putInFirstPosition()
		toolBoxJ.find(".tool-btn").click(g.selectModule)
		toolBoxJ.find(".favorite-btn").click(g.toggleToolToFavorite)

		g.stageJ.addClass('has-tool-box')

		return

	g.hideToolBox = ()->
		if g.stageJ.hasClass('has-tool-box')
			g.stageJ.find(".tool-box").remove()
			g.stageJ.removeClass('has-tool-box')
		return

	g.selectModule = ()->
		g.RModal.hide()
		g.hideToolBox()

		moduleName = $(this).attr('data-name')
		if g.tools[moduleName]?
			g.tools[moduleName].select()
		else
			g.getModule(moduleName)
		return

	g.createToolModal = ()->
		g.hideToolBox()

		g.createModuleModal("Romanesco tools", g.selectModule)

		for toolBtn in $("#GeneralTools li")

			toolBtnJ = $(toolBtn)
			name = toolBtnJ.attr('data-name')
			module =
				owner: 'Romanesco'
				coreModule: true
				accepted: true
			g.addModuleToModal(name, module, g.RModal.modalJ.find('tbody'), g.selectModule, true)

		return

	g.getSuggestions = (event)->
		inputJ = $(this)
		allModulesJ = inputJ.parents(".all-tools:first")
		if event.which == 27 	# esc key
			if allModulesJ.hasClass("tool-box")
				allModulesJ.remove()
			event.stopPropagation()
			return
		query = inputJ.val()
		if query == ""
			allModulesJ.find('li').show()
			return
		allModulesJ.find('li').hide()
		g.typeaheadModuleEngine.get query, (suggestions)->
			for suggestion in suggestions
				allModulesJ.find("li").has("li[data-name='" + suggestion.value + "']").removeClass("closed").show()
				allModulesJ.find("li[data-name='" + suggestion.value + "']").show().find('li').show()
			return
		return

	g.initializeModules = (moduleValues) ->

		g.allModulesJ = g.allToolsContainerJ.find(".all-tool-list")
		searchToolsJ = $(".search-tools")
		g.searchModuleInputJ = searchToolsJ.find("input.search-tool")
		g.searchModuleInputJ.keyup(g.getSuggestions)

		g.searchModuleBtnJ = searchToolsJ.find(".search button")
		g.searchModuleBtnJ.click(g.createToolModal)


		# get custom modules from the database, and initialize them
		# ajaxPost '/getModules', {}, (result)->
		Dajaxice.draw.getModules (result)->
			modules = JSON.parse(result.modules)

			for module, i in modules
				favorite = g.favoriteTools.indexOf(module.name)>=0
				btnJ = g.createToolButton(module.name, module.iconURL, favorite, module.category)
				btnJ.click(g.getModule)
				g.modules[module.name] = module

			moduleValues = []
			for name, module of g.modules
				moduleValues.push(value: name, iconURL: module.iconURL)
				if module.category?
					moduleValues.push(value: module.category)
			initModuleTypeahead(moduleValues)
			return

		return

	g.addModuleToModal = (name, module, tbodyJ, actionOnClick, prepend=false)->
		rowJ = $('<tr>').addClass('module')
		rowJ.attr("data-name", name).attr("data-owner", module.owner).attr("data-name", name)
		rowJ.css( cursor: 'pointer' )
		rowJ.click(actionOnClick)
		td1J = $('<td>')
		td2J = $('<td>')
		td3J = $('<td>')
		td4J = $('<td>')
		nameJ = $('<span>').addClass('name').text(name)
		authorJ = $('<span>').addClass('author').text(module.owner)
		if module.githubURL?
			githubJ = $('<a>').addClass('githubURL').text('Github repository').attr('href', module.githubURL)
		else if module.coreModule?
			githubJ = $('<a>').addClass('githubURL').text('Main romanesco repository').attr('href', 'https://github.com/RomanescoModules/Romanesco')
		if module.thumbnail?
			thumbnailJ = $('<image>').attr("src", module.thumbnail)
		descriptionJ = $('<p>').addClass('description').text(module.description)
		td1J.append(nameJ, thumbnailJ, descriptionJ)
		td2J.append(authorJ)
		td3J.append(githubJ)
		if module.accepted
			if module.lastUpdate?
				date = new Date(module.lastUpdate.$date)
				td4J.text(date.toLocaleString()).addClass("accepted")
			else
				td4J.text("-").addClass("accepted")
		else
			td4J.text("not accepted")
		rowJ.append(td1J, td2J, td3J, td4J)
		if prepend
			tbodyJ.prepend(rowJ)
		else
			tbodyJ.append(rowJ)
		return rowJ

	g.createModuleModal = (title, actionOnClick)->

		g.RModal.initialize(title)
		divJ = $('<div>')
		divJ.css( "max-height", "400px" )
		divJ.css( "overflow-y", "auto" )
		tableJ = $('<table>').addClass("table table-hover").css( width: "100%" )
		theadJ = $('<thead>')
		theadJ.append($("""<tr>
			<th>Module</th>
			<th>Author</th>
			<th>Github URL</th>
			<th>Accepted on</th>
		</tr>"""))
		tableJ.append(theadJ)
		tbodyJ = $('<tbody>')

		for name, module of g.modules
			g.addModuleToModal(name, module, tbodyJ, actionOnClick)

		tableJ.append(tbodyJ)
		divJ.append(tableJ)
		g.RModal.modalBodyJ.append(divJ)

		g.RModal.show()
		g.RModal.modalJ.find(".btn-primary").hide()

		return

	## Administration functions to test and accept modules (which are not validated yet)

	# set module as accepted in the database
	g.acceptModule = (module)->
		m = g.compileSource(module.source, module.name)
		module.iconURL = m.iconURL
		module.compiledSource = m.compiledSource
		module.description = m.description
		callback = (results)->
			if not g.checkError(results) then return
			console.log results.message
			return
		Dajaxice.draw.acceptModule( g.checkError, module )
		return

	# get modules which are not accepted yet, and put them in g.waitingModules
	g.getWaitingModules = (value)->

		getWaitingModulesCallback = (result)->
			if g.checkError(result)
				g.waitingModules = result.modules
				console.log "Waiting modules loaded:"
				console.log g.waitingModules
			return

		Dajaxice.draw.getWaitingModules( getWaitingModulesCallback, {} )
		return

	return