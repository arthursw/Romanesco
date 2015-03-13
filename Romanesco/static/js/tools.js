// Generated by CoffeeScript 1.7.1
(function() {
  var CarTool, CodeTool, ItemTool, LockTool, MediaTool, MoveTool, PathTool, RTool, ScreenshotTool, SelectTool, TextTool,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  RTool = (function() {

    /*
    	parameters = 
    		'First folder':
    			firstParameter:
    				type: 'slider' 									# type is only required when adding a color (then it must be 'color') or a string input (then it must be 'string')
    																 * if type is 'string' and there is no onChange nor onFinishChange callback:
    																 * the default onChange callback will be called on onFinishChange since we often want to update only when the change is finished
    																 * to override this behaviour, 'fireOnEveryChange' can be set to true or onChange and onFinishChange can be defined
    				label: 'Name of the parameter'					# label of the controller (name displayed in the gui)
    				value: 0										# value (deprecated)
    				default: 0 										# default value
    				step: 5 										# values will be incremented/decremented by step
    				min: 0 											# minimum value
    				max: 100 										# maximum value
    				simplified: 0 									# value during the simplified mode (useful to quickly draw an RPath, for example when modifying a curve)
    				defaultFunction: () -> 							# called to get a default value
    				addController: true 							# if true: adds the dat.gui controller to the item or the selected tool
    				onChange: (value)->  							# called when controller changes
    				onFinishChange: (value)-> 						# called when controller finishes change
    				setValue: (value, item)-> 						# called on set value of controller
    				permanent: true									# if true: the controller is never removed (always says in dat.gui)
    				defaultCheck: true 								# checked/activated by default or not
    				initializeController: (controller, item)->		# called just after controller is added to dat.gui, enables to customize the gui and add functionalities
    				fireOnEveryChange: false 						# if true and *type* is input: the default onChange callback will be called on everychange
    			secondParameter:
    				type: 'slider'
    				label: 'Second parameter'
    				value: 1
    				min: 0
    				max: 10
    		'Second folder':
    			thirdParameter:
    				type: 'slider'
    				label: 'Third parameter'
    				value: 1
    				min: 0
    				max: 10
     */
    RTool.parameters = function() {
      return {};
    };

    function RTool(name, cursorPosition, cursorDefault) {
      var description, popoverOptions;
      this.name = name;
      this.cursorPosition = cursorPosition != null ? cursorPosition : {
        x: 0,
        y: 0
      };
      this.cursorDefault = cursorDefault != null ? cursorDefault : "default";
      g.tools[this.name] = this;
      if (this.btnJ == null) {
        this.btnJ = g.toolsJ.find('li[data-type="' + this.name + '"]');
      }
      this.cursorName = this.btnJ.attr("data-cursor");
      this.btnJ.click((function(_this) {
        return function() {
          return _this.select();
        };
      })(this));
      popoverOptions = {
        placement: 'right',
        container: 'body',
        trigger: 'hover',
        delay: {
          show: 500,
          hide: 100
        }
      };
      description = this.description();
      if (description == null) {
        popoverOptions.content = this.name;
      } else {
        popoverOptions.title = this.name;
        popoverOptions.content = description;
      }
      this.btnJ.popover(popoverOptions);
      return;
    }

    RTool.prototype.description = function() {
      return null;
    };

    RTool.prototype.select = function(constructor, selectedItem, deselectItems) {
      var differentTool, _ref;
      if (constructor == null) {
        constructor = this.constructor;
      }
      if (selectedItem == null) {
        selectedItem = null;
      }
      if (deselectItems == null) {
        deselectItems = true;
      }
      differentTool = g.previousTool !== g.selectedTool;
      if (this !== g.selectedTool) {
        g.previousTool = g.selectedTool;
      }
      if ((_ref = g.selectedTool) != null) {
        _ref.deselect();
      }
      g.selectedTool = this;
      if (this.cursorName != null) {
        g.stageJ.css('cursor', 'url(static/images/cursors/' + this.cursorName + '.png) ' + this.cursorPosition.x + ' ' + this.cursorPosition.y + ',' + this.cursorDefault);
      } else {
        g.stageJ.css('cursor', this.cursorDefault);
      }
      if (deselectItems) {
        g.deselectAll();
      }
      g.updateParameters({
        tool: constructor,
        item: selectedItem
      }, differentTool);
    };

    RTool.prototype.deselect = function() {};

    RTool.prototype.begin = function(event) {};

    RTool.prototype.update = function(event) {};

    RTool.prototype.move = function(event) {};

    RTool.prototype.end = function(event) {};

    RTool.prototype.disableSnap = function() {
      return false;
    };

    return RTool;

  })();

  this.RTool = RTool;

  CodeTool = (function(_super) {
    __extends(CodeTool, _super);

    function CodeTool() {
      CodeTool.__super__.constructor.call(this, "Script");
      return;
    }

    CodeTool.prototype.select = function() {
      CodeTool.__super__.select.call(this);
      g.toolEditor();
    };

    return CodeTool;

  })(RTool);

  this.CodeTool = CodeTool;

  MoveTool = (function(_super) {
    __extends(MoveTool, _super);

    function MoveTool() {
      MoveTool.__super__.constructor.call(this, "Move", {
        x: 32,
        y: 32
      }, "move");
      this.prevPoint = {
        x: 0,
        y: 0
      };
      this.dragging = false;
      return;
    }

    MoveTool.prototype.select = function() {
      var div, _i, _len, _ref;
      MoveTool.__super__.select.call(this, this.constructor, null, false);
      g.stageJ.addClass("moveTool");
      _ref = g.divs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        div = _ref[_i];
        div.disableInteraction();
      }
    };

    MoveTool.prototype.deselect = function() {
      var div, _i, _len, _ref;
      MoveTool.__super__.deselect.call(this);
      g.stageJ.removeClass("moveTool");
      _ref = g.divs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        div = _ref[_i];
        div.enableInteraction();
      }
    };

    MoveTool.prototype.begin = function(event) {};

    MoveTool.prototype.update = function(event) {};

    MoveTool.prototype.end = function(event) {};

    MoveTool.prototype.beginNative = function(event) {
      this.dragging = true;
      this.prevPoint = {
        x: event.pageX,
        y: event.pageY
      };
    };

    MoveTool.prototype.updateNative = function(event) {
      if (this.dragging) {
        g.RMoveBy({
          x: (this.prevPoint.x - event.pageX) / view.zoom,
          y: (this.prevPoint.y - event.pageY) / view.zoom
        });
        this.prevPoint = {
          x: event.pageX,
          y: event.pageY
        };
      }
    };

    MoveTool.prototype.endNative = function(event) {
      this.dragging = false;
    };

    return MoveTool;

  })(RTool);

  this.MoveTool = MoveTool;

  CarTool = (function(_super) {
    __extends(CarTool, _super);

    CarTool.parameters = function() {
      var parameters;
      parameters = {
        'Car': {
          speed: {
            type: 'string',
            label: 'Speed',
            value: '0',
            addController: true,
            onChange: function() {}
          },
          volume: {
            type: 'slider',
            label: 'Volume',
            value: 1,
            min: 0,
            max: 10,
            onChange: function(value) {
              if (g.selectedTool.constructor.name === "CarTool") {
                if (value > 0) {
                  if (!g.sound.isPlaying) {
                    g.sound.play();
                    g.sound.setLoopStart(3.26);
                    g.sound.setLoopEnd(5.22);
                  }
                  g.sound.setVolume(0.1 * value);
                } else {
                  g.sound.stop();
                }
              }
            }
          }
        }
      };
      return parameters;
    };

    function CarTool() {
      CarTool.__super__.constructor.call(this, "Car");
      return;
    }

    CarTool.prototype.select = function() {
      CarTool.__super__.select.call(this);
      this.car = new Raster("/static/images/car.png");
      g.carLayer.addChild(this.car);
      this.car.position = view.center;
      this.speed = 0;
      this.direction = new Point(0, -1);
      this.car.onLoad = (function(_this) {
        return function() {
          console.log('car loaded');
        };
      })(this);
      this.previousSpeed = 0;
      g.sound.setVolume(0.1);
      g.sound.play(0);
      g.sound.setLoopStart(3.26);
      g.sound.setLoopEnd(5.22);
      this.lastUpdate = Date.now();
    };

    CarTool.prototype.deselect = function() {
      CarTool.__super__.deselect.call(this);
      this.car.remove();
      this.car = null;
      g.sound.stop();
    };

    CarTool.prototype.onFrame = function() {
      var maxRate, maxSpeed, minRate, minSpeed, rate, _ref, _ref1, _ref2;
      if (this.car == null) {
        return;
      }
      minSpeed = 0.05;
      maxSpeed = 100;
      if (Key.isDown('right')) {
        this.direction.angle += 5;
      }
      if (Key.isDown('left')) {
        this.direction.angle -= 5;
      }
      if (Key.isDown('up')) {
        if (this.speed < maxSpeed) {
          this.speed++;
        }
      } else if (Key.isDown('down')) {
        if (this.speed > -maxSpeed) {
          this.speed--;
        }
      } else {
        this.speed *= 0.9;
        if (Math.abs(this.speed) < minSpeed) {
          this.speed = 0;
        }
      }
      minRate = 0.25;
      maxRate = 3;
      rate = minRate + Math.abs(this.speed) / maxSpeed * (maxRate - minRate);
      g.sound.setRate(rate);
      this.previousSpeed = this.speed;
      if ((_ref = this.parameterControllers) != null) {
        if ((_ref1 = _ref['speed']) != null) {
          _ref1.setValue(this.speed.toFixed(2));
        }
      }
      this.car.rotation = this.direction.angle + 90;
      if (Math.abs(this.speed) > minSpeed) {
        this.car.position = this.car.position.add(this.direction.multiply(this.speed));
        g.RMoveTo(this.car.position);
      }
      if ((_ref2 = g.gameAt(this.car.position)) != null) {
        _ref2.updateGame(this);
      }
      if (Date.now() - this.lastUpdate > 150) {
        if (g.me != null) {
          g.chatSocket.emit("car move", g.me, this.car.position, this.car.rotation, this.speed);
        }
        this.lastUpdate = Date.now();
      }
    };

    return CarTool;

  })(RTool);

  this.CarTool = CarTool;

  SelectTool = (function(_super) {
    var hitOptions;

    __extends(SelectTool, _super);

    hitOptions = {
      stroke: true,
      fill: true,
      handles: true,
      segments: true,
      curves: true,
      selected: true,
      tolerance: 5
    };

    function SelectTool() {
      SelectTool.__super__.constructor.call(this, "Select");
      this.selectedItem = null;
      return;
    }

    SelectTool.prototype.select = function() {
      var _ref;
      this.selectedItem = g.selectedItems().first();
      SelectTool.__super__.select.call(this, ((_ref = this.selectedItem) != null ? _ref.constructor : void 0) || this.constructor, this.selectedItem, false);
    };

    SelectTool.prototype.createSelectionRectangle = function(event) {
      var bounds, item, itemsToHighlight, name, rectangle, rectanglePath, _ref, _ref1;
      rectangle = new Rectangle(event.downPoint, event.point);
      if ((_ref = g.currentPaths[g.me]) != null) {
        _ref.remove();
      }
      g.currentPaths[g.me] = new Group();
      rectanglePath = new Path.Rectangle(rectangle);
      rectanglePath.name = 'select tool selection rectangle';
      rectanglePath.strokeColor = g.selectionBlue;
      rectanglePath.dashArray = [10, 4];
      g.currentPaths[g.me].addChild(rectanglePath);
      itemsToHighlight = [];
      _ref1 = g.items;
      for (name in _ref1) {
        item = _ref1[name];
        item.unhighlight();
        bounds = item.getBounds();
        if (bounds.intersects(rectangle)) {
          item.highlight();
        }
        if (rectangle.area === 0) {
          break;
        }
      }
    };

    SelectTool.prototype.emptySelectionLayer = function() {
      g.deselectAll();
      project.activeLayer.addChildren(g.selectionLayer.removeChildren());
    };

    SelectTool.prototype.begin = function(event) {
      var hitResult, name, path, _base, _ref, _ref1;
      if (event.event.which === 2) {
        return;
      }
      _ref = g.paths;
      for (name in _ref) {
        path = _ref[name];
        path.prepareHitTest();
      }
      hitResult = g.project.hitTest(event.point, hitOptions);
      _ref1 = g.paths;
      for (name in _ref1) {
        path = _ref1[name];
        path.finishHitTest();
      }
      if (hitResult && (hitResult.item.controller != null)) {
        this.selectedItem = hitResult.item.controller;
        if (!event.modifiers.shift) {
          if (g.selectionLayer.children.length > 0) {
            if (!g.selectionLayer.isAncestor(hitResult.item)) {
              this.emptySelectionLayer();
            }
          }
        }
        if (typeof (_base = hitResult.item.controller).beginSelect === "function") {
          _base.beginSelect(event);
        }
      } else {
        this.emptySelectionLayer();
        this.createSelectionRectangle(event);
      }
    };

    SelectTool.prototype.update = function(event) {
      var item, selectedItems, _i, _len;
      if (!g.currentPaths[g.me]) {
        selectedItems = g.selectedItems();
        if (selectedItems.length === 1) {
          selectedItems[0].updateSelect(event);
        } else {
          for (_i = 0, _len = selectedItems.length; _i < _len; _i++) {
            item = selectedItems[_i];
            if (typeof item.updateMoveBy === "function") {
              item.updateMoveBy(event);
            }
          }
        }
      } else {
        this.createSelectionRectangle(event);
      }
    };

    SelectTool.prototype.end = function(event) {
      var item, itemsToSelect, name, rectangle, selectedItems, _ref, _ref1;
      if (!g.currentPaths[g.me]) {
        selectedItems = g.selectedItems();
        if (selectedItems.length === 1) {
          selectedItems[0].endSelect(event);
        }
      } else {
        rectangle = new Rectangle(event.downPoint, event.point);
        itemsToSelect = [];
        _ref = g.items;
        for (name in _ref) {
          item = _ref[name];
          if (item.getBounds().intersects(rectangle)) {
            itemsToSelect.push(item);
            if (rectangle.area === 0) {
              break;
            }
          }
        }
        if (itemsToSelect.length > 0) {
          g.commandManager.add(new SelectCommand(itemsToSelect), true);
        }
        itemsToSelect = itemsToSelect.map(function(item) {
          return {
            tool: item.constructor,
            item: item
          };
        });
        g.updateParameters(itemsToSelect);
        g.currentPaths[g.me].remove();
        delete g.currentPaths[g.me];
        _ref1 = g.items;
        for (name in _ref1) {
          item = _ref1[name];
          item.unhighlight();
        }
      }
    };

    SelectTool.prototype.doubleClick = function(event) {
      var item, _i, _len, _ref;
      _ref = g.selectedItems();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (typeof item.doubleClick === "function") {
          item.doubleClick(event);
        }
      }
    };

    SelectTool.prototype.disableSnap = function() {
      return g.currentPaths[g.me] != null;
    };

    return SelectTool;

  })(RTool);

  this.SelectTool = SelectTool;

  PathTool = (function(_super) {
    __extends(PathTool, _super);

    function PathTool(RPath, justCreated) {
      var favorite, name, shortNameJ, toolNameJ, word, words, _i, _len, _ref;
      this.RPath = RPath;
      if (justCreated == null) {
        justCreated = false;
      }
      this.name = this.RPath.rname;
      this.btnJ = g.toolsJ.find('li[data-type="' + this.name + '"]');
      if (this.btnJ.length === 0) {
        this.btnJ = $("<li>");
        this.btnJ.attr("data-type", this.name);
        this.btnJ.attr("alt", this.name);
        if (this.RPath.iconUrl != null) {
          this.btnJ.append('<img src="' + this.RPath.iconUrl + '" alt="' + this.RPath.iconAlt + '">');
        } else {
          this.btnJ.addClass("text-btn");
          name = "";
          words = this.name.split(" ");
          if (words.length > 1) {
            for (_i = 0, _len = words.length; _i < _len; _i++) {
              word = words[_i];
              name += word.substring(0, 1);
            }
          } else {
            name += this.name.substring(0, 2);
          }
          shortNameJ = $('<span class="short-name">').text(name + ".");
          this.btnJ.append(shortNameJ);
        }
        if (this.name === 'Precise path') {
          this.RPath.iconUrl = null;
        }
        favorite = justCreated | ((_ref = g.favoriteTools) != null ? _ref.indexOf(this.name) : void 0) >= 0;
        if (favorite) {
          g.favoriteToolsJ.append(this.btnJ);
        } else {
          g.allToolsJ.append(this.btnJ);
        }
      }
      toolNameJ = $('<span class="tool-name">').text(this.name);
      this.btnJ.append(toolNameJ);
      this.btnJ.addClass("tool-btn");
      PathTool.__super__.constructor.call(this, this.RPath.rname, this.RPath.cursorPosition, this.RPath.cursorDefault, this.RPath.options);
      return;
    }

    PathTool.prototype.description = function() {
      return this.RPath.rdescription;
    };

    PathTool.prototype.remove = function() {
      this.btnJ.remove();
    };

    PathTool.prototype.select = function() {
      PathTool.__super__.select.call(this, this.RPath);
      g.tool.onMouseMove = function(event) {
        event = g.snap(event);
        g.selectedTool.move(event);
      };
    };

    PathTool.prototype.deselect = function() {
      PathTool.__super__.deselect.call(this);
      this.finishPath();
      g.tool.onMouseMove = null;
    };

    PathTool.prototype.begin = function(event, from, data) {
      var _ref;
      if (from == null) {
        from = g.me;
      }
      if (data == null) {
        data = null;
      }
      if (event.event.which === 2) {
        return;
      }
      if (!((g.currentPaths[from] != null) && ((_ref = g.currentPaths[from].data) != null ? _ref.polygonMode : void 0))) {
        g.deselectAll();
        g.currentPaths[from] = new this.RPath(Date.now(), data);
      }
      g.currentPaths[from].beginCreate(event.point, event, false);
      if ((g.me != null) && from === g.me) {
        g.chatSocket.emit("begin", g.me, g.eventToObject(event), this.name, g.currentPaths[from].data);
      }
    };

    PathTool.prototype.update = function(event, from) {
      if (from == null) {
        from = g.me;
      }
      g.currentPaths[from].updateCreate(event.point, event, false);
      if ((g.me != null) && from === g.me) {
        g.chatSocket.emit("update", g.me, g.eventToObject(event), this.name);
      }
    };

    PathTool.prototype.move = function(event) {
      var _base, _ref, _ref1;
      if ((_ref = g.currentPaths[g.me]) != null ? (_ref1 = _ref.data) != null ? _ref1.polygonMode : void 0 : void 0) {
        if (typeof (_base = g.currentPaths[g.me]).createMove === "function") {
          _base.createMove(event);
        }
      }
    };

    PathTool.prototype.end = function(event, from) {
      var _ref;
      if (from == null) {
        from = g.me;
      }
      g.currentPaths[from].endCreate(event.point, event, false);
      if (!((_ref = g.currentPaths[from].data) != null ? _ref.polygonMode : void 0)) {
        if ((g.me != null) && from === g.me) {
          g.currentPaths[from].select(false);
          g.currentPaths[from].save();
          g.commandManager.add(new CreatePathCommand(g.currentPaths[from]));
          g.chatSocket.emit("end", g.me, g.eventToObject(event), this.name);
        }
        delete g.currentPaths[from];
      }
    };

    PathTool.prototype.finishPath = function(from) {
      var _ref, _ref1;
      if (from == null) {
        from = g.me;
      }
      if (!((_ref = g.currentPaths[g.me]) != null ? (_ref1 = _ref.data) != null ? _ref1.polygonMode : void 0 : void 0)) {
        return;
      }
      g.currentPaths[from].finishPath();
      if ((g.me != null) && from === g.me) {
        g.currentPaths[from].select(false);
        g.currentPaths[from].save();
        g.commandManager.add(new CreatePathCommand(g.currentPaths[from]));
        g.chatSocket.emit("bounce", {
          tool: this.name,
          "function": "finishPath",
          "arguments": g.me
        });
      }
      delete g.currentPaths[from];
    };

    return PathTool;

  })(RTool);

  this.PathTool = PathTool;

  ItemTool = (function(_super) {
    __extends(ItemTool, _super);

    function ItemTool(name, RItem) {
      this.name = name;
      this.RItem = RItem;
      ItemTool.__super__.constructor.call(this, this.name, {
        x: 24,
        y: 0
      }, "crosshair");
      return;
    }

    ItemTool.prototype.select = function() {
      ItemTool.__super__.select.call(this, this.RItem);
    };

    ItemTool.prototype.begin = function(event, from) {
      var point;
      if (from == null) {
        from = g.me;
      }
      point = event.point;
      g.currentPaths[from] = new Path.Rectangle(point, point);
      g.currentPaths[from].name = 'div tool rectangle';
      g.currentPaths[from].dashArray = [4, 10];
      g.currentPaths[from].strokeColor = 'black';
      if ((g.me != null) && from === g.me) {
        g.chatSocket.emit("begin", g.me, g.eventToObject(event), this.name, g.currentPaths[from].data);
      }
    };

    ItemTool.prototype.update = function(event, from) {
      var point;
      if (from == null) {
        from = g.me;
      }
      point = event.point;
      g.currentPaths[from].segments[2].point = point;
      g.currentPaths[from].segments[1].point.x = point.x;
      g.currentPaths[from].segments[3].point.y = point.y;
      g.currentPaths[from].fillColor = null;
      if (g.rectangleOverlapsTwoPlanets(g.currentPaths[from].bounds) || RLock.intersectsRectangle(g.currentPaths[from].bounds)) {
        g.currentPaths[from].fillColor = 'red';
      }
      if ((g.me != null) && from === g.me) {
        g.chatSocket.emit("update", g.me, point, this.name);
      }
    };

    ItemTool.prototype.end = function(event, from) {
      var point;
      if (from == null) {
        from = g.me;
      }
      if (from !== g.me) {
        g.currentPaths[from].remove();
        delete g.currentPaths[from];
        return false;
      }
      point = event.point;
      g.currentPaths[from].remove();
      if (g.rectangleOverlapsTwoPlanets(g.currentPaths[from].bounds)) {
        g.romanesco_alert('Your item overlaps with two planets.', 'error');
        return false;
      }
      if (RLock.intersectsRectangle(g.currentPaths[from].bounds)) {
        g.romanesco_alert('Your item intersects with a locked area.', 'error');
        return false;
      }
      if (g.currentPaths[from].bounds.area < 100) {
        g.currentPaths[from].width = 10;
        g.currentPaths[from].height = 10;
      }
      if ((g.me != null) && from === g.me) {
        g.chatSocket.emit("end", g.me, point, this.name);
      }
      return true;
    };

    return ItemTool;

  })(RTool);

  this.ItemTool = ItemTool;

  LockTool = (function(_super) {
    __extends(LockTool, _super);

    function LockTool() {
      LockTool.__super__.constructor.call(this, "Lock", RLock);
      this.textItem = null;
      return;
    }

    LockTool.prototype.update = function(event, from) {
      var cost, point, _ref;
      if (from == null) {
        from = g.me;
      }
      point = event.point;
      cost = g.currentPaths[from].bounds.area / 1000.0;
      if ((_ref = this.textItem) != null) {
        _ref.remove();
      }
      this.textItem = new PointText(point);
      this.textItem.justification = 'right';
      this.textItem.fillColor = 'black';
      this.textItem.content = '' + cost + ' romanescoins';
      LockTool.__super__.update.call(this, event, from);
    };

    LockTool.prototype.end = function(event, from) {
      var _ref;
      if (from == null) {
        from = g.me;
      }
      if ((_ref = this.textItem) != null) {
        _ref.remove();
      }
      if (LockTool.__super__.end.call(this, event, from)) {
        RLock.initialize(g.currentPaths[from].bounds);
        delete g.currentPaths[from];
      }
    };

    return LockTool;

  })(ItemTool);

  this.LockTool = LockTool;

  TextTool = (function(_super) {
    __extends(TextTool, _super);

    function TextTool() {
      TextTool.__super__.constructor.call(this, "Text", RText);
      return;
    }

    TextTool.prototype.end = function(event, from) {
      var text;
      if (from == null) {
        from = g.me;
      }
      if (TextTool.__super__.end.call(this, event, from)) {
        text = new RText(g.currentPaths[from].bounds);
        text.save();
        delete g.currentPaths[from];
      }
    };

    return TextTool;

  })(ItemTool);

  this.TextTool = TextTool;

  MediaTool = (function(_super) {
    __extends(MediaTool, _super);

    function MediaTool() {
      MediaTool.__super__.constructor.call(this, "Media", RMedia);
      return;
    }

    MediaTool.prototype.end = function(event, from) {
      if (from == null) {
        from = g.me;
      }
      if (MediaTool.__super__.end.call(this, event, from)) {
        RMedia.initialize(g.currentPaths[from].bounds);
        delete g.currentPaths[from];
      }
    };

    return MediaTool;

  })(ItemTool);

  this.MediaTool = MediaTool;

  ScreenshotTool = (function(_super) {
    __extends(ScreenshotTool, _super);

    function ScreenshotTool() {
      this.copyURL = __bind(this.copyURL, this);
      this.downloadSVG = __bind(this.downloadSVG, this);
      this.downloadPNG = __bind(this.downloadPNG, this);
      this.publishOnPinterest_callback = __bind(this.publishOnPinterest_callback, this);
      this.publishOnPinterest = __bind(this.publishOnPinterest, this);
      this.publishOnFacebookAsPhoto_callback = __bind(this.publishOnFacebookAsPhoto_callback, this);
      this.publishOnFacebookAsPhoto = __bind(this.publishOnFacebookAsPhoto, this);
      this.publishOnFacebook_callback = __bind(this.publishOnFacebook_callback, this);
      this.publishOnFacebook = __bind(this.publishOnFacebook, this);
      this.extractImage = __bind(this.extractImage, this);
      ScreenshotTool.__super__.constructor.call(this, 'Screenshot', {
        x: 24,
        y: 0
      }, "crosshair");
      this.modalJ = $("#screenshotModal");
      this.modalJ.find('button[name="publish-on-facebook"]').click((function(_this) {
        return function() {
          return _this.publishOnFacebook();
        };
      })(this));
      this.modalJ.find('button[name="publish-on-facebook-photo"]').click((function(_this) {
        return function() {
          return _this.publishOnFacebookAsPhoto();
        };
      })(this));
      this.modalJ.find('button[name="download-png"]').click((function(_this) {
        return function() {
          return _this.downloadPNG();
        };
      })(this));
      this.modalJ.find('button[name="download-svg"]').click((function(_this) {
        return function() {
          return _this.downloadSVG();
        };
      })(this));
      this.modalJ.find('button[name="publish-on-pinterest"]').click((function(_this) {
        return function() {
          return _this.publishOnPinterest();
        };
      })(this));
      this.descriptionJ = this.modalJ.find('input[name="message"]');
      this.descriptionJ.change((function(_this) {
        return function() {
          _this.modalJ.find('a[name="publish-on-twitter"]').attr("data-text", _this.getDescription());
        };
      })(this));
      ZeroClipboard.config({
        swfPath: g.romanescoURL + "static/libs/ZeroClipboard/ZeroClipboard.swf"
      });
      return;
    }

    ScreenshotTool.prototype.getDescription = function() {
      if (this.descriptionJ.val().length > 0) {
        return this.descriptionJ.val();
      } else {
        return "Artwork made with Romanesco: " + this.locationURL;
      }
    };

    ScreenshotTool.prototype.begin = function(event) {
      var from;
      from = g.me;
      g.currentPaths[from] = new Path.Rectangle(event.point, event.point);
      g.currentPaths[from].name = 'screenshot tool selection rectangle';
      g.currentPaths[from].dashArray = [4, 10];
      g.currentPaths[from].strokeColor = 'black';
      g.currentPaths[from].strokeWidth = 1;
    };

    ScreenshotTool.prototype.update = function(event) {
      var from;
      from = g.me;
      g.currentPaths[from].lastSegment.point = event.point;
      g.currentPaths[from].lastSegment.next.point.y = event.point.y;
      g.currentPaths[from].lastSegment.previous.point.x = event.point.x;
    };

    ScreenshotTool.prototype.end = function(event) {
      var from, r;
      from = g.me;
      g.currentPaths[from].remove();
      delete g.currentPaths[from];
      g.view.draw();
      r = new Rectangle(event.downPoint, event.point);
      if (r.area < 100) {
        return;
      }
      this.div = new RSelectionRectangle(new Rectangle(event.downPoint, event.point), this.extractImage);
    };

    ScreenshotTool.prototype.extractImage = function() {
      var copyDataBtnJ, imgJ, maxHeight, twitterLinkJ, twitterScriptJ;
      this.rectangle = this.div.getBounds();
      this.dataURL = g.areaToImageDataUrl(this.rectangle);
      this.div.remove();
      this.locationURL = g.romanescoURL + location.hash;
      this.descriptionJ.attr('placeholder', 'Artwork made with Romanesco: ' + this.locationURL);
      copyDataBtnJ = this.modalJ.find('button[name="copy-data-url"]');
      copyDataBtnJ.attr("data-clipboard-text", this.dataURL);
      imgJ = this.modalJ.find("img.png");
      imgJ.attr("src", this.dataURL);
      maxHeight = g.windowJ.height - 220;
      imgJ.css({
        'max-height': maxHeight + "px"
      });
      this.modalJ.find("a.png").attr("href", this.dataURL);
      twitterLinkJ = this.modalJ.find('a[name="publish-on-twitter"]');
      twitterLinkJ.empty().text("Publish on Twitter");
      twitterLinkJ.attr("data-url", this.locationURL);
      twitterScriptJ = $('<script type="text/javascript">window.twttr=(function(d,s,id){var t,js,fjs=d.getElementsByTagName(s)[0];if(d.getElementById(id)){return}js=d.createElement(s);js.id=id;js.src="https://platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);return window.twttr||(t={_e:[],ready:function(f){t._e.push(f)}})}(document,"script","twitter-wjs"));</script>');
      twitterLinkJ.append(twitterScriptJ);
      this.modalJ.modal('show');
      this.modalJ.on('shown.bs.modal', (function(_this) {
        return function(e) {
          var client;
          client = new ZeroClipboard(copyDataBtnJ);
          client.on("ready", function(readyEvent) {
            console.log("ZeroClipboard SWF is ready!");
            client.on("aftercopy", function(event) {
              romanesco_alert("Image data url was successfully copied into the clipboard!", "success");
              this.destroy();
            });
          });
        };
      })(this));
    };

    ScreenshotTool.prototype.saveImage = function(callback) {
      Dajaxice.draw.saveImage(callback, {
        'image': this.dataURL
      });
      romanesco_alert("Your image is being uploaded...", "info");
    };

    ScreenshotTool.prototype.publishOnFacebook = function() {
      this.saveImage(this.publishOnFacebook_callback);
    };

    ScreenshotTool.prototype.publishOnFacebook_callback = function(result) {
      var caption;
      romanesco_alert("Your image was successfully uploaded to Romanesco, posting to Facebook...", "info");
      caption = this.getDescription();
      FB.ui({
        method: "feed",
        name: "Romanesco",
        caption: caption,
        description: "Romanesco is an infinite collaborative drawing app.",
        link: this.locationURL,
        picture: g.romanescoURL + result.url
      }, function(response) {
        if (response && response.post_id) {
          romanesco_alert("Your Post was successfully published!", "success");
        } else {
          romanesco_alert("An error occured. Your post was not published.", "error");
        }
      });
    };

    ScreenshotTool.prototype.publishOnFacebookAsPhoto = function() {
      if (!g.loggedIntoFacebook) {
        FB.login((function(_this) {
          return function(response) {
            if (response && !response.error) {
              _this.saveImage(_this.publishOnFacebookAsPhoto_callback);
            } else {
              romanesco_alert("An error occured when trying to log you into facebook.", "error");
            }
          };
        })(this));
      } else {
        this.saveImage(this.publishOnFacebookAsPhoto_callback);
      }
    };

    ScreenshotTool.prototype.publishOnFacebookAsPhoto_callback = function(result) {
      var caption;
      romanesco_alert("Your image was successfully uploaded to Romanesco, posting to Facebook...", "info");
      caption = this.getDescription();
      FB.api("/me/photos", "POST", {
        "url": g.romanescoURL + result.url,
        "message": caption
      }, function(response) {
        if (response && !response.error) {
          romanesco_alert("Your Post was successfully published!", "success");
        } else {
          romanesco_alert("An error occured. Your post was not published.", "error");
          console.log(response.error);
        }
      });
    };

    ScreenshotTool.prototype.publishOnPinterest = function() {
      this.saveImage(this.publishOnPinterest_callback);
    };

    ScreenshotTool.prototype.publishOnPinterest_callback = function(result) {
      var buttonJ, caption, description, imageUrl, imgJ, linkJ, linkJcopy, pinterestModalJ, siteUrl, submit;
      romanesco_alert("Your image was successfully uploaded to Romanesco...", "info");
      pinterestModalJ = $("#customModal");
      pinterestModalJ.modal('show');
      pinterestModalJ.addClass("pinterest-modal");
      pinterestModalJ.find(".modal-title").text("Publish on Pinterest");
      siteUrl = encodeURI(g.romanescoURL);
      imageUrl = siteUrl + result.url;
      caption = this.getDescription();
      description = encodeURI(caption);
      linkJ = $("<a>");
      linkJ.addClass("image");
      linkJ.attr("href", "http://pinterest.com/pin/create/button/?url=" + siteUrl + "&media=" + imageUrl + "&description=" + description);
      linkJcopy = linkJ.clone();
      imgJ = $('<img>');
      imgJ.attr('src', siteUrl + result.url);
      linkJ.append(imgJ);
      buttonJ = pinterestModalJ.find('button[name="submit"]');
      linkJcopy.addClass("btn btn-primary").text("Pin it!").insertBefore(buttonJ);
      buttonJ.hide();
      submit = function() {
        pinterestModalJ.modal('hide');
      };
      linkJ.click(submit);
      pinterestModalJ.find(".modal-body").empty().append(linkJ);
      pinterestModalJ.on('hide.bs.modal', function(event) {
        pinterestModalJ.removeClass("pinterest-modal");
        linkJcopy.remove();
        pinterestModalJ.off('hide.bs.modal');
      });
    };

    ScreenshotTool.prototype.downloadPNG = function() {
      this.modalJ.find("a.png")[0].click();
      this.modalJ.modal('hide');
    };

    ScreenshotTool.prototype.downloadSVG = function() {
      var blob, bounds, canvasTemp, fileName, item, itemsToSave, link, position, rectanglePath, svg, svgGroup, tempProject, url, _i, _j, _k, _len, _len1, _len2, _ref, _ref1;
      rectanglePath = new Path.Rectangle(this.rectangle);
      itemsToSave = [];
      _ref = project.activeLayer.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        bounds = item.bounds;
        if ((item.controller != null) && (this.rectangle.contains(bounds) || (this.rectangle.intersects(bounds) && ((_ref1 = item.controller.controlPath) != null ? _ref1.getIntersections(rectanglePath).length : void 0) > 0))) {
          g.pushIfAbsent(itemsToSave, item.controller);
        }
      }
      svgGroup = new Group();
      for (_j = 0, _len1 = itemsToSave.length; _j < _len1; _j++) {
        item = itemsToSave[_j];
        if (item.drawing == null) {
          item.draw();
        }
      }
      view.update();
      for (_k = 0, _len2 = itemsToSave.length; _k < _len2; _k++) {
        item = itemsToSave[_k];
        svgGroup.addChild(item.drawing.clone());
      }
      rectanglePath.remove();
      position = svgGroup.position.subtract(this.rectangle.topLeft);
      fileName = "image.svg";
      canvasTemp = document.createElement('canvas');
      canvasTemp.width = this.rectangle.width;
      canvasTemp.height = this.rectangle.height;
      tempProject = new Project(canvasTemp);
      svgGroup.position = position;
      tempProject.addChild(svgGroup);
      svg = tempProject.exportSVG({
        asString: true
      });
      tempProject.remove();
      paper.projects.first().activate();
      blob = new Blob([svg], {
        type: 'image/svg+xml'
      });
      url = URL.createObjectURL(blob);
      link = document.createElement("a");
      link.download = fileName;
      link.href = url;
      link.click();
      this.modalJ.modal('hide');
    };

    ScreenshotTool.prototype.copyURL = function() {};

    return ScreenshotTool;

  })(RTool);

  this.ScreenshotTool = ScreenshotTool;

}).call(this);

//# sourceMappingURL=tools.map
