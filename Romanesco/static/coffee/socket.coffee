define [
	'utils', 'socketio', 'jquery', 'paper', 'scrollbar'
], (utils, ioo) ->

	g = utils.g()


	# websocket communication
	# websockets are only used to transfer user actions in real time, however every request which will change the database are made with ajax (at a lower frequency)
	# this is due to historical and security reasons

	# get room (string following the format: 'x: X, y: Y' X and Y being the coordinates of the view in project coordinates quantized by g.scale)
	# if current room is different: emit "join" room
	g.updateRoom = ()->
		room = g.getChatRoom()
		if g.room != room
			g.chatRoomJ.empty().append("<span>Room: </span>" + room)
			g.chatSocket.emit("join", room)
			g.room = room

	# initialize chat: emit "nickname" (username) and on callback: initialize chat or show error
	g.startChatting = (username, realUsername=true, focusOnChat=true)->
		g.chatSocket.emit("nickname", username, (set) ->
			if set
				window.clearTimeout(g.chatConnectionTimeout)
				g.chatMainJ.removeClass("hidden")
				g.chatMainJ.find("#chatConnectingMessage").addClass("hidden")
				if realUsername
					g.chatJ.find("#chatLogin").addClass("hidden")
				else
					g.chatJ.find("#chatLogin p.default-username-message").html("You are logged as <strong>" + username + "</strong>")
				g.chatJ.find("#chatUserNameError").addClass("hidden")
				if focusOnChat then g.chatMessageJ.focus()
			else
				g.chatJ.find("#chatUserNameError").removeClass("hidden")
		)

	# todo: add a "n new messages" message at the bottom of the chat box when a user has new messages and he does not focus the chat
	# initialize socket:
	g.initSocket = ()->

		# initialize jQuery objects
		g.chatJ = g.sidebarJ.find("#chatContent")
		g.chatMainJ = g.chatJ.find("#chatMain")
		g.chatRoomJ = g.chatMainJ.find("#chatRoom")
		g.chatUsernamesJ = g.chatMainJ.find("#chatUserNames")
		g.chatMessagesJ = g.chatMainJ.find("#chatMessages")
		# g.chatMessagesScrollJ = g.chatMainJ.find("#chatMessagesScroll")
		g.chatMessageJ = g.chatMainJ.find("#chatSendMessageInput")
		g.chatMessageJ.blur()
		# g.chatMessagesScrollJ.nanoScroller()

		# add message to chat message box
		# scroll sidebar and message box to bottom (depending on who is talking)
		# @param [String] message to add
		# @param [String] (optional) username of the author of the message
		# 				  if *from* is set to g.me, "me" is append before the message,
		# 				  if *from* is set to another user, *from* is append before the message,
		# 				  if *from* is not set, nothing is append before the message
		addMessage = (message, from=null) ->
			if from?
				author = if from == g.me then "me" else from
				g.chatMessagesJ.append( $("<p>").append($("<b>").text(author + ": "), message) )
			else
				g.chatMessagesJ.append( $("<p>").append(message) )
			g.chatMessageJ.val('')

			# if I am the one talking: scroll both sidebar and chat box to bottom
			if from == g.me
				$("#chatMessagesScroll").mCustomScrollbar("scrollTo","bottom")
				$(".sidebar-scrollbar.chatMessagesScroll").mCustomScrollbar("scrollTo","bottom")
			# else if anything in the chat is active: scroll the chat box to bottom
			else if $(document.activeElement).parents("#Chat").length>0
				$("#chatMessagesScroll").mCustomScrollbar("scrollTo","bottom")
			return

		g.chatSocket = io.connect("/chat")

		# on connect: update room (join the room "x: X, y: Y")
		g.chatSocket.on "connect", ->
			g.updateRoom()
			return

		# on annoucement:
		g.chatSocket.on "announcement", (msg) ->
			addMessage(msg)
			return

		# on nicknames:
		g.chatSocket.on "nicknames", (nicknames) ->
			g.chatUsernamesJ.empty().append $("<span>Online: </span>")
			for i of nicknames
				g.chatUsernamesJ.append $("<b>").text( if i>0 then ', ' + nicknames[i] else nicknames[i] )
			return

		# on message to room
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

		# emit "user message" and add message to chat box
		sendMessage = ()->
			g.chatSocket.emit( "user message", g.chatMessageJ.val() )
			addMessage( g.chatMessageJ.val(), g.me)
			return

		g.chatMainJ.find("#chatSendMessageSubmit").submit( () -> sendMessage() )

		# on key press: send message if key is return
		g.chatMessageJ.keypress( (event) ->
			if event.which == 13
				event.preventDefault()
				sendMessage()
		)

		connectionError = ()->
			g.chatMainJ.find("#chatConnectingMessage").text("Impossible to connect to chat.")

		g.chatConnectionTimeout = setTimeout(connectionError, 2000)

		# if user not logged: ask for username, start chatting when user entered a username
		if g.chatJ.find("#chatUserNameInput").length>0

			g.chatJ.find("a.sign-in").click (event)->
				$("#user-login-group > button").click()
				event.preventDefault()
				return false

			g.chatJ.find("a.change-username").click (event)->
				$("#chatUserName").show()
				$("#chatUserNameInput").focus()
				event.preventDefault()
				return false

			usernameJ = g.chatJ.find("#chatUserName")

			submitChatUserName = (username, focusOnChat=true)->
				$("#chatUserName").hide()
				username ?= usernameJ.find('#chatUserNameInput').val()
				g.startChatting( username, false, focusOnChat )
				return

			usernameJ.find('#chatUserNameInput').keypress( (event) ->
				if event.which == 13
					event.preventDefault()
					submitChatUserName()
			)

			usernameJ.find("#chatUserNameSubmit").submit( (event) -> submitChatUserName() )

			adjectives = ["Cool","Masked","Bloody","Super","Mega","Giga","Ultra","Big","Blue","Black","White",
			"Red","Purple","Golden","Silver","Dangerous","Crazy","Fast","Quick","Little","Funny","Extreme",
			"Awsome","Outstanding","Crunchy","Vicious","Zombie","Funky","Sweet"]

			things = ["Hamster","Moose","Lama","Duck","Bear","Eagle","Tiger","Rocket","Bullet","Knee",
			"Foot","Hand","Fox","Lion","King","Queen","Wizard","Elephant","Thunder","Storm","Lumberjack",
			"Pistol","Banana","Orange","Pinapple","Sugar","Leek","Blade"]

			username = adjectives.random() + " " + things.random()

			submitChatUserName(username, false)

		## Tool creation websocket messages
		# on begin, update and end: call *tool*.begin(objectToEvent(*event*), *from*, *data*)

		# g.chatSocket.on "begin", (from, event, tool, data) ->
		# 	# if from == g.me then return	# should not be necessary since "emit_to_room" from gevent socektio's Room mixin send it to everybody except the sender
		# 	console.log "begin"
		# 	g.tools[tool].begin(objectToEvent(event), from, data)
		# 	return

		# g.chatSocket.on "update", (from, event, tool) ->
		# 	console.log "update"
		# 	g.tools[tool].update(objectToEvent(event), from)
		# 	view.update()
		# 	return

		# g.chatSocket.on "end", (from, event, tool) ->
		# 	console.log "end"
		# 	g.tools[tool].end(objectToEvent(event), from)
		# 	view.update()
		# 	return

		# g.chatSocket.on "setPK", (from, pid, pk) ->
		# 	console.log "setPK"
		# 	g.items[pid]?.setPK(pk, false)
		# 	return

		# g.chatSocket.on "delete", (pk) ->
		# 	console.log "delete"
		# 	g.items[pk]?.remove()
		# 	view.update()
		# 	return

		# g.chatSocket.on "beginSelect", (from, pk, event) ->
		# 	console.log "beginSelect"
		# 	g.items[pk].beginSelect(objectToEvent(event), false)
		# 	view.update()
		# 	return

		# g.chatSocket.on "updateSelect", (from, pk, event) ->
		# 	console.log "updateSelect"
		# 	g.items[pk].updateSelect(objectToEvent(event), false)
		# 	view.update()
		# 	return

		# g.chatSocket.on "doubleClick", (from, pk, event) ->
		# 	console.log "doubleClick"
		# 	g.items[pk].doubleClick(objectToEvent(event), false)
		# 	view.update()
		# 	return

		# g.chatSocket.on "endSelect", (from, pk, event) ->
		# 	console.log "endSelect"
		# 	g.items[pk].endSelect(objectToEvent(event), false)
		# 	view.update()
		# 	return

		# g.chatSocket.on "createDiv", (data) ->
		# 	console.log "createDiv"
		# 	RDiv.saveCallback(data, false)

		# g.chatSocket.on "deleteDiv", (pk) ->
		# 	console.log "deleteDiv"
		# 	g.items[pk]?.remove()
		# 	view.update()
		# 	return

		# on car move: create car (Raster) if the car for this user does not exist, and update position, rotation and speed.
		# the car will be removed if it is not updated for 1 second
		g.chatSocket.on "car move", (user, position, rotation, speed)->
			if g.ignoreSockets then return
			g.cars[user] ?= new Raster("/static/images/car.png")
			g.cars[user].position = new Point(position)
			g.cars[user].rotation = rotation
			g.cars[user].speed = speed
			g.cars[user].rLastUpdate = Date.now()
			return

		# # on parameter change:
		# # set items[pk].data[name] to value and call parameterChanged
		# # experimental *type* == 'rFunction' to call a custom function of the item
		# g.chatSocket.on "parameterChange", (from, pk, name, value, type=null) ->
		# 	if type != "rFunction"
		# 		g.items[pk].setParameter(name, value)
		# 	else
		# 		g.items[pk][name]?(false, value)
		# 	view.update()
		# 	return

		g.chatSocket.on "bounce", (data) ->
			if g.ignoreSockets then return
			if data.function? and data.arguments?
				if data.tool?
					tool = g.tools[data.tool]
					if data.function not in ['begin', 'update', 'end', 'createPath']
						console.log 'Error: not authorized to call' + data.function
						return
					rFunction = tool?[data.function]
					if rFunction?
						data.arguments[0] = Event.prototype.fromJSON(data.arguments[0])
						rFunction.apply(tool, data.arguments)
				else if data.itemPk?
					item = g.items[data.itemPk]
					if item? and not item.currentCommand?
						allowedFunctions =
							['setRectangle', 'setRotation', 'moveTo', 'setParameter', 'modifyPoint', 'modifyPointType',
							'modifySpeed', 'setPK', 'delete', 'create', 'addPoint', 'deletePoint', 'modifyControlPath', 'setText']
						if data.function not in allowedFunctions
							console.log 'Error: not authorized to call: ' + data.function
							return
						rFunction = item[data.function]
						if not rFunction?
							console.log 'Error: function is not valid: ' + data.function
							return

						id = 'rasterizeItem-'+item.pk

						itemMustBeRasterized = data.function not in ['setPK', 'create'] and not item.drawing.visible

						if not g.updateTimeout[id]? and itemMustBeRasterized
							g.rasterizer.drawItems()
							g.rasterizer.rasterize(item, true)

						item.drawing.visible = true

						item.socketAction = true
						rFunction.apply(item, data.arguments)
						delete item.socketAction

						if itemMustBeRasterized and data.function not in ['delete']
							rasterizeItem = ()->
								if not item.currentCommand then g.rasterizer.rasterize(item)
								return
							g.deferredExecution(rasterizeItem, id, 1000)
				else if data.itemClass and data.function == 'create'
					itemClass = g[data.itemClass]
					if RItem.prototype.isPrototypeOf(itemClass)
						itemClass.socketAction = true
						itemClass.create.apply(itemClass, data.arguments)
				view.update()
			return

	return