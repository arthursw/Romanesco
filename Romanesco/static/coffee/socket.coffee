this.updateRoom = ()->
	room = g.getChatRoom()
	if g.room != room
		g.chatRoomJ.empty().append("<span>Room: </span>" + room)
		g.chatSocket.emit("join", room)
		g.room = room

this.startChatting = (username)->
	g.chatSocket.emit("nickname", username, (set) ->
		if set
			window.clearTimeout(g.chatConnectionTimeout)
			g.chatMainJ.removeClass("hidden")
			g.chatMainJ.find("#chatConnectingMessage").addClass("hidden")
			g.chatJ.find("#chatLogin").addClass("hidden")
			g.chatJ.find("#chatUserNameError").addClass("hidden")
			g.chatMessageJ.focus()
		else
			g.chatJ.find("#chatUserNameError").removeClass("hidden")
	)

# todo: add a "n new messages" message at the bottom of the chat box when a user has new messages and he does not focus the chat
this.initSocket = ()->

	g.chatJ = g.sidebarJ.find("#chatContent")
	g.chatMainJ = g.chatJ.find("#chatMain")
	g.chatRoomJ = g.chatMainJ.find("#chatRoom")
	g.chatUsernamesJ = g.chatMainJ.find("#chatUserNames")
	g.chatMessagesJ = g.chatMainJ.find("#chatMessages")
	# g.chatMessagesScrollJ = g.chatMainJ.find("#chatMessagesScroll")
	g.chatMessageJ = g.chatMainJ.find("#chatSendMessageInput")
	g.chatMessageJ.blur()
	# g.chatMessagesScrollJ.nanoScroller()

	addMessage = (message, from=null) ->
		if from?
			author = if from == g.me then "me" else from
			g.chatMessagesJ.append( $("<p>").append($("<b>").text(author + ": "), message) )
		else
			g.chatMessagesJ.append( $("<p>").append(message) )
		g.chatMessageJ.val('')

		if from == g.me
			$(".mCustomScrollbar").mCustomScrollbar("scrollTo","bottom")
		else if $(document.activeElement).parents("#Chat").length>0
			$("#chatMessagesScroll").mCustomScrollbar("scrollTo","bottom")
		return

	g.chatSocket = io.connect("/chat")

	g.chatSocket.on "connect", ->
		g.updateRoom()
		return

	g.chatSocket.on "announcement", (msg) ->
		addMessage(msg)
		return

	g.chatSocket.on "nicknames", (nicknames) ->
		g.chatUsernamesJ.empty().append $("<span>Online: </span>")
		for i of nicknames
			g.chatUsernamesJ.append $("<b>").text( if i>0 then ', ' + nicknames[i] else nicknames[i] )
		return

	g.chatSocket.on "msg_to_room", (from, msg) ->
		addMessage(msg, from)
		return

	g.chatSocket.on "reconnect", ->
		g.chatMessagesJ.remove()
		addMessage("Reconnected to the server", "System")
		return

	g.chatSocket.on "reconnecting", ->
		addMessage("Attempting to re-connect to the server", "System")
		return

	g.chatSocket.on "error", (e) ->
		addMessage((if e then e else "A unknown error occurred"), "System")
		return

	sendMessage = ()->
		g.chatSocket.emit( "user message", g.chatMessageJ.val() )
		addMessage( g.chatMessageJ.val(), g.me)
		return

	g.chatMainJ.find("#chatSendMessageSubmit").submit( () -> sendMessage() )

	g.chatMessageJ.keypress( (event) -> 
		if event.which == 13
			event.preventDefault()
			sendMessage()
	)

	connectionError = ()->
		g.chatMainJ.find("#chatConnectingMessage").text("Impossible to connect to chat.")
	
	g.chatConnectionTimeout = setTimeout(connectionError, 2000)

	# if user not logged: ask for username and start chatting
	if g.chatJ.find("#chatUserNameInput").length>0
		usernameJ = g.chatJ.find("#chatUserName")

		submitChatUserName = ()->
			g.startChatting( usernameJ.find('#chatUserNameInput').val() )
			return

		usernameJ.find('#chatUserNameInput').keypress( (event) -> 
			if event.which == 13
				event.preventDefault()
				submitChatUserName()
		)

		usernameJ.find("#chatUserNameSubmit").submit( (event) -> submitChatUserName() )

	g.chatSocket.on "begin", (from, event, tool, data) ->
		# if from == g.me then return	# should not be necessary since "emit_to_room" from gevent socektio's Room mixin send it to everybody except the sender
		console.log "begin"
		g.tools[tool].begin(parseEventObj(event), from, data)
		return

	g.chatSocket.on "update", (from, event, tool) ->
		console.log "update"
		g.tools[tool].update(parseEventObj(event), from)
		view.draw()
		return

	g.chatSocket.on "end", (from, event, tool) ->
		console.log "end"
		g.tools[tool].end(parseEventObj(event), from)
		view.draw()
		return

	g.chatSocket.on "setPathPK", (from, pid, pk) ->
		console.log "setPathPK"
		g.paths[pid]?.setPK(pk, false)
		return

	g.chatSocket.on "deletePath", (pk) ->
		console.log "deletePath"
		g.paths[pk]?.remove()
		view.draw()
		return

	g.chatSocket.on "selectBegin", (from, pk, event) ->
		console.log "selectBegin"
		g.items[pk].selectBegin(parseEventObj(event), false)
		view.draw()
		return

	g.chatSocket.on "selectUpdate", (from, pk, event) ->
		console.log "selectUpdate"
		g.items[pk].selectUpdate(parseEventObj(event), false)
		view.draw()
		return

	g.chatSocket.on "doubleClick", (from, pk, event) ->
		console.log "doubleClick"
		g.items[pk].doubleClick(parseEventObj(event), false)
		view.draw()
		return

	g.chatSocket.on "selectEnd", (from, pk, event) ->
		console.log "selectEnd"
		g.items[pk].selectEnd(parseEventObj(event), false)
		view.draw()
		return

	g.chatSocket.on "createDiv", (data) ->
		console.log "createDiv"
		RDiv.save_callback(data, false)

	g.chatSocket.on "deleteDiv", (pk) ->
		console.log "deleteDiv"
		g.items[pk]?.remove()
		view.draw()
		return

	g.chatSocket.on "car move", (user, position, rotation, speed)->
		g.cars[user] ?= new Raster("/static/images/car.png")
		g.cars[user].position = new Point(position)
		g.cars[user].rotation = rotation
		g.cars[user].speed = speed
		g.cars[user].rLastUpdate = Date.now()
		return

	g.chatSocket.on "parameterChange", (from, pk, name, value, type=null) ->
		if type != "rFunction"
			g.items[pk].data[name] = value
			g.items[pk].changed = name
			g.items[pk].parameterChanged(false)
		else
			g.items[pk][name]?(false, value)
		view.draw()
		return

	g.chatSocket.on "bounce", (data) ->
		console.log "bounce"
		if data.tool? and data.function?
			g.tools[data.tool][data.function](data.arguments)
		view.draw()
		return

