# todo: change ownership through websocket?
# todo: change lock/link popover to romanesco alert?

# RDiv is a div on top of the canvas (i.e. on top of the paper.js project) which can be resized, unless it is locked
# it is lock if it is owned by another user
#
# There are different RDivs, with different content:
# - RLocks (RLock, RLink, RWebsite and RVideoGame): @see RLock
#     they define areas which can only be modified by a single user (the on who created the RLock); all RItems in the area is the property of this user
# - RText: a textarea to write some text. The text can have any google font, any effect, but all text of an RText have the same formating.
# - RMedia: an image, video or any content inside an iframe (can be a [shadertoy](https://www.shadertoy.com/))
# - RSelectionRectangle: a special div just to defined a selection rectangle, user by {ScreenshotTool}
#
class RDiv

	# once the user made the selection rectangle, a modal window ask the user to enter additional information to create the RDiv
	# (RText and RSelectionRectangle do not require additional information)
	
	@modalTitle = '' 						# the title of the modal window
	@modalTitleUpdate = '' 					# the title of the modal window when the RDiv is being modified (not used anymore at the moment)
	@object_type = 'div' 					# string describing the type of RDiv (can be 'lock', 'link', 'website', 'video-game', 'text', 'media')
	@modalJ = $('#divModal') 				# initialize the modal jQuery element
	@modalJ.on('shown.bs.modal', (event)=> @modalJ.find('input.form-control:visible:first').focus() ) 	# focus on the first visible element when the modal shows up
	@modalJ.find('.submit-shortcut').keypress( (event) => 		# submit modal when enter is pressed
		if event.which == 13 	# enter key
			event.preventDefault()
			@modalSubmit()
	)
	@modalJ.find('.btn-primary').click( (event)=> @modalSubmit()	) # submit modal when click submit button

	# parameters are defined as in {RTool}
	@parameters: ()->

		strokeWidth = $.extend(true, {}, g.parameters.strokeWidth)
		strokeWidth.default = 1
		strokeColor = $.extend(true, {}, g.parameters.strokeColor)
		strokeColor.default = 'black'

		return parameters =
			'General': 
				# zoom: g.parameters.zoom
				# displayGrid: g.parameters.displayGrid
				# snap: g.parameters.snap
				align: g.parameters.align
				distribute: g.parameters.distribute
				duplicate: g.parameters.duplicate
				delete: g.parameters.delete
			'Style':
				strokeWidth: strokeWidth
				strokeColor: strokeColor
				fillColor: g.parameters.fillColor

	# intialize the fields of the modal
	# this is redefined by children RDivs
	# each RDiv shows the fields it needs and hide others
	@initFields: () ->
		@modalJ.find('p.cost').show()
		@modalJ.find('.url-name-group').show()
		@modalJ.find('.name-group').hide()
		@modalJ.find('.url-group').show()
		@modalJ.find('.message-group').show()
		@modalJ.find('.checkbox.restrict-area').hide()
		@modalJ.find('.checkbox.disable-toolbar').hide()
		return

	# save the RDiv to the database
	# this method is usually called when the modal is submitted
	# however, RText is saved directly after user has defined the rectangle (in TextTool)
	# save() is also called to duplicate an RDiv
	# @param rectangle [Paper rectangle] the RDiv rectangle
	# @param object_type [String] the type of RDiv (can be 'lock', 'link', 'website', 'video-game', 'text', 'media')
	# @param message [String] (optional) the message (for example, the message which will be displayed when a user click on a RLock)
	# @param url [String] (optional) the url (for example the url of the website to link for a RLink)
	# @param clonePk [ID] (optional) null by default, pk of the RDiv to duplicate
	# @param website [Boolean] whether the RDiv is a website
	# @param restrictedArea [Boolean] whether the user must be restricted to this area when landing on the website
	# @param disableToolbar [Boolean] whether the toolbar must be disabled when navigating on this website
	@save: (rectangle, object_type, message, name, url, clonePk, website, restrictedArea, disableToolbar) ->

		if @boxOverlapsTwoPlanets(rectangle)
			return
		
		if rectangle.area == 0
			romanesco_alert "Error: your box is not valid.", "error"
			return
		switch object_type
			when 'text', 'media'
				# ajaxPost '/saveDiv', { 'box': @boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'url': url, 'clonePk': clonePk }, @save_callback
				Dajaxice.draw.saveDiv( @save_callback, { 'box': @boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'url': url, 'clonePk': clonePk } )
			else
				# ajaxPost '/saveBox', { 'box': @boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url, 'clonePk': clonePk, 'website': website, 'restrictedArea': restrictedArea, 'disableToolbar': disableToolbar }, @save_callback
				Dajaxice.draw.saveBox( @save_callback, { 'box': @boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url, 'clonePk': clonePk, 'website': website, 'restrictedArea': restrictedArea, 'disableToolbar': disableToolbar } )

		# if object_type == 'text' or object_type == 'media'
		# 	Dajaxice.draw.saveDiv( @save_callback, { 'box': @boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'url': url, 'clonePk': clonePk } )
		# else if object_type == 'lock' or object_type == 'link'
		# 	Dajaxice.draw.saveBox( @save_callback, { 'box': @boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url, 'clonePk': clonePk, 'website': website, 'restrictedArea': restrictedArea, 'disableToolbar': disableToolbar } )
		return

	# save callback: check for errors and create div if success
	# usually called be the server, but can be called by websocket (when transfering RDiv creation to other users)
	# @param result [Object] the data returned by the server
	# @param owner [Boolean] whether the user created the RDiv or it is recieved from websocket
	@save_callback: (result, owner=true)->
		
		if not g.checkError(result)
			return

		tl = g.posOnPlanetToProject(result.box.tl, result.box.planet)
		br = g.posOnPlanetToProject(result.box.br, result.box.planet)

		div = null

		switch result.object_type
			when 'text'
				div = new RText(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.locked, result.message, result.data)
			when 'media'
				div = new RMedia(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.locked, result.url, result.data)
			when 'lock'
				div = new RLock(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, true, result.data)
			when 'website'
				div = new RWebsite(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, result.data)
			when 'video-game'
				div = new RVideoGame(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, result.data)
			when 'link'
				div = new RLink(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, result.name, result.url, result.data)

		# if we cloned the div: copy data from original div
		if result.clonePk
			data = g.items[result.clonePk].data
			div.data = jQuery.extend({}, data)
			div.parameterChanged()

		if owner 	# emit div creation on websocket
			g.chatSocket.emit( "createDiv", result)
			if not result.clonePk? then div.select()

		return

	# initialize the modal
	# @param object_type [String] the type of RDiv (can be 'lock', 'link', 'website', 'video-game', 'text', 'media')
	# @param rectangle [Rectangle]  the RDiv rectangle
	# @param div [RDiv] the div to update (not used anymore)
	@initModal: (object_type, rectangle=null, div=null)->
		@modalJ.object_type = object_type
		@modalJ.rectangle = rectangle
		@modalJ.update = div!=null
		@initFields()
		if @modalJ.update
			@modalJ.find('p.cost').text("")
		@modalJ.find('input.url-name').val(div?.name)
		@modalJ.find('input.url').val(div?.message)
		@modalJ.find('input.message').val(div?.url)
		@modalJ.find('.modal-title').text(@modalTitle)
		if @modalJ.update
			@modalJ.find('.btn-primary').text("Modify")
		else
			@modalJ.find('.btn-primary').text("Add")
		@modalJ.modal('show')
		return
	
	# submit the modal (to save or update the RDiv)
	# the modal is hidden
	@modalSubmit = () =>
		# get url and add http:// prefix if necessary
		url = @modalJ.find("input.url").val()
		if url.length>0 && url.indexOf("http://") != 0 && url.indexOf("https://") != 0
			url = "http://" + url

		# get field informations
		name = @modalJ.find("input.name").val()
		message = @modalJ.find("input.message").val()

		object_type = @modalJ.object_type
		website = object_type == 'website' or object_type == 'video-game'
		restrictedArea = @modalJ.find('#divModalRestrictArea').is(':checked')
		disableToolbar = @modalJ.find('#divModalDisableToolbar').is(':checked')
		
		if object_type == 'link'
			name = @modalJ.find("input.url-name").val()

		# g.tools[@object_type].select()
		# update or save the div
		if @modalJ.update
			if div.url? then div.url = url
			if div.name? then div.name = name
			if div.message? then div.message = message
			div.update()
		else
			@save(@modalJ.rectangle, object_type, message, name, url, false, website, restrictedArea, disableToolbar)
		@modalJ.modal('hide')
		return

	# get a GeoJson valid box in planet coordinates from *rectangle* 
	# @param rectangle [Paper Rectangle] the rectangle to convert
	# @return [{ points:Array<Array<2 Numbers>>, planet: Object, tl: Point, br: Point }]
	@boxFromRectangle: (rectangle)->
		# remove margin to ignore intersections of paths which are close to the edges

		planet = pointToObj( projectToPlanet(rectangle.topLeft) )

		tlOnPlanet = projectToPosOnPlanet(rectangle.topLeft, planet)
		brOnPlanet = projectToPosOnPlanet(rectangle.bottomRight, planet)

		points = []
		points.push(pointToArray(tlOnPlanet))
		points.push(pointToArray(projectToPosOnPlanet(rectangle.topRight, planet)))
		points.push(pointToArray(brOnPlanet))
		points.push(pointToArray(projectToPosOnPlanet(rectangle.bottomLeft, planet)))
		points.push(pointToArray(tlOnPlanet))

		return { points:points, planet: pointToObj(planet), tl: tlOnPlanet, br: brOnPlanet }

	# test if the box overlaps two planets
	# @param box [Paper Rectangle] the box to test
	# @return [Boolean] true if the box overlaps two planets, false otherwise
	@boxOverlapsTwoPlanets: (box) ->
		limit = getLimit()
		if ( box.left < limit.x && box.right > limit.x ) || ( box.top < limit.y && box.bottom > limit.y )
			romanesco_alert("You can not add anything in between two planets, this is not yet supported.", "info")
			return true
		return false

	# add the div jQuery element (@divJ) on top of the canvas and intialize it
	# initialize @data
	# @param position [Paper Point] the position of the div
	# @param size [Paper Size] the size of the div
	# @param owner [String] the username of the owner of the div
	# @param pk [ID] the primary key of the div
	# @param locked [Boolean] (optional) whether the div is locked by an RLock
	# @param data [Object] the data of the div (containing the stroke width, colors, etc.)
	constructor: (@position, @size, @owner, @pk, locked=false, @data) ->
		@controller = this
		@object_type = @constructor.object_type

		# initialize @divJ: main jQuery element of the div
		separatorJ = g.stageJ.find("." + @object_type + "-separator")
		@divJ = g.templatesJ.find(".custom-div").clone().insertAfter(separatorJ)
		@maskJ = @divJ.find(".mask")

		width = @size.width
		height = @size.height

		if not @data? # creation of a new object by the user: set @data to g.gui values
			@data = new Object()
			for name, folder of g.gui.__folders
				if name=='General' then continue
				for controller in folder.__controllers
					@data[controller.property] = controller.rValue()

		# update size and position
		@divJ.css(width: width, height: height)
		@updateTransform()

		if @owner != g.me and locked 	# lock div it is not mine and it is locked
			@divJ.addClass("locked")

		@divJ.attr("data-pk",@pk)
		@divJ.controller = @
		@setCss()

		if not locked
			@divJ.mousedown( @selectBegin )

		g.divs.push(@)
		g.items[@pk] = @

		# @debugRectangle = new Path.Rectangle(@position, new Size(@size))
		# @debugRectangle.strokeWidth = 5
		# @debugRectangle.strokeColor = 'red'

		if g.selectedTool.name == 'Move' then @disableInteraction()
		return

	# common to all RItems
	# construct a new RDiv and save it
	# @return [RDiv] the copy
	duplicate: ()->
		@constructor.save(@getBounds(), @object_type, @message, @name, @url, @pk)
		return

	# open modal window to modify RDiv information (not used anymore)
	modify: () ->
		@constructor.initModal(@getBounds(), @)
		return

	# updateTransform: ()->
	# 	css = 'translate(' + (@position.x * g.view.zoom) + 'px,' + (@position.y * g.view.zoom) + 'px) scale(' + g.view.zoom + ')'
	# 	@divJ.css( 'transform': css )

	# update the scale and position of the RDiv (depending on its position and scale, and the view position and scale)
	# if zoom equals 1, do no use css translate() property to avoid blurry text
	updateTransform: ()->
		# the css of the div in styles.less: transform-origin: 0% 0% 0

		viewPos = view.projectToView(@position)
		# viewPos = new Point( -g.offset.x + @position.x, -g.offset.y + @position.y )
		if view.zoom == 1
			@divJ.css( 'left': viewPos.x, 'top': viewPos.y, 'transform': 'none' )
		else
			css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
			css += ' scale(' + view.zoom + ')'

			@divJ.css( 'transform': css, 'top': 0, 'left': 0 )
		return

	# zoom: ()->
	# 	# originX = '' + (g.stageJ.width()*0.5-@position.x) + 'px'
	# 	# originY = '' + (g.stageJ.height()*0.5-@position.y) + 'px'

	# 	# originX = '' + (g.stageJ.width()*0.5) + 'px'
	# 	# originY = '' + (g.stageJ.height()*0.5) + 'px'

	# 	# @divJ.css( 'transform-origin-x': originX, 'transform-origin-y': originY )
	# 	@updateTransform()
	# 	return

	# common to all RItems
	# return [Rectangle] the bounds of the RDiv
	getBounds: ()->
		return new Rectangle(@position.x, @position.y, @divJ.outerWidth(), @divJ.outerHeight())

	# common to all RItems
	# move the RDiv to *position* and update if *userAction*
	# @param [Point] the new position of the div
	# @param [Boolean] whether this is an action from *g.me* or another user
	moveTo: (position, userAction)->
		@position = position.subtract(@size.multiply(0.5))
		@updateTransform()
		if userAction
			g.defferedExecution(@update, @pk)
			# if g.me? and userAction then g.chatSocket.emit( "select begin", g.me, @pk, g.eventToObject(event))
		return

	# common to all RItems
	# move the RDiv by *delta* and update if *userAction*
	# @param [Point] the amount by which moving the div
	# @param [Boolean] whether this is an action from *g.me* or another user
	moveBy: (delta, userAction)->
		@position.x += delta.x
		@position.y += delta.y
		@updateTransform()
		if userAction
			g.defferedExecution(@update, @pk)
			# if g.me? and userAction then g.chatSocket.emit( "select begin", g.me, @pk, g.eventToObject(event))
		return

	# get the position of the RDiv on the screen
	# @return [Paper Point] the position of the top left corner of the div
	posOnScreen: ()->
		# should be equal to view.projectToView(@position)
		# return view.projectToView(@position)
		center = new Point(g.stageJ.width()*0.5, g.stageJ.height()*0.5)
		delta = @position.subtract(center)
		return new Point(center.add(delta.multiply(g.view.zoom)))

	# the x position of the div before applying the scale (to fit the zoom)
	# @param posX [Number] the x position of the div
	# @return [Number] the x position in the div before it is scaled
	posBeforeScaleX: (posX)->
		centerX = g.stageJ.width()*0.5 					# delta = (posX-centerX) / g.view.zoom
		return centerX + (posX-centerX) / g.view.zoom 	# return centerX + delta

	# the y position of the div before applying the scale (to fit the zoom)
	# @param posY [Number] the x position of the div
	# @return [Number] the y position in the div before it is scaled
	posBeforeScaleY: (posY)->
		centerY = g.stageJ.height()*0.5
		return centerY + (posY-centerY) / g.view.zoom

	# the position of the div before applying the scale (to fit the zoom)
	# @param pos [Point] the position of the div
	# @return [Paper Point] the position in the div before it is scaled
	posBeforeScale: (pos)->
		return new Point(@posBeforeScaleX(pos.x), @posBeforeScaleY(pos.y))

	# common to all RItems
	# called when user press mouse while on the div (the event listener is set in the constructor, after @divJ is added in top of the canvas)
	# (could be called by websocket, this functionnality is disabled for now)
	# - select the div if *userAction* and the div is not selected yet
	# - if target is handle: prepare to resize the div
	# - if tagret if textarea: do nothing
	# - otherwise: prepare to move the div
	# @param event [Paper Event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	selectBegin: (event, userAction=true) =>
		# return if user used the middle mouse button (mouse wheel button, event.which == 2) to drag the stage instead of the div
		if userAction and ( g.selectedTool.name == 'Move' or event.which == 2 )
			return

		@dragging = false
		@draggedHandleJ = null

		if userAction and g.selectedDivs.indexOf(@)<0 	# select the div if *userAction* and the div is not selected yet
			if not event.shiftKey then g.deselectAll()
			@select()

		point = if userAction then new Point(event.pageX, event.pageY) else view.projectToView(event.point)
		@mouseDownPosition = point

		targetJ = if userAction then $(event.target) else @divJ.find(event.target)

		if targetJ.is("textarea")
			@selectingText = true
			return true

		@dragging = true

		# pos will be used with event.page, must be defined in screen coordinates
		pos = @posOnScreen()

		if targetJ.hasClass("handle")
			@draggedHandleJ = targetJ
			pos.x += @draggedHandleJ.position().left
			pos.y += @draggedHandleJ.position().top

		@dragOffset = {}
		@dragOffset.x = point.x-pos.x
		@dragOffset.y = point.y-pos.y

		# if g.me? and userAction then g.chatSocket.emit( "select begin", g.me, @pk, g.eventToObject(event))
		return

	# common to all RItems
	# called by main.coffee, when mousemove on window
	# move, resize or drag the div, depending on how the select action was initialized
	# @param event [Paper Event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	selectUpdate: (event, userAction=true) =>
		if @selectingText then return

		if not @dragging
			event.delta.multiply(1/view.zoom)
			if event.delta? then @moveBy(event.delta) 	# hack to move the div when dragging a selection group
			return true
		if @draggedHandleJ
			@resize(event, userAction)
		else
			@drag(event, userAction)

		# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventToObject(event))
		return

	# common to all RItems
	# called by main.coffee, when mouseup on window
	# ends the select actions
	# @param event [Paper Event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	selectEnd: (event, userAction=true) =>
		if not @dragging
			if @selectingText then @selectingText = false
			if event.delta? then @moveBy(event.delta) 	# hack to move the div when dragging a selection group
			return true

		if @mouseDownPosition.x != event.pageX and @mouseDownPosition.y != event.pageY
			@dragFinished(userAction)
		
		@dragging = false
		@draggedHandleJ = null

		# if g.me? and userAction then g.chatSocket.emit( "select end", g.me, @pk, g.eventToObject(event))
		return

	# mouse interaction must be disabled when user has the move tool (a click on an RDiv must not start a resize action)
	# disable user interaction on this div by putting a transparent mask (div) on top of the div
	disableInteraction: () ->
		@maskJ.show()
		return
	
	# see {RDiv#disableInteraction}
	# enable user interaction on this div by hiding the mask (div)
	enableInteraction: () ->
		@maskJ.hide()
		return

	# @return [Paper Point] the bottom right corner position of the div
	bottomRight: () ->
		return new Point(@position.x+@divJ.outerWidth(), @position.y+@divJ.outerHeight())

	# resize the div when the user drags one of the corner (handle)
	# the opposite corner should not change, and the neighbour corners should adapt to the new size
	# the position and size of the div are updated
	# @param event [Paper Event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	resize: (event, userAction=true) =>
		point = if userAction then new Point(event.pageX, event.pageY) else view.projectToView(event.point)
		pos = @position
		if @draggedHandleJ.hasClass("tl")
			right = pos.x+@divJ.outerWidth()
			bottom = pos.y+@divJ.outerHeight()
			newLeft = @posBeforeScaleX(point.x - @dragOffset.x)
			newLeft = g.snap1D(newLeft)
			newTop = @posBeforeScaleY(point.y - @dragOffset.y)
			newTop = g.snap1D(newTop)
			newWidth = right-newLeft
			newHeight = bottom-newTop
		else if @draggedHandleJ.hasClass("tr")
			bottom = pos.y+@divJ.outerHeight()
			newLeft = pos.x
			newLeft = g.snap1D(newLeft)
			newTop = @posBeforeScaleY(point.y-@dragOffset.y)
			newTop = g.snap1D(newTop)
			newWidth = @posBeforeScaleX(point.x-@dragOffset.x)+@draggedHandleJ.outerWidth()-newLeft
			newHeight = bottom-newTop
		else if @draggedHandleJ.hasClass("br")
			newLeft = pos.x
			newTop = pos.y
			newTop = g.snap1D(newTop)
			newWidth = @posBeforeScaleX(point.x-@dragOffset.x)+@draggedHandleJ.outerWidth()-newLeft
			newHeight = @posBeforeScaleY(point.y-@dragOffset.y)+@draggedHandleJ.outerHeight()-newTop
		else if @draggedHandleJ.hasClass("bl")
			right = pos.x+@divJ.outerWidth()
			newLeft = @posBeforeScaleX(point.x-@dragOffset.x)
			newLeft = g.snap1D(newLeft)
			newTop = pos.y
			newTop = g.snap1D(newTop)
			newWidth = right-newLeft
			newHeight = @posBeforeScaleY(point.y-@dragOffset.y)+@draggedHandleJ.outerHeight()-newTop
		@position = new Point(newLeft, newTop)
		@size = new Size(g.snap1D(newWidth), g.snap1D(newHeight))
		@updateTransform()
		@divJ.css( width: @size.width, height: @size.height )
		@divJ.find(".handle").css( 'z-index': 10)
		return

	# drag the div according to the event
	# @param event [Event] the mouse event
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	drag: (event, userAction=true) =>
		point = if userAction then new Point(event.pageX, event.pageY) else view.projectToView(event.point)
		@position = @posBeforeScale(new Point(point.x - @dragOffset.x, point.y - @dragOffset.y))
		@position = g.snap2D(@position)
		@updateTransform()
		return

	# reset drag action
	# @param userAction [Boolean] whether this is an action from *g.me* or another user 
	dragFinished: (userAction=true) =>
		@dragging = false
		@draggedHandleJ = null
		if userAction
			@update()
		return
	
	# update = false when called by parameter.onChange from websocket
	# common to all RItems
	# called when a parameter is changed:
	# - from user action (parameter.onChange) (update = true)
	# - from websocket (another user changed the parameter) (update = false)
	# @param [Boolean] (optional, default is true) whether to update the RPath in database
	parameterChanged: (update=true)->
		switch @changed
			when 'strokeWidth', 'strokeColor', 'fillColor'
				@setCss()
		if update then g.defferedExecution(@update, @pk)
		return
	
	# common to all RItems
	# @return [String] the stringified data
	getStringifiedData: ()->
		return JSON.stringify(@getData())
	
	# common to all RItems
	# get data, usually to save the RPath (some information must be added to data)
	getData: ()->
		return @data

	# called after udpate, on server response
	# @param result [Object] the server response
	updateDiv_callback: (result)->
		g.checkError(result)
		return

	# update the RDiv in the database
	# often called after the RDiv has changed, in a *g.defferedExecution(@update)*
	update: () =>
		tl = @position
		br = @bottomRight()
		
		# check if position is valid
		if @constructor.boxOverlapsTwoPlanets(tl,br)
			return
		
		# intiialize data to be saved
		data = 
			box: @constructor.boxFromRectangle(new Rectangle(tl,br))
			pk: @pk
			object_type: @object_type
			message: @message
			url: @url
			data: @getStringifiedData()

		@changed = null
		
		# update the div
		if @object_type == 'text' or @object_type == 'media' 
			# ajaxPost '/updateDiv', data, @updateDiv_callback
			Dajaxice.draw.updateDiv( @updateDiv_callback, data )
		else
			data.name = @name
			# ajaxPost '/updateBox', data, @updateDiv_callback
			Dajaxice.draw.updateBox( @updateDiv_callback, data )

		return

	# common to all RItems
	# - select the RDiv is not already selected
	# - select the select tool
	# - update parameters according to @data
	select: () =>
		if @divJ.hasClass("selected") then return
		g.selectedDivs.push(@)
		if g.selectedTool != g.tools['Select'] then g.tools['Select'].select()
		@divJ.addClass("selected")

		g.updateParameters( { tool: @constructor, item: @ }, true)
		return

	# common to all RItems
	# deselect the div
	deselect: () =>
		if not @divJ.hasClass("selected") then return
		@divJ.removeClass("selected")
		g.selectedDivs.remove(@)
		return

	# update basic apparence parameters (fill color, stroke color and stroke width) from @data
	setCss: ()->
		@setFillColor()
		@setStrokeColor()
		@setStrokeWidth()
		return

	# update fill color from @data.fillColor
	setFillColor: ()->
		@contentJ?.css( 'background-color': @data.fillColor ? 'transparent')
		return
		
	# update stroke color from @data.strokeColor
	setStrokeColor: ()->
		@contentJ?.css( 'border-color': @data.strokeColor ? 'transparent')
		return
		
	# update stroke width from @data.strokeWidth
	setStrokeWidth: ()->
		@contentJ?.css( 'border-width': @data.strokeWidth ? '0')
		return

	# common to all RItems
	# called by @delete() and to update users view through websockets
	# @delete() removes the path and delete it in the database
	# @remove() just removes visually
	remove: () ->
		@deselect()
		@divJ.remove()
		g.divs.remove(@)
		if @data.loadEntireArea then g.entireAreas.remove(@)
		if g.divToUpdate==@ then delete g.divToUpdate
		delete g.items[@pk]
		return

	# common to all RItems
	# called when user deletes the item by pressing delete key or from the gui
	# @delete() removes the path and delete it in the database
	# @remove() just removes visually
	delete: () ->
		@remove()
		if not @pk? then return
		if @object_type == 'text' or @object_type == 'media'
			# ajaxPost '/deleteDiv', { 'pk': @pk }, @deleteDiv_callback
			Dajaxice.draw.deleteDiv( @deleteDiv_callback, { 'pk': @pk } )
		else
			# ajaxPost '/deleteBox', { 'pk': @pk }, @deleteDiv_callback
			Dajaxice.draw.deleteBox( @deleteDiv_callback, { 'pk': @pk } )
		return

	# check for any error during delete, transmit delete on websocket if no errors
	deleteDiv_callback: (result)->
		if g.checkError(result)
			g.chatSocket.emit( "delete div", result.pk )
		return

@RDiv = RDiv

# RSelectionRectangle is just a helper to define a selection rectangle, it is used in {ScreenshotTool}
class RSelectionRectangle extends RDiv

	@object_type = 'lock'

	# create the div and add a "Take snapshot" button
	constructor: (@rectangle, handler) ->
		g.tools['Select'].select()
		super(rectangle.topLeft, rectangle.size)
		@divJ.addClass("selection-rectangle")
		@buttonJ = $("<button>")
		@buttonJ.text("Take snapshot")
		@buttonJ.click( (event)-> handler() )
		@divJ.append(@buttonJ)
		@select()
		return

	# update the div transformation, without taking the zoom into account
	updateTransform: ()->
		viewPos = view.projectToView(@position)
		css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
		@divJ.css( 'transform': css )
		return

	# deselect the div: remove it
	deselect: ()->
		if @deselected then return
		@deselected = true
		@remove()
		return

	# the div should not be updated (it is not related to the server/database)
	update: ()->
		return

@RSelectionRectangle = RSelectionRectangle

# RLock are locked area which can only be modified by their author 
# all RItems on the area are also locked, and can be unlocked if the user drags them outside the div
class RLock extends RDiv

	@modalTitle = "Lock an area"
	@modalTitleUpdate = "Modify your lock"
	@object_type = 'lock'

	# in the modal: the fields are reinitialized as soon as the type of RLock is changed 
	@modalJ.find("#divModalTypeSelector").click (event)=>
		@initFields()
		return

	# intialize the fields of the modal
	# the fields are initialized depending on the type of RLock (@object_type: 'lock', 'link', 'website', or 'video-game')
	@initFields: ()->
		@modalJ.find('#divModalTypeSelector').show()
		typeSelectorJ = @modalJ.find('input[type=radio][name=typeSelector]:checked')
		object_type = typeSelectorJ[0].value
		@modalJ.object_type = object_type
		area = @modalJ.rectangle.area
		cost = area
		switch object_type
			when 'lock'
				@modalJ.find('.checkbox.restrict-area').hide()
				@modalJ.find('.checkbox.disable-toolbar').hide()
				@modalJ.find('.url-name-group').hide()
				@modalJ.find('.name-group').hide()
				@modalJ.find('.url-group').hide()
				@modalJ.find('.message-group').show()
				cost = area/1000
			when 'link'
				@modalJ.find('.checkbox.restrict-area').hide()
				@modalJ.find('.checkbox.disable-toolbar').hide()
				@modalJ.find('.url-name-group').show()
				@modalJ.find('.name-group').hide()
				@modalJ.find('.url-group').show()
				@modalJ.find('.message-group').show()
				cost = area
			when 'website'
				@modalJ.find('.checkbox.restrict-area').show()
				@modalJ.find('.checkbox.disable-toolbar').show()
				@modalJ.find('.url-name-group').hide()
				@modalJ.find('.name-group').show()
				@modalJ.find('.url-group').hide()
				@modalJ.find('.message-group').hide()
				cost = 2*area/1000
			when 'video-game'
				@modalJ.find('.checkbox.restrict-area').hide()
				@modalJ.find('.checkbox.disable-toolbar').hide()
				@modalJ.find('.url-name-group').hide()
				@modalJ.find('.name-group').show()
				@modalJ.find('.url-group').hide()
				@modalJ.find('.message-group').show()
				cost = 2*area/1000
		if g.credit<cost
			g.romanesco_alert("You do not have enough romanescoins to add this link", "error")
		else
			@modalJ.find('p.cost').text("" + area + " pixels = " + cost.toFixed(2) + " romanescoins")
		return

	# @param point [Paper point] the point to test
	# @return [Boolean] true if the point is in the div, false otherwise
	@intersectPoint: (point)->
		for lock in g.locks
			if lock.getBounds().contains(point) and g.me != lock.owner
				return true
		return false

	# @param rectangle [Paper point] the point to test
	# @return [Boolean] true if the point is in the div, false otherwise
	@intersectRect: (rectangle)->
		for lock in g.locks
			if lock.getBounds().intersects(new Rectangle(rectangle)) and g.me != lock.owner
				return true
		return false

	@initModal: (rectangle=null, div=null)->
		super(@object_type, rectangle, div)

	@parameters: ()->

		parameters = super()

		parameters['Lock'] =
			backgroundMode:
				type: 'checkbox'
				label: 'Send to back'
				default: false

		return parameters

	# popover == true when not a website (then a popover will popup when user clicks), @isWebsite = not popover
	constructor: (@position, @size, @owner, @pk, @message, popover=true, @data) ->
		super(@position, @size, @owner, @pk, @owner != g.me, @data)
		@contentJ = g.templatesJ.find(".lock-content").clone().insertBefore(@maskJ)
		@contentJ = @divJ.find(".lock-content:first")
		@divJ.addClass("lock")
		if not @data.strokeColor?
			@data.strokeColor = '#adadad'
		if not @data.strokeWidth? 
			@data.strokeWidth = 1
		@setCss()
		if popover
			@contentJ.popover(placement:'auto top', trigger:'click', content: @message)
			@popover = @contentJ.data('bs.popover')
		else if @owner != g.me
			@disableInteraction()
		if @owner==g.me then @updateBackgroundMode(true)
		g.locks.push(@)

	drag: (event, userAction=true) =>
		super(event, userAction)
		if not $(event.target).hasClass('lock-content')
			@contentJ?.popover('hide')

	resize: (event, userAction=true) =>
		super(event, userAction)
		@contentJ?.popover('hide')

	select: () =>
		if @owner != g.me then return
		super()
		return

	deselect: () =>
		@contentJ?.popover('hide')
		@updateBackgroundMode(true)
		super()

	remove: () ->
		g.locks.splice(g.locks.indexOf(@),1)
		super()
		@controlPath?.remove()
		@controlPath = null
		return

	delete: () ->
		@contentJ?.popover('hide')
		super()

	update: () ->
		@contentJ.attr('data-content', @message)
		super()

	selectBegin: (event, userAction=true) =>
		if userAction and @owner != g.me then return
		if @data.backgroundMode
			@updateBackgroundMode(false)
			@select()
			return
		super(event, userAction)
	
	selectUpdate: (event, userAction=true) =>
		if (userAction and @owner != g.me) or @data.backgroundMode then return
		super(event, userAction)
	
	selectEnd: (event, userAction=true) =>
		if (userAction and @owner != g.me) or @data.backgroundMode then return
		super(event, userAction)

	updateBackgroundMode: (value)->
		if @owner != g.me then return
		if value? then @data.backgroundMode = value
		@controlPath?.remove()
		if @data.backgroundMode
			@controlPath = new Path.Rectangle(@position, @size)
			@controlPath.name = 'rlock control path'
			@controlPath.strokeWidth = if @data.strokeWidth>0 then @data.strokeWidth else 1
			@controlPath.strokeColor = if @data.strokeColor? then @data.strokeColor else 'black'
			@controlPath.controller = @
			@divJ.hide()
		else
			@divJ.show()
		view.draw()

	parameterChanged: (update=true)->
		switch @changed
			when 'backgroundMode'
				@updateBackgroundMode()
		super(update)

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@contentJ.popover(placement:'auto top', trigger:'click', content: @message)
	# 	@popover = @contentJ.data('bs.popover')
		
@RLock = RLock

class RWebsite extends RLock

	@object_type = 'website'

	constructor: (@position, @size, @owner, @pk, @message, @data) ->
		super(@position, @size, @owner, @pk, @message, false, @data)
		@maskJ.mousedown (event)->
			g.tools['Move'].select()
			return
		@maskJ.mouseup (event)->
			g.previousTool?.select()
			return
		if @owner != g.me
			@divJ.addClass("website")

	# can not enable interaction if not owner and is website
	enableInteraction: () ->
		@maskJ.hide()
		return

@RWebsite = RWebsite

class RVideoGame extends RLock

	@object_type = 'video-game'

	constructor: (@position, @size, @owner, @pk, @message, @data) ->
		super(@position, @size, @owner, @pk, @message, false, @data)
		@maskJ.mousedown (event)->
			g.tools['Move'].select()
			return
		@maskJ.mouseup (event)->
			g.previousTool?.select()
			return
		@divJ.addClass("video-game")
		@currentCheckpoint = -1
		@checkpoints = []
		
	getData: ()->
		data = super()
		data.loadEntireArea = true
		return data

	enableInteraction: () ->
		@maskJ.hide()
		return

	initGUI: ()->
		console.log "Gui init"
		return

	updateGame: (tool)->
		for checkpoint in @checkpoints
			if checkpoint.contains(tool.car.position)
				if @currentCheckpoint == checkpoint.data.checkpointNumber-1
					@currentCheckpoint = checkpoint.data.checkpointNumber
					if @currentCheckpoint == 0
						@startTime = Date.now()
						romanesco_alert "Game started, go go go!", "success"
					else	
						romanesco_alert "Checkpoint " + @currentCheckpoint + " passed!", "success"
				if @currentCheckpoint == @checkpoints.length-1
					@finishGame()
		return

	finishGame: ()->
		time = (Date.now() - @startTime)/1000
		romanesco_alert "You won ! Your time is: " + time.toFixed(2) + " seconds.", "success"
		@currentCheckpoint = -1
		return

@RVideoGame = RVideoGame

# todo: make the link enabled even with the move tool?
class RLink extends RLock

	@modalTitle = "Insert a hyperlink"
	@modalTitleUpdate = "Modify your link"
	@object_type = 'link'

	@parameters: ()->
		parameters = super()
		delete parameters['Lock']
		return parameters

	constructor: (@position, @size, @owner, @pk, @message, @name, @url, @data) ->
		super(@position, @size, @owner, @pk, @message, false, @data)
		@divJ.addClass("link")
		@setPopover()
		@linkJ = $('<a href="' + @url + '"></a>')
		@contentJ.append(@linkJ)

	setPopover: ()->
		popoverOptions = { placement:'auto top', trigger:'hover' }

		if @message? and @message.length>0
			popoverOptions.content = @message
			if @name? and @name.length>0
				popoverOptions.title = @name
		else if @name? and @name.length>0
			popoverOptions.content = @name

		@contentJ.popover(popoverOptions)
		@contentJ.addClass("link-content")
		@popover = @contentJ.data('bs.popover')

	update: () ->
		@contentJ.attr('data-title', @name)
		@contentJ.attr('data-content', @message)
		@linkJ.attr("href", @url)
		super()

	updateBackgroundMode: (value)->
		return

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@setPopover()
	# 	@linkJ.attr("href", @url)

@RLink = RLink

class RText extends RDiv

	@modalTitle = "Insert some text"
	@modalTitleUpdate = "Modify your text"
	@object_type = 'text'

	@parameters: ()->

		parameters = super()

		parameters['Font'] =
			fontName:
				type: 'input-typeahead'
				label: 'Font name'
				default: ''
				initializeController: (controller, item)->
					typeaheadJ = $(controller.domElement)
					input = typeaheadJ.find("input")
					inputValue = null
					
					input.typeahead(
						{ hint: true, highlight: true, minLength: 1 }, 
						{ valueKey: 'value', displayKey: 'value', source: g.typeaheadFontEngine.ttAdapter() }
					)

					input.on 'typeahead:opened', ()->
						dropDown = typeaheadJ.find(".tt-dropdown-menu")
						dropDown.insertAfter(typeaheadJ.parents('.cr:first'))
						dropDown.css(position: 'relative', display: 'inline-block', right:0)
						return

					input.on 'typeahead:closed', ()->
						if inputValue?
							input.val(inputValue)
						else
							inputValue = input.val()
						for item in g.selectedItems()
							item.setFontFamily?(inputValue) 	# not necessarly an RText
						return

					input.on 'typeahead:cursorchanged', ()->
						inputValue = input.val()
						return

					input.on 'typeahead:selected', ()->
						inputValue = input.val()
						return

					input.on 'typeahead:autocompleted', ()->
						inputValue = input.val()
						return
					
					if item?.data.fontFamily?
						input.val(item.data.fontFamily)
					
					return
			effect:
				type: 'dropdown'
				label: 'Effect'
				values: ['none', 'anaglyph', 'brick-sign', 'canvas-print', 'crackle', 'decaying', 'destruction', 'distressed', 'distressed-wood', 'fire', 'fragile', 'grass', 'ice', 'mitosis', 'neon', 'outline', 'puttinggreen', 'scuffed-steel', 'shadow-multiple', 'static', 'stonewash', '3d', '3d-float', 'vintage', 'wallpaper']
				default: 'none'
			styles: 
				type: 'button-group'
				label: 'Styles'
				value: ''
				setValue: (value, item)->
					fontStyleJ = $("#fontStyle:first")
					if item?.data.fontStyle?
						if item.data.fontStyle.italic then fontStyleJ.find("[name='italic']").addClass("active")
						if item.data.fontStyle.bold then fontStyleJ.find("[name='bold']").addClass("active")
						if item.data.fontStyle.decoration?.indexOf('underline')>=0 then fontStyleJ.find("[name='underline']").addClass("active")
						if item.data.fontStyle.decoration?.indexOf('overline')>=0 then fontStyleJ.find("[name='overline']").addClass("active")
						if item.data.fontStyle.decoration?.indexOf('line-through')>=0 then fontStyleJ.find("[name='line-through']").addClass("active")
				initializeController: (controller, item)->
					$(controller.domElement).find('input').remove()

					setStyles = (value)->
						for item in g.selectedItems()
							item.changeFontStyle?(value)
						return

					# todo: change fontStyle id to class
					g.templatesJ.find("#fontStyle").clone().appendTo(controller.domElement)
					fontStyleJ = $("#fontStyle:first")
					fontStyleJ.find("[name='italic']").click( (event)-> setStyles('italic') )
					fontStyleJ.find("[name='bold']").click( (event)-> setStyles('bold') )
					fontStyleJ.find("[name='underline']").click( (event)-> setStyles('underline') )
					fontStyleJ.find("[name='overline']").click( (event)-> setStyles('overline') )
					fontStyleJ.find("[name='line-through']").click( (event)-> setStyles('line-through') )

					controller.rSetValue(item)
					return
			align:
				type: 'radio-button-group'
				label: 'Align'
				value: ''
				initializeController: (controller, item)->
					$(controller.domElement).find('input').remove()

					setStyles = (value)->
						for item in g.selectedItems()
							item.changeFontStyle?(value)
						return
					
					g.templatesJ.find("#textAlign").clone().appendTo(controller.domElement)
					textAlignJ = $("#textAlign:first")
					textAlignJ.find(".justify").click( (event)-> setStyles('justify') )
					textAlignJ.find(".align-left").click( (event)-> setStyles('left') )
					textAlignJ.find(".align-center").click( (event)-> setStyles('center') )
					textAlignJ.find(".align-right").click( (event)-> setStyles('right') )
					return
			fontSize:
				type: 'slider'
				label: 'Font size'
				min: 5
				max: 300
				default: 11
			fontColor:
				type: 'color'
				label: 'Color'
				default: 'black'
				defaultCheck: true 					# checked/activated by default or not

		return parameters

	@initFields: ()->
		@modalJ.find('.url-name-group').hide()
		@modalJ.find('.name-group').hide()
		@modalJ.find('.url-group').hide()
		@modalJ.find('.message-group').show()
		@modalJ.find('#divModalTypeSelector').hide()
		@modalJ.find('.checkbox.restrict-area').hide()
		@modalJ.find('.checkbox.disable-toolbar').hide()

	@initModal: (rectangle=null, div=null)->
		super(@object_type, rectangle, div)

	# @save: (rectangle)->
	# 	super(rectangle, @object_type)

	constructor: (@position, @size, @owner, @pk, @locked, @message='', @data) ->
		super(@position, @size, @owner, @pk, @locked and @owner != g.me, @data)

		@contentJ = $("<textarea></textarea>")
		@contentJ.insertBefore(@maskJ)
		@contentJ.val(@message)
		
		lockedForMe = @owner != g.me and @locked

		if lockedForMe
			# @contentJ.attr("readonly", "true")
			message = @message
			@contentJ[0].addEventListener("input", (()-> this.value = message), false)
    
		
		@setCss()

		@contentJ.focus( () -> $(this).addClass("selected form-control") )
		@contentJ.blur( () -> $(this).removeClass("selected form-control") )
		# @contentJ.focus()

		if not lockedForMe
			@contentJ.bind('input propertychange', (event) => @textChanged(event) )

		if @data? and Object.keys(@data).length>0
			@setFont(false)

	textChanged: (event) =>
		@message = @contentJ.val()
		g.chatSocket.emit( "parameter change", g.me, @pk, "message", @message)
		g.defferedExecution(@update, @pk, 1000)
		
	setFontFamily: (fontFamily, update=true)->
		if not fontFamily? then return

		# check font validity
		available = false
		for item in g.availableFonts
			if item.family == fontFamily
				available = true
				break
		if not available then return

		@data.fontFamily = fontFamily

		g.addFont(fontFamily, @data.effect)
		g.loadFonts()

		@contentJ.css( "font-family": "'" + fontFamily + "', 'Helvetica Neue', Helvetica, Arial, sans-serif")
		
		if update
			@update()
			g.chatSocket.emit( "parameter change", g.me, @pk, "fontFamily", @data.fontFamily)
		
		return

	# only called when user modifies GUI
	changeFontStyle: (value)=>

		if not value? then return
		
		if typeof(value) != 'string'
			return
		
		@data.fontStyle ?= {}
		@data.fontStyle.decoration ?=  ''

		switch value
			when 'underline'
				if @data.fontStyle.decoration.indexOf(' underline')>=0 
					@data.fontStyle.decoration = @data.fontStyle.decoration.replace(' underline', '') 
				else
					@data.fontStyle.decoration += ' underline'
			when 'overline'
				if @data.fontStyle.decoration.indexOf(' overline')>=0 
					@data.fontStyle.decoration = @data.fontStyle.decoration.replace(' overline', '') 
				else
					@data.fontStyle.decoration += ' overline'
			when 'line-through'
				if @data.fontStyle.decoration.indexOf(' line-through')>=0 
					@data.fontStyle.decoration = @data.fontStyle.decoration.replace(' line-through', '') 
				else
					@data.fontStyle.decoration += ' line-through'
			when 'italic'
				@data.fontStyle.italic = !@data.fontStyle.italic
			when 'bold'
				@data.fontStyle.bold = !@data.fontStyle.bold
			when 'justify', 'left', 'right', 'center'
				@data.fontStyle.align = value

		# only called when user modifies GUI
		@setFontStyle(true)
		g.chatSocket.emit( "parameter change", g.me, @pk, "fontStyle", @data.fontStyle)

	setFontStyle: (update=true)->
		if @data.fontStyle?.italic?
			@contentJ.css( "font-style": if @data.fontStyle.italic then "italic" else "normal")
		if @data.fontStyle?.bold?
			@contentJ.css( "font-weight": if @data.fontStyle.bold then "bold" else "normal")
		if @data.fontStyle?.decoration?
			@contentJ.css( "text-decoration": @data.fontStyle.decoration)
		if @data.fontStyle?.align?
			@contentJ.css( "text-align": @data.fontStyle.align)
		if update
			@update()
		return

	setFontSize: (fontSize, update=true)->
		if not fontSize? then return
		@data.fontSize = fontSize
		@contentJ.css( "font-size": fontSize+"px")
		if update
			@update()
		return

	setFontEffect: (fontEffect, update=true)->
		if not fontEffect? then return

		g.addFont(@data.fontFamily, fontEffect)

		i = @contentJ[0].classList.length-1
		while i>=0
			className = @contentJ[0].classList[i]
			if className.indexOf("font-effect-")>=0
				@contentJ.removeClass(className)
			i--

		g.loadFonts()
		
		@contentJ.addClass( "font-effect-" + fontEffect)
		if update
			@update()
		return

	setFontColor: (fontColor, update=true)->
		@contentJ.css( "color": fontColor ? 'black')
		return

	setFont: (update=true)->
		@setFontStyle(update)
		@setFontFamily(@data.fontFamily, update)
		@setFontSize(@data.fontSize, update)
		@setFontEffect(@data.effect, update)
		@setFontColor(@data.fontColor, update)
	
	# update = false when called by parameter.onChange from websocket
	parameterChanged: (update=true)->
		if not update and @data.message?
			@contentJ.val(@data.message)
		switch @changed
			when 'fontStyle', 'fontFamily', 'fontSize', 'effect', 'fontColor'
				@setFont(false)
			else
				@setFont(false)
		super(update)

	getData: ()->
		data = jQuery.extend({},@data)
		delete data.message
		return data

	delete: () ->
		if @contentJ.hasClass("selected")
			return
		super()

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@contentJ.val(@message)

@RText = RText

# todo: remove @url? duplicated in @data.url or remove data.url
# todo: websocket the url change
class RMedia extends RDiv

	@modalTitle = "Insert a media"
	@modalTitleUpdate = "Modify your media"
	@object_type = 'media'

	@parameters: ()->

		parameters = super()

		parameters['Media'] =
			url:
				type: 'input'
				label: 'URL'
				default: 'http://'
				onChange: ()-> RMedia.selectedDivs = g.selectedDivs 	# onFinishChange is called on blur (focus out), it is a problem when user selects url input
																	# in the sidebar and then select another RMedia 
																	# (since it would call urlChanged on the newly selected RMedia since blur and g.selectedDiv is new)
				onFinishChange: (value)-> selectedDiv?.urlChanged(value, true) for selectedDiv in RMedia.selectedDivs
			fitImage:
				type: 'checkbox'
				label: 'Fit image'
				default: false

		return parameters

	@initFields: ()->
		@modalJ.find('.url-name-group').hide()
		@modalJ.find('.name-group').hide()
		@modalJ.find('.url-group').show()
		@modalJ.find('.message-group').hide()
		@modalJ.find('#divModalTypeSelector').hide()
		@modalJ.find('.checkbox.restrict-area').hide()
		@modalJ.find('.checkbox.disable-toolbar').hide()

	@initModal: (rectangle=null, div=null)->
		super(@object_type, rectangle, div)

	constructor: (@position, @size, @owner, @pk, @locked, @url='', @data) ->
		super(@position, @size, @owner, @pk, @locked and @owner != g.me, @data)
		@data.url = @url
		if url? and url.length>0
			@urlChanged(@url, false)
		@sizeChanged = false

	resize: (event, userAction=true) =>
		super(event, userAction)
		if @isImage?
			return
		@sizeChanged = true
		width = @divJ.width()
		height = @divJ.height()
		@contentJ?.find("iframe").attr("width",width).attr("height",height)

	dragFinished: (userAction=true) =>
		if @sizeChanged
			@urlChanged(@url, false)
		@sizeChanged = false
		super(userAction)

	# update: () ->
	# 	@urlChanged(@url, false) # todo: <- chek if necessary
	# 	super()

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@urlChanged(@url, false)

	toggleFitImage: ()->
		if @isImage?
			@contentJ.toggleClass("fit-image", @data.fitImage)

	# update = false when called by parameter.onChange from websocket
	parameterChanged: (update=true)->
		switch @changed
			when 'fitImage'
				@toggleFitImage()
		super(update)

	hasImageUrlExt: (url)->
		exts = [ "jpeg", "jpg", "gif", "png" ]
		ext = url.substring(url.lastIndexOf(".")+1)
		if ext in exts
			return true
		return false

	checkIsImage: ()->
		timedOut = false
		timeout = if @hasImageUrlExt(@url) then 5000 else 1000
		image = new Image()
		timer = setTimeout(()=>
			timedOut = true
			@loadMedia("timeout")
			return
		, timeout)
		image.onerror = image.onabort = ()=>
			if not timedOut
				clearTimeout(timer)
				@loadMedia('error')
		image.onload = ()=>
			if not timedOut
				clearTimeout(timer)
			else
				@contentJ?.remove()
			@loadMedia('success')
		image.src = @url

	loadMedia: (imageLoadResult)=>
		if imageLoadResult == 'success'
			@contentJ = $('<img class="content image" src="'+@url+'" alt="'+@url+'"">')
			@contentJ.mousedown( (event) -> event.preventDefault() )
			@isImage = true
		else
			# @contentJ = $(@url.replace("http://", ""))
			@contentJ = $(@url.substring(7))
			if @contentJ.is('iframe')
				@contentJ.attr('width', @divJ.width())
				@contentJ.attr('height', @divJ.height())
			else
				@contentJ = $('<div class="content oembedall-container"></div>')
				@contentJ.oembed(@url, { includeHandle: false, embedMethod: 'fill', maxWidth: @divJ.width(), maxHeight: @divJ.height(), afterEmbed: @afterEmbed })
		@contentJ.insertBefore(@maskJ)

		@setCss()

	# todo: called too many times when div is resized
	# maybe it was because update called urlChanged:
	urlChanged: (url, updateDiv=false) =>
		console.log 'urlChanged, updateDiv: ' + updateDiv + ', ' + @pk
		@url = url

		if @contentJ?
			@contentJ.remove()
			$("#jqoembeddata").remove()

		@checkIsImage()

		# websocket urlchange
		if updateDiv
			if g.me? and datFolder.name != 'General' then g.chatSocket.emit( "parameter change", g.me, item.pk, name, value )
			@update()

	afterEmbed: ()=>
		width = @divJ.width()
		height = @divJ.height()
		@contentJ?.find("iframe").attr("width",width).attr("height",height)


	getData: ()->
		data = jQuery.extend({}, @data)
		delete data.url
		return data

@RMedia = RMedia
