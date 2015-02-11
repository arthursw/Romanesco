# TODO: manage items and path in the same way (g.paths and g.items)? make an interface on top of path and div, and use events to update them
# todo: add else case in switches
# todo: bug when creating a small div (happened with text)
# todo: snap div
# todo: center modal vertically with an event system: http://codepen.io/dimbslmh/pen/mKfCc and http://stackoverflow.com/questions/18422223/bootstrap-3-modal-vertical-position-center

# doctodo: look for "improve", "improvement", "deprecated", "to be updated" to see each time romanesco must be updated

###
# Romanesco documentation #

Romanesco is an experiment about freedom, creativity and collaboration.

tododoc
tododoc: define RItems

The source code is divided in files:
 - [main.coffee](http://main.html) which is where the initialization
 - [path.coffee](http://path.html)
 - etc

Notations:
 - override means that the method extends functionnalities of the inherited method (super is called at some point)
 - redefine means that it totally replace the method (super is never called)

###

## Init tools
# - init jQuery elements related to the tools
# - create all tools
# - init tool typeahead (the algorithm to find the tools from a few letters in the search tool input)
# - get custom tools from the database, and initialize them
# - make the tools draggable between the 'favorite tools' and 'other tools' panels, and update g.typeaheadToolEngine and g.favoriteTools accordingly
initTools = () ->
	# init jQuery elements related to the tools
	g.toolsJ = $(".tool-list")
	g.favoriteToolsJ = $("#FavoriteTools .tool-list")
	g.allToolsContainerJ = $("#AllTools")
	g.allToolsJ = g.allToolsContainerJ.find(".all-tool-list")

	# init g.favoriteTools to see where to put the tools (in the 'favorite tools' panel or in 'other tools')
	g.favoriteTools = []
	if localStorage?
		try
			g.favoriteTools = JSON.parse(localStorage.favorites)
		catch error
			console.log error
	
	defaultFavoriteTools = [PrecisePath, ThicknessPath, Meander, GeometricLines, RectangleShape, EllipseShape, StarShape, SpiralShape]
	
	while g.favoriteTools.length < 8
		g.pushIfAbsent(g.favoriteTools, defaultFavoriteTools.pop().rname)

	# create all tools
	g.tools = new Object()
	new MoveTool()
	new CarTool()
	new SelectTool()
	new CodeTool()
	# new LinkTool(RLink)
	new LockTool(RLock)
	new TextTool(RText)
	new MediaTool(RMedia)
	new ScreenshotTool()
	
	# path tools
	for pathClass in pathClasses
		new PathTool(pathClass)

	# new PathTool(PrecisePath)
	# new PathTool(RectangleShape)
	# new PathTool(SpiralShape)
	# new PathTool(SketchPath)

	# new PathTool(SpiralPath)
	# new PathTool(ShapePath)
	# new PathTool(StarShape)
	# new PathTool(EllipseShape)

	# new PathTool(ThicknessPath)
	# new PathTool(FuzzyPath)
	# new PathTool(Checkpoint)

	# init tool typeahead
	initToolTypeahead = ()->
		toolValues = []
		toolValues.push( value: $(tool).attr("data-type") ) for tool in g.allToolsJ.children()
		g.typeaheadToolEngine = new Bloodhound({
			name: 'Tools',
			local: toolValues,
			datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
			queryTokenizer: Bloodhound.tokenizers.whitespace
		})
		promise = g.typeaheadToolEngine.initialize()

		g.searchToolInputJ = g.allToolsContainerJ.find("input.search-tool")
		g.searchToolInputJ.keyup (event)->
			query = g.searchToolInputJ.val()
			if query == ""
				g.allToolsJ.children().show()
				return
			g.allToolsJ.children().hide()
			g.typeaheadToolEngine.get( query, (suggestions)->
				for suggestion in suggestions
					console.log(suggestion)
					g.allToolsJ.children("[data-type='" + suggestion.value + "']").show()
			)
			return
		return

	# get custom tools from the database, and initialize them
	# ajaxPost '/getTools', {}, (result)->
	Dajaxice.draw.getTools (result)->
		scripts = JSON.parse(result.tools)

		for script in scripts
			g.runScript(script)

		initToolTypeahead()
		return

	# make the tools draggable between the 'favorite tools' and 'other tools' panels, and update g.typeaheadToolEngine and g.favoriteTools accordingly
	sortStart = (event, ui)->
		$( "#sortable1, #sortable2" ).addClass("drag-over")
		return

	sortStop = (event, ui)->
		$( "#sortable1, #sortable2" ).removeClass("drag-over")
		if not localStorage? then return
		names = []
		for li in g.favoriteToolsJ.children()
			names.push($(li).attr("data-type"))
		localStorage.favorites = JSON.stringify(names)

		toolValues = []
		toolValues.push( value: $(tool).attr("data-type") ) for tool in g.allToolsJ.children()
		g.typeaheadToolEngine.clear()
		g.typeaheadToolEngine.add(toolValues)

		return

	$( "#sortable1, #sortable2" ).sortable( connectWith: ".connectedSortable", appendTo: g.sidebarJ, helper: "clone", start: sortStart, stop: sortStop, delay: 250 ).disableSelection()

	g.tools['Move'].select() 		# select the move tool
	return

## Init position
# initialize the view position according to the 'data-box' of the canvas (when loading a website or video game)
# update g.entireArea and g.restrictedArea according to site settings
# update sidebar according to site settings
initPosition = ()->
	# check if canvas has an attribute 'data-box'
	boxString = g.canvasJ.attr("data-box")
	
	if not boxString or boxString.length==0
		window.onhashchange()
		return

	# initialize the area rectangle *boxRectangle* from 'data-box' attr and move to the center of the box
	box = JSON.parse( boxString )

	planet = new Point(box.planetX, box.planetY)
	
	tl = posOnPlanetToProject(box.box.coordinates[0][0], planet)
	br = posOnPlanetToProject(box.box.coordinates[0][2], planet)

	boxRectangle = new Rectangle(tl, br)
	pos = boxRectangle.center

	g.RMoveTo(pos)

	# load the entire area if 'data-load-entire-area' is set to true, and set g.entireArea
	loadEntireArea = g.canvasJ.attr("data-load-entire-area")

	if loadEntireArea
		g.entireArea = boxRectangle
		g.load(boxRectangle)

	# boxData = if box.data? and box.data.length>0 then JSON.parse(box.data) else null
	# console.log boxData

	# init g.restrictedArea
	siteString = g.canvasJ.attr("data-site")
	site = JSON.parse( siteString )
	if site.restrictedArea
		g.restrictedArea = boxRectangle
	
	g.tools['Select'].select() 		# select 'Select' tool by default when loading a website
									# since a click on an RLock will activate the drag (temporarily select the 'Move' tool) 
									# and the user must be able to select text

	# update sidebar according to site settings
	if site.disableToolbar
		# just hide the sidebar
		g.sidebarJ.hide()
	else
		# remove all panels except the chat
		g.sidebarJ.find("div.panel.panel-default:not(:last)").hide()

		# remove all controllers and folder except zoom in General.
		for folderName, folder of g.gui.__folders
			for controller in folder.__controllers
				if controller.name != 'Zoom'
					folder.remove(controller)
					folder.__controllers.remove(controller)
			if folder.__controllers.length==0
				g.gui.removeFolder(folderName)

		g.sidebarHandleJ.click()

	return

paper.install(window)

# initialize Romanesco
# all global variables and functions are stored in *g* which is a synonym of *window*
# all jQuery elements names end with a capital J: elementNameJ
init = ()->
	# g.romanescoURL = 'http://romanesc.co/'
	g.romanescoURL = 'http://localhost:8000/'
	g.windowJ = $(window)
	g.stageJ = $("#stage")
	g.sidebarJ = $("#sidebar")
	g.canvasJ = g.stageJ.find("#canvas")
	g.canvas = g.canvasJ[0]
	g.context = g.canvas.getContext('2d')
	g.templatesJ = $("#templates")
	g.me = null 							# g.me is the username of the user (sent by the server in each ajax "load")
	g.selectedDivs = []
	g.selectionGroup = null					# paper group containing all selected paper items
	g.polygonMode = false					# whether to draw in polygon mode or not (in polygon mode: each time the user clicks a point will be created, in default mode: each time the user moves the mouse a point will be created)
	g.selectionBlue = '#2fa1d6'
	g.updateTimeout = {} 					# map of id -> timeout id to clear the timeouts
	g.restrictedArea = null 				# area in which the user position will be constrained (in a website with restrictedArea == true)
	g.OSName = "Unknown OS" 				# user's operating system
	g.currentPaths = {} 					# map of username -> path id corresponding to the paths currently being created
	g.loadingBarTimeout = null 				# timeout id of the loading bar
	g.entireArea = null 					# entire area to be kept loaded, it is a paper Rectangle
	g.entireAreas = [] 						# array of RDivs which have data.loadEntireArea==true
	g.loadedAreas = [] 						# array of areas { pos: pos, planet: planet } which are loaded (to test if areas have to be loaded or unloaded)
	g.paths = new Object() 					# a map of RPath.pk (or RPath.id) -> RPath. RPath are first added with their id, and then with their pk (as soon as server saved it and responds)
	g.items = new Object() 					# map RItem.id or RItem.pk -> RItem, all loaded RItems. The key is RItem.id before RItem is savied in the database, and RItem.pk after
	g.locks = [] 							# array of loaded RLocks
	g.divs = [] 							# array of loaded RDivs
	g.sortedPaths = []						# an array where path are sorted by index (z-index)
	g.animatedItems = [] 					# an array of animated items to be updated each frame
	g.cars = {} 							# a map of username -> cars which will be updated each frame
	g.fastMode = false 						# fastMode will hide all items except the one being edited (when user edits an item)
	g.fastModeOn = false					# fastModeOn is true when the user is edditing an item
	g.alerts = null 						# An array of alerts ({ type: type, message: message }) containing all alerts info. It is append to the alert box in showAlert()
	g.scale = 1000.0 						# the scale to go from project coordinates to planet coordinates
	g.previousPoint = null 					# the previous mouse event point
	g.draggingEditor = false 				# boolean, true when user is dragging the code editor
	g.rasters = {}							# map to store rasters (tiles, rasterized version of the view)
	g.areasToUpdate = {} 					# map of areas to update { pk->rectangle } (areas which are not rasterize on the server, that we must send if we can rasterize them)
	g.rastersToUpload = [] 					# an array of { data: dataURL, position: position } containing the rasters to upload on the server 
	g.areasToRasterize = [] 				# an array of Rectangle to rasterize
	g.isUpdatingRasters = false 			# true if we are updating rasters (in loopUpdateRasters)
	g.viewUpdated = false 					# true if the view was updated ( rasters removed and items drawn in g.updateView() ) and we don't need to update anymore (until new rasters are added in load_callback)

	g.areasToUpdateRectangles = {} 			# debug map: area to update pk -> rectangle path
	g.catchErrors = false 					# the error will not be caught when drawing an RPath (let chrome catch them at the right time)

	# g.globalMaskJ = $("#globalMask")
	# g.globalMaskJ.hide()
	
	# Display a romanesco_alert message when a dajaxice error happens (problem on the server)
	Dajaxice.setup( 'default_exception_callback': (error)-> 
		console.log 'Dajaxice error!'
		romanesco_alert "Connection error", "error"
		return
	)

	# init g.OSName (user's operating system)
	if navigator.appVersion.indexOf("Win")!=-1 then g.OSName = "Windows"
	if navigator.appVersion.indexOf("Mac")!=-1 then g.OSName = "MacOS"
	if navigator.appVersion.indexOf("X11")!=-1 then g.OSName = "UNIX"
	if navigator.appVersion.indexOf("Linux")!=-1 then g.OSName = "Linux"

	# init paper.js
	paper.setup(canvas)
	activeLayer = project.activeLayer
	g.debugLayer = new Layer()				# Paper layer to append debug items
	g.carLayer = new Layer() 				# Paper layer to append all cars
	activeLayer.activate()
	paper.settings.hitTolerance = 5
	g.grid = new Group() 					# Paper Group to append all grid items
	g.grid.name = 'grid group'
	view.zoom = 1 # 0.01

	# add custom methods to export Paper Point and Rectangle to JSON
	Point.prototype.toJSON = ()->
		return { x: this.x, y: this.y }
	Point.prototype.exportJSON = ()->
		return JSON.stringify(this.toJSON())
	Rectangle.prototype.toJSON = ()->
		return { x: this.x, y: this.y, width: this.width, height: this.height }
	Rectangle.prototype.exportJSON = ()->
		return JSON.stringify(this.toJSON())

	g.tool = new Tool()

	# g.defaultColors = ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ]
	g.defaultColors = ['#d7dddb', '#4f8a83', '#e76278', '#fac699', '#712164']

	# initialize alerts
	g.alertsContainer = $("#Romanesco_alerts")
	g.alerts = []
	g.currentAlert = -1
	g.alertTimeOut = -1
	g.alertsContainer.find(".btn-up").click( -> showAlert(g.currentAlert-1) )
	g.alertsContainer.find(".btn-down").click( -> showAlert(g.currentAlert+1) )

	# initialize sidebar handle
	g.sidebarHandleJ = g.sidebarJ.find(".sidebar-handle")
	g.sidebarHandleJ.click ()->
		g.toggleSidebar()
		return

	$(".mCustomScrollbar.sidebar-scrollbar").mCustomScrollbar( keyboard: false )

	# g.sound = new RSound(['/static/sounds/space_ship_engine.mp3', '/static/sounds/space_ship_engine.ogg'])
	g.sound = new RSound(['/static/sounds/viper.ogg']) 			# load car sound

	# g.sound = new Howl( 
	# 	urls: ['/static/sounds/viper.ogg']
	# 	onload: ()->
	# 		console.log("sound loaded")
	# 		XMLHttpRequest = g.DajaxiceXMLHttpRequest
	# 		return
	# 	volume: 0.25
	# 	buffer: true
	# 	sprite:
	# 		loop: [2000, 3000, true]
	# )

	# g.sound.plays = (spriteName)->
	# 	return g.sound.spriteName == spriteName # and g.sound.pos()>0

	# g.sound.playAt = (spriteName, time)->
	# 	if time < 0 or time > 1.0 then return
	# 	sprite = g.sound.sprite()[spriteName]
	# 	begin = sprite[0]
	# 	duration = sprite[1]
	# 	looped = sprite[2]
	# 	g.sound.stop()
	# 	g.sound.spriteName = spriteName
	# 	g.sound.play(spriteName)
	# 	g.sound.pos(time*duration/1000)
	# 	callback = ()->
	# 		g.sound.stop()
	# 		if looped then g.sound.play(spriteName)
	# 		return
	# 	clearTimeout(g.sound.rTimeout)
	# 	g.sound.rTimeout = setTimeout(callback, duration-time*duration)
	# 	return false

	# g.sidebarJ.find("#buyRomanescoins").click ()-> 
	# 	g.templatesJ.find('#romanescoinModal').modal('show')
	# 	paypalFormJ = g.templatesJ.find("#paypalForm")
	# 	paypalFormJ.find("input[name='submit']").click( ()-> 
	# 		data = 
	# 			user: g.me
	# 			location: { x: view.center.x, y: view.center.y }
	# 		paypalFormJ.find("input[name='custom']").attr("value", JSON.stringify(data) )
	# 	)
	
	# load path source code
	$.ajax( url: g.romanescoURL + "static/coffee/path.coffee" ).done (data)->

		lines = data.split(/\n/)
		expressions = CoffeeScript.nodes(data).expressions

		classMap = {}
		for pathClass in g.pathClasses
			classMap[pathClass.name] = pathClass

		for expression in expressions
			classMap[expression.variable.base.value]?.source = lines[expression.locationData.first_line .. expression.locationData.last_line].join("\n")

		return


	initParameters()
	initCodeEditor()
	initTools()
	initSocket()
	initPosition()
	# initLoadingBar()

	updateGrid()

	return

# Initialize Romanesco and handlers
$(document).ready () ->

	init()

	## mouse and key listeners

	# jQuery listeners
	g.canvasJ.mousedown( g.mousedown )
	g.stageJ.mousedown( g.mousedown )
	$(window).mousemove( g.mousemove )
	$(window).mouseup( g.mouseup )
	g.stageJ.mousewheel (event)->
		g.RMoveBy(new Point(-event.deltaX, event.deltaY))
		return

	canvasJ.dblclick( (event) -> g.selectedTool.doubleClick?(event) )
	canvasJ.keydown( (event) -> if event.key == 46 then event.preventDefault() ) # cancel default delete key behaviour (not really working)

	# Paper listeners
	tool.onMouseDown = (event) ->
		$(document.activeElement).blur() # prevent to keep focus on the chat when we interact with the canvas
		# event = g.snap(event) 		# snapping mouseDown event causes some problems
		g.selectedTool.begin(event)

	tool.onMouseDrag = (event) ->
		event = g.snap(event)
		g.selectedTool.update(event)

	tool.onMouseUp = (event) ->
		event = g.snap(event)
		g.selectedTool.end(event)

	tool.onKeyDown = (event) ->
		# if user is typing: ignore
		for selectedDiv in g.selectedDivs
			if selectedDiv.constructor.name == 'RText'
				return
		if event.key == 'delete' 									# prevent default delete behaviour (not working)
			event.preventDefault()
		if event.key == 'space' and g.selectedTool.name != 'Move' 	# select 'Move' tool when user press space key (and reselect previous tool after)
			g.tools['Move'].select()

	tool.onKeyUp = (event) ->
		# if user is typing: ignore
		# for selectedDiv in g.selectedDivs
		# 	if selectedDiv.constructor.name == 'RText'
		# 		return

		# if the focus is on anything in the sidebar or is a textarea: ignore the delete
		if $(document.activeElement).parents(".sidebar").length or $(document.activeElement).is("textarea")
			return

		# - move selected RItem by delta if an arrow key was pressed (delta is function of special keys press)
		# - finish current path (if in polygon mode) if 'enter' or 'escape' was pressed
		# - select previous tool on space key up
		# - select 'Select' tool if key == 'v'
		# - delete selected item on 'delete' or 'backspace'
		if event.key in ['left', 'right', 'up', 'down']
			delta = if event.modifiers.shift then 50 else if event.modifiers.option then 5 else 1
		switch event.key
			when 'right'
				item.moveBy(new Point(delta,0), true) for item in g.selectedItems()
			when 'left'
				item.moveBy(new Point(-delta,0), true) for item in g.selectedItems()
			when 'up'
				item.moveBy(new Point(0,-delta), true) for item in g.selectedItems()
			when 'down'
				item.moveBy(new Point(0,delta), true) for item in g.selectedItems()
			when 'enter', 'escape'
				g.selectedTool.finishPath?()
			when 'space'
				g.previousTool?.select()
			when 'v'
				g.tools['Select'].select()
			when 'delete', 'backspace'
				for item in g.selectedItems()
					if item.selectedSegment?
						item.deleteSelectedPoint(true)
					else
						item.delete()
		
		event.preventDefault()
	
	# on frame event:
	# - update animatedItems
	# - update cars positions
	view.onFrame = (event)->
		TWEEN.update(event.time)

		g.selectedTool.onFrame?(event)

		for item in g.animatedItems
			item.onFrame(event)

		for username, car of g.cars
			direction = new Point(1,0)
			direction.angle = car.rotation-90
			car.position = car.position.add(direction.multiply(car.speed))
			if Date.now() - car.rLastUpdate > 1000
				g.cars[username].remove()
				delete g.cars[username]

		return

	# update grid and mCustomScrollbar when window is resized
	g.windowJ.resize( (event) ->
		updateGrid()
		$(".mCustomScrollbar").mCustomScrollbar("update")
		view.draw()
	)
	return

# mousedown event listener
this.mousedown = (event) ->
	
	switch event.which						# switch on mouse button number (left, middle or right click)
		when 2
			g.tools['Move'].select()		# select move tool if middle mouse button
		when 3
			g.selectedTool.finishPath?() 	# finish current path (in polygon mode) if right click

	if g.selectedTool.name == 'Move' 		# update 'Move' tool if it is the one selected, and return
		g.selectedTool.beginNative(event)
		return
	
	if event.target.nodeName == "CANVAS" then return false 
	g.previousPoint = new Point(event.pageX, event.pageY) 	# store previous mouse event point
	return

# mousemove event listener
this.mousemove = (event) ->
	if g.selectedTool.name == 'Move' then g.selectedTool.updateNative(event) 	# update 'Move' tool if it is the one selected

	# selectedDiv.selectUpdate(event) for selectedDiv in g.selectedDivs
	
	# update selected RDivs
	if g.previousPoint?
		event.delta = new Point(event.pageX-g.previousPoint.x, event.pageY-g.previousPoint.y)
		g.previousPoint = new Point(event.pageX, event.pageY)

		for item in g.selectedItems()
			item.selectUpdate?(event)
	
	# update code editor width
	if g.draggingEditor
		g.editorJ.css( right: g.windowJ.width()-event.pageX)

	return

# mouseup event listener
this.mouseup = (event) ->
	if g.selectedTool.name == 'Move' then g.selectedTool.endNative(event) 	# update 'Move' tool if it is the one selected

	# deselect move tool and select previous tool if middle mouse button
	if event.which == 2 # middle mouse button
		g.previousTool?.select()

	# drag handles	
	g.mousemove(event)
	# selectedDiv.selectEnd(event) for selectedDiv in g.selectedDivs

	# update selected RDivs
	if g.previousPoint?
		event.delta = new Point(event.pageX-g.previousPoint.x, event.pageY-g.previousPoint.y)
		g.previousPoint = null
		for item in g.selectedItems()
			item.selectEnd?(event)

	g.draggingEditor = false
	
	return