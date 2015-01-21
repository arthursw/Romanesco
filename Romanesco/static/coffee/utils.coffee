this.g = this

# @return [Number] sign of *x* (+1 or -1)
this.sign = (x) ->
	(if typeof x is "number" then (if x then (if x < 0 then -1 else 1) else (if x is x then 0 else NaN)) else NaN)

# @return [Number] *value* clamped with *min* and *max* ( so that min <= value <= max )
this.clamp = (min, value, max)->
	return Math.min(Math.max(value, min), max)

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

# @return [Array item] random element of then array
Array.prototype.random = () ->
	return this[Math.floor(Math.random()*this.length)]

# previously Array.prototype.pushIfAbsent, but there seem to be a colision with jQuery... 
# push if array does not contain item
this.pushIfAbsent = (array, item) ->
	if array.indexOf(item)<0 then array.push(item)
	return

# Execute *callback* after *n* milliseconds, reset the delay timer at each call
# @param [function] callback function
# @param [Anything] a unique id (usually the id or pk of RItems) to avoid collisions between deffered executions
# @param [Number] delay before *callback* is called
this.defferedExecution = (callback, id, n=500) ->
	id ?= callback
	# console.log "defferedExecution: " + id + ", updateTimeout[id]: " + g.updateTimeout[id]
	if g.updateTimeout[id]? then clearTimeout(g.updateTimeout[id])
	g.updateTimeout[id] = setTimeout(callback, n)

sqrtTwoPi = Math.sqrt(2*Math.PI)

# @param [Number] mean: expected value
# @param [Number] sigma: standard deviation
# @param [Number] x: parameter
# @return [Number] value (at *x*) of the gaussian of expected value *mean* and standard deviation *sigma*
this.gaussian = (mean, sigma, x)->
	expf = -((x-mean)*(x-mean)/(2*sigma*sigma))
	return ( 1.0/(sigma*sqrtTwoPi) ) * Math.exp(expf)

# check if an object has no property
# @param map [Object] the object to test
# @return true if there is no property, false otherwise (provided that no library overloads Object)
this.isEmpty = (map)->
	for key, value of map
		if map.hasOwnProperty(key)
			return false
	return true
