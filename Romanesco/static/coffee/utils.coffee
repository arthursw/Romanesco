define [
	'jquery'
], ($) ->

	g = {}
	window.g = g

	g.specialKeys = {
		8: 'backspace',
		9: 'tab',
		13: 'enter',
		16: 'shift',
		17: 'control',
		18: 'option',
		19: 'pause',
		20: 'caps-lock',
		27: 'escape',
		32: 'space',
		35: 'end',
		36: 'home',
		37: 'left',
		38: 'up',
		39: 'right',
		40: 'down',
		46: 'delete',
		91: 'command',
		93: 'command',
		224: 'command'
	}

	g.getParentPrototype = (object, ParentClass)->
		prototype = object.constructor.prototype
		while prototype != ParentClass.prototype
			prototype = prototype.constructor.__super__
		return prototype

	# @return [Number] sign of *x* (+1 or -1)
	g.sign = (x) ->
		(if typeof x is "number" then (if x then (if x < 0 then -1 else 1) else (if x is x then 0 else NaN)) else NaN)

	# @return [Number] *value* clamped with *min* and *max* ( so that min <= value <= max )
	g.clamp = (min, value, max)->
		return Math.min(Math.max(value, min), max)

	g.random = (min, max)->
		return min + Math.random()*(max-min)

	# removes *itemToRemove* from array
	# problem with array.splice(array.indexOf(item),1) :
	# removes the last element if item is not in array
	Array.prototype.remove = (itemToRemove) ->
		for item,i in this
			if item is itemToRemove
				this.splice(i,1)
				break
		return

	# @return [Array item] first element of the array
	Array.prototype.first = () ->
		return this[0]

	# @return [Array item] last element of the array
	Array.prototype.last = () ->
		return this[this.length-1]

	# @return [Array item] random element of the array
	Array.prototype.random = () ->
		return this[Math.floor(Math.random()*this.length)]

	# @return [Array item] maximum
	Array.prototype.max = () ->
		max = this[0]
		for item in this
			if item>max then max = item
		return max

	# @return [Array item] minimum
	Array.prototype.min = () ->
		min = this[0]
		for item in this
			if item<min then min = item
		return min

	# @return [Array item] maximum
	Array.prototype.maxc = (biggerThan) ->
		max = this[0]
		for item in this
			if biggerThan(item,max) then max = item
		return max

	# @return [Array item] minimum
	Array.prototype.minc = (smallerThan) ->
		min = this[0]
		for item in this
			if smallerThan(item,min) then min = item
		return min

	# check if array is array
	Array.isArray ?= (array)->
		return array.constructor == Array

	g.isArray = (array)->
		return array.constructor == Array

	# previously Array.prototype.pushIfAbsent, but there seem to be a colision with jQuery...
	# push if array does not contain item
	g.pushIfAbsent = (array, item) ->
		if array.indexOf(item)<0 then array.push(item)
		return

	# Execute *callback* after *n* milliseconds, reset the delay timer at each call
	# @param [function] callback function
	# @param [Anything] a unique id (usually the id or pk of RItems) to avoid collisions between deferred executions
	# @param [Number] delay before *callback* is called
	g.deferredExecution = (callback, id, n=500) ->
		id ?= callback
		callbackWrapper = ()->
			delete g.updateTimeout[id]
			callback()
			return
		# console.log "deferredExecution: " + id + ", updateTimeout[id]: " + g.updateTimeout[id]
		if g.updateTimeout[id]? then clearTimeout(g.updateTimeout[id])
		g.updateTimeout[id] = setTimeout(callbackWrapper, n)
		return

	# Execute *callback* at next animation frame
	# @param [function] callback function
	# @param [Anything] a unique id (usually the id or pk of RItems) to avoid collisions between deferred executions
	g.callNextFrame = (callback, id, args) ->
		id ?= callback
		callbackWrapper = ()->
			delete g.requestedCallbacks[id]
			if not args? then callback() else callback.apply(window, args)
			return
		g.requestedCallbacks[id] ?= window.requestAnimationFrame(callbackWrapper)
		return

	g.cancelCallNextFrame = (idToCancel)->
		window.cancelAnimationFrame(g.requestedCallbacks[idToCancel])
		delete g.requestedCallbacks[idToCancel]
		return

	sqrtTwoPi = Math.sqrt(2*Math.PI)

	# @param [Number] mean: expected value
	# @param [Number] sigma: standard deviation
	# @param [Number] x: parameter
	# @return [Number] value (at *x*) of the gaussian of expected value *mean* and standard deviation *sigma*
	g.gaussian = (mean, sigma, x)->
		expf = -((x-mean)*(x-mean)/(2*sigma*sigma))
		return ( 1.0/(sigma*sqrtTwoPi) ) * Math.exp(expf)

	# check if an object has no property
	# @param map [Object] the object to test
	# @return true if there is no property, false otherwise (provided that no library overloads Object)
	g.isEmpty = (map)->
		for key, value of map
			if map.hasOwnProperty(key)
				return false
		return true

	# returns a linear interpolation of *v1* and *v2* according to *f*
	# @param v1 [Number] the first value
	# @param v2 [Number] the second value
	# @param f [Number] the parameter (between v1 and v2 ; f==0 returns v1 ; f==0.25 returns 0.75*v1+0.25*v2 ; f==0.5 returns (v1+v2)/2 ; f==1 returns v2)
	# @return a linear interpolation of *v1* and *v2* according to *f*
	g.linearInterpolation = (v1, v2, f)->
		return v1 * (1-f) + v2 * f

	g.ajax = (url, callback, type="GET")->
		xmlhttp = new RXMLHttpRequest()
		xmlhttp.onreadystatechange = ()->
			if xmlhttp.readyState == 4 and xmlhttp.status == 200
				callback()
			return
		xmlhttp.open(type, url, true)
		xmlhttp.send()
		return xmlhttp.onreadystatechange

	return g: ()-> return g