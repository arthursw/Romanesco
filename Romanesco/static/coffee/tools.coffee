# todo: replace update by drag

class RTool

	# to be overloaded, must return the parameters to display when the tool is selected
	@parameters: ()->
		return {}

	constructor: (@name, @cursorPosition = { x: 0, y: 0 }, @cursorDefault="default") ->
		g.tools[@name] = @

		@btnJ ?= g.toolsJ.find('li[data-type="'+@name+'"]')

		@cursorName = @btnJ.attr("data-cursor")
		@btnJ.click( () => @select() )

		popoverOptions = 
			placement: 'right'
			container: 'body'
			trigger: 'hover'
			delay:
				show: 500
				hide: 100
		
		description = @description()
		if not description?
			popoverOptions.content = @name
		else
			popoverOptions.title = @name
			popoverOptions.content = description

		@btnJ.popover( popoverOptions )

	description: ()->
		return null

	select: (constructor=@constructor, selectedItem=null)->
		differentTool = g.previousTool != g.selectedTool
		
		if @ != g.selectedTool
			g.previousTool = g.selectedTool
		
		g.selectedTool?.deselect()
		g.selectedTool = @

		g.deselectAll()

		if @cursorName?
			g.stageJ.css('cursor', 'url(static/images/cursors/'+@cursorName+'.png) '+@cursorPosition.x+' '+@cursorPosition.y+','+@cursorDefault)
		else
			g.stageJ.css('cursor', @cursorDefault)
		
		g.updateParameters( { tool: constructor, item: selectedItem }, differentTool)
		return

	deselect: ()->
		return

	begin: (event) ->
		return

	update: (event) ->
		return

	move: (event) ->
		return

	end: (event) ->
		return

	disableSnap: ()->
		return false

@RTool = RTool

class CodeTool extends RTool
	constructor: ()->
		super("Script")

	select: ()->
		super()
		g.toolEditor()

@CodeTool = CodeTool

# --- Move & select tools --- #

class MoveTool extends RTool

	constructor: () -> 
		super("Move", { x: 32, y: 32 }, "move")
		@prevPoint = { x: 0, y: 0 }
		@dragging = false

	select: ()->
		super()
		g.stageJ.addClass("moveTool")
		for div in g.divs
			div.disableInteraction()

	deselect: ()->
		super()
		g.stageJ.removeClass("moveTool")
		for div in g.divs
			div.enableInteraction()
		return

	begin: (event) ->
		return

	update: (event) ->
		return

	end: (event) ->
		return

	# note: we could use g.eventObj to convert the Native event into Paper.ToolEvent, however onMouseDown/Drag/Up also fire begin/update/end
	beginNative: (event) ->
		@dragging = true
		@prevPoint = { x: event.pageX, y: event.pageY }
		return

	updateNative: (event) ->
		if @dragging
			g.RMoveBy({ x: (@prevPoint.x-event.pageX)/view.zoom, y: (@prevPoint.y-event.pageY)/view.zoom })
			@prevPoint = { x: event.pageX, y: event.pageY }
		return

	endNative: (event) ->
		@dragging = false
		return

@MoveTool = MoveTool


class CarTool extends RTool
	
	@parameters: ()->
		parameters = 
			'Car':
				speed:
					type: 'input'
					label: 'Speed'
					value: '0'
					addController: true
					onChange: ()-> return
		return parameters

	constructor: () -> 
		super("Car", { x: 0, y: 0 }, "none")
		@prevPoint = { x: 0, y: 0 }
		@dragging = false

	select: ()->
		super()
		url = "/static/images/car.png"

		@car = new Raster(url)
		g.carLayer.addChild(@car)
		@car.position = view.center
		@speed = 0
		@direction = new Point(0, -1)
		@car.onLoad = ()=>
			console.log 'car loaded'
			return

		@previousSpeed = 0
		
		g.sound.setVolume(0.1)
		g.sound.play(0)
		g.sound.setLoopStart(3.26)
		g.sound.setLoopEnd(5.22)

		@lastUpdate = Date.now()

		return

	deselect: ()->
		super()
		@car.remove()
		@car = null
		g.sound.stop()
		return

	onFrame: ()->
		if not @car? then return

		minSpeed = 0.05
		maxSpeed = 100
		
		if Key.isDown('right')
			@direction.angle += 5
		if Key.isDown('left')
			@direction.angle -= 5
		if Key.isDown('up')
			if @speed<maxSpeed then @speed++
		else if Key.isDown('down')
			if @speed>-maxSpeed then @speed--
		else
			@speed *= 0.9
			if Math.abs(@speed) < minSpeed
				@speed = 0

		minRate = 0.25
		maxRate = 3
		rate = minRate+Math.abs(@speed)/maxSpeed*(maxRate-minRate)
		# console.log rate
		g.sound.setRate(rate)

		# acc = @speed-@previousSpeed

		# if @speed > 0 and @speed < maxSpeed
		# 	if acc > 0 and not g.sound.plays('acc')
		# 		console.log 'acc'
		# 		g.sound.playAt('acc', Math.abs(@speed/maxSpeed))
		# 	else if acc < 0 and not g.sound.plays('dec')
		# 		console.log 'dec:' + g.sound.pos()
		# 		g.sound.playAt('dec', 0) #1.0-Math.abs(@speed/maxSpeed))
		# else if Math.abs(@speed) == maxSpeed and not g.sound.plays('max')
		# 	console.log 'max'
		# 	g.sound.stop()
		# 	g.sound.spriteName = 'max'
		# 	g.sound.play('max')
		# else if @speed == 0 and not g.sound.plays('idle')
		# 	console.log 'idle'
		# 	g.sound.stop()
		# 	g.sound.spriteName = 'idle'
		# 	g.sound.play('idle')
		# else if @speed < 0 and Math.abs(@speed) < maxSpeed
		# 	if acc < 0 and not g.sound.plays('acc')
		# 		console.log '-acc'
		# 		g.sound.playAt('acc', Math.abs(@speed/maxSpeed))
		# 	else if acc > 0 and not g.sound.plays('dec')
		# 		console.log '-dec'
		# 		g.sound.playAt('dec', 1.0-Math.abs(@speed/maxSpeed))

		@previousSpeed = @speed

		@parameterControllers?['speed']?.setValue(@speed.toFixed(2))

		@car.rotation = @direction.angle+90
		
		if Math.abs(@speed) > minSpeed
			@car.position = @car.position.add(@direction.multiply(@speed))
			g.RMoveTo(@car.position)

		g.gameAt(@car.position)?.updateGame(@)

		if Date.now()-@lastUpdate>150
			if g.me? then g.chatSocket.emit "car move", g.me, @car.position, @car.rotation, @speed
			@lastUpdate = Date.now()

		#project.view.center = @car.position
		return

@CarTool = CarTool

class SelectTool extends RTool

	hitOptions =
		stroke: true
		fill: true
		handles: true
		segments: true
		curves: true
		tolerance: 5

	constructor: () -> 
		super("Select")
		@selectedItem = null

	select: ()->
		@selectedItem = g.selectedItems().first()
		super(@selectedItem?.constructor or @constructor, @selectedItem)

	createSelectionRectangle: (event)->
		g.currentPaths[g.me]?.remove()
		g.currentPaths[g.me] = new Path.Rectangle(event.downPoint, event.point)
		g.currentPaths[g.me].name = 'select tool selection rectangle'
		g.currentPaths[g.me].strokeColor = g.selectionBlue
		g.currentPaths[g.me].dashArray = [10, 4]
		return


	removeSelectionGroup: ()->
		g.deselectAll()		# deselect divs
		if not g.selectionGroup? then return
		project.activeLayer.addChildren(g.selectionGroup.removeChildren())
		g.selectionGroup.remove()
		g.selectionGroup = null
		return

	begin: (event) ->
		console.log "select begin"
		path.prepareHitTest() for name, path of g.paths
		hitResult = g.project.hitTest(event.point, hitOptions)
		path.finishHitTest() for name, path of g.paths

		# if user hits a path: select it
		if hitResult and hitResult.item.controller?
			@selectedItem = hitResult.item.controller

			if not event.modifiers.shift 
				if g.selectionGroup?
					if not g.selectionGroup.isAncestor(hitResult.item) then @removeSelectionGroup()
				else 
					if g.selectedDivs.length>0 then g.deselectAll()

			hitResult.item.controller.selectBegin?(event)
		else
			@removeSelectionGroup()
			@createSelectionRectangle(event)

	update: (event) ->
		if not g.currentPaths[g.me]
			for item in g.selectedItems()
				item.selectUpdate?(event)
		else
			@createSelectionRectangle(event)
		return

	end: (event) ->
		if not g.currentPaths[g.me]

			for item in g.selectedItems()
				item.selectEnd?(event)

		else
			rectangle = new Rectangle(event.downPoint, event.point)
			
			itemsToSelect = []

			for name, item of g.items
				if item.getBounds().intersects(rectangle)
					item.select(false)
					itemsToSelect.push(item)

			# for item in project.activeLayer.children
			# 	bounds = item.bounds
			# 	if item.controller? and (rectangle.contains(bounds) or ( rectangle.intersects(bounds) and item.controller.controlPath?.getIntersections(g.currentPaths[g.me]).length>0 ))
			# 	# if item.controller? and rectangle.intersects(bounds)
			# 		g.pushIfAbsent(itemsToSelect, item.controller)
			
			# for item in itemsToSelect
			# 	item.select(false)
			itemsToSelect = itemsToSelect.map( (item)-> return { tool: item.constructor, item: item } )
			g.updateParameters(itemsToSelect)

			# for div in g.divs
			# 	if div.getBounds().intersects(rectangle)
			# 		div.select()

			g.currentPaths[g.me].remove()
			delete g.currentPaths[g.me]
		return

	doubleClick: (event) ->
		for item in g.selectedItems()
			item.doubleClick?(event)
		return

	disableSnap: ()->
		return g.currentPaths[g.me]?

@SelectTool = SelectTool

# --- Path tool --- #

class PathTool extends RTool

	constructor: (@RPath, justCreated=false) ->
		@name = @RPath.rname

		# if the tool is just created (in editor) add in favorite. Otherwise check is it was saved as a favorite tool in the localStorage (g.favoriteTools).
		favorite = justCreated | g.favoriteTools?.indexOf(@name)>=0

		@btnJ = g.toolsJ.find('li[data-type="'+@name+'"]')

		# <li data-type="Spiral" data-cursor="spiral"><img src="{% static 'icons/inverted/spiral.png' %}" alt="spiral"></li>		
		# todo: put this part in PathTool?
		if @btnJ.length==0
			@btnJ = $("<li>")
			@btnJ.attr("data-type", @name)
			# @btnJ.attr("data-cursor", @cursorDefault)
			@btnJ.attr("alt", @name)
			
			if @RPath.iconUrl?
				@btnJ.append('<img src="' + @RPath.iconUrl + '" alt="' + @RPath.iconAlt + '">')
			else
				@btnJ.addClass("text-btn")
				name = ""
				words = @name.split(" ")
				if words.length>1
					name += word.substring(0,1) for word in words
				else
					name += @name.substring(0,2)
				shortNameJ = $('<span class="short-name">').text(name + ".")
				@btnJ.append(shortNameJ)
			
			if favorite
				g.favoriteToolsJ.append(@btnJ)
			else
				g.allToolsJ.append(@btnJ)

		toolNameJ = $('<span class="tool-name">').text(@name)
		@btnJ.append(toolNameJ)
		@btnJ.addClass("tool-btn")
		
		super(@RPath.rname, @RPath.cursorPosition, @RPath.cursorDefault, @RPath.options)
		
		return

	description: ()->
		return @RPath.rdescription

	remove: () ->
		@btnJ.remove()
		return

	select: ()->
		super(@RPath)

		g.tool.onMouseMove = (event) ->
			event = g.snap(event)
			g.selectedTool.move(event)
			return
		return
	
	deselect: ()->
		super()
		@finishPath()
		g.tool.onMouseMove = null
		return

	begin: (event, from=g.me, data=null) ->

		# deselect all and create new path in all case except in polygonMode
		if not (g.currentPaths[from]? and g.currentPaths[from].data?.polygonMode)
			g.deselectAll()
			g.currentPaths[from] = new @RPath(null, data)

		g.currentPaths[from].createBegin(event.point, event, false)

		if g.me? and from==g.me then g.chatSocket.emit( "begin", g.me, g.eventObj(event), @name, g.currentPaths[from].data )
		return

	update: (event, from=g.me) ->
		g.currentPaths[from].createUpdate(event.point, event, false)
		if g.me? and from==g.me then g.chatSocket.emit( "update", g.me, g.eventObj(event), @name)
		return

	move: (event) ->
		if g.currentPaths[g.me]?.data?.polygonMode then g.currentPaths[g.me].createMove?(event)
		return

	end: (event, from=g.me) ->
		g.currentPaths[from].createEnd(event.point, event, false)

		if not g.currentPaths[from].data?.polygonMode
			if g.me? and from==g.me
				g.currentPaths[from].select(false)
				g.currentPaths[from].save()
				g.chatSocket.emit( "end", g.me, g.eventObj(event), @name )
			delete g.currentPaths[from]
		return

	finishPath: (from=g.me)->
		if not g.currentPaths[g.me]?.data?.polygonMode then return
		
		g.currentPaths[from].finishPath()
		if g.me? and from==g.me
			g.currentPaths[from].select(false)
			g.currentPaths[from].save()
			g.chatSocket.emit( "bounce", { tool: @name, function: "finishPath", arguments: g.me } )
		delete g.currentPaths[from]
		return


@PathTool = PathTool

# --- Link & lock tools --- #

class DivTool extends RTool

	constructor: (@name, @RDiv) ->
		super(@name, { x: 24, y: 0 }, "crosshair")
		# test: @isDiv = true

	select: ()->
		super(@RDiv)

	begin: (event, from=g.me) ->
		point = event.point

		g.currentPaths[from] = new Path.Rectangle(point, point)
		g.currentPaths[from].name = 'div tool rectangle'
		g.currentPaths[from].dashArray = [4, 10]
		g.currentPaths[from].strokeColor = 'black'

		if g.me? and from==g.me then g.chatSocket.emit( "begin", g.me, g.eventObj(event), @name, g.currentPaths[from].data )

	update: (event, from=g.me) ->
		point = event.point

		g.currentPaths[from].segments[2].point = point
		g.currentPaths[from].segments[1].point.x = point.x
		g.currentPaths[from].segments[3].point.y = point.y

		if g.me? and from==g.me then g.chatSocket.emit( "update", g.me, point, @name )

	end: (event, from=g.me) ->
		if from != g.me
			g.currentPaths[from].remove()
			delete g.currentPaths[from]			
			return false

		point = event.point

		g.currentPaths[from].segments[2].point = point
		g.currentPaths[from].segments[1].point.x = point.x
		g.currentPaths[from].segments[3].point.y = point.y

		g.currentPaths[from].remove()

		if RDiv.boxOverlapsTwoPlanets(g.currentPaths[from].bounds)
			return false

		if RLock.intersectRect(g.currentPaths[from].bounds)
			return false

		if g.currentPaths[from].bounds.area < 100
			g.currentPaths[from].width = 10
			g.currentPaths[from].height = 10

		if g.me? and from==g.me then g.chatSocket.emit( "end", g.me, point, @name )

		return true

@DivTool = DivTool

class LockTool extends DivTool

	constructor: () -> 
		super("Lock", RLock)
		@textItem = null

	update: (event, from=g.me) ->
		point = event.point

		cost = g.currentPaths[from].bounds.area/1000.0

		@textItem?.remove()
		@textItem = new PointText(point)
		@textItem.justification = 'right'
		@textItem.fillColor = 'black'
		@textItem.content = '' + cost + ' romanescoins'
		super(event, from)

	end: (event, from=g.me) ->
		@textItem?.remove()
		if super(event, from)
			RLock.initModal(g.currentPaths[from].bounds)
			delete g.currentPaths[from]

@LockTool = LockTool


# class LinkTool extends DivTool

# 	constructor: () -> 
# 		super("Link", RLink)
# 		@textItem = null

# 	update: (event, from=g.me) ->
# 		point = event.point
# 		cost = g.currentPaths[from].bounds.area

# 		@textItem?.remove()
# 		@textItem = new PointText(point)
# 		@textItem.justification = 'right'
# 		@textItem.fillColor = 'black'
# 		@textItem.content = '' + cost + ' romanescoins'
# 		super(event, from)


# 	end: (event, from=g.me) ->
# 		@textItem?.remove()
# 		if super(event, from)
# 			RLink.initModal(g.currentPaths[from].bounds)
# 			delete g.currentPaths[from]

# @LinkTool = LinkTool

class TextTool extends DivTool

	constructor: () -> 
		super("Text", RText)

	end: (event, from=g.me) ->
		if super(event, from)
			RText.save(g.currentPaths[from].bounds, "text")
			delete g.currentPaths[from]

@TextTool = TextTool

class MediaTool extends DivTool

	constructor: () -> 
		super("Media", RMedia)

	end: (event, from=g.me) ->
		if super(event, from)
			RMedia.initModal(g.currentPaths[from].bounds)
			delete g.currentPaths[from]

@MediaTool = MediaTool

# todo: ZeroClipboard.destroy()
class ScreenshotTool extends RTool

	constructor: () ->
		super('Screenshot', { x: 24, y: 0 }, "crosshair")
		@modalJ = $("#screenshotModal")
		# @modalJ.find('button[name="copy-data-url"]').click( ()=> @copyDataUrl() )
		@modalJ.find('button[name="publish-on-facebook"]').click( ()=> @publishOnFacebook() )
		@modalJ.find('button[name="publish-on-facebook-photo"]').click( ()=> @publishOnFacebookAsPhoto() )
		@modalJ.find('button[name="download-png"]').click( ()=> @downloadPNG() )
		@modalJ.find('button[name="download-svg"]').click( ()=> @downloadSVG() )
		@modalJ.find('button[name="publish-on-pinterest"]').click ()=>@publishOnPinterest()
		@descriptionJ = @modalJ.find('input[name="message"]')
		@descriptionJ.change ()=>
			@modalJ.find('a[name="publish-on-twitter"]').attr("data-text", @getDescription())
			return

		ZeroClipboard.config( swfPath: "http://127.0.0.1:8000/static/libs/ZeroClipboard/ZeroClipboard.swf" )
		# ZeroClipboard.destroy()
	
	getDescription: ()->
		return if @descriptionJ.val().length>0 then @descriptionJ.val() else "Artwork made in Romanesco"

	begin: (event, from=g.me) ->
		if from!=g.me then return
		g.currentPaths[from] = new Path.Rectangle(event.point, event.point)
		g.currentPaths[from].name = 'screenshot tool selection rectangle'
		g.currentPaths[from].dashArray = [4, 10]
		g.currentPaths[from].strokeColor = 'black'
		g.currentPaths[from].strokeWidth = 1

	update: (event, from=g.me) ->
		if from!=g.me then return
		g.currentPaths[from].lastSegment.point = event.point
		g.currentPaths[from].lastSegment.next.point.y = event.point.y
		g.currentPaths[from].lastSegment.previous.point.x = event.point.x

	end: (event, from=g.me) ->
		if from!=g.me then return
		g.currentPaths[from].remove()
		delete g.currentPaths[from]
		g.view.draw()

		r = new Rectangle(event.downPoint, event.point)
		if r.area<100
			return

		@div = new RSelectionRectangle(new Rectangle(event.downPoint, event.point), @extractImage)

		return

	extractImage: ()=>
		@rectangle = @div.getBounds()
		viewRectangle = g.projectToViewRectangle(@rectangle)
		@div.remove()
		canvasTemp = document.createElement('canvas')
		canvasTemp.width = viewRectangle.width
		canvasTemp.height = viewRectangle.height
		contextTemp = canvasTemp.getContext('2d')
		contextTemp.putImageData(g.context.getImageData(viewRectangle.x, viewRectangle.y, viewRectangle.width, viewRectangle.height), 0, 0)
		@dataURL = canvasTemp.toDataURL("image/png")
		copyDataBtnJ = @modalJ.find('button[name="copy-data-url"]')
		copyDataBtnJ.attr("data-clipboard-text", @dataURL)
		imgJ = @modalJ.find("img.png")
		imgJ.attr("src", @dataURL)
		maxHeight = g.windowJ.height - 220
		imgJ.css( 'max-height': maxHeight + "px" )
		
		# twitter
		twitterLinkJ = @modalJ.find('a[name="publish-on-twitter"]')
		twitterLinkJ.empty().text("Publish on Twitter")
		twitterLinkJ.attr "data-url", "http://romanesc.co/" + location.hash
		twitterScriptJ = $('<script type="text/javascript">window.twttr=(function(d,s,id){var t,js,fjs=d.getElementsByTagName(s)[0];if(d.getElementById(id)){return}js=d.createElement(s);js.id=id;js.src="https://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);return window.twttr||(t={_e:[],ready:function(f){t._e.push(f)}})}(document,"script","twitter-wjs"));</script>')
		twitterLinkJ.append(twitterScriptJ)

		@modalJ.find("a.png").attr("href", @dataURL)
		@modalJ.modal('show')
		@modalJ.on 'shown.bs.modal', (e)=>
			client = new ZeroClipboard( copyDataBtnJ )
			client.on "ready", (readyEvent)->
				console.log "ZeroClipboard SWF is ready!"
				client.on "aftercopy", (event)->
					# `this` === `client`
					# `event.target` === the element that was clicked
					# event.target.style.display = "none"
					romanesco_alert("Image data url was successfully copied into the clipboard!", "success")
					this.destroy()
					return
				return
			return
		return

	# copyDataUrl: ()=>
	# 	@modalJ.modal('hide')
	# 	return

	saveImage: (callback)->
		# ajaxPost '/saveImage', {'image': @dataURL } , callback
		Dajaxice.draw.saveImage( callback, {'image': @dataURL } )
		romanesco_alert "Your image is being uploaded...", "info"
		return

	publishOnFacebook: ()=>
		@saveImage(@publishOnFacebook_callback)
		return

	publishOnFacebook_callback: (result)=>
		romanesco_alert "Your image was successfully uploaded to Romanesco, posting to Facebook...", "info"
		caption = @getDescription()
		FB.ui(
			method: "feed"
			name: "Romanesco"
			caption: caption
			description: ("Romanesco is an infinite collaborative drawing app.")
			link: "http://61b2fd1e.ngrok.com/"
			picture: "http://61b2fd1e.ngrok.com/" + result.url
		, (response) ->
			if response and response.post_id
				romanesco_alert "Your Post was successfully published!", "success"
			else
				romanesco_alert "An error occured. Your post was not published.", "error"
			return
		)

		# @modalJ.modal('hide')
		
		# imageData = 'data:image/png;base64,'+result.image
		# image = new Image()
		# image.src = imageData
		# g.canvasJ[0].getContext("2d").drawImage(image, 300, 300)

		# # FB.login( () ->
		# # 	if (response.session) {
		# # 		if (response.perms) {
		# # 			# // user is logged in and granted some permissions.
		# # 			# // perms is a comma separated list of granted permissions
		# # 		} else {
		# # 			# // user is logged in, but did not grant any permissions
		# # 		}
		# # 	} else {
		# # 		# // user is not logged in
		# # 	}
		# # }, {perms:'read_stream,publish_stream,offline_access'})
		
		# FB.api(
		# 	"/me/photos",
		# 	"POST",
		# 	{
		# 		"object": {
		# 			"url": result.url
		# 		}
		# 	},
		# 	(response) ->
		# 		# if (response && !response.error)
		# 			# handle response
		# 		return
		# )

	publishOnFacebookAsPhoto: ()=>
		if not g.loggedIntoFacebook
			FB.login( (response)=>
				if response and !response.error
					@saveImage(@publishOnFacebookAsPhoto_callback)
				else
					romanesco_alert "An error occured when trying to log you into facebook.", "error"
				return
			)
		else
			@saveImage(@publishOnFacebookAsPhoto_callback)
		return

	publishOnFacebookAsPhoto_callback: (result)=>
		romanesco_alert "Your image was successfully uploaded to Romanesco, posting to Facebook...", "info"
		caption = @getDescription()
		FB.api(
			"/me/photos",
			"POST",
			{
				"url": "http://61b2fd1e.ngrok.com/" + result.url
				"message": caption
			},
			(response)->
				if response and !response.error
					romanesco_alert "Your Post was successfully published!", "success"
				else
					romanesco_alert("An error occured. Your post was not published.", "error")
					console.log response.error
				return
		)
		return

	publishOnPinterest: ()=>
		@saveImage(@publishOnPinterest_callback)
		return

	publishOnPinterest_callback: (result)=>
		romanesco_alert "Your image was successfully uploaded to Romanesco...", "info"

		pinterestModalJ = $("#customModal")
		pinterestModalJ.modal('show')
		pinterestModalJ.addClass("pinterest-modal")

		pinterestModalJ.find(".modal-title").text("Publish on Pinterest")
		# siteUrl = encodeURI('http://romanesc.co/')
		siteUrl = encodeURI('http://61b2fd1e.ngrok.com/')
		imageUrl = siteUrl+result.url
		caption = @getDescription()
		description = encodeURI(caption)
		linkJ = $("<a>")
		linkJ.addClass("image")
		linkJ.attr("href", "http://pinterest.com/pin/create/button/?url="+siteUrl+"&media="+imageUrl+"&description="+description)
		linkJcopy = linkJ.clone()
		
		imgJ = $('<img>')
		imgJ.attr( 'src', siteUrl+result.url )
		linkJ.append(imgJ)

		buttonJ = pinterestModalJ.find('button[name="submit"]')
		linkJcopy.addClass("btn btn-primary").text("Pin it!").insertBefore(buttonJ)
		buttonJ.hide()

		submit = ()->
			pinterestModalJ.modal('hide')
			return
		linkJ.click(submit)
		pinterestModalJ.find(".modal-body").empty().append(linkJ)

		pinterestModalJ.on 'hide.bs.modal', (event)->
			pinterestModalJ.removeClass("pinterest-modal")
			linkJcopy.remove()
			pinterestModalJ.off 'hide.bs.modal'
			return

		return

	# publishOnTwitter: ()=>
	# 	linkJ = $('<a name="publish-on-twitter" class="twitter-share-button" href="https://twitter.com/share" data-text="Artwork made on Romanesco" data-size="large" data-count="none">Publish on Twitter</a>')
	# 	linkJ.attr "data-url", "http://romanesc.co/" + location.hash
	# 	scriptJ = $('<script type="text/javascript">window.twttr=(function(d,s,id){var t,js,fjs=d.getElementsByTagName(s)[0];if(d.getElementById(id)){return}js=d.createElement(s);js.id=id;js.src="https://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);return window.twttr||(t={_e:[],ready:function(f){t._e.push(f)}})}(document,"script","twitter-wjs"));</script>')
	# 	$("div.temporary").append(linkJ)
	# 	$("div.temporary").append(scriptJ)
	# 	linkJ.click()
	# 	return

	downloadPNG: ()=>
		@modalJ.find("a.png")[0].click()
		# todo: open image in new page if in ie or safari?
		@modalJ.modal('hide')
		return

	downloadSVG: ()=>
		rectanglePath = new Path.Rectangle(@rectangle)

		itemsToSave = []
		for item in project.activeLayer.children
			bounds = item.bounds
			if item.controller? and ( @rectangle.contains(bounds) or ( @rectangle.intersects(bounds) and item.controller.controlPath?.getIntersections(rectanglePath).length>0 ) )
				g.pushIfAbsent(itemsToSave, item.controller)

		svgGroup = new Group()

		for item in itemsToSave
			svgGroup.addChild(item.drawing.clone())
		
		rectanglePath.remove()
		position = svgGroup.position.subtract(@rectangle.topLeft)
		fileName = "image.svg"

		canvasTemp = document.createElement('canvas')
		canvasTemp.width = @rectangle.width
		canvasTemp.height = @rectangle.height

		tempProject = new Project(canvasTemp)
		svgGroup.position = position
		tempProject.addChild(svgGroup)

		svg = tempProject.exportSVG( asString: true )
		tempProject.remove()
		paper.projects.first().activate()
		blob = new Blob([svg], {type: 'image/svg+xml'})
		url = URL.createObjectURL(blob)
		link = document.createElement("a")
		link.download = fileName
		link.href = url
		link.click()

		@modalJ.modal('hide')
		return

	copyURL: ()=>
		return

@ScreenshotTool = ScreenshotTool
