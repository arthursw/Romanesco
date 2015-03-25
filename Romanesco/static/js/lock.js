// Generated by CoffeeScript 1.7.1
(function() {
  var RLink, RLock, RVideoGame, RWebsite,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  RLock = (function(_super) {
    __extends(RLock, _super);

    RLock.rname = 'Lock';

    RLock.object_type = 'lock';

    RLock.initialize = function(rectangle) {
      var radioButtons, radioGroupJ, siteURLJ, siteUrlExtractor, submit;
      submit = function(data) {
        var lock;
        switch (data.object_type) {
          case 'lock':
            lock = new RLock(rectangle, data);
            break;
          case 'website':
            lock = new RWebsite(rectangle, data);
            break;
          case 'video-game':
            lock = new RVideoGame(rectangle, data);
            break;
          case 'link':
            lock = new RLink(rectangle, data);
        }
        lock.save(true);
        lock.update('rectangle');
        lock.select();
      };
      RModal.initialize('Create a locked area', submit);
      radioButtons = [
        {
          value: 'lock',
          checked: true,
          label: 'Create simple lock',
          submitShortcut: true,
          linked: []
        }, {
          value: 'link',
          checked: false,
          label: 'Create link',
          linked: ['linkName', 'url', 'message']
        }, {
          value: 'website',
          checked: false,
          label: 'Create  website (® x2)',
          linked: ['restrictArea', 'disableToolbar', 'siteName']
        }, {
          value: 'video-game',
          checked: false,
          label: 'Create  video game (® x2)',
          linked: ['message']
        }
      ];
      radioGroupJ = RModal.addRadioGroup('object_type', radioButtons);
      RModal.addCheckbox('restrictArea', 'Restrict area', "Users visiting your website will not be able to go out of the site boundaries.");
      RModal.addCheckbox('disableToolbar', 'Disable toolbar', "Users will not have access to the toolbar on your site.");
      RModal.addTextInput('linkName', 'Site name', 'text', '', 'Site name');
      RModal.addTextInput('url', 'http://', 'url', 'url', 'URL');
      siteURLJ = $("<div class=\"form-group siteName\">\n	<label for=\"modalSiteName\">Site name</label>\n	<div class=\"input-group\">\n		<input id=\"modalSiteName\" type=\"text\" class=\"name form-control\" placeholder=\"Site name\">\n		<span class=\"input-group-addon\">.romanesco.city</span>\n	</div>\n</div>");
      siteUrlExtractor = function(data, siteURLJ) {
        data.siteURL = siteURLJ.find("#modalSiteName").val();
      };
      RModal.addCustomContent('siteName', siteURLJ, siteUrlExtractor);
      RModal.addTextInput('message', 'Enter the message you want others to see when they look at this link.', 'text', '', 'Message', true);
      radioGroupJ.click(function(event) {
        var extractor, lockType, name, radioButton, _i, _len, _ref;
        lockType = radioGroupJ.find('input[type=radio][name=object_type]:checked')[0].value;
        for (_i = 0, _len = radioButtons.length; _i < _len; _i++) {
          radioButton = radioButtons[_i];
          if (radioButton.value === lockType) {
            _ref = RModal.extractors;
            for (name in _ref) {
              extractor = _ref[name];
              if (radioButton.linked.indexOf(name) >= 0) {
                extractor.div.show();
              } else if (name !== 'object_type') {
                extractor.div.hide();
              }
            }
          }
        }
      });
      radioGroupJ.click();
      RModal.show();
      radioGroupJ.find('input:first').focus();
    };

    RLock.getLockWhichContains = function(rectangle) {
      var lock, _i, _len, _ref;
      _ref = g.locks;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        lock = _ref[_i];
        if (lock.getBounds().contains(rectangle)) {
          return lock;
        }
      }
      return null;
    };

    RLock.getLocksWhichIntersect = function(rectangle) {
      var lock, locks, _i, _len, _ref;
      locks = [];
      _ref = g.locks;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        lock = _ref[_i];
        if (lock.getBounds().intersects(rectangle)) {
          locks.push(lock);
        }
      }
      return locks;
    };

    RLock.duplicate = function(rectangle, data) {
      var copy;
      copy = new this(rectangle, data);
      copy.save();
      return copy;
    };

    RLock.parameters = function() {
      var fillColor, parameters, strokeColor, strokeWidth;
      parameters = RLock.__super__.constructor.parameters.call(this);
      strokeWidth = $.extend(true, {}, g.parameters.strokeWidth);
      strokeWidth["default"] = 1;
      strokeColor = $.extend(true, {}, g.parameters.strokeColor);
      strokeColor["default"] = 'black';
      fillColor = $.extend(true, {}, g.parameters.fillColor);
      fillColor["default"] = 'white';
      fillColor.defaultCheck = true;
      fillColor.defaultFunction = null;
      parameters['Style'].strokeWidth = strokeWidth;
      parameters['Style'].strokeColor = strokeColor;
      parameters['Style'].fillColor = fillColor;
      return parameters;
    };

    function RLock(rectangle, data, pk, owner, date) {
      var item, pkString, title, titleJ, _i, _len, _ref, _ref1;
      this.rectangle = rectangle;
      this.data = data != null ? data : null;
      this.pk = pk != null ? pk : null;
      this.owner = owner != null ? owner : null;
      this.date = date;
      this.select = __bind(this.select, this);
      this.update = __bind(this.update, this);
      this.save_callback = __bind(this.save_callback, this);
      RLock.__super__.constructor.call(this, this.data, this.pk);
      g.locks.push(this);
      this.group.name = 'lock group';
      this.background = new Path.Rectangle(this.rectangle);
      this.background.name = 'rlock background';
      this.background.strokeWidth = this.data.strokeWidth > 0 ? this.data.strokeWidth : 1;
      this.background.strokeColor = this.data.strokeColor != null ? this.data.strokeColor : 'black';
      this.background.fillColor = this.data.fillColor || 'white';
      this.background.controller = this;
      this.group.addChild(this.background);
      g.lockLayer.addChild(this.group);
      this.sortedPaths = [];
      this.sortedDivs = [];
      this.itemListsJ = g.templatesJ.find(".layer").clone();
      pkString = '' + (this.pk || this.id);
      pkString = pkString.substring(pkString.length - 3);
      title = "Lock ..." + pkString;
      if (this.owner) {
        title += " of " + this.owner;
      }
      titleJ = this.itemListsJ.find(".title");
      titleJ.text(title);
      titleJ.click(function(event) {
        $(this).parent().toggleClass('closed');
      });
      this.itemListsJ.find('.rDiv-list').sortable({
        stop: g.zIndexSortStop,
        delay: 250
      });
      this.itemListsJ.find('.rPath-list').sortable({
        stop: g.zIndexSortStop,
        delay: 250
      });
      this.itemListsJ.mouseover((function(_this) {
        return function(event) {
          _this.highlight();
        };
      })(this));
      this.itemListsJ.mouseout((function(_this) {
        return function(event) {
          _this.unhighlight();
        };
      })(this));
      g.itemListsJ.prepend(this.itemListsJ);
      this.itemListsJ = g.itemListsJ.find(".layer:first");
      _ref = g.items;
      for (item = _i = 0, _len = _ref.length; _i < _len; item = ++_i) {
        pk = _ref[item];
        if (RLock.prototype.isPrototypeOf(item)) {
          continue;
        }
        if (item.getBounds().intersects(this.rectangle)) {
          this.addItem(item);
        }
      }
      if ((_ref1 = this.data) != null ? _ref1.loadEntireArea : void 0) {
        g.entireAreas.push(this);
      }
      return;
    }

    RLock.prototype.changeParameter = function(name, value, updateGUI) {
      RLock.__super__.changeParameter.call(this, name, value, updateGUI);
      switch (name) {
        case 'strokeWidth':
        case 'strokeColor':
        case 'fillColor':
          this.background[name] = this.data[name];
      }
    };

    RLock.prototype.save = function(addCreateCommand) {
      var data, siteData;
      this.addCreateCommand = addCreateCommand;
      if (g.rectangleOverlapsTwoPlanets(this.rectangle)) {
        return;
      }
      if (this.rectangle.area === 0) {
        this.remove();
        romanesco_alert("Error: your box is not valid.", "error");
        return;
      }
      data = this.getData();
      siteData = {
        restrictArea: data.restrictArea,
        disableToolbar: data.disableToolbar,
        loadEntireArea: data.loadEntireArea
      };
      Dajaxice.draw.saveBox(this.save_callback, {
        'box': g.boxFromRectangle(this.rectangle),
        'object_type': this.constructor.object_type,
        'data': JSON.stringify(data),
        'siteData': JSON.stringify(siteData),
        'name': data.name
      });
    };

    RLock.prototype.save_callback = function(result) {
      g.checkError(result);
      if (result.pk == null) {
        this.remove();
        return;
      }
      if (this.addCreateCommand) {
        g.commandManager.add(new CreateLockCommand(this));
        delete this.addCreateCommand;
      }
      this.owner = result.owner;
      this.setPK(result.pk);
      if (this.updateAfterSave != null) {
        this.update(this.updateAfterSave);
      }
    };

    RLock.prototype.update = function(type) {
      var args, item, itemsToUpdate, pk, updateBoxArgs, _i, _len, _ref;
      if (this.pk == null) {
        this.updateAfterSave = type;
        return;
      }
      delete this.updateAfterSave;
      if (g.rectangleOverlapsTwoPlanets(this.rectangle)) {
        return;
      }
      updateBoxArgs = {
        box: g.boxFromRectangle(this.rectangle),
        pk: this.pk,
        object_type: this.object_type,
        name: this.data.name,
        data: this.getStringifiedData(),
        updateType: type
      };
      args = [];
      args.push({
        "function": 'updateBox',
        "arguments": updateBoxArgs
      });
      if (type === 'position' || type === 'rectangle') {
        itemsToUpdate = type === 'position' ? this.children() : [];
        _ref = g.items;
        for (pk in _ref) {
          item = _ref[pk];
          if (!RLock.prototype.isPrototypeOf(item)) {
            if (item.lock !== this && this.rectangle.contains(item.getBounds())) {
              this.addItem(item);
              itemsToUpdate.push(item);
            }
          }
        }
        for (_i = 0, _len = itemsToUpdate.length; _i < _len; _i++) {
          item = itemsToUpdate[_i];
          args.push({
            "function": item.getUpdateFunction(),
            "arguments": item.getUpdateArguments()
          });
        }
      }
      Dajaxice.draw.multipleCalls(this.update_callback, {
        functionsAndArguments: args
      });
    };

    RLock.prototype.update_callback = function(results) {
      var result, _i, _len;
      for (_i = 0, _len = results.length; _i < _len; _i++) {
        result = results[_i];
        g.checkError(result);
      }
    };

    RLock.prototype.duplicate = function(data) {
      var copy;
      if (data == null) {
        data = this.getData();
      }
      copy = this.constructor.duplicate(this.rectangle, data);
      return copy;
    };

    RLock.prototype["delete"] = function() {
      this.remove();
      if (this.pk == null) {
        return;
      }
      Dajaxice.draw.deleteBox(this.deleteBox_callback, {
        'pk': this.pk
      });
    };

    RLock.prototype.deleteCommand = function() {
      g.commandManager.add(new DeleteLockCommand(this), true);
    };

    RLock.prototype.deleteBox_callback = function(result) {
      if (g.checkError(result)) {
        g.chatSocket.emit("delete box", result.pk);
      }
    };

    RLock.prototype.setRectangle = function(rectangle, update) {
      var p;
      RLock.__super__.setRectangle.call(this, rectangle, update);
      p = new Path.Rectangle(rectangle);
      this.background.segments = p.segments.slice();
      p.remove();
    };

    RLock.prototype.moveTo = function(position, update) {
      var delta, item, _i, _len, _ref;
      delta = position.subtract(this.group.position);
      _ref = this.children();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.rectangle.center.x += delta.x;
        item.rectangle.center.y += delta.y;
        if (RDiv.prototype.isPrototypeOf(item)) {
          item.updateTransform();
        }
      }
      RLock.__super__.moveTo.call(this, position, update);
    };

    RLock.prototype.containsChildren = function() {
      var item, _i, _len, _ref;
      _ref = this.children();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (!this.rectangle.contains(item.getBounds())) {
          return false;
        }
      }
      return true;
    };

    RLock.prototype.select = function(updateOptions) {
      var item, _i, _len, _ref;
      if (updateOptions == null) {
        updateOptions = true;
      }
      if (!RLock.__super__.select.call(this, updateOptions) || this.owner !== g.me) {
        return false;
      }
      _ref = this.children();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.deselect();
      }
      return true;
    };

    RLock.prototype.remove = function() {
      var path, _i, _len, _ref;
      _ref = this.children();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        this.removeItem(path);
      }
      this.itemListsJ.remove();
      this.itemListsJ = null;
      g.locks.remove(this);
      this.background = null;
      RLock.__super__.remove.call(this);
    };

    RLock.prototype.children = function() {
      return this.sortedDivs.concat(this.sortedPaths);
    };

    RLock.prototype.addItem = function(item) {
      g.addItemTo(item, this);
    };

    RLock.prototype.removeItem = function(item) {
      g.addItemToStage(item);
    };

    RLock.prototype.highlight = function(color) {
      RLock.__super__.highlight.call(this);
      this.highlightRectangle.moveAbove(this.background);
      if (color) {
        this.highlightRectangle.fillColor = color;
        this.highlightRectangle.strokeColor = color;
        this.highlightRectangle.dashArray = [];
      }
    };

    return RLock;

  })(RItem);

  this.RLock = RLock;

  RWebsite = (function(_super) {
    __extends(RWebsite, _super);

    RWebsite.rname = 'Website';

    RWebsite.object_type = 'website';

    function RWebsite(rectangle, data, pk, owner, date) {
      this.rectangle = rectangle;
      this.data = data != null ? data : null;
      this.pk = pk != null ? pk : null;
      this.owner = owner != null ? owner : null;
      if (date == null) {
        date = null;
      }
      RWebsite.__super__.constructor.call(this, this.rectangle, this.data, this.pk, this.owner, date);
      return;
    }

    RWebsite.prototype.enableInteraction = function() {};

    return RWebsite;

  })(RLock);

  this.RWebsite = RWebsite;

  RVideoGame = (function(_super) {
    __extends(RVideoGame, _super);

    RVideoGame.rname = 'Video game';

    RVideoGame.object_type = 'video-game';

    function RVideoGame(rectangle, data, pk, owner, date) {
      this.rectangle = rectangle;
      this.data = data != null ? data : null;
      this.pk = pk != null ? pk : null;
      this.owner = owner != null ? owner : null;
      if (date == null) {
        date = null;
      }
      RVideoGame.__super__.constructor.call(this, this.rectangle, this.data, this.pk, this.owner, date);
      this.currentCheckpoint = -1;
      this.checkpoints = [];
      return;
    }

    RVideoGame.prototype.getData = function() {
      var data;
      data = RVideoGame.__super__.getData.call(this);
      data.loadEntireArea = true;
      return data;
    };

    RVideoGame.prototype.enableInteraction = function() {};

    RVideoGame.prototype.initGUI = function() {
      console.log("Gui init");
    };

    RVideoGame.prototype.updateGame = function(tool) {
      var checkpoint, _i, _len, _ref;
      _ref = this.checkpoints;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        checkpoint = _ref[_i];
        if (checkpoint.contains(tool.car.position)) {
          if (this.currentCheckpoint === checkpoint.data.checkpointNumber - 1) {
            this.currentCheckpoint = checkpoint.data.checkpointNumber;
            if (this.currentCheckpoint === 0) {
              this.startTime = Date.now();
              romanesco_alert("Game started, go go go!", "success");
            } else {
              romanesco_alert("Checkpoint " + this.currentCheckpoint + " passed!", "success");
            }
          }
          if (this.currentCheckpoint === this.checkpoints.length - 1) {
            this.finishGame();
          }
        }
      }
    };

    RVideoGame.prototype.finishGame = function() {
      var time;
      time = (Date.now() - this.startTime) / 1000;
      romanesco_alert("You won ! Your time is: " + time.toFixed(2) + " seconds.", "success");
      this.currentCheckpoint = -1;
    };

    return RVideoGame;

  })(RLock);

  this.RVideoGame = RVideoGame;

  RLink = (function(_super) {
    __extends(RLink, _super);

    RLink.rname = 'Link';

    RLink.modalTitle = "Insert a hyperlink";

    RLink.modalTitleUpdate = "Modify your link";

    RLink.object_type = 'link';

    RLink.parameters = function() {
      var parameters;
      parameters = RLink.__super__.constructor.parameters.call(this);
      delete parameters['Lock'];
      return parameters;
    };

    function RLink(rectangle, data, pk, owner, date) {
      var _ref;
      this.rectangle = rectangle;
      this.data = data != null ? data : null;
      this.pk = pk != null ? pk : null;
      this.owner = owner != null ? owner : null;
      if (date == null) {
        date = null;
      }
      RLink.__super__.constructor.call(this, this.rectangle, this.data, this.pk, this.owner, date);
      if ((_ref = this.linkJ) != null) {
        _ref.click((function(_this) {
          return function(event) {
            var location, p, pos;
            if (_this.linkJ.attr("href").indexOf("http://romanesc.co/#") === 0) {
              location = _this.linkJ.attr("href").replace("http://romanesc.co/#", "");
              pos = location.split(',');
              p = new Point();
              p.x = parseFloat(pos[0]);
              p.y = parseFloat(pos[1]);
              g.RMoveTo(p, 1000);
              event.preventDefault();
              return false;
            }
          };
        })(this));
      }
      return;
    }

    return RLink;

  })(RLock);

  this.RLink = RLink;

}).call(this);

//# sourceMappingURL=lock.map
