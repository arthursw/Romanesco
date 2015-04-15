
# paper.install(window)

# # initialize Romanesco
# # all global variables and functions are stored in *g* which is a synonym of *window*
# # all jQuery elements names end with a capital J: elementNameJ
# init = ()->
# 	# g.romanescoURL = 'http://romanesc.co/'
# 	g.romanescoURL = 'http://localhost:8000/'
# 	g.windowJ = $(window)
# 	g.stageJ = $("#stage")
# 	g.sidebarJ = $("#sidebar")
# 	g.canvasJ = g.stageJ.find("#canvas")
# 	g.canvas = g.canvasJ[0]
# 	g.context = g.canvas.getContext('2d')
# 	g.templatesJ = $("#templates")
# 	g.me = null 							# g.me is the username of the user (sent by the server in each ajax "load")
# 	g.selectionLayer = null					# paper layer containing all selected paper items
# 	g.polygonMode = false					# whether to draw in polygon mode or not (in polygon mode: each time the user
# 						# clicks a point will be created, in default mode: each time the user moves the mouse a point will be created)
# 	g.selectionBlue = '#2fa1d6'
# 	g.updateTimeout = {} 					# map of id -> timeout id to clear the timeouts
# 	g.requestedCallbacks = {} 				# map of id -> request id to clear the requestAnimationFrame
# 	g.restrictedArea = null 				# area in which the user position will be constrained (in a website with restrictedArea == true)
# 	g.currentPaths = {} 					# map of username -> path id corresponding to the paths currently being created
# 	g.loadingBarTimeout = null 				# timeout id of the loading bar
# 	g.entireArea = null 					# entire area to be kept loaded, it is a paper Rectangle
# 	g.entireAreas = [] 						# array of RDivs which have data.loadEntireArea==true
# 	g.loadedAreas = [] 						# array of areas { pos: pos, planet: planet } which are loaded (to test if areas have to be loaded or unloaded)
# 	g.paths = new Object() 					# a map of RPath.pk (or RPath.id) -> RPath. RPath are first added with their id, and then with their pk (as soon as server saved it and responds)
# 	g.items = new Object() 					# map RItem.id or RItem.pk -> RItem, all loaded RItems. The key is RItem.id before RItem is savied in the database, and RItem.pk after
# 	g.locks = [] 							# array of loaded RLocks
# 	g.divs = [] 							# array of loaded RDivs
# 	g.sortedPaths = []						# an array where paths are sorted by index (z-index)
# 	g.sortedDivs = []						# an array where divs are sorted by index (z-index)
# 	# g.fastMode = false 						# fastMode will hide all items except the one being edited (when user edits an item)
# 	# g.fastModeOn = false					# fastModeOn is true when the user is edditing an item
# 	g.scale = 1000.0 						# the scale to go from project coordinates to planet coordinates
# 	g.rasters = {}							# map to store rasters (tiles, rasterized version of the view)
# 	g.catchErrors = false 					# the error will not be caught when drawing an RPath (let chrome catch them at the right time)
# 	g.limitPathV = null 					# the vertical limit path (line between two planets)
# 	g.limitPathH = null 					# the horizontal limit path (line between two planets)
# 	g.defaultColors = []
# 	g.gui = __folders: {}
# 	g.animatedItems = []
# 	g.rasterizerMode = true
# 	g.areaToRasterize = null				# the area to rasterize

# 	# Display a romanesco_alert message when a dajaxice error happens (problem on the server)
# 	Dajaxice.setup( 'default_exception_callback': (error)->
# 		console.log 'Dajaxice error!'
# 		romanesco_alert "Connection error", "error"
# 		return
# 	)

# 	g.itemListsJ = $()
# 	g.pathList = $()
# 	g.divList = $()

# 	# init paper.js
# 	paper.setup(canvas)
# 	Layer.project = "gogo"
# 	g.mainLayer = project.activeLayer
# 	g.lockLayer = new Layer()	 			# Paper layer to keep all locked items
# 	g.debugLayer = new Layer()				# Paper layer to append debug items
# 	g.areasToUpdateLayer = new Layer() 		# Paper layer to show areas to update
# 	g.mainLayer.activate()
# 	g.grid = new Group() 					# Paper Group to append all grid items
# 	g.grid.name = 'grid group'
# 	g.grid.visible = false
# 	g.debugLayer.visible = false

# 	view.zoom = 1 # 0.01
# 	view.pause()

# 	# load path source code
# 	$.ajax( url: g.romanescoURL + "static/coffee/path.coffee" ).done (data)->

# 		lines = data.split(/\n/)
# 		expressions = CoffeeScript.nodes(data).expressions

# 		classMap = {}
# 		for pathClass in g.pathClasses
# 			classMap[pathClass.name] = pathClass

# 		for expression in expressions
# 			source = lines[expression.locationData.first_line .. expression.locationData.last_line].join("\n")
# 			classMap[expression.variable.base.value]?.source = source

# 		return

# 	# initializeGlobalParameters()
# 	initTools()
# 	# initPosition()

# 	return

# $(document).ready () ->
# 	init()
# 	return

# fake functions

this.rasterizerMode = true

this.setTools = () ->
	g.tools = {}
	for pathClass in pathClasses
		g.tools[pathClass.rname] = RPath: pathClass
	return

this.fakeFunction = ()->
	return

this.updateRoom = this.fakeFunction
this.setControllerValueByName = this.fakeFunction
this.setControllerValue = this.fakeFunction
this.deferredExecution = this.fakeFunction
this.romanesco_alert = this.fakeFunction
this.rasterizer =
	load: this.fakeFunction
	unload: this.fakeFunction
	move: this.fakeFunction
	rasterizeAreasToUpdate: this.fakeFunction
	addAreaToUpdate: this.fakeFunction
	setQZoomToUpdate: this.fakeFunction
jQuery.fn.mCustomScrollbar = this.fakeFunction
this.selectedToolNeedsDrawings = ()->
	return true

this.CommandManager = this.fakeFunction
this.Rasterizer = this.fakeFunction
this.initializeGlobalParameters = this.fakeFunction
this.initParameters = this.fakeFunction
this.initCodeEditor = this.fakeFunction
this.initSocket = this.fakeFunction
this.initPosition = this.fakeFunction
this.updateGrid = this.fakeFunction
this.RSound = this.fakeFunction
this.chatSocket = emit: this.fakeFunction
this.defaultColors = []
this.gui = __folders: {}
this.animatedItems = []
this.areaToRasterize = null				# the area to rasterize

# rasterizer

this.createItemsDates = (bounds)->
	itemsDates = {}
	for pk, item of g.items
		# if bounds.contains(item.getBounds())
		type = ''
		if RLock.prototype.isPrototypeOf(item)
			type = 'Box'
		else if RDiv.prototype.isPrototypeOf(item)
			type = 'Div'
		else if RPath.prototype.isPrototypeOf(item)
			type = 'Path'
		itemsDates[pk] = item.lastUpdateDate
		# itemsDates.push( pk: pk, lastUpdate: item.lastUpdateDate, type: type )
	return itemsDates

# this.removeItemsToUpdate = (itemsToUpdate)->
# 	for pk in itemsToUpdate
# 		g.items[pk].remove()
# 	return


this.loopRasterize = ()->

	rectangle = g.areaToRasterize

	width = Math.min(1000, rectangle.right - view.bounds.left)
	height = Math.min(1000, rectangle.bottom - view.bounds.top)

	newSize = new Size(width, height)

	if not view.viewSize.equals(newSize)
		topLeft = view.bounds.topLeft
		view.viewSize = newSize
		view.center = topLeft.add(newSize.multiply(0.5))

	imagePosition = view.bounds.topLeft.clone()

	# text = new PointText(view.bounds.center)
	# text.justification = 'center'
	# text.fillColor = 'black'
	# text.content = 'Pos: ' + view.bounds.center.toString()

	# view.update()
	dataURL = g.canvas.toDataURL()

	finished = view.bounds.bottom >= rectangle.bottom and view.bounds.right >= rectangle.right

	if not finished
		if view.bounds.right < rectangle.right
			view.center = view.center.add(1000, 0)
		else
			view.center = new Point(rectangle.left+view.viewSize.width*0.5, view.bounds.bottom+view.viewSize.height*0.5)
	else
		g.areaToRasterize = null
	window.saveOnServer(dataURL, imagePosition.x, imagePosition.y, finished)
	return

this.rasterizeAndSaveOnServer = ()->
	console.log "area rasterized"

	view.viewSize = Size.min(new Size(1000,1000), g.areaToRasterize.size)
	view.center = g.areaToRasterize.topLeft.add(view.size.multiply(0.5))
	g.loopRasterize()

	return

this.loadArea = (args)->
	console.log "load_area"

	if g.areaToRasterize?
		console.log "error: load_area while loading !!"
		return

	area = g.expandRectangleToInteger(g.rectangleFromBox(JSON.parse(args)))
	g.areaToRasterize = area
	# view.viewSize = Size.min(area.size, new Size(1000, 1000))

	# move the view
	delta = area.center.subtract(view.center)
	project.view.scrollBy(delta)
	for div in g.divs
		div.updateTransform()

	console.log "call load"

	g.load(area)

	return

# rasterizer tests

this.getAreasToUpdate = ()->
	if g.areasToRasterize.length==0 and g.imageSaved
		Dajaxice.draw.getAreasToUpdate(g.getAreasToUpdateCallback)
	return

this.loadNextArea = ()->
	if g.areasToRasterize.length>0
		area = g.areasToRasterize.shift()
		g.areaToRasterizePk = area._id.$oid
		g.imageSaved = false
		g.loadArea(JSON.stringify(area))
	return

this.getAreasToUpdateCallback = (areas)->
	g.areasToRasterize = areas
	loadNextArea()
	return

this.testSaveOnServer = (imageDataURL, x, y, finished)->
	if not imageDataURL
		console.log "no image data url"
	g.rasterizedAreasJ.append($('<img src="' + imageDataURL + '" data-position="' + x + ', ' + y + '" finished="' + finished + '">')
	.css( border: '1px solid black'))
	console.log 'position: ' + x + ', ' + y
	console.log 'finished: ' + finished
	if finished
		Dajaxice.draw.deleteAreaToUpdate(g.deleteAreaToUpdateCallback, { pk: g.areaToRasterizePk } )
	else
		g.loopRasterize()
	return

this.deleteAreaToUpdateCallback = (result)->
	g.checkError(result)
	g.imageSaved = true
	loadNextArea()
	return

this.testRasterizer = ()->
	g.rasterizedAreasJ = $('<div class="rasterized-areas">')
	g.rasterizedAreasJ.css( position: 'absolute', top: 1000, left: 0 )
	$('body').css( overflow: 'auto' ).prepend(g.rasterizedAreasJ)
	window.saveOnServer = g.testSaveOnServer
	g.areasToRasterize = []
	g.imageSaved = true
	setInterval(getAreasToUpdate, 1000)
	return


