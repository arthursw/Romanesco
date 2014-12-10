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
# @param [Number] alert index 
this.showAlert = (index) ->
	if g.alerts.length<=0 || index<0 || index>=g.alerts.length then return  	# check that index is valid

	prevType = g.alerts[g.currentAlert].type
	g.currentAlert = index
	alertJ = g.alertsContainer.find(".alert")
	alertJ.removeClass(prevType).addClass(g.alerts[g.currentAlert].type).text(g.alerts[g.currentAlert].message)

	g.alertsContainer.find(".alert-number").text(g.currentAlert+1)
	return

# Display an alert with message, type and delay
#
# @param [String] alert message 
# @param [String] can be 'success', 'info' (default), 'warning', 'danger', 'error' or null ('error' has the same effect as 'danger')
# @param [Number] alert stays on screen *delay* millisecond
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
# @param [jQuery or Paper.js event] event to convert
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
# @param [object event] event to convert
this.objectToEvent = (event)->
	event.point = new Point(event.point)
	event.downPoint = new Point(event.downPoint)
	event.delta = new Point(event.delta)
	return event

# Test if the special key is pressed. Special key is command key on a mac, and control key on other systems.
#
# @param [jQuery or Paper.js event] key event
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
# @param [Number] value to snap
# @param [Number] optional snap, default is getSnap()
# @return [Number] snapped value
this.snap1D = (value, snap)->
	snap ?= g.getSnap()
	if snap != 0
		return Math.floor(value/snap)*snap
	else
		return value

# Returns snapped point
#
# @param [Point] point to snap
# @param [Number] optional snap, default is getSnap()
# @return [Paper point] snapped point
this.snap2D = (point, snap)->
	snap ?= g.getSnap()
	if snap != 0
		return new Point(snap1D(point.x, snap), snap1D(point.y, snap))
	else
		return point

# Returns snapped event
#
# @param [Paper Event] event to snap
# @param [String] (optional) username of the one who emitted of the event
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
# @param [RItem] the only item not to hide
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
# @param [Rectangle] rectangle to test
# @return [Boolean] true if overlaps
g.rectangleOverlapsTwoPlanets = (rectangle)->
	return g.overlapsTwoPlanets(new Path.Rectangle(rectangle))

# Test if *path* overlaps two planets
# 
# @param [Paper path] path to test
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
# @param [Point] point to test
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
# @param [Point] destination
g.RMoveTo = (pos) ->
	g.RMoveBy(pos.subtract(view.center))

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
# @param [Point] delta
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

	if newEntireArea? then load(g.entireArea) else load()

	g.updateRoom() 											# update websocket room

	g.defferedExecution(g.updateHash, 500) 					# update hash in 500 milliseconds
	g.setControllerValue(g.parameters.location.controller, null, '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2)) # update location in sidebar
	return

## Hash

# Update hash (the string after '#' in the url bar) according to the location of the (center of the) view
# set *g.moving* flag to ignore this change in *window.onhashchange* callback
g.updateHash = ()->
	g.moving = true
	location.hash = '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2)
	return

# Update hash (the string after '#' in the url bar) according to the location of the (center of the) view
# set *g.moving* flag to ignore this change in *window.onhashchange* callback
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
# @param [Boolean] show the sidebar, defaults to the opposite of the current state (true if hidden, false if shown)
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