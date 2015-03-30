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

# check for any error in an ajax callback and display the appropriate error message
# @return [Boolean] true if there was no error, false otherwise
this.checkError = (result)->
	# console.log result
	if not result? then return true
	if result.state == 'not_logged_in'
		romanesco_alert("You must be logged in to update drawings to the database.", "info")
		return false
	if result.state == 'error'
		if result.message == 'invalid_url'
			romanesco_alert("Your URL is invalid or does not point to an existing page.", "error")
		else
			romanesco_alert("Error: " + result.message, "error")
		return false
	else if result.state == 'system_error'
		console.log result.message
		return false
	return true

# Convert a jQuery event to a project position
# @return [Paper Point] the project position corresponding to the event pageX, pageY
this.jEventToPoint = (event)->
	return view.viewToProject(new Point(event.pageX-g.canvasJ.offset().left, event.pageY-g.canvasJ.offset().top))

## Event to object conversion (to send event info through websockets)

# Convert an event (jQuery event or Paper.js event) to an object
# Only specific data is copied: modifiers (in paper.js event), position (pageX/Y or event.point), downPoint, delta, and target
# convert the class name to selector to be able to find the target on the other clients [to be modified]
#
# @param event [jQuery or Paper.js event] event to convert
this.eventToObject = (event)->
	eo =
		modifiers: event.modifiers
		point: if not event.pageX? then event.point else g.jEventToPoint(event)
		downPoint: event.downPoint?
		delta: event.delta
	if event.pageX? and event.pageY?
		eo.modifiers = {}
		eo.modifiers.control = event.ctrlKey
		eo.modifiers.command = event.metaKey
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

# Convert a jQuery event to a Paper event
#
# @param event [jQuert event] event to convert
# @param previousPosition [Paper Point] (optional) the previous position of the mouse
# @param initialPosition [Paper Point] (optional) the initial position of the mouse
# @param type [String] (optional) the type of event
# @param count [Number] (optional) the number of times the mouse event was fired
# @return Paper event
this.jEventToPaperEvent = (event, previousPosition=null, initialPosition=null, type=null, count=null)->
	currentPosition = g.jEventToPoint(event)
	previousPosition ?= currentPosition
	initialPosition ?= currentPosition
	delta = currentPosition.subtract(previousPosition)
	paperEvent =
		modifiers: 
			shift: event.shiftKey
			control: event.ctrlKey
			option: event.altKey
			command: event.metaKey
		point: currentPosition
		downPoint: initialPosition
		delta: delta
		middlePoint: previousPosition.add(delta.divide(2))
		type: type
		count: count
	return paperEvent

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

# # Hide show RItems (RPath and RDivs)

# # Hide every path except *me* and set fastModeOn to true
# #
# # @param me [RItem] the only item not to hide
# g.hideOthers = (me)->
# 	for name, item of g.paths
# 		if item != me
# 			item.group?.visible = false
# 	g.fastModeOn = true
# 	return

# # Show every path and set fastModeOn to false (do nothing if not in fastMode. The fastMode is when items are hidden when user modifies an RItem)
# g.showAll = ()->
# 	if not g.fastModeOn then return
# 	for name, item of g.paths
# 		item.group?.visible = true
# 	g.fastModeOn = false
# 	return

## Manage limits between planets

# Test if *rectangle* overlaps two planets
# 
# @param rectangle [Rectangle] rectangle to test
# @return [Boolean] true if overlaps
g.rectangleOverlapsTwoPlanets = (rectangle)->
	limit = getLimit()
	if ( rectangle.left < limit.x && rectangle.right > limit.x ) || ( rectangle.top < limit.y && rectangle.bottom > limit.y )
		return true
	return false

# Test if *path* overlaps two planets
# 
# @param path [Paper path] path to test
# @return [Boolean] true if overlaps
# g.pathOverlapsTwoPlanets = (path)->
# 	limitPaths = g.getLimitPaths()
# 	limitPathV = limitPaths.vertical
# 	limitPathH = limitPaths.horizontal

# 	if limitPathV?
# 		intersections = path.getIntersections(limitPathV)
# 		limitPathV.remove()
# 		if intersections.length>0
# 			return true

# 	if limitPathH?
# 		intersections = path.getIntersections(limitPathH)
# 		limitPathH.remove()
# 		if intersections.length>0
# 			return true

# 	return false

g.updateLimitPaths = ()->
	limit = getLimit()

	g.limitPathV = null
	g.limitPathH = null

	if limit.x >= view.bounds.left and limit.x <= view.bounds.right
		g.limitPathV = new Path()
		g.limitPathV.name = 'limitPathV'
		g.limitPathV.add(limit.x,view.bounds.top)
		g.limitPathV.add(limit.x,view.bounds.bottom)
		g.grid.addChild(g.limitPathV)

	if limit.y >= view.bounds.top and limit.y <= view.bounds.bottom
		g.limitPathH = new Path()
		g.limitPathH.name = 'limitPathH'
		g.limitPathH.add(view.bounds.left, limit.y)
		g.limitPathH.add(view.bounds.right, limit.y)
		g.grid.addChild(g.limitPathH)

	return

# Draw planet limits, and draw the grid if *g.displayGrid*
# The grid size is equal to the snap, except when snap < 15, then it is set to 25
# one line every 4 lines is thick and darker
g.updateGrid = ()->

	# draw planet limits (thick green lines)
	g.grid.removeChildren()

	g.updateLimitPaths()

	if g.limitPathV?
		g.limitPathV.strokeColor = 'green'
		g.limitPathV.strokeWidth = 5

	if g.limitPathH?
		g.limitPathH.strokeColor = 'green'
		g.limitPathH.strokeWidth = 5

	if view.bounds.width > window.innerWidth or view.bounds.height > window.innerHeight
		halfSize = new Point(window.innerWidth*0.5, window.innerHeight*0.5)
		bounds = new Path.Rectangle(view.center.subtract(halfSize), view.center.add(halfSize))
		bounds.strokeWidth = 1
		bounds.strokeColor = 'black'
		g.grid.addChild(bounds)

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
g.RMoveTo = (pos, delay, addCommand=true) ->
	if not delay?
		somethingToLoad = g.RMoveBy(pos.subtract(view.center), addCommand)
	else
		# console.log pos
		# console.log delay
		initialPosition = view.center
		tween = new TWEEN.Tween( initialPosition ).to( pos, delay ).easing( TWEEN.Easing.Exponential.InOut ).onUpdate( ()->
			g.RMoveTo(this, addCommand)
			# console.log this.x + ', ' + this.y
			return
		).start()
	return somethingToLoad

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
g.RMoveBy = (delta, addCommand=true) ->
	
	# if user is in a restricted area (a website or videogame with restrictedArea), the move will be constrained in this area
	if g.restrictedArea?
		
		# check if the restricted area contains view.center (if not, move to center)
		if not g.restrictedArea.contains(view.center)
			# delta = g.restrictedArea.center.subtract(view.size.multiply(0.5)).subtract(view.bounds.topLeft)
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
	
	g.previousViewPosition ?= view.center

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

	somethingToLoad = if newEntireArea? then load(g.entireArea) else load()

	g.updateRoom() 											# update websocket room

	g.deferredExecution(g.updateHash, 'updateHash', 500) 					# update hash in 500 milliseconds
	
	if addCommand
		addMoveCommand = ()->
			g.commandManager.add(new MoveViewCommand(g.previousViewPosition, view.center))
			g.previousViewPosition = null
			return
		g.deferredExecution(addMoveCommand, 'add move command')

	# g.willUpdateAreasToUpdate = true
	# g.deferredExecution(g.updateAreasToUpdate, 'updateAreasToUpdate', 500) 					# update areas to update in 500 milliseconds
	
	for pk, rectangle of g.areasToUpdate
		if rectangle.intersects(view.bounds)
			g.updateView()
			break
	
	g.setControllerValue(g.parameters.location.controller, null, '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2)) # update location in sidebar
	return somethingToLoad

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

# Deselect all RItems (and paper items)
this.deselectAll = ()->
	g.previouslySelectedItems = g.selectedItems.slice()
	item.deselect?(false) for item in g.previouslySelectedItems
	project.activeLayer.selected = false
	g.selectedItems = []
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

this.highlightStage = (color)->
	g.backgroundRectangle = new Path.Rectangle(view.bounds)
	g.backgroundRectangle.fillColor = color
	g.backgroundRectangle.sendToBack()
	return

this.unhighlightStage = ()->
	g.backgroundRectangle?.remove()
	g.backgroundRectangle = null
	return

this.drawView = ()->
	time = Date.now()
	view.draw()
	console.log "Time to draw the view: " + ((Date.now()-time)/1000) + " sec."
	return

# this.benchmarkRectangleClone = ()->
# 	start = Date.now()
# 	r = new Rectangle(1,2,3,4)
# 	p = new Point(5,6)
# 	for i in [0 .. 1000000]
# 		r2 = r.clone()
# 		r2.center = p
# 	end = Date.now()
# 	console.log "rectangle clone time: " + (end-start)

# 	d = p.subtract(r.center)
	
# 	start = Date.now()
# 	for i in [0 .. 1000000]
# 		r.x += d.x
# 		r.y += d.y
# 	end = Date.now()
	
# 	console.log "rectangle move time: " + (end-start)

# 	return

this.highlightValidity = (item)->
	g.validatePosition(item, null, true)
	return

# - check if *bounds* is valid: does not intersect with a planet nor a lock
# - if bounds is not defined, the bounds of the item will be used
# - cancel all highlights
# - if the item has been dragged over a lock or out of a lock: highlight (if *highlight*) or update the items accordingly
# @param item [RItem] the item to check
# @param bounds [Paper Rectangle] (optional) the bounds to consider, item's bounds are used if *bounds* is null
# @param highlight [boolean] (optional) whether to highlight or update the items
this.validatePosition = (item, bounds=null, highlight=false)->
	bounds ?= item.getBounds()

	g.limitPathV?.strokeColor = 'green'
	g.limitPathH?.strokeColor = 'green'

	for lock in g.locks
		lock.unhighlight()

	this.unhighlightStage()

	if g.rectangleOverlapsTwoPlanets(bounds)
		if highlight
			g.limitPathV?.strokeColor = 'red'
			g.limitPathH?.strokeColor = 'red'
		else
			return false

	locks = RLock.getLocksWhichIntersect(bounds)

	for lock in locks
		if RLock.prototype.isPrototypeOf(item)
			if item != lock
				if highlight
					lock.highlight('red')
				else
					return false
		else
			if lock.getBounds().contains(bounds) and g.me == lock.owner
				if item.lock != lock
					if highlight
						lock.highlight('green')
					else
						lock.addItem(item)
			else
				if highlight
					lock.highlight('red')
				else
					return false
	
	if locks.length == 0
		if item.lock?
			if highlight
				this.highlightStage('green')
			else
				g.addItemToStage(item)

	# if item is a lock: check that it still contains its children
	if RLock.prototype.isPrototypeOf(item)
		if not item.containsChildren()
			if highlight
				item.highlight('red')
			else
				return false
	return true

this.zIndexSortStop = (event, ui)=>
	g.deselectAll()
	rItem = g.items[ui.item.attr("data-pk")]
	nextItemJ = ui.item.next()
	if nextItemJ.length>0
		rItem.insertAbove(g.items[nextItemJ.attr("data-pk")], null, true)
	else
		previousItemJ = ui.item.prev()
		if previousItemJ.length>0
			rItem.insertBelow(g.items[previousItemJ.attr("data-pk")], null, true)
	for item in g.previouslySelectedItems
		item.select()
	return

this.addItemToStage = (item)->
	g.addItemTo(item)
	return

this.addItemTo = (item, lock=null)->
	wasSelected = item.isSelected()
	if wasSelected then item.deselect()
	group = if lock then lock.group else g.mainLayer
	group.addChild(item.group)
	item.lock = lock
	item.sortedItems.remove(item)
	parent = lock or g
	if RDiv.prototype.isPrototypeOf(item)
		item.sortedItems = parent.sortedDivs
		parent.itemListsJ.find(".rDiv-list").append(item.liJ)
	else if RPath.prototype.isPrototypeOf(item)
		item.sortedItems = parent.sortedPaths
		parent.itemListsJ.find(".rPath-list").append(item.liJ)
	else
		console.error "Error: the item is neither an RDiv nor an RPath"
	item.updateZIndex()
	if wasSelected then item.select()
	return

# @return [Paper Rectangle] the bounding box of *rectangle* (smallest rectangle containing *rectangle*) when it is rotated by *rotation*
this.getRotatedBounds = (rectangle, rotation=0)->
	topLeft = rectangle.topLeft.subtract(rectangle.center)
	topLeft.angle += rotation
	bottomRight = rectangle.bottomRight.subtract(rectangle.center)
	bottomRight.angle += rotation
	bottomLeft = rectangle.bottomLeft.subtract(rectangle.center)
	bottomLeft.angle += rotation
	topRight = rectangle.topRight.subtract(rectangle.center)
	topRight.angle += rotation
	bounds = new Rectangle(rectangle.center.add(topLeft), rectangle.center.add(bottomRight))
	bounds = bounds.include(rectangle.center.add(bottomLeft))
	bounds = bounds.include(rectangle.center.add(topRight))
	return bounds

# this.rasterizePaths = ()->
# 	for pk, path of g.paths
# 		raster = path.drawing.rasterize()
# 		position = Point.max(view.projectToView(raster.bounds.topLeft), new Point(0,0))
# 		g.context.drawImage(raster.canvas, position.x, position.y)
# 		raster.remove()
# 		path.group.visible = false
# 	return

# this.deletePaths = ()->
# 	for pk, path of g.paths
# 		path.remove()
# 	return

# this.rasterizeProject = (path)->
# 	if path.controlPath?
# 		path.group.visible = false
# 		view.draw()
# 	g.backgroundCanvasJ.show()
# 	g.backgroundContext.drawImage(g.canvas, 0, 0, g.canvas.width, g.canvas.height)
# 	for pk, p of g.paths
# 		if p != path
# 			p.group.visible = false
# 	path.group.visible = true
# 	return

# this.restoreProject = ()->
# 	g.backgroundCanvasJ.hide()
# 	g.backgroundContext.clearRect(0, 0, canvas.width, canvas.height)
# 	for pk, p of g.paths
# 		p.group.visible = true
# 	return

this.rasterizeProject = (paths)->

	for pk, p of g.path
		if not p.drawing? then p.draw()
		p.group.visible = true

	# do we need update when path is not created
	for path in paths
		path.group.visible = false
		view.update()

	# g.backgroundCanvasJ.show()
	# g.backgroundContext.drawImage(g.canvas, 0, 0, g.canvas.width, g.canvas.height)
	
	g.putViewToRasters()

	for pk, p of g.paths
		if paths.indexOf(p)<0 then p.group.visible = false
	
	for path in paths
		path.group.visible = true

	return

this.restoreProject = ()->
	# g.backgroundCanvasJ.hide()
	# g.backgroundContext.clearRect(0, 0, canvas.width, canvas.height)

	# for pk, p of g.paths
	# 	p.group.visible = true

	# view.update()
	# g.rasterizeToRasters()

	if path.getDrawingBounds() < 2000*2000
		g.putImageToRasters(path.drawing.rasterize())

	return

this.rasterizeToRasters = ()->
	for x, rasterColumn of g.rasters
		for y, raster of rasterColumn
			intersection = raster.bounds.intersect(view.bounds)
			if intersection.area > 0
				positionInRaster = intersection.topLeft.subtract(raster.bounds.topLeft) #.divide(raster.bounds.width, raster.bounds.height).multiply(1000, 1000)
				intersectionInView = g.projectToViewRectangle(intersection)
				imageData = g.context.getImageData(intersectionInView.x, intersectionInView.y, intersectionInView.width, intersectionInView.height)
				raster.setImageData(imageData, positionInRaster.x, positionInRaster.y)

	return
	

this.putViewToRasters = (r)->
	g.putImageToRasters(g.context, view.bounds)
	return

this.putRasterToRasters = (raster)->
	bounds = g.projectToViewRectangle(raster.bounds)
	raster.size = raster.size.multiply(view.zoom)
	g.putImageToRasters(raster, bounds)
	return

this.putRasterToRasters = (raster)->
	raster.size = raster.size.multiply(view.zoom)
	bounds = raster.bounds
	for x, rasterColumn of g.rasters
		for y, raster of rasterColumn
			intersection = raster.bounds.intersect(bounds)
			if intersection.area > 0
				positionInRaster = intersection.topLeft.subtract(raster.bounds.topLeft).divide(raster.bounds.width, raster.bounds.height).multiply(1000, 1000)
				intersectionInView = g.projectToViewRectangle(intersection)
				imageData = container.getImageData(intersectionInView.x, intersectionInView.y, intersectionInView.width, intersectionInView.height)
				raster.setImageData(imageData, positionInRaster.x, positionInRaster.y)

	return

this.putImageToRasters = (container, bounds)->

	for x, rasterColumn of g.rasters
		for y, raster of rasterColumn
			intersection = raster.bounds.intersect(bounds)
			if intersection.area > 0
				positionInRaster = intersection.topLeft.subtract(raster.bounds.topLeft).divide(raster.bounds.width, raster.bounds.height).multiply(1000, 1000)
				intersectionInView = g.projectToViewRectangle(intersection)
				imageData = container.getImageData(intersectionInView.x, intersectionInView.y, intersectionInView.width, intersectionInView.height)
				raster.setImageData(imageData, positionInRaster.x, positionInRaster.y)

	return

# hide rasters and redraw all items
# this.updateView = ()->

# 	for x, rasterColumn of g.rasters
# 		for y, raster of rasterColumn
# 			raster.remove()
# 			delete g.rasters[x][y]
# 			if g.isEmpty(g.rasters[x]) then delete g.rasters[x]

# 	for pk, item of g.paths
# 		item.draw()

# 	return

# this.hidePaths = ()->
# 	for pk, path of g.paths
# 		path.group.visible = false
# 	return

# this.showPaths = ()->
# 	for pk, path of g.paths
# 		path.group.visible = true
# 	return

# Get the image in *rectangle* of the view in a data url
# @param rectangle [Paper Rectangle] a rectangle in view or project coordinates representing the area to extract
# @param convertToView [Boolean] (optional) a boolean indicating whether to intersect *rectangle* with the view bounds and convert to view coordinates
# @return [String] the data url of the view image defined by area
this.areaToImageDataUrl = (rectangle, convertToView=true)->
	if rectangle.height <=0 or rectangle.width <=0 
		console.log 'Warning: trying to extract empty area!!!'
		return null

	if convertToView
		rectangle = rectangle.intersect(view.bounds)
		viewRectangle = g.projectToViewRectangle(rectangle)
	else
		viewRectangle = rectangle

	if viewRectangle.size.equals(view.size) and viewRectangle.x == 0 and viewRectangle.y == 0
		return g.canvas.toDataURL("image/png")

	canvasTemp = document.createElement('canvas')
	canvasTemp.width = viewRectangle.width
	canvasTemp.height = viewRectangle.height
	contextTemp = canvasTemp.getContext('2d')
	contextTemp.putImageData(g.context.getImageData(viewRectangle.x, viewRectangle.y, viewRectangle.width, viewRectangle.height), 0, 0)
	
	dataURL = canvasTemp.toDataURL("image/png")
	return dataURL

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

# 			rastebounds = new Rectangle(x, y, 1000, 1000)

# 			for pk, item of g.items
# 				console.log "item: " + item.name
# 				console.log item.getBounds()
# 				console.log rastebounds
# 				console.log item.getBounds().intersects(rastebounds)
# 				if item != ritem and item.getBounds().intersects(rastebounds)
# 					item.draw()
# 	return

# return a rectangle with integer coordinates and dimensions: left and top positions will be ceiled, right and bottom position will be floored
# @param rectangle [Paper Rectangle] the rectangle to round
# @return [Paper Rectangle] the resulting shrinked rectangle
this.shrinkRectangleToInteger = (rectangle)->
	# return new Rectangle(new Point(Math.ceil(rectangle.left), Math.ceil(rectangle.top)), new Point(Math.floor(rectangle.right), Math.floor(rectangle.bottom)))
	return new Rectangle(rectangle.topLeft.ceil(), rectangle.bottomRight.floor())

# return a rectangle with integer coordinates and dimensions: left and top positions will be floored, right and bottom position will be ceiled
# @param rectangle [Paper Rectangle] the rectangle to round
# @return [Paper Rectangle] the resulting expanded rectangle
this.expandRectangleToInteger = (rectangle)->
	# return new Rectangle(new Point(Math.floor(rectangle.left), Math.floor(rectangle.top)), new Point(Math.ceil(rectangle.right), Math.ceil(rectangle.bottom)))
	return new Rectangle(rectangle.topLeft.floor(), rectangle.bottomRight.ceil())

# return a rounded rectangle with integer coordinates and dimensions
# @param rectangle [Paper Rectangle] the rectangle to round
# @return [Paper Rectangle] the resulting rounded rectangle
this.roundRectangle = (rectangle)->
	return new Rectangle(rectangle.topLeft.round(), rectangle.bottomRight.round())

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

this.highlightAreasToUpdate = ()->
	for pk, rectangle of g.areasToUpdate
		rectanglePath = project.getItem( name: pk )
		rectanglePath.strokeColor = 'green'
	return

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
	console.log 'selected rasters:'
	return rasters

this.printPathList = ()->
	names = []
	for pathClass in g.pathClasses
		names.push(pathClass.rname)
	console.log names
	return

this.fakeGeoJsonBox = (rectangle)->
	box = {}

	planet = pointToObj( projectToPlanet(rectangle.topLeft) )

	box.planetX = planet.x
	box.planetY = planet.y

	box.box = coordinates: [[
		g.pointToArray(projectToPosOnPlanet(rectangle.topLeft, planet))
		g.pointToArray(projectToPosOnPlanet(rectangle.topRight, planet))
		g.pointToArray(projectToPosOnPlanet(rectangle.bottomRight, planet))
		g.pointToArray(projectToPosOnPlanet(rectangle.bottomLeft, planet))
	]]
	return JSON.stringify(box)

this.getControllerFromFomElement = ()->
	for folderName, folder of g.gui.__folders
		for controller in folder.__controllers
			if controller.domElement == $0 or $($0).find(controller.domElement).length>0
				return controller
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

# Paper.js onFrame event also wotks with requestAnimationFrame so it is better to use the paper default function
# deprecated animate function for Tween.js
# this.animate = (time)->
# 	requestAnimationFrame( animate )
# 	TWEEN.update(time)
# 	return