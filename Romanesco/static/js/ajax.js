// Generated by CoffeeScript 1.7.1
(function() {
  var __hasProp = {}.hasOwnProperty;

  this.areaIsLoaded = function(pos, planet) {
    var area, _i, _len, _ref;
    _ref = g.loadedAreas;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      area = _ref[_i];
      if (area.planet.x === planet.x && area.planet.y === planet.y) {
        if (area.pos.x === pos.x && area.pos.y === pos.y) {
          return true;
        }
      }
    }
    return false;
  };

  this.areaIsQuickLoaded = function(area) {
    var a, _i, _len, _ref;
    _ref = g.loadedAreas;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      a = _ref[_i];
      if (a.x === area.x && a.y === area.y) {
        return true;
      }
    }
    return false;
  };

  this.load = function(area) {
    var areaRectangle, areasToLoad, b, bounds, debug, i, item, itemsOutsideLimit, j, l, limit, pk, planet, pos, r, raster, rasterColumn, rectangle, removeRectangle, scale, showLoadingBar, t, unloadDist, x, y, _i, _j, _ref, _ref1, _ref2, _ref3, _ref4;
    if (area == null) {
      area = null;
    }
    if ((g.previousLoadPosition != null) && g.previousLoadPosition.subtract(view.center).length < 50) {
      return;
    }
    console.log("load");
    debug = false;
    scale = !debug ? g.scale : 500;
    g.previousLoadPosition = view.center;
    if (area == null) {
      bounds = !debug ? view.bounds : view.bounds.scale(0.3, 0.3);
    } else {
      bounds = area;
    }
    if (debug) {
      if ((_ref = g.unloadRectangle) != null) {
        _ref.remove();
      }
      if ((_ref1 = g.viewRectangle) != null) {
        _ref1.remove();
      }
      if ((_ref2 = g.limitRectangle) != null) {
        _ref2.remove();
      }
    }
    unloadDist = 0;
    if (!g.entireArea) {
      limit = bounds.expand(unloadDist);
    } else {
      limit = g.entireArea;
    }
    itemsOutsideLimit = [];
    _ref3 = g.items;
    for (pk in _ref3) {
      if (!__hasProp.call(_ref3, pk)) continue;
      item = _ref3[pk];
      if (!item.getBounds().intersects(limit)) {
        itemsOutsideLimit.push(item);
      }
    }
    if (debug) {
      g.unloadRectangle = new Path.Rectangle(limit);
      g.unloadRectangle.name = 'debug load unload rectangle';
      g.unloadRectangle.strokeWidth = 1;
      g.unloadRectangle.strokeColor = 'red';
      g.unloadRectangle.dashArray = [10, 4];
      g.debugLayer.addChild(g.unloadRectangle);
    }
    if (debug) {
      removeRectangle = function(rectangle) {
        var removeRect;
        removeRect = function() {
          return rectangle.remove();
        };
        setTimeout(removeRect, 1500);
      };
    }
    _ref4 = g.rasters;
    for (x in _ref4) {
      rasterColumn = _ref4[x];
      for (y in rasterColumn) {
        raster = rasterColumn[y];
        if (!raster.rRectangle.intersects(limit)) {
          raster.remove();
          delete g.rasters[x][y];
          if (g.isEmpty(g.rasters[x])) {
            delete g.rasters[x];
          }
        }
      }
    }
    i = g.loadedAreas.length;
    while (i--) {
      area = g.loadedAreas[i];
      pos = posOnPlanetToProject(area.pos, area.planet);
      rectangle = new Rectangle(pos.x, pos.y, scale, scale);
      if (!rectangle.intersects(limit)) {
        if (debug) {
          area.rectangle.strokeColor = 'red';
          removeRectangle(area.rectangle);
        }
        g.loadedAreas.splice(i, 1);
        j = itemsOutsideLimit.length;
        while (j--) {
          item = itemsOutsideLimit[j];
          if (item.getBounds().intersects(rectangle)) {
            item.remove();
            itemsOutsideLimit.splice(j, 1);
          }
        }
      }
    }
    itemsOutsideLimit = null;
    t = g.roundToLowerMultiple(bounds.top, scale);
    l = g.roundToLowerMultiple(bounds.left, scale);
    b = g.roundToLowerMultiple(bounds.bottom, scale);
    r = g.roundToLowerMultiple(bounds.right, scale);
    if (debug) {
      g.viewRectangle = new Path.Rectangle(bounds);
      g.viewRectangle.name = 'debug load view rectangle';
      g.viewRectangle.strokeWidth = 1;
      g.viewRectangle.strokeColor = 'blue';
      g.debugLayer.addChild(g.viewRectangle);
      g.limitRectangle = new Path.Rectangle(new Point(l, t), new Point(r, b));
      g.limitRectangle.name = 'debug load limit rectangle';
      g.limitRectangle.strokeWidth = 2;
      g.limitRectangle.strokeColor = 'blue';
      g.limitRectangle.dashArray = [10, 4];
      g.debugLayer.addChild(g.limitRectangle);
    }
    areasToLoad = [];
    for (x = _i = l; scale > 0 ? _i <= r : _i >= r; x = _i += scale) {
      for (y = _j = t; scale > 0 ? _j <= b : _j >= b; y = _j += scale) {
        planet = projectToPlanet(new Point(x, y));
        pos = projectToPosOnPlanet(new Point(x, y));
        if (!areaIsLoaded(pos, planet)) {
          if (debug) {
            areaRectangle = new Path.Rectangle(x, y, scale, scale);
            areaRectangle.name = 'debug load area rectangle';
            areaRectangle.strokeWidth = 1;
            areaRectangle.strokeColor = 'green';
            g.debugLayer.addChild(areaRectangle);
          }
          area = {
            pos: pos,
            planet: planet,
            x: x / 1000,
            y: y / 1000
          };
          areasToLoad.push(area);
          if (debug) {
            area.rectangle = areaRectangle;
          }
          g.loadedAreas.push(area);
        }
      }
    }
    if (areasToLoad.length <= 0) {
      return;
    }
    if (g.loadingBarTimeout == null) {
      showLoadingBar = function() {
        $("#loadingBar").show();
      };
      g.loadingBarTimeout = setTimeout(showLoadingBar, 0);
    }
    console.log("load areas: " + areasToLoad.length);
    rectangle = {
      left: l / 1000,
      top: t / 1000,
      right: r / 1000,
      bottom: b / 1000
    };
    console.log("load rectangle");
    console.log(rectangle);
    Dajaxice.draw.load(load_callback, {
      rectangle: rectangle,
      areasToLoad: areasToLoad,
      zoom: view.zoom
    });
  };

  this.load_callback = function(results) {
    var box, data, date, div, i, item, itemIsLoaded, itemsToLoad, lock, newAreasToUpdate, path, pk, planet, point, points, position, raster, rdiv, rectangle, rpath, _base, _i, _j, _k, _l, _len, _len1, _len2, _len3, _name, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
    checkError(results);
    if (results.hasOwnProperty('message') && results.message === 'no_paths') {
      return;
    }
    if (g.me == null) {
      g.me = results.user;
      if (g.chatJ.find("#chatUserNameInput").length === 0) {
        g.startChatting(g.me);
      }
    }
    itemIsLoaded = function(pk) {
      return g.items[pk] != null;
    };
    _ref = results.rasters;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      raster = _ref[_i];
      position = new Point(raster.position).multiply(1000);
      if (((_ref1 = g.rasters[position.x]) != null ? (_ref2 = _ref1[position.y]) != null ? _ref2.rZoom : void 0 : void 0) === results.zoom) {
        continue;
      }
      raster = new Raster(g.romanescoURL + raster.url);
      if (results.zoom > 0.2) {
        raster.position = position.add(1000 / 2);
        raster.rRectangle = new Rectangle(position, new Size(1000, 1000));
      } else if (results.zoom > 0.04) {
        raster.scale(5);
        raster.position = position.add(5000 / 2);
        raster.rRectangle = new Rectangle(position, new Size(5000, 5000));
      } else {
        raster.scale(25);
        raster.position = position.add(25000 / 2);
        raster.rRectangle = new Rectangle(position, new Size(25000, 25000));
      }
      console.log("raster.position: " + raster.position.toString() + ", raster.scaling" + raster.scaling.toString());
      raster.name = 'raster: ' + raster.position.toString() + ', zoom: ' + results.zoom;
      raster.rZoom = results.zoom;
      if ((_base = g.rasters)[_name = position.x] == null) {
        _base[_name] = {};
      }
      g.rasters[position.x][position.y] = raster;
    }
    newAreasToUpdate = [];
    itemsToLoad = [];
    _ref3 = results.items;
    for (_j = 0, _len1 = _ref3.length; _j < _len1; _j++) {
      i = _ref3[_j];
      item = JSON.parse(i);
      if (g.items[item._id.$oid] != null) {
        continue;
      }
      if (item.rType === 'Box') {
        box = item;
        if (box.box.coordinates[0].length < 5) {
          console.log("Error: box has less than 5 points");
        }
        data = (box.data != null) && box.data.length > 0 ? JSON.parse(box.data) : null;
        lock = null;
        switch (box.object_type) {
          case 'link':
            lock = new RLink(g.rectangleFromBox(box), data, box._id.$oid, box.owner);
            break;
          case 'lock':
            lock = new RLock(g.rectangleFromBox(box), data, box._id.$oid, box.owner);
            break;
          case 'website':
            lock = new RWebsite(g.rectangleFromBox(box), data, box._id.$oid, box.owner);
            break;
          case 'video-game':
            lock = new RVideoGame(g.rectangleFromBox(box), data, box._id.$oid, box.owner);
        }
      } else {
        itemsToLoad.push(item);
      }
    }
    for (_k = 0, _len2 = itemsToLoad.length; _k < _len2; _k++) {
      item = itemsToLoad[_k];
      switch (item.rType) {
        case 'Div':
          div = item;
          if (div.box.coordinates[0].length < 5) {
            console.log("Error: box has less than 5 points");
          }
          data = (div.data != null) && div.data.length > 0 ? JSON.parse(div.data) : null;
          date = div.date.$date;
          switch (div.object_type) {
            case 'text':
              rdiv = new RText(g.rectangleFromBox(div), data, div._id.$oid, date, div.lock != null ? g.items[div.lock] : null);
              break;
            case 'media':
              rdiv = new RMedia(g.rectangleFromBox(div), data, div._id.$oid, date, div.lock != null ? g.items[div.lock] : null);
          }
          break;
        case 'Path':
          path = item;
          planet = new Point(path.planetX, path.planetY);
          date = path.date.$date;
          if ((path.data != null) && path.data.length > 0) {
            data = JSON.parse(path.data);
            data.planet = planet;
          }
          points = [];
          _ref4 = path.points.coordinates;
          for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
            point = _ref4[_l];
            points.push(posOnPlanetToProject(point, planet));
          }
          rpath = null;
          if (g.tools[path.object_type] != null) {
            rpath = new g.tools[path.object_type].RPath(date, data, path._id.$oid, points, path.lock != null ? g.items[path.lock] : null);
            if (rpath.constructor.name === "Checkpoint") {
              console.log(rpath);
            }
          } else {
            console.log("Unknown path type: " + path.object_type);
          }
          break;
        case 'AreaToUpdate':
          newAreasToUpdate.push(item);
          break;
        default:
          continue;
      }
    }
    RDiv.updateZIndex(g.sortedDivs);
    g.addAreasToUpdate(newAreasToUpdate);
    _ref5 = g.areasToUpdate;
    for (pk in _ref5) {
      rectangle = _ref5[pk];
      if (rectangle.intersects(view.bounds)) {
        g.updateView();
        break;
      }
    }
    view.draw();
    updateView();
    clearTimeout(g.loadingBarTimeout);
    g.loadingBarTimeout = null;
    $("#loadingBar").hide();
  };

  this.benchmark_load = function() {
    var area, areasToLoad, b, bounds, l, planet, pos, r, scale, t, x, y, _i, _j;
    bounds = view.bounds;
    scale = g.scale;
    t = g.roundToLowerMultiple(bounds.top, scale);
    l = g.roundToLowerMultiple(bounds.left, scale);
    b = g.roundToLowerMultiple(bounds.bottom, scale);
    r = g.roundToLowerMultiple(bounds.right, scale);
    areasToLoad = [];
    for (x = _i = l; scale > 0 ? _i <= r : _i >= r; x = _i += scale) {
      for (y = _j = t; scale > 0 ? _j <= b : _j >= b; y = _j += scale) {
        planet = projectToPlanet(new Point(x, y));
        pos = projectToPosOnPlanet(new Point(x, y));
        area = {
          pos: pos,
          planet: planet,
          x: x / 1000,
          y: y / 1000
        };
        areasToLoad.push(area);
      }
    }
    console.log("areasToLoad: ");
    console.log(areasToLoad);
    Dajaxice.draw.benchmark_load(g.checkError, {
      areasToLoad: areasToLoad
    });
  };

}).call(this);

//# sourceMappingURL=ajax.map
