// Generated by CoffeeScript 1.7.1
(function() {
  this.updateRoom = function() {
    var room;
    room = g.getChatRoom();
    if (g.room !== room) {
      g.chatRoomJ.empty().append("<span>Room: </span>" + room);
      g.chatSocket.emit("join", room);
      return g.room = room;
    }
  };

  this.startChatting = function(username) {
    return g.chatSocket.emit("nickname", username, function(set) {
      if (set) {
        window.clearTimeout(g.chatConnectionTimeout);
        g.chatMainJ.removeClass("hidden");
        g.chatMainJ.find("#chatConnectingMessage").addClass("hidden");
        g.chatJ.find("#chatLogin").addClass("hidden");
        g.chatJ.find("#chatUserNameError").addClass("hidden");
        return g.chatMessageJ.focus();
      } else {
        return g.chatJ.find("#chatUserNameError").removeClass("hidden");
      }
    });
  };

  this.initSocket = function() {
    var addMessage, connectionError, sendMessage, submitChatUserName, usernameJ;
    g.chatJ = g.sidebarJ.find("#chatContent");
    g.chatMainJ = g.chatJ.find("#chatMain");
    g.chatRoomJ = g.chatMainJ.find("#chatRoom");
    g.chatUsernamesJ = g.chatMainJ.find("#chatUserNames");
    g.chatMessagesJ = g.chatMainJ.find("#chatMessages");
    g.chatMessageJ = g.chatMainJ.find("#chatSendMessageInput");
    g.chatMessageJ.blur();
    addMessage = function(message, from) {
      var author;
      if (from == null) {
        from = null;
      }
      if (from != null) {
        author = from === g.me ? "me" : from;
        g.chatMessagesJ.append($("<p>").append($("<b>").text(author + ": "), message));
      } else {
        g.chatMessagesJ.append($("<p>").append(message));
      }
      g.chatMessageJ.val('');
      if (from === g.me) {
        $(".mCustomScrollbar").mCustomScrollbar("scrollTo", "bottom");
      } else if ($(document.activeElement).parents("#Chat").length > 0) {
        $("#chatMessagesScroll").mCustomScrollbar("scrollTo", "bottom");
      }
    };
    g.chatSocket = io.connect("/chat");
    g.chatSocket.on("connect", function() {
      g.updateRoom();
    });
    g.chatSocket.on("announcement", function(msg) {
      addMessage(msg);
    });
    g.chatSocket.on("nicknames", function(nicknames) {
      var i;
      g.chatUsernamesJ.empty().append($("<span>Online: </span>"));
      for (i in nicknames) {
        g.chatUsernamesJ.append($("<b>").text(i > 0 ? ', ' + nicknames[i] : nicknames[i]));
      }
    });
    g.chatSocket.on("msg_to_room", function(from, msg) {
      addMessage(msg, from);
    });
    g.chatSocket.on("reconnect", function() {
      g.chatMessagesJ.remove();
      addMessage("Reconnected to the server", "System");
    });
    g.chatSocket.on("reconnecting", function() {
      addMessage("Attempting to re-connect to the server", "System");
    });
    g.chatSocket.on("error", function(e) {
      addMessage((e ? e : "A unknown error occurred"), "System");
    });
    sendMessage = function() {
      g.chatSocket.emit("user message", g.chatMessageJ.val());
      addMessage(g.chatMessageJ.val(), g.me);
    };
    g.chatMainJ.find("#chatSendMessageSubmit").submit(function() {
      return sendMessage();
    });
    g.chatMessageJ.keypress(function(event) {
      if (event.which === 13) {
        event.preventDefault();
        return sendMessage();
      }
    });
    connectionError = function() {
      return g.chatMainJ.find("#chatConnectingMessage").text("Impossible to connect to chat.");
    };
    g.chatConnectionTimeout = setTimeout(connectionError, 2000);
    if (g.chatJ.find("#chatUserNameInput").length > 0) {
      usernameJ = g.chatJ.find("#chatUserName");
      submitChatUserName = function() {
        g.startChatting(usernameJ.find('#chatUserNameInput').val());
      };
      usernameJ.find('#chatUserNameInput').keypress(function(event) {
        if (event.which === 13) {
          event.preventDefault();
          return submitChatUserName();
        }
      });
      usernameJ.find("#chatUserNameSubmit").submit(function(event) {
        return submitChatUserName();
      });
    }
    g.chatSocket.on("begin", function(from, event, tool, data) {
      console.log("begin");
      g.tools[tool].begin(objectToEvent(event), from, data);
    });
    g.chatSocket.on("update", function(from, event, tool) {
      console.log("update");
      g.tools[tool].update(objectToEvent(event), from);
      view.draw();
    });
    g.chatSocket.on("end", function(from, event, tool) {
      console.log("end");
      g.tools[tool].end(objectToEvent(event), from);
      view.draw();
    });
    g.chatSocket.on("setPathPK", function(from, pid, pk) {
      var _ref;
      console.log("setPathPK");
      if ((_ref = g.paths[pid]) != null) {
        _ref.setPK(pk, false);
      }
    });
    g.chatSocket.on("deletePath", function(pk) {
      var _ref;
      console.log("deletePath");
      if ((_ref = g.paths[pk]) != null) {
        _ref.remove();
      }
      view.draw();
    });
    g.chatSocket.on("selectBegin", function(from, pk, event) {
      console.log("selectBegin");
      g.items[pk].selectBegin(objectToEvent(event), false);
      view.draw();
    });
    g.chatSocket.on("selectUpdate", function(from, pk, event) {
      console.log("selectUpdate");
      g.items[pk].selectUpdate(objectToEvent(event), false);
      view.draw();
    });
    g.chatSocket.on("doubleClick", function(from, pk, event) {
      console.log("doubleClick");
      g.items[pk].doubleClick(objectToEvent(event), false);
      view.draw();
    });
    g.chatSocket.on("selectEnd", function(from, pk, event) {
      console.log("selectEnd");
      g.items[pk].selectEnd(objectToEvent(event), false);
      view.draw();
    });
    g.chatSocket.on("createDiv", function(data) {
      console.log("createDiv");
      return RDiv.save_callback(data, false);
    });
    g.chatSocket.on("deleteDiv", function(pk) {
      var _ref;
      console.log("deleteDiv");
      if ((_ref = g.items[pk]) != null) {
        _ref.remove();
      }
      view.draw();
    });
    g.chatSocket.on("car move", function(user, position, rotation, speed) {
      var _base;
      if ((_base = g.cars)[user] == null) {
        _base[user] = new Raster("/static/images/car.png");
      }
      g.cars[user].position = new Point(position);
      g.cars[user].rotation = rotation;
      g.cars[user].speed = speed;
      g.cars[user].rLastUpdate = Date.now();
    });
    g.chatSocket.on("parameterChange", function(from, pk, name, value, type) {
      var _base;
      if (type == null) {
        type = null;
      }
      if (type !== "rFunction") {
        g.items[pk].data[name] = value;
        g.items[pk].changed = name;
        g.items[pk].parameterChanged(false);
      } else {
        if (typeof (_base = g.items[pk])[name] === "function") {
          _base[name](false, value);
        }
      }
      view.draw();
    });
    return g.chatSocket.on("bounce", function(data) {
      console.log("bounce");
      if ((data.tool != null) && (data["function"] != null)) {
        g.tools[data.tool][data["function"]](data["arguments"]);
      }
      view.draw();
    });
  };

}).call(this);

//# sourceMappingURL=socket.map
