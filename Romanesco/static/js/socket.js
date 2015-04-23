// Generated by CoffeeScript 1.7.1
(function() {
  var __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  define(['utils', 'socketio', 'jquery', 'paper', 'scrollbar'], function(utils, ioo) {
    var g;
    g = utils.g();
    g.updateRoom = function() {
      var room;
      room = g.getChatRoom();
      if (g.room !== room) {
        g.chatRoomJ.empty().append("<span>Room: </span>" + room);
        g.chatSocket.emit("join", room);
        return g.room = room;
      }
    };
    g.startChatting = function(username, realUsername, focusOnChat) {
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
    g.initSocket = function() {
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
      g.chatSocket.on("car move", function(user, position, rotation, speed) {
        var _base;
        if (g.ignoreSockets) {
          return;
        }
        if ((_base = g.cars)[user] == null) {
          _base[user] = new Raster("/static/images/car.png");
        }
        g.cars[user].position = new Point(position);
        g.cars[user].rotation = rotation;
        g.cars[user].speed = speed;
        g.cars[user].rLastUpdate = Date.now();
      });
      return g.chatSocket.on("bounce", function(data) {
        var allowedFunctions, id, item, itemClass, itemMustBeRasterized, rFunction, rasterizeItem, tool, _ref, _ref1, _ref2, _ref3;
        if (g.ignoreSockets) {
          return;
        }
        if ((data["function"] != null) && (data["arguments"] != null)) {
          if (data.tool != null) {
            tool = g.tools[data.tool];
            if ((_ref = data["function"]) !== 'begin' && _ref !== 'update' && _ref !== 'end' && _ref !== 'createPath') {
              console.log('Error: not authorized to call' + data["function"]);
              return;
            }
            rFunction = tool != null ? tool[data["function"]] : void 0;
            if (rFunction != null) {
              data["arguments"][0] = Event.prototype.fromJSON(data["arguments"][0]);
              rFunction.apply(tool, data["arguments"]);
            }
          } else if (data.itemPk != null) {
            item = g.items[data.itemPk];
            if ((item != null) && (item.currentCommand == null)) {
              allowedFunctions = ['setRectangle', 'setRotation', 'moveTo', 'setParameter', 'modifyPoint', 'modifyPointType', 'modifySpeed', 'setPK', 'delete', 'create', 'addPoint', 'deletePoint'];
              if (_ref1 = data["function"], __indexOf.call(allowedFunctions, _ref1) < 0) {
                console.log('Error: not authorized to call: ' + data["function"]);
                return;
              }
              rFunction = item[data["function"]];
              if (rFunction == null) {
                console.log('Error: function is not valid: ' + data["function"]);
                return;
              }
              id = 'rasterizeItem-' + item.pk;
              itemMustBeRasterized = ((_ref2 = data["function"]) !== 'setPK' && _ref2 !== 'create') && !item.drawing.visible;
              if ((g.updateTimeout[id] == null) && itemMustBeRasterized) {
                g.rasterizer.drawItems();
                g.rasterizer.rasterize(item, true);
              }
              item.drawing.visible = true;
              item.socketAction = true;
              rFunction.apply(item, data["arguments"]);
              delete item.socketAction;
              if (itemMustBeRasterized && ((_ref3 = data["function"]) !== 'delete')) {
                rasterizeItem = function() {
                  if (!item.currentCommand) {
                    g.rasterizer.rasterize(item);
                  }
                };
                g.deferredExecution(rasterizeItem, id, 1000);
              }
            }
          } else if (data.itemClass && data["function"] === 'create') {
            itemClass = g[data.itemClass];
            if (RItem.prototype.isPrototypeOf(itemClass)) {
              itemClass.socketAction = true;
              itemClass.create.apply(itemClass, data["arguments"]);
            }
          }
          view.update();
        }
      });
    };
  });

}).call(this);

//# sourceMappingURL=socket.map
