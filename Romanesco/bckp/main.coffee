paper.install(window)

# TODO: manage items and path in the same way (g.paths and g.items)?

# divs: lock, links, text and medias 

updateGrid = ()->
	g.grid.removeChildren()

	if not g.displayGrid
		return
	[tlX, tlY, brX, brY] = screenBox()


	pos = new Point(-g.offset.x, -g.offset.y)
	planet = screenToPlanet( pos )
	posOnplanet = screenToPosOnPlanet( pos )

	i = tlX
	while i<brX+1
		p = new Path()
		
		if screenToPosOnPlanetX(i*g.scale) == -180
			p.strokeColor = "#00FF00"
			p.strokeWidth = 5
		else if i-Math.floor(i)>0.0
			p.strokeColor = "#666666"
		else
			p.strokeColor = "#000000"
			p.strokeWidth = 2

		p.add(new Point(i*g.scale+g.offset.x, 0))
		p.add(new Point(i*g.scale+g.offset.x, view.size.height))
		g.grid.addChild(p)
		i += 0.25

	i = tlY
	while i<brY+1
		p = new Path()

		if screenToPosOnPlanetY(i*g.scale) == -90
			p.strokeColor = "#0000FF"
			p.strokeWidth = 5
		else if i-Math.floor(i)>0.0
			p.strokeColor = "#666666"
		else
			p.strokeColor = "#000000"
			p.strokeWidth = 2

		p.add(new Point(0, i*g.scale+g.offset.y))
		p.add(new Point(view.size.width, i*g.scale+g.offset.y))
		g.grid.addChild(p)
		i += 0.25

	i = tlX
	while i<brX+1
		j = tlY
		while j<brY+1
			x = i*g.scale+g.offset.x
			y = j*g.scale+g.offset.y
			planetText = new PointText(new Point(x-10,y-40))
			planetText.justification = 'right'
			planetText.fillColor = 'black'
			p = screenToPlanet(new Point(i*1000,j*1000))
			planetText.content = 'px: ' + Math.floor(p.x) + ', py: ' + Math.floor(p.y)
			g.grid.addChild(planetText)
			posText = new PointText(new Point(x-10,y-20))
			posText.justification = 'right'
			posText.fillColor = 'black'
			p = screenToPosOnPlanet(new Point(i*1000,j*1000))
			posText.content = 'x: ' + p.x.toFixed(2) + ', y: ' + p.y.toFixed(2)
			g.grid.addChild(posText)
			j += 0.25
		i += 0.25
	return

g.RMoveTo = (pos) ->
	g.RMoveBy(pos.subtract(g.offset))

g.RMoveBy = (delta) ->
	project.activeLayer.position.x += delta.x
	project.activeLayer.position.y += delta.y

	for item in $(".ft-controls")
		itemJ = $(item)
		p = itemJ.offset()
		itemJ.offset( { left: p.left+delta.x, top: p.top+delta.y } )

	for itemJ in g.()
		p = itemJ.offset()
		
		itemJ.offset( { left: p.left+delta.x, top: p.top+delta.y } )

		if itemJ.hasClass('item')
			itemJ.data('freetrans').x += delta.x
			itemJ.data('freetrans').y += delta.y

	g.offset.x += delta.x
	g.offset.y += delta.y
	updateGrid()
	load()
	g.moving = true
	location.hash = '' + g.offset.x.toFixed(2) + ',' + g.offset.y.toFixed(2)

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

# --- Tools --- #
initTools = () ->
	g.toolsJ = $(".tool-list")

	g.tools = new Object()
	new MoveTool()
	new BrushTool()
	new RollerBrushTool()
	new LinkTool()
	new LockTool()
	new RectangleTool()
	new CircleTool()
	new SelectTool()
	new TextTool()
	new MediaTool()

	g.tools['move'].select()

# --- Options --- #

updateFillColor = ()->
	if not g.itemsToUpdate?
		return
	for item in g.itemsToUpdate
		g.updatePath(item, 'fillColor')
	return

updateStrokeColor = ()->
	if not g.itemsToUpdate?
		return
	for item in g.itemsToUpdate
		g.updatePath(item, 'strokeColor')
	return

initOptions = () ->
	colorName = g.defaultColors[Math.floor(Math.random()*g.defaultColors.length)]
	colorRGBstring = tinycolor(colorName).toRgbString() 
	g.strokeColor = colorRGBstring
	g.fillColor = "rgb(255,255,255,255)"
	g.optionsJ = $(".option-list")

	# --- Sliders --- #

	g.strokeColorSlider = optionsJ.find("#strokeColorPicker").ColorPickerSliders( {
		title: 'Stroke color',
		placement: 'right',
		color: g.strokeColor,
		order: {
			hsl: 1,
			rgb: 2,
			opacity: 3,
			preview: 4
		},
		labels: {
			rgbred: 'Red',
			rgbgreen: 'Green',
			rgbblue: 'Blue',
			hslhue: 'Hue',
			hslsaturation: 'Saturation',
			hsllightness: 'Lightness',
			preview: 'Preview',
			opacity: 'Opacity'
		},
		customswatches: "different-swatches-groupname",
		swatches: ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ],
		onchange: ((container, color)-> 
			g.strokeColor = color.tiny.toRgbString()
			for item in g.project.selectedItems
				item.strokeColor = g.strokeColor

			if g.strokeColorTimeout?
				clearTimeout(g.strokeColorTimeout)
			g.itemsToUpdate = g.project.selectedItems
			g.strokeColorTimeout = setTimeout(updateStrokeColor, 500)
		)
	})
	g.fillColorSlider = optionsJ.find("#fillColorPicker").ColorPickerSliders( {
		title: 'Fill color',
		placement: 'right',
		color: g.fillColor,
		order: {
			hsl: 1,
			rgb: 2,
			opacity: 3,
			preview: 4
		},
		labels: {
			rgbred: 'Red',
			rgbgreen: 'Green',
			rgbblue: 'Blue',
			hslhue: 'Hue',
			hslsaturation: 'Saturation',
			hsllightness: 'Lightness',
			preview: 'Preview',
			opacity: 'Opacity'
		},
		customswatches: "different-swatches-groupname",
		swatches: ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ],
		onchange: ((container, color)-> 
			g.fillColor = color.tiny.toRgbString() 
			for item in g.project.selectedItems
				item.fillColor = g.fillColor

			if g.fillColorTimeout?
				clearTimeout(g.fillColorTimeout)
			g.itemsToUpdate = g.project.selectedItems
			g.fillColorTimeout = setTimeout(updateFillColor, 500)
		)
	})
	g.fillColorSlider.blur(()->
		for item in g.project.selectedItems
			g.updatePath(item, 'fillColor')
		return
	)
	g.strokeWidth = 3
	g.sizeSlider = optionsJ.find("#sizeSlider").slider().on('slide', (event)-> 
		g.strokeWidth = event.value
		for item in g.project.selectedItems
			item.strokeWidth = event.value
		return
	).on('slideStop', (event)-> 
		g.strokeWidth = event.value
		for item in g.project.selectedItems
			item.strokeWidth = event.value
			g.updatePath(item, 'strokeWidth')
		return
	)
	
	project.selectedMedias = new Array()
	g.scaleSlider = optionsJ.find("#scaleSlider").slider().on('slide', (event)->
		for media in project.selectedMedias
			if not media.hasOwnProperty('customScale')
				media.customScale = 1
			media.scale(event.value/media.customScale)
			media.customScale *= event.value/media.customScale
	)
	g.rotationSlider = optionsJ.find("#rotationSlider").slider().on('slide', (event)->
		for media in project.selectedMedias
			if not media.hasOwnProperty('customRotation')
				media.customRotation = 0
			media.rotate(event.value-media.customRotation)
			media.customRotation += event.value-media.customRotation
	)
	
	g.fillShape = false
	
	optionsJ.find("#fillShape").change( ()-> 
		g.fillShape = $(this).is(":checked") 
	)
	g.displayGrid = false
	optionsJ.find("#displayGrid").change( ()-> 
		g.displayGrid = $(this).is(":checked")
		updateGrid()
	)

	$("#deleteSelectedItems").click( (event)->
		for item in g.project.selectedItems
			g.deletePath(item)
		if g.selectedDiv?
			g.selectedDiv.delete()
		return
	)

	$("#modifySelectedItems").click( (event)-> g.selectedDiv?.modify() )

	optionsJ.find("label.scale-type-input > input").change( ()-> 
		g.selectemItem = $(this).is(":checked")
	)

	# --- Media list --- #

	g.addingMedia = null
	g.selectedMedia = null
	g.container = $("div.container-fluid")
	g.mediaList = $(".media-list")

	deselectMedias = ()->
		for media in g.medias
			media.freetrans('controls', false)

	# begin media drag
	
	g.mediaList.find('li').mousedown( (event)->
		deselectMedias()
		project.activeLayer.selected = false
		mediaJ = $(this).find(".media")
		g.addingMedia = mediaJ.clone().prependTo(g.container)
		g.addingMedia.css('position': 'absolute')
		g.addingMedia.offset( left:event.pageX, top:event.pageY )
		g.addingMedia.mousedown( (event)->
			deselectMedias()
			g.selectedMedia = $(this)
			g.selectedMedia.freetrans('controls', true)
		)
		event.preventDefault()
	)

	# dragging media

	g.container.mousemove( (event)->
		g.addingMedia?.offset( left:event.pageX, top:event.pageY )
	)

	# releasing media

	g.container.mouseup( (event)->
		if g.addingMedia?
			g.addingMedia.prependTo(g.stageJ)
			g.addingMedia.css('z-index': 0)
			g.addingMedia.offset( left: event.pageX-g.stageJ.offset().left, top: event.pageY-g.stageJ.offset().top )
			g.addingMedia.freetrans()
			g.selectedMedia = g.addingMedia
			g.medias.push(g.addingMedia)
			g.addingMedia = null
	)

	# toggle controls

	g.container.click( (event) ->
		targetJ = $(event.target) 
		# if there is a selected media but we did not click on it: deselect
		if g.selectedMedia && !targetJ.hasClass("ft-container") && !targetJ.hasClass("ft-controls") && !targetJ.hasClass("media")
			deselectMedias()
			g.selectedMedia = false
		# if there was no selected media but we clicked one: select it
		# else if !g.selectedMedia && targetJ.hasClass("ft-controls")
		# 	g.selectedMedia = targetJ
		# 	g.selectedMedia.freetrans('controls', true)
	)

this.mousemove = (event) ->
	return unless g.draggedDiv?

	draggedDivJ = g.draggedDiv.divJ
	if g.draggedHandleJ?
		position = draggedDivJ.position()
		if g.draggedHandleJ.hasClass("tl")
			right = position.left+draggedDivJ.outerWidth()
			bottom = position.top+draggedDivJ.outerHeight()
			newLeft = event.pageX-g.dragOffset.x
			newTop = event.pageY-g.dragOffset.y
			newWidth = right-newLeft
			newHeight = bottom-newTop
		else if g.draggedHandleJ.hasClass("tr")
			bottom = position.top+draggedDivJ.outerHeight()
			newLeft = position.left
			newTop = event.pageY-g.dragOffset.y
			newWidth = event.pageX-g.dragOffset.x+g.draggedHandleJ.width()-newLeft
			newHeight = bottom-newTop
		else if g.draggedHandleJ.hasClass("br")
			newLeft = position.left
			newTop = position.top
			newWidth = event.pageX-g.dragOffset.x+g.draggedHandleJ.width()-newLeft
			newHeight = event.pageY-g.dragOffset.y+g.draggedHandleJ.height()-newTop
		else if g.draggedHandleJ.hasClass("bl")
			right = position.left+draggedDivJ.outerWidth()
			newLeft = event.pageX-g.dragOffset.x
			newTop = position.top
			newWidth = right-newLeft
			newHeight = event.pageY-g.dragOffset.y+g.draggedHandleJ.height()-newTop
		draggedDivJ.css( left: newLeft, top: newTop, width: newWidth, height: newHeight )
		g.draggedDiv.resize()
	else
		draggedDivJ.css( left: event.pageX-g.dragOffset.x, top: event.pageY-g.dragOffset.y )
		g.draggedDiv.dragging(event)

this.mouseup = (event) ->
	return unless g.draggedDiv?

	g.mousemove(event)
	
	if g.mouseDownPosition.x != event.pageX and g.mouseDownPosition.y != event.pageY
		g.draggedDiv.update()
		g.draggedDiv.dragFinished()
	
	g.draggedDiv = null
	g.draggedHandleJ = null

# init global variables
init = ()->
	g.windowJ = $(window)
	g.stageJ = $("#stage")
	g.canvasJ = g.stageJ.find("#canvas")
	g.templatesJ = $("#templates")
	g.me = ""
	g.dragOffset = { x: 0, y: 0 }
	g.draggedDivJ = null


	g.OSName = "Unknown OS"
	if navigator.appVersion.indexOf("Win")!=-1 then g.OSName = "Windows"
	if navigator.appVersion.indexOf("Mac")!=-1 then g.OSName = "MacOS"
	if navigator.appVersion.indexOf("X11")!=-1 then g.OSName = "UNIX"
	if navigator.appVersion.indexOf("Linux")!=-1 then g.OSName = "Linux"

	$(".nano").nanoScroller()
	$('.panel').on('hidden.bs.collapse', () -> $(".nano").nanoScroller() )
	$('.panel').on('shown.bs.collapse', () -> $(".nano").nanoScroller() )

	paper.setup(canvas)

	g.tool = new Tool()
	g.tool.minDistance = 1

	g.id = 0
	g.paths = new Object()
	g.grid = new Group()

	# g.defaultColors = ['#bfb7e6', '#7d86c1', '#403874', '#261c4e', '#1f0937', '#574331', '#9d9121', '#a49959', '#b6b37e', '#91a3f5' ]
	g.defaultColors = ['#d7dddb', '#4f8a83', '#e76278', '#fac699', '#712164']

	# --- Alerts --- #
	g.alertsContainer = $("#Romanesco_alerts")
	g.alerts = new Array()
	g.currentAlert = -1
	g.alertTimeOut = -1
	g.alertsContainer.find(".btn-up").click( -> setAlert(g.currentAlert-1) )
	g.alertsContainer.find(".btn-down").click( -> setAlert(g.currentAlert+1) )

	g.loadedAreas = new Array()
	g.areasToObjects = new Object()
	g.loadedPaths = new Array()
	g.locks = new Array()
	g.medias = new Array()
	g.offset = new Point(0,0)

	g.stageJ.mousemove( (event) => g.mousemove(event) )
	g.stageJ.mouseup( (event) => g.mouseup(event) )

	initOptions()
	initTools()

$(document).ready( ->
	g.currentPath = null

	init()
	window.onhashchange()
	load()
	updateGrid()

	tool.onMouseDown = (event) ->
		g.selectedDiv?.deselect()
		g.selectedTool.begin(event)

	tool.onMouseDrag = (event) ->
		g.selectedTool.update(event)

	tool.onMouseUp = (event) ->
		g.selectedTool.end(event)

	tool.onKeyDown = (event) ->
		if event.key == 'space' && g.selectedTool.name != 'move'
			g.tools['move'].select()

	tool.onKeyUp = (event) ->
		if event.key == 'space'
			g.previousTool.select()

		# if the focus is on anything in the siderbar: ignore the delete
		if $(document.activeElement).parents(".sidebar").length>0
			return

		if event.key == 'delete' or event.key == 'backspace'
			for item in g.project.selectedItems
				item.controller?.delete()
			if g.selectedDiv?
				g.selectedDiv.delete()
			event.preventDefault()

	g.windowJ.resize( (event) ->
		updateGrid()
		view.draw()
	)

	view.draw()

	# debug function to log pk of selected path
	debugSelectedBefore = null
	debug = ()->
		if project.selectedItems.length>0 and debugSelectedBefore!=project.selectedItems[0]
			debugSelectedBefore = project.selectedItems[0]
			if project.selectedItems[0].hasOwnProperty('pk')
				console.log project.selectedItems[0].pk

	setInterval(debug, 500)
)