define [
	'utils'
	'paper'
	'coordinateSystems'
	'global'
	'ajax'
	'options'
	'socket'
	'command'
	'item'
	'div'
	'lock'
	'path'
	'tools'
	'rasterizer'
	'editor'
	'sound'
	'modal'
	'jquery'
	'jqueryUi'
	'mousewheel'
	'scrollbar'
	'tween'
	'typeahead'
	'prefix'
	'ace'
], (utils, paper) ->

	g = utils.g()

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

	initializeAddons = () ->

		if g.rasterizerMode?
			g.setTools()
			return

		# init tool typeahead
		initAddonTypeahead = (addons)->
			g.typeaheadAddonEngine = new Bloodhound({
				name: 'Addons',
				local: addons,
				datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
				queryTokenizer: Bloodhound.tokenizers.whitespace
			})

			g.typeaheadAddonEngine.initialize()
			g.codeEditor.initializeAddonInput()
			return

		g.allAddonsJ = g.allToolsContainerJ.find(".all-tool-list")

		# get custom addons from the database, and initialize them
		# ajaxPost '/getAddons', {}, (result)->
		Dajaxice.draw.getAddons (result)->
			addons = JSON.parse(result.addons)
			addonValues = []
			for addon, i in addons
				g.createButton(addon.name, addon.iconURL, g.allAddonsJ)
				addonValues.push(value: addon.name, iconURL: addon.iconURL)

			initAddonTypeahead(addonValues)
			return

		g.searchAddonInputJ = $("#AllTools").find("input.search-tool")
		g.searchAddonInputJ.keyup (event)->
			query = g.searchAddonInputJ.val()
			if query == ""
				g.allAddonsJ.children().show()
				return
			g.allAddonsJ.children().hide()
			g.typeaheadAddonEngine.get( query, (suggestions)->
				for suggestion in suggestions
					g.allAddonsJ.children("[data-type='" + suggestion.value + "']").show()
			)
			return

		return

	## Init tools
	# - init jQuery elements related to the tools
	# - create all tools
	# - init tool typeahead (the algorithm to find the tools from a few letters in the search tool input)
	# - get custom tools from the database, and initialize them
	# - make the tools draggable between the 'favorite tools' and 'other tools' panels, and update g.typeaheadToolEngine and g.favoriteTools accordingly
	initTools = () ->
		# $.getJSON 'https://api.github.com/users/RomanescoAddons/repos', (json)->
		# 	for repo in json.repos
		# 		repo.
		# 	return

		if g.rasterizerMode?
			g.setTools()
			return

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

		defaultFavoriteTools = [g.PrecisePath, g.ThicknessPath, g.Meander, g.GeometricLines, g.RectangleShape, g.EllipseShape, g.StarShape, g.SpiralShape]

		while g.favoriteTools.length < 8
			g.pushIfAbsent(g.favoriteTools, defaultFavoriteTools.pop().rname)

		# create all tools
		g.tools = {}
		new g.MoveTool()
		new g.CarTool()
		new g.SelectTool()
		new g.CodeTool()
		# new LinkTool(RLink)
		new g.LockTool(g.RLock)
		new g.TextTool(g.RText)
		new g.MediaTool(g.RMedia)
		new g.ScreenshotTool()

		# path tools
		for pathClass in g.pathClasses
			new g.PathTool(pathClass)

		initializeAddons()

		# # init tool typeahead
		# initToolTypeahead = ()->
		# 	toolValues = []
		# 	toolValues.push( value: $(tool).attr("data-type") ) for tool in g.allToolsJ.children()
		# 	g.typeaheadToolEngine = new Bloodhound({
		# 		name: 'Tools',
		# 		local: toolValues,
		# 		datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
		# 		queryTokenizer: Bloodhound.tokenizers.whitespace
		# 	})
		# 	promise = g.typeaheadToolEngine.initialize()

		# 	g.searchToolInputJ = g.allToolsContainerJ.find("input.search-tool")
		# 	g.searchToolInputJ.keyup (event)->
		# 		query = g.searchToolInputJ.val()
		# 		if query == ""
		# 			g.allToolsJ.children().show()
		# 			return
		# 		g.allToolsJ.children().hide()
		# 		g.typeaheadToolEngine.get( query, (suggestions)->
		# 			for suggestion in suggestions
		# 				console.log(suggestion)
		# 				g.allToolsJ.children("[data-type='" + suggestion.value + "']").show()
		# 		)
		# 		return
		# 	return

		# # get custom tools from the database, and initialize them
		# # ajaxPost '/getTools', {}, (result)->
		# Dajaxice.draw.getTools (result)->
		# 	scripts = JSON.parse(result.tools)

		# 	for script in scripts
		# 		g.runScript(script)

		# 	initToolTypeahead()
		# 	return

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

		sortableArgs =
			connectWith: ".connectedSortable"
			appendTo: g.sidebarJ
			helper: "clone"
			start: sortStart
			stop: sortStop
			delay: 250
		$( "#sortable1, #sortable2" ).sortable( sortableArgs ).disableSelection()

		g.tools['Move'].select() 		# select the move tool

		# ---  init Wacom tablet API --- #

		g.wacomPlugin = document.getElementById('wacomPlugin')
		if g.wacomPlugin?
			g.wacomPenAPI = wacomPlugin.penAPI
			g.wacomTouchAPI = wacomPlugin.touchAPI
			g.wacomPointerType = { 0: 'Mouse', 1: 'Pen', 2: 'Puck', 3: 'Eraser' }
		# # Wacom API documentation:

		# # penAPI properties:

		# penAPI.isWacom
		# penAPI.isEraser
		# penAPI.pressure
		# penAPI.posX
		# penAPI.posY
		# penAPI.sysX
		# penAPI.sysY
		# penAPI.tabX
		# penAPI.tabY
		# penAPI.rotationDeg
		# penAPI.rotationRad
		# penAPI.tiltX
		# penAPI.tiltY
		# penAPI.tangentialPressure
		# penAPI.version
		# penAPI.pointerType
		# penAPI.tabletModel

		# # add touchAPI event listeners (> IE 11)

		# touchAPI.addEventListener("TouchDataEvent", touchDataEventHandler)
		# touchAPI.addEventListener("TouchDeviceAttachEvent", touchDeviceAttachHandler)
		# touchAPI.addEventListener("TouchDeviceDetachEvent", touchDeviceDetachHandler)

		# # Open / close touch device connection

		# touchAPI.Close(touchDeviceID)
		# error = touchAPI.Open(touchDeviceID, passThrough) # passThrough == true: observe and pass touch data to system
		# if error != 0 then console.log "unable to establish connection to wacom plugin"

		# # touch device capacities:

		# deviceCapacities = touchAPI.TouchDeviceCapabilities(touchDeviceID)
		# deviceCapacities.Version
		# deviceCapacities.DeviceID
		# deviceCapacities.MaxFingers
		# deviceCapacities.ReportedSizeX
		# deviceCapacities.ReportedSizeY
		# deviceCapacities.PhysicalSizeX
		# deviceCapacities.PhysicalSizeY
		# deviceCapacities.LogicalOriginX
		# deviceCapacities.LogicalOriginY
		# deviceCapacities.LogicalWidth
		# deviceCapacities.LogicalHeight

		# # touch state helper map:
		# touchStates = [ 0: 'None', 1: 'Down', 2: 'Hold', 3: 'Up']
		# touchStates[touchState]

		# # Get touch data for as many fingers as supported
		# touchRawFingerData = touchAPI.TouchRawFingerData(touchDeviceID)

		# if touchRawFingerData.Status == -1 	# Bad data
		# 	return

		# touchRawFingerData.NumFingers

		# for finger in touchRawFingerData.FingerList
		# 	finger.FingerID
		# 	finger.PosX
		# 	finger.PosY
		# 	finger.Width
		# 	finger.Height
		# 	finger.Orientation
		# 	finger.Confidence
		# 	finger.Sensitivity
		# 	touchStates[finger.TouchState]

		return

	## Init position
	# initialize the view position according to the 'data-box' of the canvas (when loading a website or video game)
	# update g.entireArea and g.restrictedArea according to site settings
	# update sidebar according to site settings
	initPosition = ()->
		if g.rasterizerMode then return

		# check if canvas has an attribute 'data-box'
		boxString = g.canvasJ.attr("data-box")

		if not boxString or boxString.length==0
			window.onhashchange()
			return

		# initialize the area rectangle *boxRectangle* from 'data-box' attr and move to the center of the box
		box = JSON.parse( boxString )

		planet = new Point(box.planetX, box.planetY)

		tl = g.posOnPlanetToProject(box.box.coordinates[0][0], planet)
		br = g.posOnPlanetToProject(box.box.coordinates[0][2], planet)

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
		g.stageJ = $("#stage")
		g.sidebarJ = $("#sidebar")
		g.canvasJ = g.stageJ.find("#canvas")
		g.canvas = g.canvasJ[0]
		g.canvas.width = window.innerWidth
		g.canvas.height = window.innerHeight
		g.context = g.canvas.getContext('2d')
		# g.backgroundCanvasJ = g.stageJ.find("#background-canvas")
		# g.backgroundCanvas = g.backgroundCanvasJ[0]
		# g.backgroundCanvas.width = window.innerWidth
		# g.backgroundCanvas.height = window.innerHeight
		# g.backgroundCanvasJ.width(window.innerWidth)
		# g.backgroundCanvasJ.height(window.innerHeight)
		# g.backgroundContext = g.backgroundCanvas.getContext('2d')
		g.templatesJ = $("#templates")
		g.me = null 							# g.me is the username of the user (sent by the server in each ajax "load")
		g.selectionLayer = null					# paper layer containing all selected paper items
		g.polygonMode = false					# whether to draw in polygon mode or not (in polygon mode: each time the user clicks a point
												# will be created, in default mode: each time the user moves the mouse a point will be created)
		g.selectionBlue = '#2fa1d6'
		g.updateTimeout = {} 					# map of id -> timeout id to clear the timeouts
		g.requestedCallbacks = {} 				# map of id -> request id to clear the requestAnimationFrame
		g.restrictedArea = null 				# area in which the user position will be constrained (in a website with restrictedArea == true)
		g.OSName = "Unknown OS" 				# user's operating system
		g.currentPaths = {} 					# map of username -> path id corresponding to the paths currently being created
		g.loadingBarTimeout = null 				# timeout id of the loading bar
		g.entireArea = null 					# entire area to be kept loaded, it is a paper Rectangle
		g.entireAreas = [] 						# array of RDivs which have data.loadEntireArea==true
		g.loadedAreas = [] 						# array of areas { pos: pos, planet: planet } which are loaded
												# (to test if areas have to be loaded or unloaded)
		g.paths = new Object() 					# a map of RPath.pk (or RPath.id) -> RPath. RPath are first added with their id, and then with their pk
												# (as soon as server saved it and responds)
		g.items = new Object() 					# map RItem.id or RItem.pk -> RItem, all loaded RItems. The key is RItem.id before RItem is saved
												# in the database, and RItem.pk after
		g.locks = [] 							# array of loaded RLocks
		g.divs = [] 							# array of loaded RDivs
		g.sortedPaths = []						# an array where paths are sorted by index (z-index)
		g.sortedDivs = []						# an array where divs are sorted by index (z-index)
		g.animatedItems = [] 					# an array of animated items to be updated each frame
		g.cars = {} 							# a map of username -> cars which will be updated each frame
		# g.fastMode = false 						# fastMode will hide all items except the one being edited (when user edits an item)
		# g.fastModeOn = false					# fastModeOn is true when the user is edditing an item
		g.alerts = null 						# An array of alerts ({ type: type, message: message }) containing all alerts info.
												# It is append to the alert box in showAlert().
		g.scale = 1000.0 						# the scale to go from project coordinates to planet coordinates
		g.previousPoint = null 					# the previous mouse event point
		g.draggingEditor = false 				# boolean, true when user is dragging the code editor
		# g.rasters = {}							# map to store rasters (tiles, rasterized version of the view)
		g.areasToUpdate = {} 					# map of areas to update { pk->rectangle }
												# (areas which are not rasterize on the server, that we must send if we can rasterize them)
		g.rastersToUpload = [] 					# an array of { data: dataURL, position: position } containing the rasters to upload on the server
		g.areasToRasterize = [] 				# an array of Rectangle to rasterize
		g.isUpdatingRasters = false 			# true if we are updating rasters (in loopUpdateRasters)
		g.viewUpdated = false 					# true if the view was updated ( rasters removed and items drawn in g.updateView() )
												# and we don't need to update anymore (until new Rasters are added in load_callback)
		g.currentDiv = null 					# the div currently being edited (dragged, moved or resized) used to also send jQuery mouse event to divs
		g.areasToUpdateRectangles = {} 			# debug map: area to update pk -> rectangle path
		g.catchErrors = false 					# the error will not be caught when drawing an RPath (let chrome catch them at the right time)
		g.previousMousePosition = null 			# the previous position of the mouse in the mousedown/move/up
		g.initialMousePosition = null 			# the initial position of the mouse in the mousedown/move/up
		g.previousViewPosition = null			# the previous view position
		g.backgroundRectangle = null 			# the rectangle to highlight the stage when dragging an RContent over it
		g.limitPathV = null 					# the vertical limit path (line between two planets)
		g.limitPathH = null 					# the horizontal limit path (line between two planets)
		g.selectedItems = [] 					# the selectedItems
		g.ignoreSockets = false 				# whether sockets messages are ignored
		# initialize sort

		g.itemListsJ = $("#RItems .layers")
		g.pathList = g.itemListsJ.find(".rPath-list")
		g.pathList.sortable( stop: g.zIndexSortStop, delay: 250 )
		g.pathList.disableSelection()
		g.divList = g.itemListsJ.find(".rDiv-list")
		g.divList.sortable( stop: g.zIndexSortStop, delay: 250 )
		g.divList.disableSelection()
		g.itemListsJ.find('.title').click (event)->
			$(this).parent().toggleClass('closed')
			return
		g.commandManager = new g.CommandManager()
		# g.globalMaskJ = $("#globalMask")
		# g.globalMaskJ.hide()

		# Display a g.romanesco_alert message when a dajaxice error happens (problem on the server)
		Dajaxice.setup( 'default_exception_callback': (error)->
			console.log 'Dajaxice error!'
			g.romanesco_alert "Connection error", "error"
			return
		)

		# init g.OSName (user's operating system)
		if navigator.appVersion.indexOf("Win")!=-1 then g.OSName = "Windows"
		if navigator.appVersion.indexOf("Mac")!=-1 then g.OSName = "MacOS"
		if navigator.appVersion.indexOf("X11")!=-1 then g.OSName = "UNIX"
		if navigator.appVersion.indexOf("Linux")!=-1 then g.OSName = "Linux"

		# init paper.js
		paper.setup(g.canvas)
		g.project = project
		g.mainLayer = project.activeLayer
		g.debugLayer = new Layer()				# Paper layer to append debug items
		g.debugLayer.name = 'debug layer'
		g.carLayer = new Layer() 				# Paper layer to append all cars
		g.carLayer.name = 'car layer'
		g.lockLayer = new Layer()	 			# Paper layer to keep all locked items
		g.lockLayer.name = 'lock layer'
		g.selectionLayer = new Layer() 			# Paper layer to keep all selected items
		g.selectionLayer.name = 'selection layer'
		g.areasToUpdateLayer = new Layer() 		# Paper layer to show areas to update
		g.areasToUpdateLayer.name = 'areasToUpdateLayer'
		g.mainLayer.activate()
		paper.settings.hitTolerance = 5
		g.grid = new Group() 					# Paper Group to append all grid items
		g.grid.name = 'grid group'
		view.zoom = 1 # 0.01
		g.previousViewPosition = view.center

		g.rasterizer ?= new g.Rasterizer()

		# add custom methods to export Paper Point and Rectangle to JSON
		Point.prototype.toJSON = ()->
			return { x: this.x, y: this.y }
		Point.prototype.exportJSON = ()->
			return JSON.stringify(this.toJSON())
		Rectangle.prototype.toJSON = ()->
			return { x: this.x, y: this.y, width: this.width, height: this.height }
		Rectangle.prototype.exportJSON = ()->
			return JSON.stringify(this.toJSON())
		Rectangle.prototype.translate = (point)->
			return new Rectangle(this.x + point.x, this.y + point.y, this.width, this.height)
		Rectangle.prototype.moveSide = (sideName, destination)->
			switch sideName
				when 'left'
					this.x = destination
				when 'right'
					this.x = destination - this.width
				when 'top'
					this.y = destination
				when 'bottom'
					this.y = destination - this.height
			return
		Rectangle.prototype.moveCorner = (cornerName, destination)->
			switch cornerName
				when 'topLeft'
					this.x = destination.x
					this.y = destination.y
				when 'topRight'
					this.x = destination.x - this.width
					this.y = destination.y
				when 'bottomRight'
					this.x = destination.x - this.width
					this.y = destination.y - this.height
				when 'bottomLeft'
					this.x = destination.x
					this.y = destination.y - this.height
			return
		Rectangle.prototype.moveCenter = (destination)->
			this.x = destination.x - this.width * 0.5
			this.y = destination.y - this.height * 0.5
			return

		Event.prototype.toJSON = ()->
			event =
				modifiers: this.modifiers
				event: which: this.event.which
				point: this.point
				downPoint: this.downPoint
				delta: this.delta
				middlePoint: this.middlePoint
				type: this.type
				count: this.count
			return event
		Event.prototype.fromJSON = (event)->
			if event.point? then event.point = new Point(event.point)
			if event.downPoint? then event.downPoint = new Point(event.downPoint)
			if event.delta? then event.delta = new Point(event.delta)
			if event.middlePoint? then event.middlePoint = new Point(event.middlePoint)
			return event

		# g.defaultColors = ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ]
		# g.defaultColors = ['#d7dddb', '#4f8a83', '#e76278', '#fac699', '#712164']
		# g.defaultColors = ['#395A8F', '#4A79B1', '#659ADF', '#A4D2F3', '#EBEEF3']

		g.defaultColors = []

		hueRange = g.random(10, 180)
		minHue = g.random(0, 360-hueRange)
		step = hueRange/10

		for i in [0 .. 10]
			g.defaultColors.push(Color.HSL( minHue + i * step, g.random(0.3, 0.9), g.random(0.5, 0.7) ).toCSS())
			# g.defaultColors.push(Color.random().toCSS())

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

		# g.sound = new g.RSound(['/static/sounds/space_ship_engine.mp3', '/static/sounds/space_ship_engine.ogg'])
		g.sound = new g.RSound(['/static/sounds/viper.ogg']) 			# load car sound

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
				source = lines[expression.locationData.first_line .. expression.locationData.last_line].join("\n")
				classMap[expression.variable.base.value]?.source = source

			return

		g.initializeGlobalParameters()
		g.initParameters()
		g.initCodeEditor()
		g.initSocket()

		initTools()
		initPosition()

		# initLoadingBar()
		g.updateGrid()

		return

	# Initialize Romanesco and handlers
	$(document).ready () ->

		init()
		if g.rasterizerMode then return

		## mouse and key listeners

		g.canvasJ.dblclick( (event) -> g.selectedTool.doubleClick?(event) )
		# cancel default delete key behaviour (not really working)
		g.canvasJ.keydown( (event) -> if event.key == 46 then event.preventDefault(); return false )

		g.tool = new Tool()

		focusIsOnCanvas = ()->
			activeElementIsOnSidebar = $(document.activeElement).parents(".sidebar").length>0
			activeElementIsTextarea = $(document.activeElement).is("textarea")
			activeElementIsOnParameterBar = $(document.activeElement).parents(".dat-gui").length
			return not activeElementIsOnSidebar and not activeElementIsTextarea and not activeElementIsOnParameterBar

		# Paper listeners
		g.tool.onMouseDown = (event) ->
			if g.wacomPenAPI?.isEraser
				g.tool.onKeyUp( key: 'delete' )
				return
			$(document.activeElement).blur() # prevent to keep focus on the chat when we interact with the canvas
			# event = g.snap(event) 		# snapping mouseDown event causes some problems
			g.selectedTool.begin(event)
			return

		g.tool.onMouseDrag = (event) ->
			if g.wacomPenAPI?.isEraser then return
			if g.currentDiv? then return
			# event = g.snap(event)
			g.selectedTool.update(event)
			return

		g.tool.onMouseUp = (event) ->
			if g.wacomPenAPI?.isEraser then return
			if g.currentDiv? then return
			# event = g.snap(event)
			g.selectedTool.end(event)
			return

		g.tool.onKeyDown = (event) ->

			# if the focus is on anything in the sidebar or is a textarea or in parameters bar: ignore the event
			if not focusIsOnCanvas() then return

			if event.key == 'delete' 									# prevent default delete behaviour (not working)
				event.preventDefault()
				return false

			# select 'Move' tool when user press space key (and reselect previous tool after)
			if event.key == 'space' and g.selectedTool.name != 'Move'
				g.tools['Move'].select()

			return

		g.tool.onKeyUp = (event) ->
			# if the focus is on anything in the sidebar or is a textarea or in parameters bar: ignore the event
			if not focusIsOnCanvas() then return

			# - move selected RItem by delta if an arrow key was pressed (delta is function of special keys press)
			# - finish current path (if in polygon mode) if 'enter' or 'escape' was pressed
			# - select previous tool on space key up
			# - select 'Select' tool if key == 'v'
			# - delete selected item on 'delete' or 'backspace'
			if event.key in ['left', 'right', 'up', 'down']
				delta = if event.modifiers.shift then 50 else if event.modifiers.option then 5 else 1
			switch event.key
				when 'right'
					item.moveBy(new Point(delta,0), true) for item in g.selectedItems
				when 'left'
					item.moveBy(new Point(-delta,0), true) for item in g.selectedItems
				when 'up'
					item.moveBy(new Point(0,-delta), true) for item in g.selectedItems
				when 'down'
					item.moveBy(new Point(0,delta), true) for item in g.selectedItems
				when 'enter', 'escape'
					g.selectedTool.finish?()
				when 'space'
					g.previousTool?.select()
				when 'v'
					g.tools['Select'].select()
				when 'delete', 'backspace'
					selectedItems = g.selectedItems.slice()
					for item in selectedItems
						if item.selectionState?.segment?
							item.deletePointCommand()
						else
							item.deleteCommand()

			event.preventDefault()
			return

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
		$(window).resize (event) ->
			# g.backgroundCanvas.width = window.innerWidth
			# g.backgroundCanvas.height = window.innerHeight
			# g.backgroundCanvasJ.width(window.innerWidth)
			# g.backgroundCanvasJ.height(window.innerHeight)
			g.updateGrid()
			$(".mCustomScrollbar").mCustomScrollbar("update")
			view.update()
			return

		# mousedown event listener
		mousedown = (event) ->

			switch event.which						# switch on mouse button number (left, middle or right click)
				when 2
					g.tools['Move'].select()		# select move tool if middle mouse button
				when 3
					g.selectedTool.finish?() 	# finish current path (in polygon mode) if right click

			if g.selectedTool.name == 'Move' 		# update 'Move' tool if it is the one selected, and return
				# g.initialMousePosition = new Point(event.pageX, event.pageY)
				# g.previousMousePosition = g.initialMousePosition.clone()
				# g.selectedTool.begin()
				g.selectedTool.beginNative(event)
				return

			g.initialMousePosition = g.jEventToPoint(event)
			g.previousMousePosition = g.initialMousePosition.clone()

			return

		# mousemove event listener
		mousemove = (event) ->

			if g.selectedTool.name == 'Move' and g.selectedTool.dragging
				# mousePosition = new Point(event.pageX, event.pageY)
				# simpleEvent = delta: g.previousMousePosition.subtract(mousePosition)
				# g.previousMousePosition = mousePosition
				# console.log simpleEvent.delta.toString()
				# g.selectedTool.update(simpleEvent) 	# update 'Move' tool if it is the one selected
				g.selectedTool.updateNative(event)
				return

			# update selected RDivs
			# if g.previousPoint?
			# 	event.delta = new Point(event.pageX-g.previousPoint.x, event.pageY-g.previousPoint.y)
			# 	g.previousPoint = new Point(event.pageX, event.pageY)

			# 	for item in g.selectedItems
			# 		item.updateSelect?(event)

			# update code editor width
			g.codeEditor.mousemove(event)

			if g.currentDiv?
				paperEvent = g.jEventToPaperEvent(event, g.previousMousePosition, g.initialMousePosition, 'mousemove')
				g.currentDiv.updateSelect?(paperEvent)
				g.previousMousePosition = paperEvent.point

			return

		# mouseup event listener
		mouseup = (event) ->

			if g.selectedTool.name == 'Move'
				# g.selectedTool.end(g.previousMousePosition.equals(g.initialMousePosition))
				g.selectedTool.endNative(event)
				return

			# deselect move tool and select previous tool if middle mouse button
			if event.which == 2 # middle mouse button
				g.previousTool?.select()

			if g.currentDiv?
				paperEvent = g.jEventToPaperEvent(event, g.previousMousePosition, g.initialMousePosition, 'mouseup')
				g.currentDiv.endSelect?(paperEvent)
				g.previousMousePosition = paperEvent.point

			# drag handles
			# g.mousemove(event)
			# selectedDiv.endSelect(event) for selectedDiv in g.selectedDivs

			# # update selected RDivs
			# if g.previousPoint?
			# 	event.delta = new Point(event.pageX-g.previousPoint.x, event.pageY-g.previousPoint.y)
			# 	g.previousPoint = null
			# 	for item in g.selectedItems
			# 		item.endSelect?(event)

			g.codeEditor.mouseup(event)

			return
		# jQuery listeners
		g.canvasJ.mousedown( mousedown )
		g.stageJ.mousedown( mousedown )
		$(window).mousemove( mousemove )
		$(window).mouseup( mouseup )
		g.stageJ.mousewheel (event)->
			g.RMoveBy(new Point(-event.deltaX, event.deltaY))
			return


		return


	return
