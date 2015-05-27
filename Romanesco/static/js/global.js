// Generated by CoffeeScript 1.7.1
(function() {
  var __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  define(['utils', 'jquery', 'bootstrap', 'paper', 'tween'], function(utils) {
    var doAreasOverlap, g;
    g = utils.g();

    /*
    	 * Global functions #
    
    	Here are all global functions (which do not belong to classes and are not event handlers neither initialization functions).
     */
    g.showAlert = function(index) {
      var alertJ, prevType;
      if (g.alerts.length <= 0 || index < 0 || index >= g.alerts.length) {
        return;
      }
      prevType = g.alerts[g.currentAlert].type;
      g.currentAlert = index;
      alertJ = g.alertsContainer.find(".alert");
      alertJ.removeClass(prevType).addClass(g.alerts[g.currentAlert].type).text(g.alerts[g.currentAlert].message);
      g.alertsContainer.find(".alert-number").text(g.currentAlert + 1);
    };
    g.romanesco_alert = function(message, type, delay) {
      var alertJ;
      if (type == null) {
        type = "";
      }
      if (delay == null) {
        delay = 2000;
      }
      if (type.length === 0) {
        type = "info";
      } else if (type === "error") {
        type = "danger";
      }
      type = " alert-" + type;
      alertJ = g.alertsContainer.find(".alert");
      g.alertsContainer.removeClass("r-hidden");
      g.currentAlert = g.alerts.length;
      g.alerts.push({
        type: type,
        message: message
      });
      if (g.alerts.length > 0) {
        g.alertsContainer.addClass("activated");
      }
      g.showAlert(g.alerts.length - 1);
      g.alertsContainer.addClass("show");
      if (delay !== 0) {
        clearTimeout(g.alertTimeOut);
        g.alertTimeOut = setTimeout((function() {
          return g.alertsContainer.removeClass("show");
        }), delay);
      }
    };
    g.checkError = function(result) {
      if (result == null) {
        return true;
      }
      if (result.state === 'not_logged_in') {
        g.romanesco_alert("You must be logged in to update drawings to the database.", "info");
        return false;
      }
      if (result.state === 'error') {
        if (result.message === 'invalid_url') {
          g.romanesco_alert("Your URL is invalid or does not point to an existing page.", "error");
        } else {
          g.romanesco_alert("Error: " + result.message, "error");
        }
        return false;
      } else if (result.state === 'system_error') {
        console.log(result.message);
        return false;
      }
      return true;
    };
    g.jEventToPoint = function(event) {
      return view.viewToProject(new Point(event.pageX - g.canvasJ.offset().left, event.pageY - g.canvasJ.offset().top));
    };
    g.eventToObject = function(event) {
      var eo;
      eo = {
        modifiers: event.modifiers,
        point: event.pageX == null ? event.point : g.jEventToPoint(event),
        downPoint: event.downPoint != null,
        delta: event.delta
      };
      if ((event.pageX != null) && (event.pageY != null)) {
        eo.modifiers = {};
        eo.modifiers.control = event.ctrlKey;
        eo.modifiers.command = event.metaKey;
      }
      if (event.target != null) {
        eo.target = "." + event.target.className.replace(" ", ".");
      }
      return eo;
    };
    g.objectToEvent = function(event) {
      event.point = new Point(event.point);
      event.downPoint = new Point(event.downPoint);
      event.delta = new Point(event.delta);
      return event;
    };
    g.jEventToPaperEvent = function(event, previousPosition, initialPosition, type, count) {
      var currentPosition, delta, paperEvent;
      if (previousPosition == null) {
        previousPosition = null;
      }
      if (initialPosition == null) {
        initialPosition = null;
      }
      if (type == null) {
        type = null;
      }
      if (count == null) {
        count = null;
      }
      currentPosition = g.jEventToPoint(event);
      if (previousPosition == null) {
        previousPosition = currentPosition;
      }
      if (initialPosition == null) {
        initialPosition = currentPosition;
      }
      delta = currentPosition.subtract(previousPosition);
      paperEvent = {
        modifiers: {
          shift: event.shiftKey,
          control: event.ctrlKey,
          option: event.altKey,
          command: event.metaKey
        },
        point: currentPosition,
        downPoint: initialPosition,
        delta: delta,
        middlePoint: previousPosition.add(delta.divide(2)),
        type: type,
        count: count
      };
      return paperEvent;
    };
    g.updatePathRectangle = function(path, rectangle) {
      path.segments[0].point = rectangle.bottomLeft;
      path.segments[1].point = rectangle.topLeft;
      path.segments[2].point = rectangle.topRight;
      path.segments[3].point = rectangle.bottomRight;
    };
    g.specialKey = function(event) {
      var specialKey;
      if ((event.pageX != null) && (event.pageY != null)) {
        specialKey = g.OSName === "MacOS" ? event.metaKey : event.ctrlKey;
      } else {
        specialKey = g.OSName === "MacOS" ? event.modifiers.command : event.modifiers.control;
      }
      return specialKey;
    };
    g.getSnap = function() {
      return g.parameters.snap.snap;
    };
    g.snap1D = function(value, snap) {
      if (snap == null) {
        snap = g.getSnap();
      }
      if (snap !== 0) {
        return Math.round(value / snap) * snap;
      } else {
        return value;
      }
    };
    g.snap2D = function(point, snap) {
      if (snap == null) {
        snap = g.getSnap();
      }
      if (snap !== 0) {
        return new Point(g.snap1D(point.x, snap), g.snap1D(point.y, snap));
      } else {
        return point;
      }
    };
    g.snap = function(event, from) {
      var snap, snappedEvent;
      if (from == null) {
        from = g.me;
      }
      if (from !== g.me) {
        return event;
      }
      if (g.selectedTool.disableSnap()) {
        return event;
      }
      snap = g.parameters.snap.snap;
      snap = snap - snap % g.parameters.snap.step;
      if (snap !== 0) {
        snappedEvent = jQuery.extend({}, event);
        snappedEvent.modifiers = event.modifiers;
        snappedEvent.point = g.snap2D(event.point, snap);
        if (event.lastPoint != null) {
          snappedEvent.lastPoint = g.snap2D(event.lastPoint, snap);
        }
        if (event.downPoint != null) {
          snappedEvent.downPoint = g.snap2D(event.downPoint, snap);
        }
        if (event.lastPoint != null) {
          snappedEvent.middlePoint = snappedEvent.point.add(snappedEvent.lastPoint).multiply(0.5);
        }
        if (event.type !== 'mouseup' && (event.lastPoint != null)) {
          snappedEvent.delta = snappedEvent.point.subtract(snappedEvent.lastPoint);
        } else if (event.downPoint != null) {
          snappedEvent.delta = snappedEvent.point.subtract(snappedEvent.downPoint);
        }
        return snappedEvent;
      } else {
        return event;
      }
    };
    g.rectangleOverlapsTwoPlanets = function(rectangle) {
      var limit;
      limit = g.getLimit();
      if ((rectangle.left < limit.x && rectangle.right > limit.x) || (rectangle.top < limit.y && rectangle.bottom > limit.y)) {
        return true;
      }
      return false;
    };
    g.updateLimitPaths = function() {
      var limit;
      limit = g.getLimit();
      g.limitPathV = null;
      g.limitPathH = null;
      if (limit.x >= view.bounds.left && limit.x <= view.bounds.right) {
        g.limitPathV = new Path();
        g.limitPathV.name = 'limitPathV';
        g.limitPathV.strokeColor = 'green';
        g.limitPathV.strokeWidth = 5;
        g.limitPathV.add(limit.x, view.bounds.top);
        g.limitPathV.add(limit.x, view.bounds.bottom);
        g.grid.addChild(g.limitPathV);
      }
      if (limit.y >= view.bounds.top && limit.y <= view.bounds.bottom) {
        g.limitPathH = new Path();
        g.limitPathH.name = 'limitPathH';
        g.limitPathH.strokeColor = 'green';
        g.limitPathH.strokeWidth = 5;
        g.limitPathH.add(view.bounds.left, limit.y);
        g.limitPathH.add(view.bounds.right, limit.y);
        g.grid.addChild(g.limitPathH);
      }
    };
    g.updateGrid = function() {
      var bounds, boundsCompoundPath, halfSize, left, px, py, snap, top;
      g.grid.removeChildren();
      g.updateLimitPaths();
      if (view.bounds.width > window.innerWidth || view.bounds.height > window.innerHeight) {
        halfSize = new Point(window.innerWidth * 0.5, window.innerHeight * 0.5);
        bounds = new Rectangle(view.center.subtract(halfSize), view.center.add(halfSize));
        boundsCompoundPath = new CompoundPath({
          children: [new Path.Rectangle(view.bounds), new Path.Rectangle(bounds)]
        });
        boundsCompoundPath.strokeScaling = false;
        boundsCompoundPath.fillColor = 'rgba(0,0,0,0.1)';
        g.grid.addChild(boundsCompoundPath);
      }
      if (!g.displayGrid) {
        return;
      }
      snap = g.getSnap();
      bounds = g.expandRectangleToMultiple(view.bounds, snap);
      left = bounds.left;
      top = bounds.top;
      while (left < bounds.right || top < bounds.bottom) {
        px = new Path();
        px.name = "grid px";
        py = new Path();
        px.name = "grid py";
        px.strokeColor = "#666666";
        if ((left / snap) % 4 === 0) {
          px.strokeColor = "#000000";
          px.strokeWidth = 2;
        }
        py.strokeColor = "#666666";
        if ((top / snap) % 4 === 0) {
          py.strokeColor = "#000000";
          py.strokeWidth = 2;
        }
        px.add(new Point(left, view.bounds.top));
        px.add(new Point(left, view.bounds.bottom));
        py.add(new Point(view.bounds.left, top));
        py.add(new Point(view.bounds.right, top));
        g.grid.addChild(px);
        g.grid.addChild(py);
        left += snap;
        top += snap;
      }
    };
    g.selectedToolNeedsDrawings = function() {
      var lockToolSelected, pathToolSelected;
      pathToolSelected = g.PathTool.prototype.isPrototypeOf(g.selectedTool);
      lockToolSelected = g.LockTool.prototype.isPrototypeOf(g.selectedTool);
      return g.selectedTool === g.tools['Select'] || g.selectedTool === g.tools['Screenshot'] || pathToolSelected || lockToolSelected;
    };
    g.gameAt = function(point) {
      var div, _i, _len, _ref;
      _ref = g.divs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        div = _ref[_i];
        if (div.getBounds().contains(point) && div.constructor.name === 'RVideoGame') {
          return div;
        }
      }
      return null;
    };
    g.RMoveTo = function(pos, delay, addCommand) {
      var initialPosition, somethingToLoad, tween;
      if (addCommand == null) {
        addCommand = true;
      }
      if (delay == null) {
        somethingToLoad = g.RMoveBy(pos.subtract(view.center), addCommand);
      } else {
        initialPosition = view.center;
        tween = new TWEEN.Tween(initialPosition).to(pos, delay).easing(TWEEN.Easing.Exponential.InOut).onUpdate(function() {
          g.RMoveTo(this, addCommand);
        }).start();
      }
      return somethingToLoad;
    };
    g.RMoveBy = function(delta, addCommand) {
      var addMoveCommand, area, div, newEntireArea, newView, restrictedAreaShrinked, somethingToLoad, _i, _j, _len, _len1, _ref, _ref1;
      if (addCommand == null) {
        addCommand = true;
      }
      if (g.restrictedArea != null) {
        if (!g.restrictedArea.contains(view.center)) {
          delta = g.restrictedArea.center.subtract(view.center);
        } else {
          newView = view.bounds.clone();
          newView.center.x += delta.x;
          newView.center.y += delta.y;
          if (!g.restrictedArea.contains(newView)) {
            restrictedAreaShrinked = g.restrictedArea.expand(view.size.multiply(-1));
            if (restrictedAreaShrinked.width < 0) {
              restrictedAreaShrinked.left = restrictedAreaShrinked.right = g.restrictedArea.center.x;
            }
            if (restrictedAreaShrinked.height < 0) {
              restrictedAreaShrinked.top = restrictedAreaShrinked.bottom = g.restrictedArea.center.y;
            }
            newView.center.x = g.clamp(restrictedAreaShrinked.left, newView.center.x, restrictedAreaShrinked.right);
            newView.center.y = g.clamp(restrictedAreaShrinked.top, newView.center.y, restrictedAreaShrinked.bottom);
            delta = newView.center.subtract(view.center);
          }
        }
      }
      if (g.previousViewPosition == null) {
        g.previousViewPosition = view.center;
      }
      project.view.scrollBy(new Point(delta.x, delta.y));
      g.selectionProject.view.scrollBy(new Point(delta.x, delta.y));
      _ref = g.divs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        div = _ref[_i];
        div.updateTransform();
      }
      g.rasterizer.move();
      g.updateGrid();
      newEntireArea = null;
      _ref1 = g.entireAreas;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        area = _ref1[_j];
        if (area.getBounds().contains(project.view.center)) {
          newEntireArea = area;
          break;
        }
      }
      if ((g.entireArea == null) && (newEntireArea != null)) {
        g.entireArea = newEntireArea.getBounds();
      } else if ((g.entireArea != null) && (newEntireArea == null)) {
        g.entireArea = null;
      }
      somethingToLoad = newEntireArea != null ? g.load(g.entireArea) : g.load();
      g.updateRoom();
      g.deferredExecution(g.updateHash, 'updateHash', 500);
      if (addCommand) {
        addMoveCommand = function() {
          g.commandManager.add(new g.MoveViewCommand(g.previousViewPosition, view.center));
          g.previousViewPosition = null;
        };
        g.deferredExecution(addMoveCommand, 'add move command');
      }
      g.setControllerValue(g.parameters.location.controller, null, '' + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2));
      return somethingToLoad;
    };
    g.updateHash = function() {
      var prefix;
      g.ignoreHashChange = true;
      prefix = '';
      if ((g.city.owner != null) && (g.city.name != null) && g.city.owner !== 'RomanescoOrg' && g.city.name !== 'Romanesco') {
        prefix = g.city.owner + '/' + g.city.name + '/';
      }
      location.hash = prefix + view.center.x.toFixed(2) + ',' + view.center.y.toFixed(2);
    };
    window.onhashchange = function(event) {
      var fields, name, owner, p, pos;
      if (g.ignoreHashChange) {
        g.ignoreHashChange = false;
        return;
      }
      p = new Point();
      fields = location.hash.substr(1).split('/');
      if (fields.length >= 3) {
        owner = fields[0];
        name = fields[1];
        if (g.city.name !== name || g.city.owner !== owner) {
          g.loadCity(name, owner);
        }
      }
      pos = fields.last().split(',');
      p.x = parseFloat(pos[0]);
      p.y = parseFloat(pos[1]);
      if (!p.x) {
        p.x = 0;
      }
      if (!p.y) {
        p.y = 0;
      }
      g.RMoveTo(p);
    };
    g.deselectAll = function() {
      if (g.selectedItems.length > 0) {
        g.commandManager.add(new g.DeselectCommand(), true);
      }
      project.activeLayer.selected = false;
    };
    g.toggleSidebar = function(show) {
      if (show == null) {
        show = !g.sidebarJ.hasClass("r-hidden");
      }
      if (show) {
        g.sidebarJ.addClass("r-hidden");
        g.codeEditor.editorJ.addClass("r-hidden");
        g.alertsContainer.addClass("r-sidebar-hidden");
        g.sidebarHandleJ.find("span").removeClass("glyphicon-chevron-left").addClass("glyphicon-chevron-right");
      } else {
        g.sidebarJ.removeClass("r-hidden");
        g.codeEditor.editorJ.removeClass("r-hidden");
        g.alertsContainer.removeClass("r-sidebar-hidden");
        g.sidebarHandleJ.find("span").removeClass("glyphicon-chevron-right").addClass("glyphicon-chevron-left");
      }
    };
    g.highlightStage = function(color) {
      g.backgroundRectangle = new Path.Rectangle(view.bounds);
      g.backgroundRectangle.fillColor = color;
      g.backgroundRectangle.sendToBack();
    };
    g.unhighlightStage = function() {
      var _ref;
      if ((_ref = g.backgroundRectangle) != null) {
        _ref.remove();
      }
      g.backgroundRectangle = null;
    };
    g.drawView = function() {
      var time;
      time = Date.now();
      view.draw();
      console.log("Time to draw the view: " + ((Date.now() - time) / 1000) + " sec.");
    };
    g.highlightValidity = function(item) {
      g.validatePosition(item, null, true);
    };
    g.validatePosition = function(item, bounds, highlight) {
      var lock, locks, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _ref4;
      if (bounds == null) {
        bounds = null;
      }
      if (highlight == null) {
        highlight = false;
      }
      if ((typeof item.getDrawingBounds === "function" ? item.getDrawingBounds() : void 0) > g.rasterizer.maxArea()) {
        if (highlight) {
          g.romanesco_alert('The path is too big.', 'Warning');
        } else {
          return false;
        }
      }
      if (bounds == null) {
        bounds = item.getBounds();
      }
      if ((_ref = g.limitPathV) != null) {
        _ref.strokeColor = 'green';
      }
      if ((_ref1 = g.limitPathH) != null) {
        _ref1.strokeColor = 'green';
      }
      _ref2 = g.locks;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        lock = _ref2[_i];
        lock.unhighlight();
      }
      g.unhighlightStage();
      if (g.rectangleOverlapsTwoPlanets(bounds)) {
        if (highlight) {
          if ((_ref3 = g.limitPathV) != null) {
            _ref3.strokeColor = 'red';
          }
          if ((_ref4 = g.limitPathH) != null) {
            _ref4.strokeColor = 'red';
          }
        } else {
          return false;
        }
      }
      locks = g.RLock.getLocksWhichIntersect(bounds);
      for (_j = 0, _len1 = locks.length; _j < _len1; _j++) {
        lock = locks[_j];
        if (g.RLock.prototype.isPrototypeOf(item)) {
          if (item !== lock) {
            if (highlight) {
              lock.highlight('red');
            } else {
              return false;
            }
          }
        } else {
          if (lock.getBounds().contains(bounds) && g.me === lock.owner) {
            if (item.lock !== lock) {
              if (highlight) {
                lock.highlight('green');
              } else {
                lock.addItem(item);
              }
            }
          } else {
            if (highlight) {
              lock.highlight('red');
            } else {
              return false;
            }
          }
        }
      }
      if (locks.length === 0) {
        if (item.lock != null) {
          if (highlight) {
            g.highlightStage('green');
          } else {
            g.addItemToStage(item);
          }
        }
      }
      if (g.RLock.prototype.isPrototypeOf(item)) {
        if (!item.containsChildren()) {
          if (highlight) {
            item.highlight('red');
          } else {
            return false;
          }
        }
      }
      return true;
    };
    g.zIndexSortStop = function(event, ui) {
      var item, nextItemJ, previousItemJ, previouslySelectedItems, rItem, _i, _len;
      previouslySelectedItems = g.selectedItems;
      g.deselectAll();
      rItem = g.items[ui.item.attr("data-pk")];
      nextItemJ = ui.item.next();
      if (nextItemJ.length > 0) {
        rItem.insertAbove(g.items[nextItemJ.attr("data-pk")], null, true);
      } else {
        previousItemJ = ui.item.prev();
        if (previousItemJ.length > 0) {
          rItem.insertBelow(g.items[previousItemJ.attr("data-pk")], null, true);
        }
      }
      for (_i = 0, _len = previouslySelectedItems.length; _i < _len; _i++) {
        item = previouslySelectedItems[_i];
        item.select();
      }
    };
    g.addItemToStage = function(item) {
      g.addItemTo(item);
    };
    g.addItemTo = function(item, lock) {
      var group, parent, wasSelected;
      if (lock == null) {
        lock = null;
      }
      wasSelected = item.isSelected();
      if (wasSelected) {
        item.deselect();
      }
      group = lock ? lock.group : g.mainLayer;
      group.addChild(item.group);
      item.lock = lock;
      item.sortedItems.remove(item);
      parent = lock || g;
      if (g.RDiv.prototype.isPrototypeOf(item)) {
        item.sortedItems = parent.sortedDivs;
        parent.itemListsJ.find(".rDiv-list").append(item.liJ);
      } else if (g.RPath.prototype.isPrototypeOf(item)) {
        item.sortedItems = parent.sortedPaths;
        parent.itemListsJ.find(".rPath-list").append(item.liJ);
      } else {
        console.error("Error: the item is neither an RDiv nor an RPath");
      }
      item.updateZIndex();
      if (wasSelected) {
        item.select();
      }
    };
    g.getRotatedBounds = function(rectangle, rotation) {
      var bottomLeft, bottomRight, bounds, topLeft, topRight;
      if (rotation == null) {
        rotation = 0;
      }
      topLeft = rectangle.topLeft.subtract(rectangle.center);
      topLeft.angle += rotation;
      bottomRight = rectangle.bottomRight.subtract(rectangle.center);
      bottomRight.angle += rotation;
      bottomLeft = rectangle.bottomLeft.subtract(rectangle.center);
      bottomLeft.angle += rotation;
      topRight = rectangle.topRight.subtract(rectangle.center);
      topRight.angle += rotation;
      bounds = new Rectangle(rectangle.center.add(topLeft), rectangle.center.add(bottomRight));
      bounds = bounds.include(rectangle.center.add(bottomLeft));
      bounds = bounds.include(rectangle.center.add(topRight));
      return bounds;
    };
    g.rasterizeProject = function(paths) {
      var p, path, pk, _i, _j, _len, _len1, _ref, _ref1;
      _ref = g.path;
      for (pk in _ref) {
        p = _ref[pk];
        if (p.drawing == null) {
          p.draw();
        }
        p.group.visible = true;
      }
      for (_i = 0, _len = paths.length; _i < _len; _i++) {
        path = paths[_i];
        path.group.visible = false;
        view.update();
      }
      g.putViewToRasters();
      _ref1 = g.paths;
      for (pk in _ref1) {
        p = _ref1[pk];
        if (paths.indexOf(p) < 0) {
          p.group.visible = false;
        }
      }
      for (_j = 0, _len1 = paths.length; _j < _len1; _j++) {
        path = paths[_j];
        path.group.visible = true;
      }
    };
    g.restoreProject = function() {
      if (path.getDrawingBounds() < 2000 * 2000) {
        g.putImageToRasters(path.drawing.rasterize());
      }
    };
    g.rasterizeToRasters = function() {
      var imageData, intersection, intersectionInView, positionInRaster, raster, rasterColumn, x, y, _ref;
      _ref = g.rasters;
      for (x in _ref) {
        rasterColumn = _ref[x];
        for (y in rasterColumn) {
          raster = rasterColumn[y];
          intersection = raster.bounds.intersect(view.bounds);
          if (intersection.area > 0) {
            positionInRaster = intersection.topLeft.subtract(raster.bounds.topLeft);
            intersectionInView = g.projectToViewRectangle(intersection);
            imageData = g.context.getImageData(intersectionInView.x, intersectionInView.y, intersectionInView.width, intersectionInView.height);
            raster.setImageData(imageData, positionInRaster.x, positionInRaster.y);
          }
        }
      }
    };
    g.putViewToRasters = function(r) {
      g.putImageToRasters(g.context, view.bounds);
    };
    g.putRasterToRasters = function(raster) {
      var bounds;
      bounds = g.projectToViewRectangle(raster.bounds);
      raster.size = raster.size.multiply(view.zoom);
      g.putImageToRasters(raster, bounds);
    };
    g.putRasterToRasters = function(raster) {
      var bounds, imageData, intersection, intersectionInView, positionInRaster, rasterColumn, x, y, _ref;
      raster.size = raster.size.multiply(view.zoom);
      bounds = raster.bounds;
      _ref = g.rasters;
      for (x in _ref) {
        rasterColumn = _ref[x];
        for (y in rasterColumn) {
          raster = rasterColumn[y];
          intersection = raster.bounds.intersect(bounds);
          if (intersection.area > 0) {
            positionInRaster = intersection.topLeft.subtract(raster.bounds.topLeft).divide(raster.bounds.width, raster.bounds.height).multiply(1000, 1000);
            intersectionInView = g.projectToViewRectangle(intersection);
            imageData = container.getImageData(intersectionInView.x, intersectionInView.y, intersectionInView.width, intersectionInView.height);
            raster.setImageData(imageData, positionInRaster.x, positionInRaster.y);
          }
        }
      }
    };
    g.putImageToRasters = function(container, bounds) {
      var imageData, intersection, intersectionInView, positionInRaster, raster, rasterColumn, x, y, _ref;
      _ref = g.rasters;
      for (x in _ref) {
        rasterColumn = _ref[x];
        for (y in rasterColumn) {
          raster = rasterColumn[y];
          intersection = raster.bounds.intersect(bounds);
          if (intersection.area > 0) {
            positionInRaster = intersection.topLeft.subtract(raster.bounds.topLeft).divide(raster.bounds.width, raster.bounds.height).multiply(1000, 1000);
            intersectionInView = g.projectToViewRectangle(intersection);
            imageData = container.getImageData(intersectionInView.x, intersectionInView.y, intersectionInView.width, intersectionInView.height);
            raster.setImageData(imageData, positionInRaster.x, positionInRaster.y);
          }
        }
      }
    };
    g.areaToImageDataUrl = function(rectangle, convertToView) {
      var canvasTemp, contextTemp, dataURL, viewRectangle;
      if (convertToView == null) {
        convertToView = true;
      }
      if (rectangle.height <= 0 || rectangle.width <= 0) {
        console.log('Warning: trying to extract empty area!!!');
        return null;
      }
      if (convertToView) {
        rectangle = rectangle.intersect(view.bounds);
        viewRectangle = g.projectToViewRectangle(rectangle);
      } else {
        viewRectangle = rectangle;
      }
      if (viewRectangle.size.equals(view.size) && viewRectangle.x === 0 && viewRectangle.y === 0) {
        return g.canvas.toDataURL("image/png");
      }
      canvasTemp = document.createElement('canvas');
      canvasTemp.width = viewRectangle.width;
      canvasTemp.height = viewRectangle.height;
      contextTemp = canvasTemp.getContext('2d');
      contextTemp.putImageData(g.context.getImageData(viewRectangle.x, viewRectangle.y, viewRectangle.width, viewRectangle.height), 0, 0);
      dataURL = canvasTemp.toDataURL("image/png");
      return dataURL;
    };
    g.shrinkRectangleToInteger = function(rectangle) {
      return new Rectangle(rectangle.topLeft.ceil(), rectangle.bottomRight.floor());
    };
    g.expandRectangleToInteger = function(rectangle) {
      return new Rectangle(rectangle.topLeft.floor(), rectangle.bottomRight.ceil());
    };
    g.expandRectangleToMultiple = function(rectangle, multiple) {
      return new Rectangle(g.floorPointToMultiple(rectangle.topLeft, multiple), g.ceilPointToMultiple(rectangle.bottomRight, multiple));
    };
    g.roundRectangle = function(rectangle) {
      return new Rectangle(rectangle.topLeft.round(), rectangle.bottomRight.round());
    };
    g.floorToMultiple = function(x, m) {
      return Math.floor(x / m) * m;
    };
    g.ceilToMultiple = function(x, m) {
      return Math.ceil(x / m) * m;
    };
    g.roundToMultiple = function(x, m) {
      return Math.round(x / m) * m;
    };
    g.floorPointToMultiple = function(point, m) {
      return new Point(g.floorToMultiple(point.x, m), g.floorToMultiple(point.y, m));
    };
    g.ceilPointToMultiple = function(point, m) {
      return new Point(g.ceilToMultiple(point.x, m), g.ceilToMultiple(point.y, m));
    };
    g.roundPointToMultiple = function(point, m) {
      return new Point(g.roundToMultiple(point.x, m), g.roundToMultiple(point.y, m));
    };
    g.addChildrenToParent = function(parent, sortedItems) {
      var item, _i, _len, _ref;
      if (parent.children == null) {
        return;
      }
      _ref = parent.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if ((item.controller != null) && Group.prototype.isPrototypeOf(item)) {
          sortedItems.push(item.controller);
          if (g.RLock.prototype.isPrototypeOf(item.controller)) {
            g.addChildrenToParent(item, sortedItems);
          }
        }
      }
    };
    g.getSortedItems = function() {
      var sortedItems;
      sortedItems = [];
      g.addChildrenToParent(g.mainLayer, sortedItems);
      g.addChildrenToParent(g.lockLayer, sortedItems);
      return sortedItems;
    };
    g.highlightAreasToUpdate = function() {
      var pk, rectangle, rectanglePath, _ref;
      _ref = g.areasToUpdate;
      for (pk in _ref) {
        rectangle = _ref[pk];
        rectanglePath = project.getItem({
          name: pk
        });
        rectanglePath.strokeColor = 'green';
      }
    };
    g.logItems = function() {
      var i, item, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      console.log("Selected items:");
      _ref = project.selectedItems;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        item = _ref[i];
        if (((_ref1 = item.name) != null ? _ref1.indexOf("debug") : void 0) === 0) {
          continue;
        }
        console.log("------" + i + "------");
        console.log(item.name);
        console.log(item);
        console.log(item.controller);
        console.log((_ref2 = item.controller) != null ? _ref2.pk : void 0);
      }
      console.log("All items:");
      _ref3 = project.activeLayer.children;
      for (i = _j = 0, _len1 = _ref3.length; _j < _len1; i = ++_j) {
        item = _ref3[i];
        if (((_ref4 = item.name) != null ? _ref4.indexOf("debug") : void 0) === 0) {
          continue;
        }
        console.log("------" + i + "------");
        console.log(item.name);
        console.log(item);
        console.log(item.controller);
        console.log((_ref5 = item.controller) != null ? _ref5.pk : void 0);
      }
      return "--- THE END ---";
    };
    g.checkRasters = function() {
      var item, _i, _len, _ref;
      _ref = project.activeLayer.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if ((item.controller != null) && (item.controller.raster == null)) {
          console.log(item.controller);
        }
      }
    };
    g.selectRasters = function() {
      var item, rasters, _i, _len, _ref;
      rasters = [];
      _ref = project.activeLayer.children;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        if (item.constructor.name === "Raster") {
          item.selected = true;
          rasters.push(item);
        }
      }
      console.log('selected rasters:');
      return rasters;
    };
    g.printPathList = function() {
      var names, pathClass, _i, _len, _ref;
      names = [];
      _ref = g.pathClasses;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        pathClass = _ref[_i];
        names.push(pathClass.rname);
      }
      console.log(names);
    };
    g.fakeGeoJsonBox = function(rectangle) {
      var box, planet;
      box = {};
      planet = g.pointToObj(g.projectToPlanet(rectangle.topLeft));
      box.planetX = planet.x;
      box.planetY = planet.y;
      box.box = {
        coordinates: [[g.pointToArray(g.projectToPosOnPlanet(rectangle.topLeft, planet)), g.pointToArray(g.projectToPosOnPlanet(rectangle.topRight, planet)), g.pointToArray(g.projectToPosOnPlanet(rectangle.bottomRight, planet)), g.pointToArray(g.projectToPosOnPlanet(rectangle.bottomLeft, planet))]]
      };
      return JSON.stringify(box);
    };
    g.getControllerFromFomElement = function() {
      var controller, folder, folderName, _i, _len, _ref, _ref1;
      _ref = g.gui.__folders;
      for (folderName in _ref) {
        folder = _ref[folderName];
        _ref1 = folder.__controllers;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          controller = _ref1[_i];
          if (controller.domElement === $0 || $($0).find(controller.domElement).length > 0) {
            return controller;
          }
        }
      }
    };
    g.logStack = function() {
      var caller;
      caller = arguments.callee.caller;
      while (caller != null) {
        console.log(caller.prototype);
        caller = caller.caller;
      }
    };
    g.getCoffeeSources = function() {
      $.ajax({
        url: g.romanescoURL + "static/coffee/path.coffee"
      }).done(function(data) {
        var classMap, expression, expressions, lines, pathClass, _i, _j, _len, _len1, _ref, _ref1;
        lines = data.split(/\n/);
        expressions = CoffeeScript.nodes(data).expressions;
        classMap = {};
        _ref = g.pathClasses;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          pathClass = _ref[_i];
          classMap[pathClass.name] = pathClass;
        }
        for (_j = 0, _len1 = expressions.length; _j < _len1; _j++) {
          expression = expressions[_j];
          if ((_ref1 = classMap[expression.variable.base.value]) != null) {
            _ref1.source = lines.slice(expression.locationData.first_line, +expression.locationData.last_line + 1 || 9e9).join("\n");
          }
        }
      });
    };
    g.toggleToolToFavorite = function(event, btnJ) {
      var cloneJ, li, names, targetJ, toolName, _i, _len, _ref;
      if (btnJ == null) {
        event.stopPropagation();
        targetJ = $(event.target);
        btnJ = targetJ.parents("li.tool-btn:first");
      }
      toolName = btnJ.attr("data-name");
      if (btnJ.hasClass("selected")) {
        btnJ.removeClass("selected");
        g.favoriteToolsJ.find("[data-name='" + toolName + "']").remove();
        g.favoriteTools.remove(toolName);
      } else {
        btnJ.addClass("selected");
        cloneJ = btnJ.clone();
        g.favoriteToolsJ.append(cloneJ);
        cloneJ.click(function(event) {
          var _ref;
          toolName = $(this).attr("data-name");
          if ((_ref = g.tools[toolName]) != null) {
            _ref.select();
          }
        });
        g.favoriteTools.push(toolName);
      }
      if (typeof localStorage === "undefined" || localStorage === null) {
        return;
      }
      names = [];
      _ref = g.favoriteToolsJ.children();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        li = _ref[_i];
        names.push($(li).attr("data-name"));
      }
      localStorage.favorites = JSON.stringify(names);
    };
    g.createToolButton = function(name, iconURL, favorite, category, parentJ) {
      var btnJ, categories, favoriteBtnJ, hJ, liJ, shortName, shortNameJ, toolNameJ, ulJ, word, words, _i, _j, _len, _len1;
      if (category == null) {
        category = null;
      }
      if (parentJ == null) {
        parentJ = g.allToolsJ;
      }
      if ((category != null) && category !== "") {
        categories = category.split("/");
        for (_i = 0, _len = categories.length; _i < _len; _i++) {
          category = categories[_i];
          ulJ = parentJ.find("li[data-name='" + category + "'] > ul");
          if (ulJ.length === 0) {
            liJ = $("<li data-name='" + category + "'>");
            liJ.addClass('category');
            hJ = $('<h6>');
            hJ.text(category).addClass("title");
            liJ.append(hJ);
            ulJ = $("<ul>");
            ulJ.addClass('folder');
            liJ.append(ulJ);
            hJ.click(function(event) {
              $(this).parent().toggleClass('closed');
            });
            parentJ.append(liJ);
          }
          parentJ = ulJ;
        }
      }
      btnJ = $("<li>");
      btnJ.attr("data-name", name);
      btnJ.attr("alt", name);
      if ((iconURL != null) && iconURL !== '') {
        btnJ.append('<img src="' + iconURL + '" alt="' + name + '-icon">');
      } else {
        btnJ.addClass("text-btn");
        words = name.split(" ");
        shortName = "";
        if (words.length > 1) {
          for (_j = 0, _len1 = words.length; _j < _len1; _j++) {
            word = words[_j];
            shortName += word.substring(0, 1);
          }
        } else {
          shortName += name.substring(0, 2);
        }
        shortNameJ = $('<span class="short-name">').text(shortName + ".");
        btnJ.append(shortNameJ);
      }
      parentJ.append(btnJ);
      toolNameJ = $('<span class="tool-name">').text(name);
      btnJ.append(toolNameJ);
      btnJ.addClass("tool-btn");
      favoriteBtnJ = $("<button type=\"button\" class=\"btn btn-default favorite-btn\">\n  			<span class=\"glyphicon glyphicon-star\" aria-hidden=\"true\"></span>\n</button>");
      favoriteBtnJ.click(g.toggleToolToFavorite);
      btnJ.append(favoriteBtnJ);
      if (favorite) {
        g.toggleToolToFavorite(null, btnJ);
      }
      return btnJ;
    };
    g.startTime = Date.now();
    g.logElapsedTime = function() {
      var time;
      time = (Date.now() - g.startTime) / 1000;
      console.log("Time elapsed: " + time + " sec.");
    };
    g.startTimer = function() {
      g.timerStartTime = Date.now();
    };
    g.stopTimer = function(message) {
      var time;
      time = (Date.now() - g.timerStartTime) / 1000;
      console.log("" + message + ": " + time + " sec.");
    };
    g.setDebugMode = function(debugMode) {
      Dajaxice.draw.setDebugMode(g.checkError, {
        debug: debugMode
      });
    };
    g.roughSizeOfObject = function(object, maxDepth) {
      var blackList, bytes, depth, ignoreBlackList, name, objectList, property, s, stack, value;
      if (maxDepth == null) {
        maxDepth = 4;
      }
      if (Item.prototype.isPrototypeOf(object)) {
        object = object.clone(false);
      }
      blackList = ['project', 'layer', 'view', 'parent', '_project', '_layer', '_view', '_parent'];
      objectList = [];
      stack = [
        {
          depth: 0,
          object: object
        }
      ];
      bytes = 0;
      depth = 0;
      while (stack.length) {
        s = stack.pop();
        value = s.object;
        depth = s.depth;
        if (depth > maxDepth) {
          console.log(s.name);
          continue;
        }
        ignoreBlackList = Item.prototype.isPrototypeOf(value) || Style.prototype.isPrototypeOf(value);
        if (typeof value === 'boolean') {
          bytes += 4;
        } else if (typeof value === 'string') {
          bytes += value.length * 2;
        } else if (typeof value === 'number') {
          bytes += 8;
        } else if (typeof value === 'object' && objectList.indexOf(value) === -1) {
          objectList.push(value);
          for (name in value) {
            property = value[name];
            if (__indexOf.call(blackList, name) < 0) {
              stack.push({
                object: property,
                depth: s.depth + 1,
                name: name
              });
            }
          }
        }
      }
      console.log('takes ' + bytes + ' bytes.');
      return bytes;
    };
    doAreasOverlap = function(areas) {
      var a, area, _i, _j, _len, _len1;
      for (_i = 0, _len = areas.length; _i < _len; _i++) {
        area = areas[_i];
        for (_j = 0, _len1 = areas.length; _j < _len1; _j++) {
          a = areas[_j];
          if (a.intersects(area)) {
            console.log("OVERLAAAAAAAAAPP");
          }
        }
      }
    };
  });

}).call(this);

//# sourceMappingURL=global.map
