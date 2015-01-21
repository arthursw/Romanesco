###
# Global functions #

Here are all global functions (which do not belong to classes and are not event handlers neither initialization functions).

###

# doctodo: explain planets, see coordinateSystems.coffee
# doctodo: define types: Point, Paper point, RItem, etc.

## Alerts

# An array of alerts ({ type: type, message: message }) contains all alerts info, it is put to the alert box in showAlert()

# Display the alert number *index*
# Called when user clicks on up/down arrow of the message box
# Change the text and the class of the alert box to the ones from alert number *index*
#
# @param index [Number] alert index 
this.showAlert = (index) ->
	if g.alerts.length<=0 || index<0 || index>=g.alerts.length then return  	# check that index is valid

	prevType = g.alerts[g.currentAlert].type
	g.currentAlert = index
	alertJ = g.alertsContainer.find(".alert")
	alertJ.removeClass(prevType).addClass(g.alerts[g.currentAlert].type).text(g.alerts[g.currentAlert].message)

	g.alertsContainer.find(".alert-number").text(g.currentAlert+1)
	return

# animate function for Tween.js
this.animate = (time)->
	requestAnimationFrame( animate )
	TWEEN.update(time)
	return

# Display an alert with message, type and delay
#
# @param message [String] alert message 
# @param type [String] can be 'success', 'info' (default), 'warning', 'danger', 'error' or null ('error' has the same effect as 'danger')
# @param delay [Number] alert stays on screen *delay* millisecond
this.romanesco_alert = (message, type="", delay=2000) ->
	# set type ('info' to default, 'error' == 'danger')
	if type.length==0
		type = "info"
	else if type == "error"
		type = "danger"
	
	type = " alert-" + type

	# find and show the alert box
	alertJ = g.alertsContainer.find(".alert")
	g.alertsContainer.removeClass("r-hidden")
	
	# append alert to alert array
	g.currentAlert = g.alerts.length
	g.alerts.push( { type: type, message: message } )

	if g.alerts.length>0 then g.alertsContainer.addClass("activated") 		# activate alert box (required for the first time)

	this.showAlert(g.alerts.length-1)

	# show and hide in *delay* milliseconds
	g.alertsContainer.addClass("show")
	if delay!=0
		clearTimeout(g.alertTimeOut)
		g.alertTimeOut = setTimeout( ( () -> g.alertsContainer.removeClass("show") ) , delay )
	return

## Event to object conversion (to send event info through websockets)

# Convert an event (jQuery event or Paper.js event) to an object
# Only specific data is copied: modifiers (in paper.js event), position (pageX/Y or event.point), downPoint, delta, and target
# convert the class name to selector to be able to find the target on the other clients [to be modified]
#
# @param event [jQuery or Paper.js event] event to convert
this.eventToObject = (event)->
	eo =
		modifiers: event.modifiers
		point: if not event.pageX? then event.point else view.viewToProject(new Point(event.pageX, event.pageY))
		downPoint: event.downPoint?
		delta: event.delta
	if event.pageX? and event.pageY?
		eo.modifiers = {}
		eo.modifiers.control = event.ctrlKey
		eo.modifiers.command = event.command
	if event.target?
		eo.target = "." + event.target.className.replace(" ", ".") # convert class name to selector to be able to find the target on the other clients (websocket com)
	return eo

# Convert an object to an event (to receive event info through websockets)
#
# @param event [object event] event to convert
this.objectToEvent = (event)->
	event.point = new Point(event.point)
	event.downPoint = new Point(event.downPoint)
	event.delta = new Point(event.delta)
	return event

# Test if the special key is pressed. Special key is command key on a mac, and control key on other systems.
#
# @param event [jQuery or Paper.js event] key event
# @return [Boolean] *specialKey*
this.specialKey = (event)->
	if event.pageX? and event.pageY?
		specialKey = if g.OSName == "MacOS" then event.metaKey else event.ctrlKey
	else
		specialKey = if g.OSName == "MacOS" then event.modifiers.command else event.modifiers.control
	return specialKey

## Snap management
# The snap is applied to all emitted events (on the downPoint, point, delta and lastPoint properties)
# This is a poor and dirty implementation
# not good at all since it does not help to align elements on a grid (the offset between the initial position and the closest grid point is not cancelled)

# Returns quantized snap
#
# @return [Number] *snap*
this.getSnap = ()->
	snap = g.parameters.snap.snap
	return snap-snap%g.parameters.snap.step

# Returns snapped value
#
# @param value [Number] value to snap
# @param snap [Number] optional snap, default is getSnap()
# @return [Number] snapped value
this.snap1D = (value, snap)->
	snap ?= g.getSnap()
	if snap != 0
		return Math.floor(value/snap)*snap
	else
		return value

# Returns snapped point
#
# @param point [Point] point to snap
# @param snap [Number] optional snap, default is getSnap()
# @return [Paper point] snapped point
this.snap2D = (point, snap)->
	snap ?= g.getSnap()
	if snap != 0
		return new Point(snap1D(point.x, snap), snap1D(point.y, snap))
	else
		return point

# Returns snapped event
#
# @param event [Paper Event] event to snap
# @param from [String] (optional) username of the one who emitted of the event
# @return [Paper event] snapped event
this.snap = (event, from=g.me)->
	if from!=g.me then return event
	if g.selectedTool.disableSnap() then return event
	snap = g.parameters.snap.snap
	snap = snap-snap%g.parameters.snap.step
	if snap != 0
		snappedEvent = jQuery.extend({}, event)
		snappedEvent.modifiers = event.modifiers
		snappedEvent.point = g.snap2D(event.point, snap)
		if event.lastPoint? then snappedEvent.lastPoint = g.snap2D(event.lastPoint, snap)
		if event.downPoint? then snappedEvent.downPoint = g.snap2D(event.downPoint, snap)
		if event.lastPoint? then snappedEvent.middlePoint = snappedEvent.point.add(snappedEvent.lastPoint).multiply(0.5)
		if event.type != 'mouseup' and event.lastPoint?
			snappedEvent.delta = snappedEvent.point.subtract(snappedEvent.lastPoint)
		else if event.downPoint?
			snappedEvent.delta = snappedEvent.point.subtract(snappedEvent.downPoint)
		return snappedEvent
	else
		return event

## Hide show RItems (RPath and RDivs)

# Hide every path except *me* and set fastModeOn to true
#
# @param me [RItem] the only item not to hide
g.hideOthers = (me)->
	for name, item of g.paths
		if item != me
			item.group?.visible = false
	g.fastModeOn = true
	return

# Show every path and set fastModeOn to false (do nothing if not in fastMode. The fastMode is when items are hidden when user modifies an RItem)
g.showAll = ()->
	if not g.fastModeOn then return
	for name, item of g.paths
		item.group?.visible = true
	g.fastModeOn = false
	return

## Manage limits between planets


# @return [{vertical: Paper Path, horizontal: Paper Path}] two paper paths corresponding to the limits of the planet (one horizontal and one vertical)
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

# Test if *rectangle* overlaps two planets
# 
# @param rectangle [Rectangle] rectangle to test
# @return [Boolean] true if overlaps
g.rectangleOverlapsTwoPlanets = (rectangle)->
	return g.overlapsTwoPlanets(new Path.Rectangle(rectangle))

# Test if *path* overlaps two planets
# 
# @param path [Paper path] path to test
# @return [Boolean] true if overlaps
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

# Draw planet limits, and draw the grid if *g.displayGrid*
# The grid size is equal to the snap, except when snap < 15, then it is set to 25
# one line every 4 lines is thick and darker
g.updateGrid = ()->

	# draw planet limits (thick green lines)
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
	
	# draw grid

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

	# draw lines
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

	# draw position text if debug
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

# Get the game under *point*
# @param point [Point] point to test
# @return [RVideoGame] the video game at *point*
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

## Move/scroll the romanesco view

# Move the romanesco view to *pos*
# @param pos [Point] destination
# @param delay [Number] time of the animation to go to destination in millisecond
g.RMoveTo = (pos, delay) ->
	if not delay?
		g.RMoveBy(pos.subtract(view.center))
	else
		console.log pos
		console.log delay
		initialPosition = view.center
		tween = new TWEEN.Tween( initialPosition ).to( pos, delay ).easing( TWEEN.Easing.Exponential.InOut ).onUpdate( ()->
			g.RMoveTo(this)
			console.log this.x + ', ' + this.y
			return
		).start()
	return

# Move the romanesco view from *delta*
# if user is in a restricted area (a website or videogame with restrictedArea), the move will be constrained in this area
# This method does:
# - scroll the paper view
# - update RDivs' positions
# - update grid
# - update g.entireArea (the area which must be kept loaded, in a video game or website)
# - load entire area if we have a new entire area
# - update websocket room
# - update hash in 0.5 seconds
# - set location in the general options
# @param delta [Point]
g.RMoveBy = (delta) ->
	
	# if user is in a restricted area (a website or videogame with restrictedArea), the move will be constrained in this area
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
	

	project.view.scrollBy(new Point(delta.x, delta.y)) 		# scroll the paper view
	
	for div in g.divs 										# update RDivs' positions
		div.updateTransform()

	updateGrid() 											# update grid

	# update g.entireArea (the area which must be kept loaded, in a video game or website)
	# if the loaded entire areas contain the center of the view, it is the current entire area
	# g.entireArea [Rectangle]
	# g.entireAreas [array of RDiv] the array is updated when we load the RDivs (in ajax.coffee)
	# get the new entire area
	newEntireArea = null
	for area in g.entireAreas
		if area.getBounds().contains(project.view.center)
			newEntireArea = area
			break

	# update g.entireArea
	if not g.entireArea? and newEntireArea?
		g.entireArea = newEntireArea.getBounds()
	else if g.entireArea? and not newEntireArea?
		g.entireArea = null

	if newEntireArea? then quick_load(g.entireArea) else quick_load()

	g.updateRoom() 											# update websocket room

	g.defferedExecution(g.updateHash, 'updateHash', 500) 					# update hash in 500 milliseconds
	g.willUpdateAreasToUpdate = true
	g.defferedExecution(g.updateAreasToUpdate, 'updateAreasToUpdate', 500) 					# update areas to update in 500 milliseconds

	g.setControllerValue(g.parameters.location.controller, null, '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2)) # update location in sidebar
	return

## Hash

# Update hash (the string after '#' in the url bar) according to the location of the (center of the) view
# set *g.ignoreHashChange* flag to ignore this change in *window.onhashchange* callback
g.updateHash = ()->
	g.ignoreHashChange = true
	location.hash = '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2)
	return

# Update hash (the string after '#' in the url bar) according to the location of the (center of the) view
# set *g.ignoreHashChange* flag to ignore this change in *window.onhashchange* callback
window.onhashchange = (event) ->
	if g.ignoreHashChange
		g.ignoreHashChange = false
		return
	pos = location.hash.substr(1).split(',')
	p = new Point()
	p.x = parseFloat(pos[0])
	p.y = parseFloat(pos[1])
	if not p.x then p.x = 0
	if not p.y then p.y = 0
	g.RMoveTo(p)
	return

## RItems selection

# Get selected RItems
this.selectedItems = ()->
	items = []
	for item in project.selectedItems
		if item.controller? and items.indexOf(item.controller)<0 then items.push(item.controller)
	return items.concat g.selectedDivs

# Deselect all RItems (and paper items)
this.deselectAll = ()->
	item.deselect?() for item in g.selectedItems()
	project.activeLayer.selected = false
	return

# Toggle (hide/show) sidebar (called when user clicks on the sidebar handle)
# @param show [Boolean] show the sidebar, defaults to the opposite of the current state (true if hidden, false if shown)
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

# get a list of rectangles obtained from the cut of rectangle 2 in rectangle 1
# the rectangles A, B, C and D are the resulting rectangles
#
# example 1 when the rectangle 1 is bigger than the rectangle 2 in every directions:
#  ----------------------
#  |		A			|
#  |--------------------|
#  |    |         |     |
#  |  B | Rect 2  |  C  |
#  |    |         |     |
#  |--------------------|
#  |        D           |
#  ----------------------
#  
# example 2 when the bottom-left corner of the rectangle 1 is outside the rectangle 2:
#  
#  -----------
#  |         |------
#  | Rect 2  |  C  |
#  |         |     |
#  ----------------|
#     |     D      |
#     --------------
# @param rectangle1 [Paper Rectangle] the rectangle 1
# @param rectangle2 [Paper Rectangle] the rectangle 2
# @return [Array<Paper Rectangle>] the resulting list of rectangles of the cut of rectangle 2 in rectangle 1
this.getRectangleListFromIntersection = (rectangle1, rectangle2)->
	
	rectangles = []
	
	# if the rectangles do not interect or if rectangle 1 is contained within rectangle 2: return an empty list
	if (not rectangle1.intersects(rectangle2)) or (rectangle2.contains(rectangle1)) then return rectangles

	# push all rectangles A, B, C, D as if we were in example 1, and then remove rectangle which have negative width or height

	rA = new Rectangle()
	rA.topLeft = rectangle1.topLeft
	rA.bottomRight = new Point(rectangle1.right, rectangle2.top)
	rectangles.push(rA)

	rB = new Rectangle()
	rB.topLeft = new Point(rectangle1.left, Math.max(rectangle2.top, rectangle1.top))
	rB.bottomRight = new Point(rectangle2.left, Math.min(rectangle2.bottom, rectangle1.bottom))
	rectangles.push(rB)

	rC = new Rectangle()
	rC.topLeft = new Point(rectangle2.right, Math.max(rectangle2.top, rectangle1.top))
	rC.bottomRight = new Point(rectangle1.right, Math.min(rectangle2.bottom, rectangle1.bottom))
	rectangles.push(rC)

	rD = new Rectangle()
	rD.topLeft = new Point(rectangle1.left, rectangle2.bottom)
	rD.bottomRight = rectangle1.bottomRight
	rectangles.push(rD)

	# remove rectangles which have negative width or height
	i = rectangles.length-1
	while i>=0
		rectangle = rectangles[i]

		if rectangle.width<=0 or rectangle.height<=0
			rectangles.splice(i,1)
		i--

	return rectangles

# Get the image in *rectangle* of the view in a data url
# @param rectangle [Paper Rectangle] a rectangle in project coordinate representing the area to extract
# @param intersectView [Boolean] (optional) a boolean indicating whether to intersect *rectangle* with the view bounds
# @return [String] the data url of the view image defined by area
this.areaToImageDataUrl = (rectangle, intersectView=true)->
	if intersectView then rectangle = rectangle.intersect(view.bounds)
	if rectangle.height <=0 or rectangle.width <=0 
		console.log 'Warning: trying to extract empty area!!!'
		return null

	viewRectangle = g.projectToViewRectangle(rectangle)

	canvasTemp = document.createElement('canvas')
	canvasTemp.width = viewRectangle.width
	canvasTemp.height = viewRectangle.height
	contextTemp = canvasTemp.getContext('2d')
	contextTemp.putImageData(g.context.getImageData(viewRectangle.x, viewRectangle.y, viewRectangle.width, viewRectangle.height), 0, 0)
	
	dataURL = canvasTemp.toDataURL("image/png")
	return dataURL

# Get the image in *rectangle* of the view in a data url and the a list of areas (rectangle) which could not be rasterized because they are outside the view
# @param rectangle [Paper Rectangle] a rectangle in project coordinate representing the area to extract
# @return [String or { dataURL: String, areasNotRasterized: Array<Paper Rectangle>}] an object with the dataUrl and the areas not rasterized
this.areaToImageDataUrlWithAreasNotRasterized = (rectangle)->
	rectangle = g.expandRectangleToInteger(rectangle)
	intersection = rectangle.intersect(view.bounds)
	intersection = g.shrinkRectangleToInteger(intersection)

	if view.zoom != 1
		g.romanesco_alert("You are creating or modifying an item in a zoom different than 100. \nThis will not be rasterized, other users will have to render it \n(please consider drawing and modifying items at zoom 100 for better loading performances).", "warning", 3000)
		return { dataURL: null, rectangle: intersection, areasNotRasterized: [g.boxFromRectangle(rectangle)] }

	# deselect items (in paper.js view) and keep them in an array to reselect them after rasterization
	selectedItems = []
	for item in project.getItems({selected: true})
		if item.constructor?.name != "Group" and item.constructor?.name != "Layer"
			selectedItems.push( { item: item, fullySelected: item.fullySelected } )
	
	project.activeLayer.selected = false
	g.carLayer.visible = false
	g.debugLayer.visible = false
	view.draw()
	
	# rasterize (only what it is possible to rasterize)
	dataURL = areaToImageDataUrl(intersection, false)
	
	# debugRaster = new Raster( source: dataURL, position: rectangle.intersect(view.bounds).center )
	# debugRaster.selected = true
	# debugRaster.opacity = 0.5
	# debugRaster.on('mousedrag', (event)-> this.position = event.point )
	# g.debugLayer.addChild(debugRaster)
	
	g.debugLayer.visible = true
	g.carLayer.visible = true
	
	# reselect items
	for itemObject in selectedItems
		if itemObject.fullySelected
			itemObject.item.fullySelected = true
		else
			itemObject.item.selected = true

	# make a list of rectangles (areas) which we can not extract since it is outside the view
	areasNotRasterized = g.getRectangleListFromIntersection(rectangle, intersection)

	# convert the list of area in a GeoJSON compatible format
	areasNotRasterizedBox = (g.boxFromRectangle(area) for area in areasNotRasterized)
	# or: areasNotRasterizedBox = areasNotRasterized.map( (areaNotRasterized)-> return g.boxFromRectangle(area) )

	return { dataURL: dataURL, rectangle: intersection, areasNotRasterized: areasNotRasterizedBox }

# - delete areas to delete (areas which were overlapping with the areas which were just added)
# - add areas to update in g.areasToUpdate, from result of server
# called in load_callback, and on updateAreasToUpdate callback (when we rasterize part of an area, we must add the new remaining areas)
# @param result [Object] the server result of the load (when called from load_callback) or the updateAreasToUpdate (when called from updateAreasToUpdate)
this.addAreasToUpdate = (results)->
	if typeof(results)=='string' then results = JSON.parse(results)
	if not g.checkError(results) then return
	if results.state == 'log' and results.message == 'Delete impossible: area does not exist' then return 	# dirty way to ignore when the area was deleted (probaby updated by another user before) 

	console.log 'areas to delete: ' + results.areasDeleted?.length
	# delete areas to delete (areas which were overlapping with the areas which were just added)
	if results.areasDeleted?
		for areaToDeletePk in results.areasDeleted
			console.log 'delete area: ' + areaToDeletePk
			if g.areasToUpdate[areaToDeletePk]?
				debugRectangle = debugLayer.getItem( name: areaToDeletePk )
				if debugRectangle?
					debugRectangle.strokeColor = 'green'
					setTimeout(((debugRectangle)-> return ()-> debugRectangle.remove())(debugRectangle), 2000)
				else
					console.log 'Error: could not find debug rectangle'
				delete g.areasToUpdate[areaToDeletePk]
			else
				console.log 'Error: area to delete could not be found'
				debugger

	# add areas to update in g.areasToUpdate
	if results.areasToUpdate?
		for a in results.areasToUpdate
			areas = JSON.parse(a)
			# areas is either an array (when addAreasToUpdate is called from load_callback) or an area (otherwise)
			if areas.constructor != Array then areas = [areas]
			console.log 'areas to add: ' + areas.length
			for area in areas
				if g.areasToUpdate[area._id.$oid]? then continue 	# do not add if it is already there (meaning we add areas from load_callback)
				planet = new Point(area.planetX, area.planetY)
				
				tl = posOnPlanetToProject(area.box.coordinates[0][0], planet)
				br = posOnPlanetToProject(area.box.coordinates[0][2], planet)

				rectangle = new Rectangle(tl, br)

				console.log 'add: ' + area._id.$oid + ', rectangle: ' + rectangle.toString()
				g.areasToUpdate[area._id.$oid] = rectangle

				# debug
				debugRectangle = new Path.Rectangle(rectangle)
				debugRectangle.strokeColor = 'red'
				debugRectangle.strokeWidth = 1
				debugRectangle.name = area._id.$oid
				g.debugLayer.addChild(debugRectangle)

	return

# update rasters on the server
# called in two cases:
# - by RPath.update when a path must be updated, the rasters must also be updated
# - by updateAreasToUpdate: when the view is moved on top of an area to update, the rasters are updated
# - on server response, the callback will also add the new areas to update to g.areasToUpdate (the remaining areas)
# @param rectangle [Paper Rectangle] the rectangle to update
# @param areaPk [ID] the primary key of the area that we updated (used when called from updateAreasToUpdate)
this.updateRasters = (rectangle, areaPk=null)->
	extraction = g.areaToImageDataUrlWithAreasNotRasterized(rectangle)
	console.log 'request to add ' + extraction.areasNotRasterized?.length + ' areas'
	if extraction.dataURL == "data:,"
		console.log "Warning: trying to add an area outside the screen!"
	Dajaxice.draw.updateRasters(g.addAreasToUpdate, { 'data': extraction.dataURL, 'position': extraction.rectangle.topLeft, 'areasNotRasterized': extraction.areasNotRasterized, 'areaToDeletePk': areaPk } )
	return

# draw/update the areas to update:
# for all areas to update: if it is in the view, refresh the view and delete area
# if the area was not entirely in the view, the remaining areas are sent to the server to be added
# on server callback, the remaining areas will be added to g.areasToUpdate (in addAreasToUpdate)
this.updateAreasToUpdate = ()->

	viewUpdated = false

	for pk, rectangle of g.areasToUpdate
		intersection = rectangle.intersect(view.bounds)
		
		console.log 'try to update area ' + pk + ', rectangle: ' + rectangle.toString() + '...'
		if (rectangle.width > 1 and intersection.width <= 1) or (rectangle.height > 1 and intersection.height <= 1)
			console.log '...not in view'
			continue

		if view.zoom == 1
			debugRectangle = debugLayer.getItem( name: pk )
			if debugRectangle?
				debugRectangle.strokeColor = 'blue'
				# setTimeout((()-> debugRectangle.remove()), 2000)
				setTimeout(((debugRectangle)-> return ()-> debugRectangle.remove())(debugRectangle), 2000)
			else
				console.log 'Error: could not find debug rectangle'
		
		# draw all items on this area
		# for item in newItems
		# 	if item.getBounds().intersects(intersection)
		# 		item.draw()
		
		# refresh view (only once)
		if not viewUpdated
			g.updateView()
			view.draw()
			viewUpdated = true

		# newAreas = g.getRectangleListFromIntersection(rectangle, intersection)

		# newAreasBox = []
		# for area in newAreas
		# 	newAreasBox.push(g.boxFromRectangle(area))

		# Dajaxice.draw.updateAreasToUpdate(addAreasToUpdate, { 'pk': area.pk, 'newAreas': newAreasBox } )
		
		updateRasters(rectangle, pk)

		console.log '...updated'
		delete g.areasToUpdate[pk]

	g.willUpdateAreasToUpdate = false
	return

# hide rasters and redraw all items (except ritem if specified)
# @param item [RItem] (optional) the item not to update (draw)
this.updateView = (ritem=null)->
	console.log "updateView: remove rasters and redraw"

	# remove all rasters
	for x, rasterColumn of g.rasters
		for y, raster of rasterColumn
			raster.remove()
			delete g.rasters[x][y]
			if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

	# redraw paths (could redraw all RItems)
	for pk, item of g.paths 		# could be g.items
		item.draw()

	return

# # deprecated
# # 1. remove rasters on which @ lies
# # 2. redraw all items which lie on those rasters
# # @param bounds [Paper rectangle] the area to update
# # @param item [RItem] (optional) the item not to update (draw)
# this.updateClientRasters = (bounds, ritem=null)->
	
# 	console.log "updateClientRasters"

# 	# find top, left, bottom and right positions of the area in the quantized space
# 	scale = g.scale
# 	t = Math.floor(bounds.top / scale) * scale
# 	l = Math.floor(bounds.left / scale) * scale
# 	b = Math.floor(bounds.bottom / scale) * scale
# 	r = Math.floor(bounds.right / scale) * scale

# 	# for all rasters on which @ relies
# 	areasToLoad = []
# 	for x in [l .. r] by scale
# 		for y in [t .. b] by scale
# 			raster = g.rasters[x]?[y]

# 			if not raster then continue

# 			console.log "remove raster: " + x + "," + y

# 			raster.remove()
# 			delete g.rasters[x][y]
# 			if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

# 			rasterRectangle = new Rectangle(x, y, 1000, 1000)

# 			for pk, item of g.items
# 				console.log "item: " + item.name
# 				console.log item.getBounds()
# 				console.log rasterRectangle
# 				console.log item.getBounds().intersects(rasterRectangle)
# 				if item != ritem and item.getBounds().intersects(rasterRectangle)
# 					item.draw()
# 	return

# return a rectangle with integer coordinates and dimensions: left and top positions will be ceiled, right and bottom position will be floored
# @param rectangle [Paper Rectangle] the rectangle to round
# @return [Paper Rectangle] the resulting shrinked rectangle
this.shrinkRectangleToInteger = (rectangle)->
	return new Rectangle(new Point(Math.ceil(rectangle.left), Math.ceil(rectangle.top)), new Point(Math.floor(rectangle.right), Math.floor(rectangle.bottom)))

# return a rectangle with integer coordinates and dimensions: left and top positions will be floored, right and bottom position will be ceiled
# @param rectangle [Paper Rectangle] the rectangle to round
# @return [Paper Rectangle] the resulting expanded rectangle
this.expandRectangleToInteger = (rectangle)->
	return new Rectangle(new Point(Math.floor(rectangle.left), Math.floor(rectangle.top)), new Point(Math.ceil(rectangle.right), Math.ceil(rectangle.bottom)))

# round *x* to the lower multiple of *m*
# @param x [Number] the value to round
# @param m [Number] the multiple
# @return [Number] the multiple of *m* below *x*
this.roundToLowerMultiple = (x, m)->
	return Math.floor(x / m) * m

# round *x* to the greater multiple of *m*
# @param x [Number] the value to round
# @param m [Number] the multiple
# @return [Number] the multiple of *m* above *x*
this.roundToGreaterMultiple = (x, m)->
	return Math.ceil(x / m) * m

## Debug

# Log all RItems
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

# Check if there are items without rasters
this.checkRasters = ()->
	for item in project.activeLayer.children
		if item.controller? and not item.controller.raster?
			console.log item.controller
			# item.controller.rasterize()
	return

# select rasters
this.selectRasters = ()->
	rasters = []
	for item in project.activeLayer.children
		if item.constructor.name == "Raster"
			item.selected = true
			rasters.push(item)
	return rasters

this.printPathList = ()->
	names = []
	for pathClass in g.pathClasses
		names.push(pathClass.rname)
	console.log names
	return

this.testRectangleIntersection = ()->
	r = new Rectangle(0,0,250,400)
	pr = new Path.Rectangle(r)
	pr.strokeColor = 'blue'
	pr.strokeWidth = 5

	r2 = new Rectangle(-30,10,10,10)
	pr2 = new Path.Rectangle(r2)
	pr2.strokeColor = 'green'
	pr2.strokeWidth = 5
	
	rectangles = g.getRectangleListFromIntersection(r2,r)
	
	for rectangle in rectangles
		p = new Path.Rectangle(rectangle)
		p.strokeColor = 'red'
		p.strokeWidth = 1
	
	return

# one complicated solution to handle the loading:
# this.showMask = (show)->
	# if show
	# 	g.globalMaskJ.show()
	# else
	# 	g.globalMaskJ.hide()
	# return
# this.loop = (work, max, batchSize, callback, init=0, step=1, callbackArgs) ->
# 	length = init
	
# 	doWork = () ->
# 		limit = Math.min(length+batchSize*step, max)
# 		while length < limit
# 			if not work(length) then return
# 			length += step
# 		if length < max
# 			setTimeout(doWork, 0)
# 		else
# 			callback(callbackArgs)
# 		return
	
# 	doWork()
# 	return

# 	draw: (simplified=false, loading=false)->
#		g.showMask(true)
# 		if @isDrawing
# 			@stopDrawing = true
# 			_this = @
# 			setTimeout( ( ()-> _this.draw(simplified, loading) ), 0)
		
# 		@isDrawing = true

# 		if @controlPath.segments.length < 2 then return
	
# 		if simplified then @simplifiedModeOn()

# 		step = @data.step
# 		controlPathLength = @controlPath.length
# 		nf = controlPathLength/step
# 		nIteration  = Math.floor(nf)
# 		reminder = nf-nIteration
# 		length = reminder*step/2

# 		@drawBegin()

# 		drawUpdateJob = (length)=>
# 			try
# 				if @stopDrawing
# 					@isDrawing = false
# 					@stopDrawing = false
# 					return false 		# @controlPath is null if the path was removed before totally drawn, then return false (stop the loop execution)
# 				@drawUpdate(length)
# 				view.draw()
# 			catch error
# 				console.error error
# 				throw error
# 			# g.setLoadingBar(length/controlPathLength)
# 			return true

# 		g.loop(drawUpdateJob, controlPathLength, 10, @finishDraw, length, step, simplified)

# 		# while length<controlPathLength
# 		# 	@drawUpdate(length)
# 		# 	length += step

# 		return

# 	finishDraw: (simplified)=>
# 		@drawEnd()

# 		if simplified 
# 			@simplifiedModeOff()
# 		else
# 			@rasterize()
#		g.showMask(false)
# 		return