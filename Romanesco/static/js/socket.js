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

  this.startChatting = function(username, realUsername, focusOnChat) {
    if (realUsername == null) {
      realUsername = true;
    }
    if (focusOnChat == null) {
      focusOnChat = true;
    }
    return g.chatSocket.emit("nickname", username, function(set) {
      if (set) {
        window.clearTimeout(g.chatConnectionTimeout);
        g.chatMainJ.removeClass("hidden");
        g.chatMainJ.find("#chatConnectingMessage").addClass("hidden");
        if (realUsername) {
          g.chatJ.find("#chatLogin").addClass("hidden");
        } else {
          g.chatJ.find("#chatLogin p.default-username-message").html("You are logged as <strong>" + username + "</strong>");
        }
        g.chatJ.find("#chatUserNameError").addClass("hidden");
        if (focusOnChat) {
          return g.chatMessageJ.focus();
        }
      } else {
        return g.chatJ.find("#chatUserNameError").removeClass("hidden");
      }
    });
  };

  this.initSocket = function() {
    var addMessage, adjectives, connectionError, sendMessage, submitChatUserName, things, username, usernameJ;
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
        $("#chatMessagesScroll").mCustomScrollbar("scrollTo", "bottom");
        $(".sidebar-scrollbar.chatMessagesScroll").mCustomScrollbar("scrollTo", "bottom");
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
      g.chatJ.find("a.sign-in").click(function(event) {
        $("#user-login-group > button").click();
        event.preventDefault();
        return false;
      });
      g.chatJ.find("a.change-username").click(function(event) {
        $("#chatUserName").show();
        $("#chatUserNameInput").focus();
        event.preventDefault();
        return false;
      });
      usernameJ = g.chatJ.find("#chatUserName");
      submitChatUserName = function(username, focusOnChat) {
        if (focusOnChat == null) {
          focusOnChat = true;
        }
        $("#chatUserName").hide();
        if (username == null) {
          username = usernameJ.find('#chatUserNameInput').val();
        }
        g.startChatting(username, false, focusOnChat);
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
      adjectives = ["Cool", "Masked", "Bloody", "Super", "Mega", "Giga", "Ultra", "Big", "Blue", "Black", "White", "Red", "Purple", "Golden", "Silver", "Dangerous", "Crazy", "Fast", "Quick", "Little", "Funny", "Extreme", "Awsome", "Outstanding", "Crunchy", "Vicious", "Zombie", "Funky", "Sweet"];
      things = ["Hamster", "Moose", "Lama", "Duck", "Bear", "Eagle", "Tiger", "Rocket", "Bullet", "Knee", "Foot", "Hand", "Fox", "Lion", "King", "Queen", "Wizard", "Elephant", "Thunder", "Storm", "Lumberjack", "Pistol", "Banana", "Orange", "Pinapple", "Sugar", "Leek", "Blade"];
      username = adjectives.random() + " " + things.random();
      submitChatUserName(username, false);
    }
    g.chatSocket.on("begin", function(from, event, tool, data) {
      console.log("begin");
      g.tools[tool].begin(objectToEvent(event), from, data);
    });
    g.chatSocket.on("update", function(from, event, tool) {
      console.log("update");
      g.tools[tool].update(objectToEvent(event), from);
      view.update();
    });
    g.chatSocket.on("end", function(from, event, tool) {
      console.log("end");
      g.tools[tool].end(objectToEvent(event), from);
      view.update();
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
      view.update();
    });
    g.chatSocket.on("beginSelect", function(from, pk, event) {
      console.log("beginSelect");
      g.items[pk].beginSelect(objectToEvent(event), false);
      view.update();
    });
    g.chatSocket.on("updateSelect", function(from, pk, event) {
      console.log("updateSelect");
      g.items[pk].updateSelect(objectToEvent(event), false);
      view.update();
    });
    g.chatSocket.on("doubleClick", function(from, pk, event) {
      console.log("doubleClick");
      g.items[pk].doubleClick(objectToEvent(event), false);
      view.update();
    });
    g.chatSocket.on("endSelect", function(from, pk, event) {
      console.log("endSelect");
      g.items[pk].endSelect(objectToEvent(event), false);
      view.update();
    });
    g.chatSocket.on("createDiv", function(data) {
      console.log("createDiv");
      return RDiv.saveCallback(data, false);
    });
    g.chatSocket.on("deleteDiv", function(pk) {
      var _ref;
      console.log("deleteDiv");
      if ((_ref = g.items[pk]) != null) {
        _ref.remove();
      }
      view.update();
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
        g.items[pk].changeParameter(name, value);
      } else {
        if (typeof (_base = g.items[pk])[name] === "function") {
          _base[name](false, value);
        }
      }
      view.update();
    });
    return g.chatSocket.on("bounce", function(data) {
      console.log("bounce");
      if ((data.tool != null) && (data["function"] != null)) {
        g.tools[data.tool][data["function"]](data["arguments"]);
      }
      view.update();
    });
  };

}).call(this);

//# sourceMappingURL=socket.map
