define [
	'utils'
], (utils) ->

	g = utils.g()
	## RSound
	# small helper class to load and play a sound file
	class RSound
		window.AudioContext = window.AudioContext || window.webkitAudioContext
		@context = new AudioContext()

		# @param urlList [Array<String>] the list of urls of the files to load. (one sound file, many formats: list of urls to each format of the same file)
		#                                The first url will be loaded, and taken as source if the load succeeds.
		#                                Otherwise the second url will be loaded and so on until a file succeeds or all urls have been tested.
		# @param onLoadCallback [function] called after the file is loaded
		constructor: (@urlList, @onLoadCallback)->
			@context = @constructor.context
			@load()
			return

		# load the file starting from the first url
		load: ()->
			@loadBuffer(0)
			return

		# load the url number *index*
		# this will be called with *index+1* if decoding fails
		# @bufferOnLoad will be called on success
		# @param index [Number] index of the url to load
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

		# buffer load callback: decode the audio data
		# @bufferOnDecoded is called on success
		# @param response [XMLHttpRequest response] XMLHttpRequest response
		bufferOnLoad: (response)=>
			@context.decodeAudioData( response, @bufferOnDecoded, @bufferOnError )
			return

		# buffer decoded callback:
		# store buffer if decoding was successful
		# load next url otherwise
		# play sound if @playOnLoad is true
		# @param buffer [Buffer] the newly created buffer
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

		# buffer decode error callback: display error if any
		bufferOnError: (error)->
			console.error 'decodeAudioData', error

		# Create buffer source, connect it to the context destination and start at *time* (play the sound)
		# a gain node is also created to control the volume
		# the sound is looped by default
		# the sound does not restart if it is already playing
		play: (time=0)->
			if not @buffer? 		# returns if @buffer is not created yet (not decoded) and set @playOnLoad to play the sound as soon as it is loaded
				@playOnLoad = time
				return
			if @isPlaying then return
			# create the sound source
			@source = @context.createBufferSource()
			@source.buffer = @buffer
			@source.connect(@context.destination)
			@source.loop = true
			# create the gain node to control the volume
			@gainNode = @context.createGain()
			@source.connect(@gainNode)
			@gainNode.connect(@context.destination)
			@gainNode.gain.value = @volume
			# play the sound
			@source.start(time)
			@isPlaying = true 		# a boolean to avoid restarting the sound if play is called before sound is stopped or finished
			@source.onended = ()=> 	# called when sound has finished playing or @source.stop() was called (for example in @stop())
				@isPlaying = false
				return
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

	g.RSound = RSound
	return