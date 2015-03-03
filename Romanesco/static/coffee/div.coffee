# todo: change ownership through websocket?
# todo: change lock/link popover to romanesco alert?

# RDiv is a div on top of the canvas (i.e. on top of the paper.js project) which can be resized, unless it is locked
# it is lock if it is owned by another user
#
# There are different RDivs, with different content:
# - RLocks (RLock, RLink, RWebsite and RVideoGame): @see RLock
#     they define areas which can only be modified by a single user (the on who created the RLock); all RItems in the area is the property of this user
# - RText: a textarea to write some text. The text can have any google font, any effect, but the whole text has the same formating.
# - RMedia: an image, video or any content inside an iframe (can be a [shadertoy](https://www.shadertoy.com/))
# - RSelectionRectangle: a special div just to defined a selection rectangle, user by {ScreenshotTool}
#
class RDiv extends RItem

	@zIndexMin = 1
	@zIndexMax = 100000
	@dateMin = 1425044061386

	# once the user made the selection rectangle, a modal window ask the user to enter additional information to create the RDiv
	# (RText and RSelectionRectangle do not require additional information)
	@rname = 'RDiv'
	@modalTitle = '' 						# the title of the modal window
	@modalTitleUpdate = '' 					# the title of the modal window when the RDiv is being modified (not used anymore at the moment)
	@object_type = 'div' 					# string describing the type of RDiv (can be 'lock', 'link', 'website', 'video-game', 'text', 'media')
	@modalJ = $('#divModal') 				# initialize the modal jQuery element
	@modalJ.on('shown.bs.modal', (event)=> @modalJ.find('input.form-control:visible:first').focus() ) 	# focus on the first visible element when the modal shows up
	@modalJ.find('.submit-shortcut').keypress( (event) => 				# submit modal when enter is pressed
		if event.which == 13 	# enter key
			event.preventDefault()
			@modalSubmit()
	)
	@modalJ.find('.btn-primary').click( (event)=> @modalSubmit() ) 		# submit modal when click submit button

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
				# ajaxPost '/saveDiv', { 'box': g.boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'url': url, 'clonePk': clonePk }, @save_callback
				Dajaxice.draw.saveDiv( @save_callback, { 'box': g.boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'url': url, 'clonePk': clonePk, 'bounds': rectangle, 'date': Date.now() } )
			else
				# ajaxPost '/saveBox', { 'box': g.boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url, 'clonePk': clonePk, 'website': website, 'restrictedArea': restrictedArea, 'disableToolbar': disableToolbar }, @save_callback
				Dajaxice.draw.saveBox( @save_callback, { 'box': g.boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url, 'clonePk': clonePk, 'website': website, 'restrictedArea': restrictedArea, 'disableToolbar': disableToolbar, 'bounds': rectangle } )

		# if object_type == 'text' or object_type == 'media'
		# 	Dajaxice.draw.saveDiv( @save_callback, { 'box': g.boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'url': url, 'clonePk': clonePk } )
		# else if object_type == 'lock' or object_type == 'link'
		# 	Dajaxice.draw.saveBox( @save_callback, { 'box': g.boxFromRectangle(rectangle), 'object_type': object_type, 'message': message, 'name': name, 'url': url, 'clonePk': clonePk, 'website': website, 'restrictedArea': restrictedArea, 'disableToolbar': disableToolbar } )
		return

	# save callback: check for errors and create div if success
	# usually called be the server, but can be called by websocket (when transfering RDiv creation to other users)
	# @param result [Object] the data returned by the server
	# @param owner [Boolean] whether the user created the RDiv or it is recieved from websocket
	@save_callback: (result, owner=true)=>
		
		if not g.checkError(result)
			return

		tl = g.posOnPlanetToProject(result.box.tl, result.box.planet)
		br = g.posOnPlanetToProject(result.box.br, result.box.planet)

		div = null

		switch result.object_type
			when 'text'
				div = new RText(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.locked, result.message, result.data, result.date)
			when 'media'
				div = new RMedia(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.locked, result.url, result.data, result.date)
			when 'lock'
				div = new RLock(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, true, result.data)
			when 'website'
				div = new RWebsite(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, result.data)
			when 'video-game'
				div = new RVideoGame(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, result.data)
			when 'link'
				div = new RLink(tl, new Size(br.subtract(tl)), result.owner, result.pk, result.message, result.name, result.url, result.data)

		# if we cloned the div: copy data from original div
		if div.constructor.clonedItemData
			# div.data = jQuery.extend({}, @clonedItemData)
			# data = g.items[result.clonePk].data
			# div.data = jQuery.extend({}, data)
			for name, value of div.constructor.clonedItemData
				div.changeParameter(name, value)
			div.constructor.clonedItemData = null
			g.deselectAll()
			div.select()
			div.constructor.duplicateCommand?[result.clonePk]?.setDiv(div)
		else
			g.commandManager.add(new CreateDivCommand(div))

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
		if url.length>0 && url.indexOf("http://") != 0 && url.indexOf("https://") != 0 && url.indexOf("data:") != 0
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

	# test if the box overlaps two planets
	# @param box [Paper Rectangle] the box to test
	# @return [Boolean] true if the box overlaps two planets, false otherwise
	@boxOverlapsTwoPlanets: (box) ->
		limit = getLimit()
		if ( box.left < limit.x && box.right > limit.x ) || ( box.top < limit.y && box.bottom > limit.y )
			romanesco_alert("You can not add anything in between two planets, this is not yet supported.", "info")
			return true
		return false

	# common to all RItems
	# construct a new RDiv based on the parameters and save it
	@duplicate: (bounds, object_type, message, name, url, pk, data)->
		@clonedItemData = data
		@save(bounds, object_type, message, name, url, pk)
		return

	@updateZIndex: (sortedDivs)->
		for div, i in sortedDivs
			div.divJ.css( 'z-index': i )
		return

	# add the div jQuery element (@divJ) on top of the canvas and intialize it
	# initialize @data
	# @param position [Paper Point] the position of the div
	# @param size [Paper Size] the size of the div
	# @param owner [String] the username of the owner of the div
	# @param pk [ID] the primary key of the div
	# @param locked [Boolean] (optional) whether the div is locked by an RLock
	# @param data [Object] the data of the div (containing the stroke width, colors, etc.)
	# @param date [Number] the date of the div (used as zindex)
	constructor: (@position, @size, @owner, @pk, locked=false, @data, @date) ->
		super(g.divList, g.sortedDivs)
		@controller = this
		@object_type = @constructor.object_type

		# initialize @divJ: main jQuery element of the div
		separatorJ = g.stageJ.find("." + @object_type + "-separator")
		@divJ = g.templatesJ.find(".custom-div").clone().insertAfter(separatorJ)
		@maskJ = @divJ.find(".mask")

		if not @data? # creation of a new object by the user: set @data to g.gui values
			@data = new Object()
			for name, folder of g.gui.__folders
				if name=='General' then continue
				for controller in folder.__controllers
					@data[controller.property] = controller.rValue()

		# update size and position
		@rectangle = new Rectangle(@position, @size)

		@divJ.css(width: @size.width, height: @size.height)

		if @date and not RLock.prototype.isPrototypeOf(@) then @updateZIndex()
		@updateTransform(false)

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
	duplicate: (bounds=null, object_type=@object_type, message=@message, name=@name, url=@url, pk=@pk, data=null)->
		bounds ?= @getBounds()
		@constructor.duplicate(bounds, object_type, message, name, url, pk, data)
		return

	# common to all RItems
	# construct a new RDiv and save it
	# @return [RDiv] the copy
	duplicateCommand: ()->
		g.commandManager.add(new CreateDivCommand(@, "Duplicate div", true))
		return

	# open modal window to modify RDiv information (not used anymore)
	modify: () ->
		@constructor.initModal(@getBounds(), @)
		return

	setRectangle: (rectangle)->
		super(rectangle, false)
		@position = @rectangle.topLeft
		@size = @rectangle.size
		@updateTransform(true)
		return

	setRotation: (rotation)->
		super(rotation, false)
		@position = @rectangle.topLeft
		@size = @rectangle.size
		@updateTransform(true)
		return

	# updateTransform: ()->
	# 	css = 'translate(' + (@position.x * g.view.zoom) + 'px,' + (@position.y * g.view.zoom) + 'px) scale(' + g.view.zoom + ')'
	# 	@divJ.css( 'transform': css )

	# update the scale and position of the RDiv (depending on its position and scale, and the view position and scale)
	# if zoom equals 1, do no use css translate() property to avoid blurry text
	# @param update [Boolean] (optional) whether update is required
	updateTransform: (update=true)->
		# the css of the div in styles.less: transform-origin: 0% 0% 0

		viewPos = view.projectToView(@position)
		# viewPos = new Point( -g.offset.x + @position.x, -g.offset.y + @position.y )
		if view.zoom == 1 and ( @rotation == 0 or not @rotation? )
			@divJ.css( 'left': viewPos.x, 'top': viewPos.y, 'transform': 'none' )
		else
			sizeScaled = @size.multiply(view.zoom)
			translation = viewPos.add(sizeScaled.divide(2))
			css = 'translate(' + translation.x + 'px,' + translation.y + 'px)'
			css += 'translate(-50%, -50%)'
			css += ' scale(' + view.zoom + ')'
			if @rotation then css += ' rotate(' + @rotation + 'deg)'

			@divJ.css( 'transform': css, 'top': 0, 'left': 0, 'transform-origin': '50% 50%' )

			# css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
			# css += ' scale(' + view.zoom + ')'

			# @divJ.css( 'transform': css, 'top': 0, 'left': 0 )

		if update
			g.defferedExecution(@update, @getPk())
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
	# getBounds: ()->
	# 	return new Rectangle(@position.x, @position.y, @divJ.outerWidth(), @divJ.outerHeight())

	# common to all RItems
	# return [Point] the position of the center of the RDiv
	getPosition: ()->
		return @position.add(@size.multiply(0.5))

	# common to all RItems
	# return [PK] the primary key of the div
	getPk: ()->
		return @pk

	# insert above given *div*
	# @param div [RDiv] div on which to insert this
	# @param index [Number] the index at which to add the div in g.sortedDivs
	insertAbove: (div, index=null, update=false)->
		super(div, index, update)
		if not index then @constructor.updateZIndex(@sortedItems)
		return

	# insert below given *div*
	# @param div [RDiv] div under which to insert this
	# @param index [Number] the index at which to add the div in g.sortedDivs
	insertBelow: (div, index=null, update=false)->
		super(div, index, update)
		if not index then @constructor.updateZIndex(@sortedItems)
		return

	# deprecated
	# common to all RItems
	# @return [Array<{x: x, y: y}>] the list of areas on which the item lies
	# getAreas: ()->
	# 	bounds = @getBounds()
	# 	t = Math.floor(bounds.top / g.scale)
	# 	l = Math.floor(bounds.left / g.scale)
	# 	b = Math.floor(bounds.bottom / g.scale)
	# 	r = Math.floor(bounds.right / g.scale)
	# 	areas = {}
	# 	for x in [l .. r]
	# 		for y in [t .. b]
	# 			areas[x] ?= {}
	# 			areas[x][y] = true
	# 	return areas

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

	moveByCommand: (delta)->
		@moveToCommand(@getPosition().add(delta))
		return

	moveToCommand: (position, previousPosition=null, execute=true)->
		g.commandManager.add(new MoveCommand(@, position, previousPosition, execute))
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

	# # common to all RItems
	# # called when user press mouse while on the div (the event listener is set in the constructor, after @divJ is added in top of the canvas)
	# # (could be called by websocket, this functionnality is disabled for now)
	# # - select the div if *userAction* and the div is not selected yet
	# # - if target is handle: prepare to resize the div
	# # - if tagret if textarea: do nothing
	# # - otherwise: prepare to move the div
	# # @param event [Paper Event] the mouse event
	# # @param userAction [Boolean] whether this is an action from *g.me* or another user 
	# selectBegin: (event, userAction=true) =>
	# 	# return if user used the middle mouse button (mouse wheel button, event.which == 2) to drag the stage instead of the div
	# 	if userAction and ( g.selectedTool.name == 'Move' or event.which == 2 )
	# 		return

	# 	@dragging = false
	# 	@draggedHandleJ = null

	# 	if userAction and g.selectedDivs.indexOf(@)<0 	# select the div if *userAction* and the div is not selected yet
	# 		if not event.shiftKey then g.deselectAll()
	# 		@select()

	# 	point = if userAction then new Point(event.pageX, event.pageY) else view.projectToView(event.point)
	# 	@mouseDownPosition = point

	# 	targetJ = if userAction then $(event.target) else @divJ.find(event.target)

	# 	if targetJ.is("textarea")
	# 		@selectingText = true
	# 		return true

	# 	@dragging = true

	# 	# pos will be used with event.page, must be defined in screen coordinates
	# 	pos = @posOnScreen()

	# 	if targetJ.hasClass("handle")
	# 		@draggedHandleJ = targetJ
	# 		pos.x += @draggedHandleJ.position().left
	# 		pos.y += @draggedHandleJ.position().top

	# 	@dragOffset = {}
	# 	@dragOffset.x = point.x-pos.x
	# 	@dragOffset.y = point.y-pos.y

	# 	@changed = null

	# 	if targetJ.hasClass("handle")			
	# 		@selectCommand = new ResizeDivCommand(@)
	# 	else
	# 		@selectCommand = new MoveCommand(@, null, null, false)
	# 	# if g.me? and userAction then g.chatSocket.emit( "select begin", g.me, @pk, g.eventToObject(event))
	# 	return

	# # common to all RItems
	# # called by main.coffee, when mousemove on window
	# # move, resize or drag the div, depending on how the select action was initialized
	# # @param event [Paper Event] the mouse event
	# # @param userAction [Boolean] whether this is an action from *g.me* or another user 
	# selectUpdate: (event, userAction=true) =>
	# 	if @selectingText then return

	# 	if not @dragging
	# 		event.delta.multiply(1/view.zoom)
	# 		if event.delta? then @moveBy(event.delta) 	# hack to move the div when dragging a selection group
	# 		return true
	# 	if @draggedHandleJ
	# 		@resize(event, userAction)
	# 		@changed = 'resize'
	# 	else
	# 		@drag(event, userAction)
	# 		@changed = 'moved'

	# 	# if g.me? and userAction then g.chatSocket.emit( "select update", g.me, @pk, g.eventToObject(event))
	# 	return

	# # common to all RItems
	# # called by main.coffee, when mouseup on window
	# # ends the select actions
	# # @param event [Paper Event] the mouse event
	# # @param userAction [Boolean] whether this is an action from *g.me* or another user 
	# selectEnd: (event, userAction=true) =>

	# 	if @changed?
	# 		@selectCommand.update()
	# 		g.commandManager.add(@selectCommand)
	# 	else
	# 		@selectCommand = null

	# 	if not @dragging
	# 		if @selectingText then @selectingText = false
	# 		if event.delta?
	# 			@moveBy(event.delta) 	# hack to move the div when dragging a selection group
	# 		return true
		
	# 	@dragging = false
	# 	@draggedHandleJ = null

	# 	# if g.me? and userAction then g.chatSocket.emit( "select end", g.me, @pk, g.eventToObject(event))
	# 	return

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

	# resize the div to fit *position* and *size*
	# @param position [Paper Point] the new position
	# @param size [Paper Size] the new size
	resizeTo: (@position, @size)->
		@updateTransform()
		@divJ.css( width: @size.width, height: @size.height )
		@divJ.find(".handle").css( 'z-index': 10)
		return

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
		@resizeTo(new Point(newLeft, newTop), new Size(g.snap1D(newWidth), g.snap1D(newHeight)))
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

	changeParameterCommand: (name, value)->
		if @data[name] == value then return
		@parameterChangeCommand ?= new ChangeParameterCommand(@, name)
		@changeParameter(name, value)
		g.defferedExecution(@addChangeParameterCommand, @getPk() + "change parameter: " + name)
		return
	
	addChangeParameterCommand: ()=>
		@parameterChangeCommand.update()
		g.commandManager.add(@parameterChangeCommand)
		@parameterChangeCommand = null
		return

	# common to all RItems
	# called when a parameter is changed:
	# - from user action (parameter.onChange) (userAction = true)
	# - from websocket (another user changed the parameter) (userAction = false)
	# @param name [String] the name of the value to change
	# @param value [Anything] the new value
	# @param userAction [Boolean] (optional, default is true) whether to update the RPath in database
	changeParameter: (name, value, userAction=true)->
		@data[name] = value
		@changed = name
		switch name
			when 'strokeWidth', 'strokeColor', 'fillColor'
				@setCss()
		if userAction then g.defferedExecution(@update, @getPk())
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
	update: (type) =>
		tl = @position
		br = @bottomRight()
		
		# check if position is valid
		if @constructor.boxOverlapsTwoPlanets(tl,br)
			return
		
		# initialize data to be saved
		if type == "z-index"
			data = date: @date, pk: @pk
		else
			data = 
				box: g.boxFromRectangle(new Rectangle(tl,br))
				pk: @pk
				object_type: @object_type
				message: @message
				url: @url
				data: @getStringifiedData()
				bounds: @getBounds()

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
		super()
		g.selectedDivs.push(@)
		g.s = @
		if g.selectedTool != g.tools['Select'] then g.tools['Select'].select()
		@divJ.addClass("selected")

		g.updateParameters( { tool: @constructor, item: @ }, true)
		return

	# common to all RItems
	# deselect the div
	deselect: () =>
		if not @divJ.hasClass("selected") then return
		super()
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
		super()
		return

	deleteCommand: ()->
		g.commandManager.add(new DeleteDivCommand(@))
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
	@rname = 'Selection rectangle'
	@object_type = 'lock'

	# create the div and add a "Take snapshot" button
	constructor: (@rectangle, handler) ->
		g.tools['Select'].select()
		super(rectangle.topLeft, rectangle.size.multiply(1*view.zoom))
		@divJ.addClass("selection-rectangle")
		@buttonJ = $("<button>")
		@buttonJ.text("Take snapshot")
		@buttonJ.click( (event)-> handler() )
		@divJ.append(@buttonJ)
		@select()
		return

	# update the div transformation, without taking the zoom into account
	# updateTransform: ()->
	# 	viewPos = view.projectToView(@position)
	# 	css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)'
	# 	@divJ.css( 'transform': css )
	# 	return

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

# There are different RLocks:
# - RLock: a simple RLock which just locks the area and the items underneath, and displays a popover with a message when the user clicks on it
# - RLink: extends RLock but works as a link: the one who clicks on it is redirected to the website
# - RWebsite:
#    - extends RLock and provide the author a special website adresse 
#    - the owner of the site can choose a few options: "restrict area" and "hide toolbar"
#    - a user going to a site with the "restricted area" option can not go outside the area
#    - the tool bar will be hidden to users navigating to site with the "hide toolbar" option
# - RVideogame:
#    - a video game is an area which can interact with other RItems (very experimental)
#    - video games are always loaded entirely (the whole area is loaded at once with its items)

# an RLock can be set in background mode ({RLock#updateBackgroundMode}):
# - this hide the jQuery div and display a equivalent rectangle on the paper project instead (named controlPath in the code)
# - it is usefull to add and edit items on the area
#

class RLock extends RDiv
	@rname = 'Lock'

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
				@modalJ.find('.url-group label').text("URL")
				@modalJ.find('.url-group input').attr("placeholder", "http://")
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
				@modalJ.find('.name-group').hide()
				@modalJ.find('.url-group').hide()
				@modalJ.find('.message-group').show()
				cost = 2*area/1000
		if g.credit<cost
			g.romanesco_alert("You do not have enough romanescoins to add this link", "error")
		else
			@modalJ.find('p.cost').text("" + area + " pixels = " + cost.toFixed(2) + " romanescoins")
		return

	# @param point [Paper point] the point to test
	# @return [PK] the primary key of the intersecting lock or null
	@intersectPoint: (point)->
		for lock in g.locks
			if lock.getBounds().contains(point) and g.me != lock.owner
				return lock.pk
		return null

	# @param rectangle [Paper Rectangle] the rectangle to test
	# @return [PK] the primary key of the intersecting lock or null
	@intersectRect: (rectangle)->
		for lock in g.locks
			if lock.getBounds().intersects(new Rectangle(rectangle)) and g.me != lock.owner
				return lock.pk
		return null

	# initialize modal with object_type
	@initModal: (rectangle=null, div=null)->
		super(@object_type, rectangle, div)
		return

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

		# if @owner==g.me then @updateBackgroundMode(true)
		
		g.locks.push(@)

		@group = new Group()
		@group.name = 'lock group'
		
		# create special list to contains children paths
		@sortedPaths = []
		@pathList = $("""<ul class="rPaths romanesco-ui rPath-list"></ul>""")
		@hrJ = $("<hr>")
		@hrJ.insertAfter(g.divList)
		@pathList.insertAfter(@hrJ)

		return

	# overload {RDiv#drag}
	# hide popover on drag
	drag: (event, userAction=true) =>
		super(event, userAction)
		if not $(event.target).hasClass('lock-content')
			@contentJ?.popover('hide')
		return

	# overload {RDiv#resize}
	# hide popover on resize
	resize: (event, userAction=true) =>
		super(event, userAction)
		@contentJ?.popover('hide')

	# overload {RDiv#select}
	# can not select a lock which the user does not own
	select: () =>
		if @owner != g.me then return
		super()
		return

	# overload {RDiv#deselect}
	# put lock to background mode
	deselect: () =>
		@contentJ?.popover('hide')
		# @updateBackgroundMode(true)
		super()

	# overload {RDiv#remove} and remove lock from g.locks
	remove: () ->
		g.locks.splice(g.locks.indexOf(@),1)
		super()
		@controlPath?.remove()
		@controlPath = null
		return

	# overload {RDiv#remove} and hide the popover
	delete: () ->
		@contentJ?.popover('hide')
		super()
		return

	# overload {RDiv#update}
	update: () ->
		@contentJ.attr('data-content', @message)
		super()
		return

	# overload {RDiv#selectBegin}
	# unset background mode before selecting the lock
	selectBegin: (event, userAction=true) =>
		if userAction and @owner != g.me then return
		if @data.backgroundMode
			@updateBackgroundMode(false)
			@select()
			return
		super(event, userAction)
		return
	
	# overload {RDiv#selectUpdate}
	# do nothing if in background mode
	selectUpdate: (event, userAction=true) =>
		if (userAction and @owner != g.me) or @data.backgroundMode then return
		super(event, userAction)
		return
	
	# overload {RDiv#selectEnd}
	# do nothing if in background mode
	selectEnd: (event, userAction=true) =>
		if (userAction and @owner != g.me) or @data.backgroundMode then return
		super(event, userAction)
		return

	# set/unset background mode
	# - in background mode: hide the jQuery div @divJ and display a equivalent rectangle on the paper project instead (@controlPath)
	# - usefull to add and edit items on the area
	# @param value [Boolean] (optional) whether to set or unset the background mode
	updateBackgroundMode: (value=null)->
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
		return

	# overload {RDiv#changeParameter}
	# update background mode
	changeParameter: (name, value, userAction=true)->
		super(name, value, userAction)
		switch name
			when 'backgroundMode'
				@updateBackgroundMode()
		return

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@contentJ.popover(placement:'auto top', trigger:'click', content: @message)
	# 	@popover = @contentJ.data('bs.popover')
		
@RLock = RLock

# RWebsite:
#  - extends RLock and provide the author a special website adresse 
#  - the owner of the site can choose a few options: "restrict area" and "hide toolbar"
#  - a user going to a site with the "restricted area" option can not go outside the area
#  - the tool bar will be hidden to users navigating to site with the "hide toolbar" option
class RWebsite extends RLock
	@rname = 'Website'
	@object_type = 'website'

	# overload {RDiv#constructor}
	# the mouse interaction is modified to enable user navigation (the user can scroll the view by dragging on the website area)
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
		return

	# todo: remove
	# can not enable interaction if the user not owner and is website
	enableInteraction: () ->
		@maskJ.hide()
		return

@RWebsite = RWebsite

# RVideogame:
# - a video game is an area which can interact with other RItems (very experimental)
# - video games are always loaded entirely (the whole area is loaded at the same time with its items)
# this a default videogame class which must be redefined in custom scripts
class RVideoGame extends RLock
	@rname = 'Video game'
	@object_type = 'video-game'

	# overload {RDiv#constructor}
	# the mouse interaction is modified to enable user navigation (the user can scroll the view by dragging on the videogame area)
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
		return
	
	# overload {RDiv#getData} + set data.loadEntireArea to true (we want videogames to load entirely)
	getData: ()->
		data = super()
		data.loadEntireArea = true
		return data

	# todo: remove
	# redefine {RLock#enableInteraction}
	enableInteraction: () ->
		@maskJ.hide()
		return

	# initialize the video game gui (does nothing for now)
	initGUI: ()->
		console.log "Gui init"
		return

	# update game machanics: 
	# called at each frame (currently by the tool event, but should move to main.coffee in the onFrame event)
	# @param tool [RTool] the car tool to get the car position
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

	# ends the game: called when user passes the last checkpoint!
	finishGame: ()->
		time = (Date.now() - @startTime)/1000
		romanesco_alert "You won ! Your time is: " + time.toFixed(2) + " seconds.", "success"
		@currentCheckpoint = -1
		return

@RVideoGame = RVideoGame

# todo: make the link enabled even with the move tool?
# RLink: extends RLock but works as a link: the one who clicks on it is redirected to the website
class RLink extends RLock
	@rname = 'Link'
	@modalTitle = "Insert a hyperlink"
	@modalTitleUpdate = "Modify your link"
	@object_type = 'link'

	@parameters: ()->
		parameters = super()
		delete parameters['Lock']
		return parameters

	# overload {RLock#constructor}
	# add the link tag with the url
	constructor: (@position, @size, @owner, @pk, @message, @name, @url, @data) ->
		super(@position, @size, @owner, @pk, @message, false, @data)
		@divJ.addClass("link")
		@setPopover()
		@linkJ = $('<a href="' + @url + '"></a>')
		@linkJ.click (event)=>
			if @linkJ.attr("href").indexOf("http://romanesc.co/#") == 0
				location = @linkJ.attr("href").replace("http://romanesc.co/#", "")
				pos = location.split(',')
				p = new Point()
				p.x = parseFloat(pos[0])
				p.y = parseFloat(pos[1])
				g.RMoveTo(p, 1000)
				event.preventDefault()
				return false
			return
		@contentJ.append(@linkJ)
		return

	# set popover for the link
	# called by the constructor
	# the popover displays the site name, and a custom message (the information that the user gives when creating the RLink)
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
		return

	# overload {RLock#update} 
	# also update the name, message and url
	update: () ->
		@contentJ.attr('data-title', @name)
		@contentJ.attr('data-content', @message)
		@linkJ.attr("href", @url)
		super()
		return

	# redefine {RLock#updateBackgroundMode}
	# an RLink can not be in background mode (for now)
	updateBackgroundMode: (value)->
		return

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@setPopover()
	# 	@linkJ.attr("href", @url)

@RLink = RLink

# RText: a textarea to write some text. 
# The text can have any google font, any effect, but all the text has the same formating.
class RText extends RDiv
	@rname = 'Text'

	@modalTitle = "Insert some text"
	@modalTitleUpdate = "Modify your text"
	@object_type = 'text'

	# parameters of the RText highly customize the gui (add functionnalities like font selector, etc.)
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

	# overload {RDiv#initFields}
	@initFields: ()->
		@modalJ.find('.url-name-group').hide()
		@modalJ.find('.name-group').hide()
		@modalJ.find('.url-group').hide()
		@modalJ.find('.message-group').show()
		@modalJ.find('#divModalTypeSelector').hide()
		@modalJ.find('.checkbox.restrict-area').hide()
		@modalJ.find('.checkbox.disable-toolbar').hide()
		return

	# overload {RDiv#initModal}
	@initModal: (rectangle=null, div=null)->
		super(@object_type, rectangle, div)
		return

	# @save: (rectangle)->
	# 	super(rectangle, @object_type)

	# overload {RDiv#constructor}
	# initialize mouse event listeners to be able to select and edit text, bind key event listener to @textChanged
	constructor: (@position, @size, @owner, @pk, @lock, @message='', @data, @date) ->
		super(@position, @size, @owner, @pk, @lock and @owner != g.me, @data, @date)

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
		return

	# called whenever the text is changed:
	# emit the new text to websocket
	# update the RText in 1 second (deffered execution)
	# @param event [jQuery Event] the key event
	textChanged: (event) =>
		@message = @contentJ.val()
		g.chatSocket.emit( "parameter change", g.me, @pk, "message", @message)
		g.defferedExecution(@update, @pk, 1000)
		return
	
	# set the font family for the text
	# - check font validity
	# - add font to the page header (in a script tag, this will load the font)
	# - update css
	# - update RText if *update*
	# @param fontFamily [String] the name of the font family
	# @param update [Boolean] whether to update the RText
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
	# add/remove (toggle) the font style of the text defined by *value*
	# if *value* is 'justify', 'left', 'right' or 'center', the text is aligned as the *value* (the previous value is ignored, no toggle)
	# this only modifies @data, the css will be modified in {RText#setFontStyle}
	# eit the change on websocket
	# @param value [String] the style to toggle, can be 'underline', 'overline', 'line-through', 'italic', 'bold', 'justify', 'left', 'right' or 'center'
	changeFontStyle: (value)=>

		if not value? then return
		
		if typeof(value) != 'string'
			return
		
		@data.fontStyle ?= {}
		@data.fontStyle.decoration ?= ''

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
		return

	# set the font style of the text (update the css)
	# called by {RText#changeFontStyle}
	# @param update [Boolean] (optional) whether to update the RText
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

	# set the font size of the text (update @data and the css)
	# @param fontSize [Number] the new font size
	# @param update [Boolean] (optional) whether to update the RText
	setFontSize: (fontSize, update=true)->
		if not fontSize? then return
		@data.fontSize = fontSize
		@contentJ.css( "font-size": fontSize+"px")
		if update
			@update()
		return

	# set the font effect of the text, only one effect can be applied at the same time (for now)
	# @param fontEffect [String] the new font effect
	# @param update [Boolean] (optional) whether to update the RText
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

	# set the font color of the text, update css
	# @param fontColor [String] the new font color
	# @param update [Boolean] (optional) whether to update the RText
	setFontColor: (fontColor, update=true)->
		@contentJ.css( "color": fontColor ? 'black')
		return

	# update font to match the styles, effects and colors in @data
	# @param update [Boolean] (optional) whether to update the RText
	setFont: (update=true)->
		@setFontStyle(update)
		@setFontFamily(@data.fontFamily, update)
		@setFontSize(@data.fontSize, update)
		@setFontEffect(@data.effect, update)
		@setFontColor(@data.fontColor, update)
		return
	
	# update = false when called by parameter.onChange from websocket
	# overload {RDiv#changeParameter}
	# update text content and font styles, effects and colors
	changeParameter: (name, value, userAction=true)->
		super(name, value, userAction)
		if not userAction and @data.message?
			@contentJ.val(@data.message)
		switch name
			when 'fontStyle', 'fontFamily', 'fontSize', 'effect', 'fontColor'
				@setFont(false)
			else
				@setFont(false)
		return

	# overload {RDiv#getData}
	# copy @data and add @data.message
	getData: ()->
		data = jQuery.extend({},@data)
		delete data.message
		return data

	# overload {RDiv#delete}
	# do not delete RText if we are editing the text (the delete key is used to delete the text)
	delete: () ->
		if @contentJ.hasClass("selected")
			return
		super()
		return

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@contentJ.val(@message)

@RText = RText

# todo: remove @url? duplicated in @data.url or remove data.url
# todo: websocket the url change

# RMedia holds an image, video or any content inside an iframe (can be a [shadertoy](https://www.shadertoy.com/))
# The first attempt is to load the media as an image:
# - if it succeeds, the image is embedded as a simple image tag, 
#   and can be either be fit (proportion are kept) or resized (dimensions will be the same as RMedia) in the RMedia 
#   (the user can modify this in the gui with the 'fit image' button)
# - if it fails, RMedia checks if the url start with 'iframe'
#   if it does, the iframe is embedded as is (this enables to embed shadertoys for example)
# - otherwise RMedia tries to embed it with jquery oembed (this enable to embed youtube and vimeo videos just with the video link)
class RMedia extends RDiv
	@rname = 'Media'
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
				onChange: ()-> 
					# onFinishChange is called on blur (focus out), it is a problem when user selects url input
					# in the sidebar and then select another RMedia 
					# (since it would call urlChanged on the newly selected RMedia since blur and g.selectedDiv is new)
					RMedia.selectedDivs = g.selectedDivs
					return
				onFinishChange: (value)-> 
					selectedDiv?.urlChanged(value, true) for selectedDiv in RMedia.selectedDivs
					return
			fitImage:
				type: 'checkbox'
				label: 'Fit image'
				default: false

		return parameters

	# overload {RDiv#initFields}
	@initFields: ()->
		@modalJ.find('.url-name-group').hide()
		@modalJ.find('.name-group').hide()
		@modalJ.find('.url-group').show()
		@modalJ.find('.url-group label').text("URL or <iframe>")
		@modalJ.find('.url-group input').attr("placeholder", "http:// or <iframe>")
		@modalJ.find('.message-group').hide()
		@modalJ.find('#divModalTypeSelector').hide()
		@modalJ.find('.checkbox.restrict-area').hide()
		@modalJ.find('.checkbox.disable-toolbar').hide()
		return

	# overload {RDiv#initModal}
	@initModal: (rectangle=null, div=null)->
		super(@object_type, rectangle, div)
		return

	# overload {RDiv#constructor}
	# initialize the url, load the media if any (when the RMedia is loaded)
	constructor: (@position, @size, @owner, @pk, @lock, @url='', @data, @date) ->
		super(@position, @size, @owner, @pk, @lock and @owner != g.me, @data, @date)
		@data.url = @url
		if url? and url.length>0
			@urlChanged(@url, false)
		@sizeChanged = false
		return

	# update the size of the iframe according to the size of @divJ
	updateSize: ()->
		width = @divJ.width()
		height = @divJ.height()
		@contentJ?.find("iframe").attr("width",width).attr("height",height).css( "max-width": width, "max-height": height )
		return

	# overload {RDiv#resize}
	# reload media on resize, to make sure the media is properly fitted to the RMedia
	# this should be relatively fast since it is likely to be cached
	resize: (event, userAction=true) =>
		super(event, userAction)
		if @isImage?
			return
		@sizeChanged = true
		@updateSize()
		return

	# overload {RDiv#resizeTo}
	resizeTo: (@position, @size)->
		super(@position, @size)
		@updateSize()
		return

	# overload {RDiv#dragFinished}
	# call {RMedia#urlChanged} if the size has changed (the RMedia has been resized)
	dragFinished: (userAction=true) =>
		if @sizeChanged
			@urlChanged(@url, false)
		@sizeChanged = false
		super(userAction)
		return

	# update: () ->
	# 	@urlChanged(@url, false) # todo: <- chek if necessary
	# 	super()

	# updateAll: (x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth) ->
	# 	super(x, y, width, height, name, message, url, fillColor, strokeColor, strokeWidth)
	# 	@urlChanged(@url, false)

	# called when user clicks in the "fit image" button in the gui
	# toggle the 'fit-image' class to fit (proportion are kept) or resize (dimensions will be the same as RMedia) the image in the RMedia 
	toggleFitImage: ()->
		if @isImage?
			@contentJ.toggleClass("fit-image", @data.fitImage)
		return

	# overload {RDiv#changeParameter}
	# update = false when called by parameter.onChange from websocket
	# toggle fit image if required
	changeParameter: (name, value, userAction=true)->
		super(name, value, userAction)
		switch name
			when 'fitImage'
				@toggleFitImage()
		return

	# return [Boolean] true if the url ends with an image extension: "jpeg", "jpg", "gif" or "png" 
	hasImageUrlExt: (url)->
		exts = [ "jpeg", "jpg", "gif", "png" ]
		ext = url.substring(url.lastIndexOf(".")+1)
		if ext in exts
			return true
		return false

	# try to load the url as an image: and call {RMedia#loadMedia} with the following string:
	# - 'success' if it succeeds
	# - 'error' if it fails
	# - 'timeout' if there was no response for 1 seconds (wait 5 seconds if the url as an image extension since it is likely that it will succeed)
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
			return
		image.onload = ()=>
			if not timedOut
				clearTimeout(timer)
			else
				@contentJ?.remove()
			@loadMedia('success')
			return
		image.src = @url
		return

	# embed the media in the div (this will load it) and update css
	# called by {RMedia#checkIsImage}
	# @param imageLoadResult [String] the result of the image load test: 'success', 'error' or 'timeout'
	loadMedia: (imageLoadResult)=>
		if imageLoadResult == 'success'
			@contentJ = $('<img class="content image" src="'+@url+'" alt="'+@url+'"">')
			@contentJ.mousedown( (event) -> event.preventDefault() )
			@isImage = true
		else
			# @contentJ = $(@url.replace("http://", ""))

			oembbedContent = ()=>
				@contentJ = $('<div class="content oembedall-container"></div>')
				@contentJ.oembed(@url, { includeHandle: false, embedMethod: 'fill', maxWidth: @divJ.width(), maxHeight: @divJ.height(), afterEmbed: @afterEmbed })
				return

			if @url.indexOf("http://")!=0 and @url.indexOf("https://")!=0
				@contentJ = $(@url)
				if @contentJ.is('iframe') 	# if 'url' starts with 'iframe', the user wants to integrate an iframe, not embed using jquery oembed
					@contentJ.attr('width', @divJ.width())
					@contentJ.attr('height', @divJ.height())
				else
					oembbedContent()
			else
				oembbedContent()
		
		@contentJ.insertBefore(@maskJ)

		@setCss()
		return

	# bug?: called many times when div is resized, maybe because update called urlChanged

	# remove the RMedia content and embed the media from *url*
	# update the RMedia if *updateDiv*
	# @param url [String] the url of the media to embed
	# @param updateDiv [Boolean] whether to update the RMedia
	urlChanged: (url, updateDiv=false) =>
		console.log 'urlChanged, updateDiv: ' + updateDiv + ', ' + @pk
		@url = url

		if @contentJ?
			@contentJ.remove()
			$("#jqoembeddata").remove()

		@checkIsImage()

		# websocket urlchange
		if updateDiv
			# if g.me? then g.chatSocket.emit( "parameter change", g.me, @pk, "url", @url ) # will not work unless url is in @data.url
			@update()
		return

	# set the size of the iframe to fit the size of the media once the media is loaded
	# called when the media embedded with jquery oembed is loaded
	afterEmbed: ()=>
		width = @divJ.width()
		height = @divJ.height()
		@contentJ?.find("iframe").attr("width",width).attr("height",height)
		return

	# overload {RDiv#getData}
	# delete data.url since we already save it in the url field in database
	getData: ()->
		data = jQuery.extend({}, @data)
		delete data.url
		return data

@RMedia = RMedia
