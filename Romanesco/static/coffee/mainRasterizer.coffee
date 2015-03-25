
initTools = () ->
	g.tools = {}
	for pathClass in pathClasses
		g.tools[pathClass.rname] = RPath: pathClass
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
	g.selectionLayer = null					# paper layer containing all selected paper items
	g.polygonMode = false					# whether to draw in polygon mode or not (in polygon mode: each time the user clicks a point will be created, in default mode: each time the user moves the mouse a point will be created)
	g.selectionBlue = '#2fa1d6'
	g.updateTimeout = {} 					# map of id -> timeout id to clear the timeouts
	g.restrictedArea = null 				# area in which the user position will be constrained (in a website with restrictedArea == true)
	g.currentPaths = {} 					# map of username -> path id corresponding to the paths currently being created
	g.loadingBarTimeout = null 				# timeout id of the loading bar
	g.entireArea = null 					# entire area to be kept loaded, it is a paper Rectangle
	g.entireAreas = [] 						# array of RDivs which have data.loadEntireArea==true
	g.loadedAreas = [] 						# array of areas { pos: pos, planet: planet } which are loaded (to test if areas have to be loaded or unloaded)
	g.paths = new Object() 					# a map of RPath.pk (or RPath.id) -> RPath. RPath are first added with their id, and then with their pk (as soon as server saved it and responds)
	g.items = new Object() 					# map RItem.id or RItem.pk -> RItem, all loaded RItems. The key is RItem.id before RItem is savied in the database, and RItem.pk after
	g.locks = [] 							# array of loaded RLocks
	g.divs = [] 							# array of loaded RDivs
	g.sortedPaths = []						# an array where paths are sorted by index (z-index)
	g.sortedDivs = []						# an array where divs are sorted by index (z-index)
	g.fastMode = false 						# fastMode will hide all items except the one being edited (when user edits an item)
	g.fastModeOn = false					# fastModeOn is true when the user is edditing an item
	g.scale = 1000.0 						# the scale to go from project coordinates to planet coordinates
	g.rasters = {}							# map to store rasters (tiles, rasterized version of the view)
	g.catchErrors = false 					# the error will not be caught when drawing an RPath (let chrome catch them at the right time)
	g.limitPathV = null 					# the vertical limit path (line between two planets)
	g.limitPathH = null 					# the horizontal limit path (line between two planets)
	g.defaultColors = []
	g.gui = __folders: {}
	g.animatedItems = []
	g.rasterizerMode = true
	g.areaToRasterize = null				# the area to rasterize

	# Display a romanesco_alert message when a dajaxice error happens (problem on the server)
	Dajaxice.setup( 'default_exception_callback': (error)-> 
		console.log 'Dajaxice error!'
		romanesco_alert "Connection error", "error"
		return
	)

	g.itemListsJ = $()
	g.pathList = $()
	g.divList = $()

	# init paper.js
	paper.setup(canvas)
	Layer.project = "gogo"
	g.mainLayer = project.activeLayer
	g.lockLayer = new Layer()	 			# Paper layer to keep all locked items
	g.debugLayer = new Layer()				# Paper layer to append debug items
	g.mainLayer.activate()
	g.grid = new Group() 					# Paper Group to append all grid items
	g.grid.name = 'grid group'

	view.zoom = 1 # 0.01

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

	initializeGlobalParameters()
	initTools()
	# initPosition()
	
	return

$(document).ready () ->
	init()
	return

# fake functions
this.fakeFunction = ()->
	return

this.updateRoom = this.fakeFunction
this.setControllerValueByName = this.fakeFunction
this.setControllerValue = this.fakeFunction
this.deferredExecution = this.fakeFunction
this.romanesco_alert = this.fakeFunction
jQuery.fn.mCustomScrollbar = this.fakeFunction
