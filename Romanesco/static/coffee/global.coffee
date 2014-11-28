g = this
this.g = g
g.alerts = null
g.scale = 1000.0

# GH: General Helper

this.getTime = ()->
	return new Date().getTime()

this.sign = (x) ->
	(if typeof x is "number" then (if x then (if x < 0 then -1 else 1) else (if x is x then 0 else NaN)) else NaN)

this.clamp = (min, value, max)->
	return Math.min(Math.max(value, min), max)

# removes itemToRemove from array 
# Array.prototype.remove = (itemToRemove) ->
# 	this.splice(this.indexOf(item),1)

# removes itemToRemove from array 
# problem with array.splice(array.indexOf(item),1) :
# removes the last element if item is not in array
Array.prototype.remove = (itemToRemove) ->
	for item,i in this
		if item is itemToRemove
			this.splice(i,1)
			break
	return

# get first element of array
Array.prototype.first = () ->
	return this[0]

# get last element of array
Array.prototype.last = () ->
	return this[this.length-1]

# get random element of array
Array.prototype.random = () ->
	return this[Math.floor(Math.random()*this.length)]

# previously Array.prototype.pushIfAbsent, but there seem to be a colision with jQuery... 
# push if array does not contain item
this.pushIfAbsent = (array, item) ->
	if array.indexOf(item)<0 then array.push(item)
	return

# execute handler after n milliseconds, reset the delay timer at each call
this.defferedExecution = (handler, id, n=500) ->
	if g.updateTimeout[id]? then clearTimeout(g.updateTimeout[id])
	g.updateTimeout[id] = setTimeout(handler, n)

this.load = ->
	console.log("load")

this.setAlert = (index) ->

	if g.alerts.length<=0 || index<0 || index>=g.alerts.length
		return

	prevType = g.alerts[g.currentAlert].type
	g.currentAlert = index
	alertJ = g.alertsContainer.find(".alert")
	alertJ.removeClass(prevType).addClass(g.alerts[g.currentAlert].type).text(g.alerts[g.currentAlert].message)

	g.alertsContainer.find(".alert-number").text(g.currentAlert+1)

# display an alert with message, type and delay in container (or in alert div by default)
this.romanesco_alert = (message, type="", delay=2000, container=null) ->
	if type.length==0
		type = "info"
	else if type == "error"
		type = "danger"
	
	type = " alert-" + type

	alertJ = g.alertsContainer.find(".alert")
	g.alertsContainer.removeClass("r-hidden")

	prevType = if g.alerts.length>0 then g.alerts[g.alerts.length-1].type else ""
	
	g.currentAlert = g.alerts.length
	g.alerts.push( { type: type, message: message } )

	if g.alerts.length>0
		g.alertsContainer.addClass("activated")

	alertJ.removeClass(prevType).addClass(type).text(message)

	g.alertsContainer.find(".alert-number").text(g.alerts.length)

	g.alertsContainer.addClass("show")

	if delay!=0
		clearTimeout(g.alertTimeOut)
		g.alertTimeOut = setTimeout( ( () -> g.alertsContainer.removeClass("show") ) , delay )

sqrtTwoPi = Math.sqrt(2*Math.PI)

# mean: expected value
# sigma: standard deviation
this.gaussian = (mean, sigma, x)->
	expf = -((x-mean)*(x-mean)/(2*sigma*sigma))
	return ( 1.0/(sigma*sqrtTwoPi) ) * Math.exp(expf)

# divs: lock, links, text and medias 
this.eventObj = (event)->
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

this.parseEventObj = (event)->
	event.point = new Point(event.point)
	event.downPoint = new Point(event.downPoint)
	event.delta = new Point(event.delta)
	return event

this.specialKey = (event)->
	if event.pageX? and event.pageY?
		specialKey = if g.OSName == "MacOS" then event.metaKey else event.ctrlKey
	else
		specialKey = if g.OSName == "MacOS" then event.modifiers.command else event.modifiers.control
	return specialKey

this.getSnap = ()->
	snap = g.parameters.snap.snap
	return snap-snap%g.parameters.snap.step

this.snap1D = (value, snap)->
	snap ?= g.getSnap()
	if snap != 0
		return Math.floor(value/snap)*snap
	else
		return value

this.snap2D = (point, snap)->
	snap ?= g.getSnap()
	if snap != 0
		return new Point(snap1D(point.x, snap), snap1D(point.y, snap))
	else
		return point

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

class RSound
	window.AudioContext = window.AudioContext || window.webkitAudioContext
	@context = new AudioContext()

	constructor: (@urlList, @onLoadCallback)->
		@context = @constructor.context
		@load()
		return

	load: ()->
		@loadBuffer(0)
		return

	loadBuffer: (@index)->
		if @index>=@urlList.length then return
		url = @urlList[@index]
		request = new RXMLHttpRequest()
		request.open("GET", url, true)
		request.responseType = "arraybuffer"

		request.onload = ()=>
			@bufferOnLoad(request.response)
			return

		request.onerror = ()->
			console.error 'BufferLoader: XHR error'
			return

		request.send()
		return

	bufferOnLoad: (response)=>
		@context.decodeAudioData( response, @bufferOnDecoded, @bufferOnError )
		return

	bufferOnDecoded: (@buffer)=>
		if not @buffer
			console.log 'Error decoding url number ' + @index + ', trying next url.'
			if @index+1<@urlList.length
				@loadBuffer(@index+1)
			else
				console.error 'Error decoding file data.'
			return
		if @playOnLoad?
			@play(@playOnLoad)
			@playOnLoad = null
		@onLoadCallback?()
		console.log 'Sound loaded using url: ' + @urlList[@index]
		return

	bufferOnError: (error)->
		console.error 'decodeAudioData', error

	play: (time=0)->
		if not @buffer? 
			@playOnLoad = time
			return
		@source = @context.createBufferSource()
		@source.buffer = @buffer
		@source.connect(@context.destination)
		@source.loop = true
		@gainNode = @context.createGain()
		@source.connect(@gainNode)
		@gainNode.connect(@context.destination)
		@gainNode.gain.value = @volume
		@source.start(time)
		return

	setLoopStart: (start)->
		@source.loopStart = start
		return

	setLoopEnd: (end)->
		@source.loopEnd = end
		return

	stop: ()->
		@source.stop()
		return

	setRate: (rate)->
		@source.playbackRate.value = rate
		return

	rate: ()->
		return @source.playbackRate.value
	
	volume: ()->
		return @volume

	setVolume: (@volume)->
		if not @source? then return
		return @gainNode.gain.value = @volume


@RSound = RSound


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