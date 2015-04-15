// Generated by CoffeeScript 1.7.1
(function() {
  var Rasterizer,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Rasterizer = (function() {
    Rasterizer.MAX_AREA = 1.5;

    Rasterizer.UNION_RATIO = 1.5;

    function Rasterizer() {
      this.rasterizeCallback = __bind(this.rasterizeCallback, this);
      var bounds, qBounds, scale, x, y, zoom, _i, _j, _ref, _ref1, _ref2, _ref3;
      this.itemsToExclude = [];
      this.areaToRasterize = null;
      this.areasToUpdate = [];
      this.rasters = {};
      bounds = view.bounds;
      zoom = g.quantizeZoom(1.0 / view.zoom);
      scale = zoom * g.scale;
      qBounds = this.quantizeBounds(bounds, scale);
      for (x = _i = _ref = qBounds.l, _ref1 = qBounds.r; scale > 0 ? _i <= _ref1 : _i >= _ref1; x = _i += scale) {
        for (y = _j = _ref2 = qBounds.t, _ref3 = qBounds.b; scale > 0 ? _j <= _ref3 : _j >= _ref3; y = _j += scale) {
          this.createUpdateRaster(x, y, zoom);
        }
      }
      this.move();
      return;
    }

    Rasterizer.prototype.quantizeBounds = function(bounds, scale) {
      var quantizedBounds;
      if (bounds == null) {
        bounds = view.bounds;
      }
      if (scale == null) {
        scale = g.scale;
      }
      quantizedBounds = {
        t: g.floorToMultiple(bounds.top, scale),
        l: g.floorToMultiple(bounds.left, scale),
        b: g.floorToMultiple(bounds.bottom, scale),
        r: g.floorToMultiple(bounds.right, scale)
      };
      return quantizedBounds;
    };

    Rasterizer.prototype.createUpdateRaster = function(x, y, zoom) {
      var raster, _base, _ref;
      raster = (_ref = this.rasters[x]) != null ? _ref[y] : void 0;
      if (raster != null) {
        return;
      }
      raster = {};
      raster.canvasJ = $('<canvas hidpi="off" width="' + g.scale + '" height="' + g.scale + '">');
      raster.canvas = raster.canvasJ[0];
      raster.zoom = zoom;
      raster.context = raster.canvas.getContext('2d');
      raster.image = new Image();
      raster.image.onload = (function(_this) {
        return function() {
          var allRastersAreReady, rasterColumn, _ref1;
          console.log(raster.image.src);
          raster.context.clearRect(0, 0, g.scale, g.scale);
          raster.context.drawImage(raster.image, 0, 0);
          raster.ready = true;
          allRastersAreReady = true;
          _ref1 = _this.rasters;
          for (x in _ref1) {
            rasterColumn = _ref1[x];
            for (y in rasterColumn) {
              raster = rasterColumn[y];
              allRastersAreReady &= raster.ready;
            }
          }
          if (allRastersAreReady) {
            _this.rasterizeAreasToUpdate();
          }
        };
      })(this);
      raster.ready = true;
      $("#rasters").append(raster.canvasJ);
      if ((_base = this.rasters)[x] == null) {
        _base[x] = {};
      }
      this.rasters[x][y] = raster;
    };

    Rasterizer.prototype.getRasterBounds = function(x, y) {
      var size;
      size = this.rasters[x][y].zoom * g.scale;
      return new Rectangle(x, y, size, size);
    };

    Rasterizer.prototype.removeRaster = function(raster, x, y) {
      raster.canvasJ.remove();
      delete this.rasters[x][y];
      if (g.isEmpty(this.rasters[x])) {
        delete this.rasters[x];
      }
    };

    Rasterizer.prototype.unload = function(limit) {
      var qZoom, raster, rasterColumn, rectangle, x, y, _ref;
      qZoom = g.quantizeZoom(1.0 / view.zoom);
      _ref = this.rasters;
      for (x in _ref) {
        rasterColumn = _ref[x];
        x = Number(x);
        for (y in rasterColumn) {
          raster = rasterColumn[y];
          y = Number(y);
          rectangle = this.getRasterBounds(x, y);
          if (!limit.intersects(rectangle) || this.rasters[x][y].zoom !== qZoom) {
            this.removeRaster(raster, x, y);
          }
        }
      }
    };

    Rasterizer.prototype.load = function(rasters, qZoom) {
      var r, raster, x, y, _i, _len, _ref;
      this.move();
      for (_i = 0, _len = rasters.length; _i < _len; _i++) {
        r = rasters[_i];
        x = r.position.x * g.scale;
        y = r.position.y * g.scale;
        raster = (_ref = this.rasters[x]) != null ? _ref[y] : void 0;
        if (raster) {
          raster.ready = false;
          raster.image.src = g.romanescoURL + r.url + '?' + Math.random();
        }
      }
    };

    Rasterizer.prototype.move = function() {
      var css, qBounds, qZoom, raster, rasterColumn, scale, viewPos, x, y, _i, _j, _ref, _ref1, _ref2, _ref3, _ref4;
      qZoom = g.quantizeZoom(1.0 / view.zoom);
      scale = g.scale * qZoom;
      qBounds = this.quantizeBounds(view.bounds, scale);
      for (x = _i = _ref = qBounds.l, _ref1 = qBounds.r; scale > 0 ? _i <= _ref1 : _i >= _ref1; x = _i += scale) {
        for (y = _j = _ref2 = qBounds.t, _ref3 = qBounds.b; scale > 0 ? _j <= _ref3 : _j >= _ref3; y = _j += scale) {
          this.createUpdateRaster(x, y, qZoom);
        }
      }
      _ref4 = this.rasters;
      for (x in _ref4) {
        rasterColumn = _ref4[x];
        x = Number(x);
        for (y in rasterColumn) {
          raster = rasterColumn[y];
          y = Number(y);
          viewPos = view.projectToView(new Point(x, y));
          if (view.zoom === 1) {
            raster.canvasJ.css({
              'left': viewPos.x,
              'top': viewPos.y,
              'transform': 'none'
            });
          } else {
            scale = view.zoom * raster.zoom;
            css = 'translate(' + viewPos.x + 'px,' + viewPos.y + 'px)';
            css += ' scale(' + scale + ')';
            raster.canvasJ.css({
              'transform': css,
              'top': 0,
              'left': 0,
              'transform-origin': '0 0'
            });
          }
        }
      }
    };

    Rasterizer.prototype.splitAreaToRasterize = function() {
      var area, areas, maxSize;
      maxSize = view.size.multiply(2);
      area = g.expandRectangleToInteger(new Rectangle(this.areaToRasterize.topLeft, Size.min(maxSize, this.areaToRasterize.size)));
      areas = [area.clone()];
      while (area.right < this.areaToRasterize.right || area.bottom < this.areaToRasterize.bottom) {
        if (area.right < this.areaToRasterize.right) {
          area.x += maxSize.width;
        } else {
          area.y += maxSize.height;
        }
        areas.push(area.clone());
      }
      return areas;
    };

    Rasterizer.prototype.rasterizeCanvasInRaster = function(x, y, canvas, rectangle, qZoom, clearRasters) {
      var context, destinationRectangle, intersection, rasterRectangle, sourceRectangle, _ref;
      if (clearRasters == null) {
        clearRasters = false;
      }
      if (((_ref = this.rasters[x]) != null ? _ref[y] : void 0) == null) {
        return;
      }
      rasterRectangle = this.getRasterBounds(x, y);
      intersection = rectangle.intersect(rasterRectangle);
      sourceRectangle = new Rectangle(intersection.topLeft.subtract(rectangle.topLeft).divide(qZoom), intersection.size.divide(qZoom));
      destinationRectangle = new Rectangle(intersection.topLeft.subtract(rasterRectangle.topLeft).divide(qZoom), intersection.size.divide(qZoom));
      context = this.rasters[x][y].context;
      if (clearRasters) {
        context.clearRect(destinationRectangle.x, destinationRectangle.y, destinationRectangle.width, destinationRectangle.height);
      }
      context.drawImage(canvas, sourceRectangle.x, sourceRectangle.y, sourceRectangle.width, sourceRectangle.height, destinationRectangle.x, destinationRectangle.y, destinationRectangle.width, destinationRectangle.height);
    };

    Rasterizer.prototype.rasterizeCanvas = function(canvas, rectangle, clearRasters) {
      var qBounds, qZoom, scale, x, y, _i, _j, _ref, _ref1, _ref2, _ref3;
      if (clearRasters == null) {
        clearRasters = false;
      }
      console.log("rasterize: " + rectangle.width + ", " + rectangle.height);
      qZoom = g.quantizeZoom(1.0 / view.zoom);
      scale = g.scale * qZoom;
      qBounds = this.quantizeBounds(rectangle, scale);
      for (x = _i = _ref = qBounds.l, _ref1 = qBounds.r; scale > 0 ? _i <= _ref1 : _i >= _ref1; x = _i += scale) {
        for (y = _j = _ref2 = qBounds.t, _ref3 = qBounds.b; scale > 0 ? _j <= _ref3 : _j >= _ref3; y = _j += scale) {
          this.rasterizeCanvasInRaster(x, y, canvas, rectangle, qZoom, clearRasters);
        }
      }
    };

    Rasterizer.prototype.rasterizeArea = function(area) {
      view.viewSize = area.size.multiply(view.zoom);
      view.center = area.center;
      view.update();
      this.rasterizeCanvas(g.canvas, area, true);
    };

    Rasterizer.prototype.rasterizeAreas = function(areas) {
      var area, viewPosition, viewSize, viewZoom, _i, _len;
      viewZoom = view.zoom;
      viewSize = view.viewSize;
      viewPosition = view.center;
      view.zoom = 1.0 / g.quantizeZoom(1.0 / view.zoom);
      for (_i = 0, _len = areas.length; _i < _len; _i++) {
        area = areas[_i];
        this.rasterizeArea(area);
      }
      view.zoom = viewZoom;
      view.viewSize = viewSize;
      view.center = viewPosition;
    };

    Rasterizer.prototype.rasterizeCallback = function(step) {
      var areas, item, pk, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6;
      if (this.rasterizationDisabled) {
        return;
      }
      console.log("rasterize");
      console.log(Date.now());
      _ref = g.items;
      for (pk in _ref) {
        item = _ref[pk];
        item.group.visible = true;
      }
      areas = this.splitAreaToRasterize();
      _ref1 = this.itemsToExclude;
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        item = _ref1[_i];
        if ((_ref2 = item.group) != null) {
          _ref2.visible = false;
        }
      }
      g.grid.visible = false;
      g.selectionLayer.visible = false;
      this.rasterizeAreas(areas);
      g.selectionLayer.visible = true;
      g.grid.visible = true;
      _ref3 = g.items;
      for (pk in _ref3) {
        item = _ref3[pk];
        if ((_ref4 = item.group) != null) {
          _ref4.visible = item.selectionRectangle != null;
        }
      }
      _ref5 = this.itemsToExclude;
      for (_j = 0, _len1 = _ref5.length; _j < _len1; _j++) {
        item = _ref5[_j];
        if ((_ref6 = item.group) != null) {
          _ref6.visible = true;
        }
        if (typeof item.showChildren === "function") {
          item.showChildren();
        }
      }
      this.itemsToExclude = [];
      this.areaToRasterize = null;
    };

    Rasterizer.prototype.rasterize = function(items, excludeItems) {
      var item, _i, _len;
      if (this.rasterizationDisabled) {
        return;
      }
      console.log("ask rasterize" + (excludeItems ? "exclude items" : ""));
      if (!g.isArray(items)) {
        items = [items];
      }
      for (_i = 0, _len = items.length; _i < _len; _i++) {
        item = items[_i];
        if (this.areaToRasterize == null) {
          this.areaToRasterize = item.getDrawingBounds();
        }
        this.areaToRasterize = this.areaToRasterize.unite(item.getDrawingBounds());
        if (excludeItems) {
          g.pushIfAbsent(this.itemsToExclude, item);
        }
      }
      g.callNextFrame(this.rasterizeCallback, 'rasterize');
    };

    Rasterizer.prototype.rasterizeRectangle = function(rectangle) {
      if (this.rasterizationDisabled) {
        return;
      }
      this.drawItems();
      if (this.areaToRasterize == null) {
        this.areaToRasterize = rectangle;
      } else {
        this.areaToRasterize = this.areaToRasterize.unite(rectangle);
      }
      g.callNextFrame(this.rasterizeCallback, 'rasterize');
    };

    Rasterizer.prototype.addAreaToUpdate = function(area) {
      this.areasToUpdate.push(area);
    };

    Rasterizer.prototype.setQZoomToUpdate = function(qZoom) {
      this.areasToUpdateQZoom = qZoom;
    };

    Rasterizer.prototype.rasterizeAreasToUpdate = function() {
      var area, previousAreaToRasterize, previousItemsToExclude, previousZoom, _i, _len, _ref;
      if (this.rasterizationDisabled) {
        return;
      }
      if (this.areasToUpdate.length === 0) {
        return;
      }
      this.drawItems(true);
      previousItemsToExclude = this.itemsToExclude;
      previousAreaToRasterize = this.areaToRasterize;
      previousZoom = view.zoom;
      view.zoom = 1.0 / this.areasToUpdateQZoom;
      this.itemsToExclude = [];
      _ref = this.areasToUpdate;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        area = _ref[_i];
        this.areaToRasterize = area;
        this.rasterizeCallback();
      }
      this.areasToUpdate = [];
      this.itemsToExclude = previousItemsToExclude;
      this.areaToRasterize = previousAreaToRasterize;
      view.zoom = previousZoom;
    };

    Rasterizer.prototype.maxArea = function() {
      return view.bounds.area * this.constructor.MAX_AREA;
    };

    Rasterizer.prototype.drawItems = function(showPath) {
      var item, pk, _ref;
      if (showPath == null) {
        showPath = false;
      }
      if (this.rasterizationDisabled) {
        return;
      }
      _ref = g.items;
      for (pk in _ref) {
        item = _ref[pk];
        if (item.drawing == null) {
          if (typeof item.draw === "function") {
            item.draw();
          }
        }
        item.group.visible = showPath || (item.selectionRectangle != null);
      }
    };

    Rasterizer.prototype.clearRasters = function() {
      var raster, rasterColumn, x, y, _ref;
      _ref = this.rasters;
      for (x in _ref) {
        rasterColumn = _ref[x];
        for (y in rasterColumn) {
          raster = rasterColumn[y];
          raster.context.clearRect(0, 0, g.scale, g.scale);
        }
      }
    };

    Rasterizer.prototype.rasterizeView = function() {
      this.rasterizeRectangle(view.bounds);
    };

    Rasterizer.prototype.disableRasterization = function() {
      var name, property;
      this.drawItems(true);
      g.hideRasters();
      this.previousFunctions = {};
      for (name in this) {
        property = this[name];
        if (typeof property === 'function' && name !== 'enableRasterization') {
          this.previousFunctions[name] = property;
          this[name] = function() {};
        }
      }
    };

    Rasterizer.prototype.enableRasterization = function() {
      var name, property, _ref;
      _ref = this.previousFunction;
      for (name in _ref) {
        property = _ref[name];
        if (typeof property === 'function') {
          this[name] = this.previousFunction[name];
        }
      }
      delete this.previousFunctions;
      g.showRasters();
      this.clearRasters();
      this.rasterizeView();
    };

    return Rasterizer;

  })();

  this.Rasterizer = Rasterizer;

}).call(this);

//# sourceMappingURL=rasterizer.map
