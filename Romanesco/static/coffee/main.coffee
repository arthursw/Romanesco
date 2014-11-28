# TODO: manage items and path in the same way (g.paths and g.items)? make an interface on top of path and div, and use events to update them
# todo: add else case in switches
# todo: bug when creating a small div (happened with text)
# todo: snap div
# todo: center modal vertically with an event system: http://codepen.io/dimbslmh/pen/mKfCc and http://stackoverflow.com/questions/18422223/bootstrap-3-modal-vertical-position-center

paper.install(window)

g.hideOthers = (me)->
	for name, item of g.paths
		if item != me
			item.group?.visible = false
	g.fastModeOn = true
	return

g.showAll = (me)->
	if not g.fastModeOn then return
	for name, item of g.paths
		item.group?.visible = true
	g.fastModeOn = false
	return

g.getLimitPaths = ()->
	limit = getLimit()

	limitPathV = null
	limitPathH = null

	if limit.x >= view.bounds.left and limit.x <= view.bounds.right
		limitPathV = new Path()
		limitPathV.name = 'limitPathV'
		limitPathV.add(limit.x,view.bounds.top)
		limitPathV.add(limit.x,view.bounds.bottom)

	if limit.y >= view.bounds.top and limit.y <= view.bounds.bottom
		limitPathH = new Path()
		limitPathH.name = 'limitPathH'
		limitPathH.add(view.bounds.left, limit.y)
		limitPathH.add(view.bounds.right, limit.y)

	return vertical: limitPathV, horizontal: limitPathH

g.rectangleOverlapsTwoPlanets = (rectangle)->
	return g.overlapsTwoPlanets(new Path.Rectangle(rectangle))

g.pathOverlapsTwoPlanets = (path)->
	limitPaths = g.getLimitPaths()
	limitPathV = limitPaths.vertical
	limitPathH = limitPaths.horizontal

	if limitPathV?
		intersections = path.getIntersections(limitPathV)
		limitPathV.remove()
		if intersections.length>0
			return true

	if limitPathH?
		intersections = path.getIntersections(limitPathH)
		limitPathH.remove()
		if intersections.length>0
			return true

	return false

g.updateGrid = ()->
	g.grid.removeChildren()

	limitPaths = g.getLimitPaths()
	limitPathV = limitPaths.vertical
	limitPathH = limitPaths.horizontal

	if limitPathV?
		limitPathV.strokeColor = "#00FF00"
		limitPathV.strokeWidth = 5
		g.grid.addChild(limitPathV)

	if limitPathH?
		limitPathH.strokeColor = "#00FF00"
		limitPathH.strokeWidth = 5
		g.grid.addChild(limitPathH)

	if not g.displayGrid
		return
	
	t = Math.floor(view.bounds.top / g.scale)
	l = Math.floor(view.bounds.left / g.scale)
	b = Math.floor(view.bounds.bottom / g.scale)
	r = Math.floor(view.bounds.right / g.scale)

	pos = getTopLeftCorner()

	planet = projectToPlanet( pos )
	posOnPlanet = projectToPosOnPlanet( pos )

	debug = false

	snap = g.getSnap()
	if snap < 15 then snap = 15
	if debug then snap = 250

	n = 1
	i = l
	j = t
	while i<r+1 or j<b+1

		px = new Path()
		px.name = "grid px"
		py = new Path()
		px.name = "grid py"
		
		ijOnPlanet = projectToPosOnPlanet(new Point(i*g.scale,j*g.scale))

		if ijOnPlanet.x == -180
			px.strokeColor = "#00FF00"
			px.strokeWidth = 5
		else if n<4 # i-Math.floor(i)>0.0
			px.strokeColor = "#666666"
		else
			px.strokeColor = "#000000"
			px.strokeWidth = 2

		if ijOnPlanet.y == -90
			py.strokeColor = "#00FF00"
			py.strokeWidth = 5
		else if n<4 # j-Math.floor(j)>0.0
			py.strokeColor = "#666666"
		else
			py.strokeColor = "#000000"
			py.strokeWidth = 2

		px.add(new Point(i*g.scale, view.bounds.top))
		px.add(new Point(i*g.scale, view.bounds.bottom))

		py.add(new Point(view.bounds.left, j*g.scale))
		py.add(new Point(view.bounds.right, j*g.scale))
		
		g.grid.addChild(px)
		g.grid.addChild(py)

		i += snap/g.scale
		j += snap/g.scale
		
		if n==4 then n=0
		n++

	if not debug then return

	i = l
	while i<r+1
		j = t
		while j<b+1
			x = i*g.scale
			y = j*g.scale
			
			planetText = new PointText(new Point(x-10,y-40))
			planetText.justification = 'right'
			planetText.fillColor = 'black'
			p = projectToPlanet(new Point(i*g.scale,j*g.scale))
			planetText.content = 'px: ' + Math.floor(p.x) + ', py: ' + Math.floor(p.y)
			g.grid.addChild(planetText)
			posText = new PointText(new Point(x-10,y-20))
			posText.justification = 'right'
			posText.fillColor = 'black'
			p = projectToPosOnPlanet(new Point(i*g.scale,j*g.scale))
			posText.content = 'x: ' + p.x.toFixed(2) + ', y: ' + p.y.toFixed(2)
			g.grid.addChild(posText)
			

			j += snap/g.scale

		i += snap/g.scale
	return

this.gameAt = (point)->
	for div in g.divs
		if div.getBounds().contains(point) and div.constructor.name == 'RVideoGame'
		 	return div
	return null

# g.updateLoadingBar = (percentage)->
# 	updateLoadingText = ()->
# 		$("#loadingBar").text((percentage*100).toFixed(2) + '%')
# 		return
# 	window.setTimeout(updateLoadingText, 10)
# 	return

# g.initLoadingBar = ()->
# 	g.nLoadingRequest = 0
# 	g.nLoadingStartRequest = 0
# 	g.loadingBarTimeout = null 
# 	g.loadingBarJ = $("#loadingBar")
# 	g.loadingBarProject = new Project("loadingBar")
# 	g.loadingBarProject.activate()
# 	size = 70
# 	s = new Path.Star(new Point(size+30, size+30), 8, 0.8*size, size)
# 	s.strokeWidth = 10
# 	s.strokeColor = 'rgb(146, 215, 94)'

# 	for i in [1 .. 10]
# 		s = s.clone()
# 		s.rotation = 45/2
# 		s.scaling = 0.7
# 		l = s.strokeColor.getLightness()
# 		s.strokeColor.setLightness(l+(i+1)*0.01)
	
# 	paper.projects.first().activate()
# 	g.startLoadingBar()

# 	return

# g.setLoadingBar = (percentage)->
# 	if percentage>=1 then return
# 	loadingBarPath = g.loadingBarProject.activeLayer.children[0].clone()
# 	loadingBarPath.strokeColor = 'rgb(47, 161, 214)'
# 	reminder = loadingBarPath.split(loadingBarPath.length*percentage)
# 	reminder.remove()
# 	return

# g.animatedLoadingBar = ()->
# 	if not g.loadingBarJ? then return
# 	g.loadingBarProject.activeLayer.rotation += 0.5
# 	g.loadingBarProject.view.draw()
# 	# divJ = g.loadingBarJ.find(".rotation")
# 	# divJ.css( transform: 'rotate(' + (Date.now()/10) + 'deg)')
# 	# context = g.loadingBarJ.getContext("2d")
# 	# context.rotate(Date.now()/10)
# 	return

# g.startLoadingBar = (timeBeforeStart=200)->
# 	if not g.loadingBarJ? then return
# 	if g.loadingBarTimeout? then return
# 	g.loadingBarTimeout = setTimeout(g.startLoadingBarHandler, timeBeforeStart)
# 	g.nLoadingStartRequest++
# 	return

# g.startLoadingBarHandler = ()->
# 	if not g.loadingBarJ? then return

# 	g.nLoadingRequest++
# 	if g.loadingState == 'started' then return

# 	g.loadingBarJ.stop(true)
# 	g.loadingBarJ.fadeIn( duration: 200, queue: false )
# 	clearInterval(g.loadingInterval)
# 	g.loadingInterval = setInterval(g.animatedLoadingBar, 1000/60)
# 	g.loadingState = 'started'

# 	return

# g.stopLoadingBar = ()->
# 	if not g.loadingBarJ? then return
	
# 	g.nLoadingRequest--
# 	if g.nLoadingRequest>0 then return

# 	g.nLoadingStartRequest--
# 	if g.nLoadingStartRequest==0 then clearTimeout(g.loadingBarTimeout)

# 	g.loadingState = 'stop requested'
	
# 	g.loadingBarJ.fadeOut( duration: 200, queue: false, complete: ()-> 
# 		clearInterval(g.loadingInterval)
# 		g.loadingInterval = null
# 		g.loadingState = 'stopped'
# 		return
# 	)
# 	return

g.RMoveTo = (pos) ->
	g.RMoveBy(pos.subtract(view.center))

g.RMoveBy = (delta) ->
	
	if g.restrictedArea?
		
		# check if the restricted area contains view.center (if not, move to center)
		if not g.restrictedArea.contains(view.center)
			# delta = g.restrictedArea.center.subtract(view.size.multiply(0.5)).subtract(view.topLeft)
			delta = g.restrictedArea.center.subtract(view.center)
		else
			# test if new pos is still in restricted area
			newView = view.bounds.clone()
			newView.center.x += delta.x
			newView.center.y += delta.y

			# if it does not contain the view, change delta so that it contains it
			if not g.restrictedArea.contains(newView)

				restrictedAreaShrinked = g.restrictedArea.expand(view.size.multiply(-1)) # restricted area shrinked by view.size
				
				if restrictedAreaShrinked.width<0
					restrictedAreaShrinked.left = restrictedAreaShrinked.right = g.restrictedArea.center.x
				if restrictedAreaShrinked.height<0
					restrictedAreaShrinked.top = restrictedAreaShrinked.bottom = g.restrictedArea.center.y

				newView.center.x = g.clamp(restrictedAreaShrinked.left, newView.center.x, restrictedAreaShrinked.right)
				newView.center.y = g.clamp(restrictedAreaShrinked.top, newView.center.y, restrictedAreaShrinked.bottom)
				delta = newView.center.subtract(view.center)
	
	# console.log minusDelta
	project.view.scrollBy(new Point(delta.x, delta.y))
	
	for div in g.divs
		div.updateTransform()

	newEntireArea = null
	for area in g.entireAreas
		if area.getBounds().contains(project.view.center)
			newEntireArea = area
			break

	if not g.entireArea? and newEntireArea?
		g.entireArea = newEntireArea.getBounds()
	else if g.entireArea? and not newEntireArea?
		g.entireArea = null

	updateGrid()
	if newEntireArea? then load(g.entireArea) else load()
	g.updateRoom()

	g.defferedExecution(g.updateHash, 500)
	g.setControllerValue(g.parameters.location.controller, null, '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2))
	return

g.updateHash = ()->
	g.moving = true
	location.hash = '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2)
	return

window.onhashchange = (event) ->
	if g.moving
		g.moving = false
		return
	pos = location.hash.substr(1).split(',')
	p = new Point()
	p.x = parseFloat(pos[0])
	p.y = parseFloat(pos[1])
	if not p.x then p.x = 0
	if not p.y then p.y = 0
	g.RMoveTo(p)
	return

# --- Tools --- #

initTools = () ->
	g.toolsJ = $(".tool-list")
	g.favoriteToolsJ = $("#FavoriteTools .tool-list")
	g.allToolsContainerJ = $("#AllTools")
	g.allToolsJ = g.allToolsContainerJ.find(".all-tool-list")

	if localStorage?
		try
			g.favoriteTools = JSON.parse(localStorage.favorites)
		catch error
			console.log error

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
	
	new PathTool(PrecisePath)
	new PathTool(RectangleShape)
	new PathTool(SpiralShape)
	new PathTool(SketchPath)

	new PathTool(SpiralPath)
	new PathTool(ShapePath)
	new PathTool(StarShape)
	new PathTool(EllipseShape)

	new PathTool(RollerPath)
	new PathTool(FuzzyPath)
	new PathTool(Checkpoint)

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

	# ajaxPost '/getTools', {}, (result)->
	Dajaxice.draw.getTools (result)->
		scripts = JSON.parse(result.tools)

		for script in scripts
			g.runScript(script)

		initToolTypeahead()
		return

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

	$( "#sortable1, #sortable2" ).sortable( connectWith: ".connectedSortable", appendTo: g.sidebarJ, helper: "clone", start: sortStart, stop: sortStop ).disableSelection()

	g.tools['Move'].select()


this.deselectAll = ()->
	item.deselect?() for item in g.selectedItems()
	project.activeLayer.selected = false
	return

this.mousedown = (event) ->
	# select move tool if middle mouse button
	switch event.which # middle mouse button
		when 2
			g.tools['Move'].select()
		when 3
			g.selectedTool.finishPath?()

	if g.selectedTool.name == 'Move' 
		g.selectedTool.beginNative(event)
		return
	
	if event.target.nodeName == "CANVAS" then return false
	g.previousPoint = new Point(event.pageX, event.pageY)
	return

this.mousemove = (event) ->
	if g.selectedTool.name == 'Move' then g.selectedTool.updateNative(event)

	# selectedDiv.selectUpdate(event) for selectedDiv in g.selectedDivs
	
	if g.previousPoint?
		event.delta = new Point(event.pageX-g.previousPoint.x, event.pageY-g.previousPoint.y)
		g.previousPoint = new Point(event.pageX, event.pageY)

		for item in g.selectedItems()
			item.selectUpdate?(event)
	
	if g.draggingEditor
		g.editorJ.css( right: g.windowJ.width()-event.pageX)

	return

this.mouseup = (event) ->
	if g.selectedTool.name == 'Move' then g.selectedTool.endNative(event)

	# deselect move tool and select previous tool if middle mouse button
	if event.which == 2 # middle mouse button
		g.previousTool?.select()

	# drag handles	
	g.mousemove(event)
	# selectedDiv.selectEnd(event) for selectedDiv in g.selectedDivs

	if g.previousPoint?
		event.delta = new Point(event.pageX-g.previousPoint.x, event.pageY-g.previousPoint.y)
		g.previousPoint = null
		for item in g.selectedItems()
			item.selectEnd?(event)

	g.draggingEditor = false
	
	return

this.selectedItems = ()->
	items = []
	for item in project.selectedItems
		if item.controller? and items.indexOf(item.controller)<0 then items.push(item.controller)
	return items.concat g.selectedDivs

this.sel = ()->
	return g.selectedItems()[0]

initPosition = ()->
	boxString = g.canvasJ.attr("data-box")
	
	if not boxString or boxString.length==0
		window.onhashchange()
		return

	box = JSON.parse( boxString )

	planet = new Point(box.planetX, box.planetY)
	
	tl = posOnPlanetToProject(box.box.coordinates[0][0], planet)
	br = posOnPlanetToProject(box.box.coordinates[0][2], planet)

	boxRectangle = new Rectangle(tl, br)
	pos = boxRectangle.center

	loadEntireArea = g.canvasJ.attr("data-load-entire-area")
	g.RMoveTo(pos)

	if loadEntireArea
		g.entireArea = boxRectangle
		g.load(boxRectangle)

	# boxData = if box.data? and box.data.length>0 then JSON.parse(box.data) else null
	# console.log boxData

	siteString = g.canvasJ.attr("data-site")
	site = JSON.parse( siteString )
	if site.restrictedArea
		g.restrictedArea = boxRectangle
	
	g.tools['Select'].select()

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

this.toggleSidebar = (show)->
	show ?= not g.sidebarJ.hasClass("r-hidden")
	if show
		g.sidebarJ.addClass("r-hidden")
		g.editorJ.addClass("r-hidden")
		g.alertsContainer.addClass("r-sidebar-hidden")
		g.sidebarHandleJ.find("span").removeClass("glyphicon-chevron-left").addClass("glyphicon-chevron-right")
	else
		g.sidebarJ.removeClass("r-hidden")
		g.editorJ.removeClass("r-hidden")
		g.alertsContainer.removeClass("r-sidebar-hidden")
		g.sidebarHandleJ.find("span").removeClass("glyphicon-chevron-right").addClass("glyphicon-chevron-left")
	return

# init global variables
init = ()->
	g.windowJ = $(window)
	g.stageJ = $("#stage")
	g.sidebarJ = $("#sidebar")
	g.canvasJ = g.stageJ.find("#canvas")
	g.canvas = g.canvasJ[0]
	g.context = g.canvas.getContext('2d')
	g.templatesJ = $("#templates")
	g.me = null
	g.dragOffset = { x: 0, y: 0 }
	g.draggedDivJ = null
	g.selectedDivs = []
	g.selectionGroup = null
	g.polygonMode = false
	g.selectionBlue = '#2fa1d6'
	g.updateTimeout = {}
	g.restrictedArea = null
	g.offset = { x: 0, y: 0 }
	g.OSName = "Unknown OS"
	g.currentPaths = {}
	g.loadingBarTimeout = null
	g.entireArea = null
	g.entireAreas = []
	g.animatedItems = []
	g.cars = {}
	g.fastMode = false
	g.fastModeOn = false
	# g.globalMaskJ = $("#globalMask")
	# g.globalMaskJ.hide()

	if navigator.appVersion.indexOf("Win")!=-1 then g.OSName = "Windows"
	if navigator.appVersion.indexOf("Mac")!=-1 then g.OSName = "MacOS"
	if navigator.appVersion.indexOf("X11")!=-1 then g.OSName = "UNIX"
	if navigator.appVersion.indexOf("Linux")!=-1 then g.OSName = "Linux"

	paper.setup(canvas)
	activeLayer = project.activeLayer
	g.carLayer = new Layer()
	activeLayer.activate()
	paper.settings.hitTolerance = 5

	Point.prototype.toJSON = ()->
		return { x: this.x, y: this.y }
	Point.prototype.exportJSON = ()->
		return JSON.stringify(this.toJSON())

	g.tool = new Tool()

	g.paths = new Object()
	g.sortedPaths = []
	g.grid = new Group()
	g.grid.name = 'grid group'

	# g.defaultColors = ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ]
	g.defaultColors = ['#d7dddb', '#4f8a83', '#e76278', '#fac699', '#712164']

	# --- Alerts --- #
	g.alertsContainer = $("#Romanesco_alerts")
	g.alerts = []
	g.currentAlert = -1
	g.alertTimeOut = -1
	g.alertsContainer.find(".btn-up").click( -> setAlert(g.currentAlert-1) )
	g.alertsContainer.find(".btn-down").click( -> setAlert(g.currentAlert+1) )

	g.loadedAreas = []
	g.areasToObjects = new Object()
	g.items = new Object()
	g.locks = []
	g.divs = []

	g.sidebarHandleJ = g.sidebarJ.find(".sidebar-handle")
	g.sidebarHandleJ.click ()->
		g.toggleSidebar()
		return

	g.sidebarJ.find("#buyRomanescoins").click ()-> 
		g.templatesJ.find('#romanescoinModal').modal('show')
		paypalFormJ = g.templatesJ.find("#paypalForm")
		paypalFormJ.find("input[name='submit']").click( ()-> 
			data = 
				user: g.me
				location: { x: view.center.x, y: view.center.y }
			paypalFormJ.find("input[name='custom']").attr("value", JSON.stringify(data) )
		)
	

	g.sidebarJ.find("#codeSubmit").click ()->
		return

	# g.sound = new RSound(['/static/sounds/space_ship_engine.mp3', '/static/sounds/space_ship_engine.ogg'])

	g.sound = new RSound(['/static/sounds/viper.ogg'])

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

	initOptions()
	initCodeEditor()
	initTools()
	initSocket()
	initPosition()
	# initLoadingBar()

	g.canvasJ.mousedown( g.mousedown )
	g.stageJ.mousedown( g.mousedown )
	$(window).mousemove( g.mousemove )
	$(window).mouseup( g.mouseup )
	g.stageJ.mousewheel( (event)->
		g.RMoveBy(new Point(-event.deltaX, -event.deltaY))
		return
	)

	return

$(document).ready () ->
	init()
	updateGrid()

	canvasJ.dblclick( (event) -> g.selectedTool.doubleClick?(event) )
	canvasJ.keydown( (event) -> if event.key == 43 then event.preventDefault() )

	tool.onMouseDown = (event) ->
		$(document.activeElement).blur() # prevent to keep focus on the chat when we interact with the canvas
		# event = g.snap(event)
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
		if event.key == 'delete'
			event.preventDefault()
		if event.key == 'space' and g.selectedTool.name != 'Move'
			g.tools['Move'].select()

	tool.onKeyUp = (event) ->
		# if user is typing: ignore
		# for selectedDiv in g.selectedDivs
		# 	if selectedDiv.constructor.name == 'RText'
		# 		return

		# if the focus is on anything in the sidebar or is a textarea: ignore the delete
		if $(document.activeElement).parents(".sidebar").length or $(document.activeElement).is("textarea")
			return

		if event.key in ['left', 'right', 'up', 'down']
			delta = if event.modifiers.shift then 50 else if event.modifiers.option then 5 else 1
		switch event.key
			when 'right'
				item.moveBy(new Point(delta,0)) for item in g.selectedItems()
			when 'left'
				item.moveBy(new Point(-delta,0)) for item in g.selectedItems()
			when 'up'
				item.moveBy(new Point(0,-delta)) for item in g.selectedItems()
			when 'down'
				item.moveBy(new Point(0,delta)) for item in g.selectedItems()
			when 'enter', 'escape'
				g.selectedTool.finishPath?()
			when 'space'
				g.previousTool?.select()
			when 'v'
				g.tools['Select'].select()
			when 'delete', 'backspace'
				for item in g.selectedItems()
					item.delete()
		
		event.preventDefault()
	
	view.onFrame = (event)->
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

	$(".mCustomScrollbar.sidebar-scrollbar").mCustomScrollbar( keyboard: false )

	g.windowJ.resize( (event) ->
		updateGrid()
		$(".mCustomScrollbar").mCustomScrollbar("update")
		view.draw()
	)

	# debug function to log pk of selected path
	# debugSelectedBefore = null
	# debug = ()->
	# 	paper.view.draw()
	# 	if project.selectedItems.length>0 and debugSelectedBefore!=project.selectedItems[0]
	# 		debugSelectedBefore = project.selectedItems[0]
	# 		if project.selectedItems[0].hasOwnProperty('pk')
	# 			console.log project.selectedItems[0].pk

	# setInterval(debug, 500)

this.logItems = ()->

	console.log "Selected items:"
	for item, i in project.selectedItems
		if item.name?.indexOf("debug")==0 then continue
		console.log "------" + i + "------"
		console.log item.name
		console.log item
		console.log item.controller
		console.log item.controller?.pk
	console.log "All items:"
	for item, i in project.activeLayer.children
		if item.name?.indexOf("debug")==0 then continue
		console.log "------" + i + "------"
		console.log item.name
		console.log item
		console.log item.controller
		console.log item.controller?.pk
	console.log "hiiiiiii"
	return "--- THE END ---"

this.checkRasters = ()->
	for item in project.activeLayer.children
		if item.controller? and not item.controller.raster?
			console.log item.controller
			# item.controller.rasterize()
	return