// Generated by CoffeeScript 1.7.1
(function() {
  define(['utils'], function(utils) {
    var g;
    g = utils.g();
    if (!window.rasterizerMode) {
      return;
    }
    g.initializeRasterizerMode = function() {
      g.initToolsRasterizer = function() {
        var pathClass, _i, _len, _ref;
        g.tools = {};
        g.modules = {};
        _ref = g.pathClasses;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          pathClass = _ref[_i];
          g.tools[pathClass.rname] = {
            RPath: pathClass
          };
          g.modules[pathClass.rname] = {
            name: pathClass.rname,
            iconURL: pathClass.iconURL,
            source: pathClass.source,
            description: pathClass.description,
            owner: 'Romanesco',
            thumbnailURL: pathClass.thumbnailURL,
            accepted: true,
            coreModule: true,
            category: pathClass.category
          };
        }
        g.initializeModules();
      };
      g.fakeFunction = function() {};
      g.updateRoom = g.fakeFunction;
      g.deferredExecution = g.fakeFunction;
      g.romanesco_alert = g.fakeFunction;
      g.rasterizer = {
        load: g.fakeFunction,
        unload: g.fakeFunction,
        move: g.fakeFunction,
        rasterizeAreasToUpdate: g.fakeFunction,
        addAreaToUpdate: g.fakeFunction,
        setQZoomToUpdate: g.fakeFunction,
        clearRasters: g.fakeFunction
      };
      jQuery.fn.mCustomScrollbar = g.fakeFunction;
      g.selectedToolNeedsDrawings = function() {
        return true;
      };
      g.CommandManager = g.fakeFunction;
      g.Rasterizer = g.fakeFunction;
      g.initializeGlobalParameters = g.fakeFunction;
      g.initParameters = g.fakeFunction;
      g.initCodeEditor = g.fakeFunction;
      g.initSocket = g.fakeFunction;
      g.initPosition = g.fakeFunction;
      g.updateGrid = g.fakeFunction;
      g.RSound = g.fakeFunction;
      g.chatSocket = {
        emit: g.fakeFunction
      };
      g.defaultColors = [];
      g.gui = {
        __folders: {}
      };
      g.animatedItems = [];
      g.areaToRasterize = null;
      g.createItemsDates = function(bounds) {
        var item, itemsDates, pk, type, _ref;
        itemsDates = {};
        _ref = g.items;
        for (pk in _ref) {
          item = _ref[pk];
          type = '';
          if (g.RLock.prototype.isPrototypeOf(item)) {
            type = 'Box';
          } else if (g.RDiv.prototype.isPrototypeOf(item)) {
            type = 'Div';
          } else if (g.RPath.prototype.isPrototypeOf(item)) {
            type = 'Path';
          }
          itemsDates[pk] = item.lastUpdateDate;
        }
        return itemsDates;
      };
      window.loopRasterize = function() {
        var dataURL, finished, height, imagePosition, newSize, rectangle, topLeft, width;
        rectangle = g.areaToRasterize;
        width = Math.min(1000, rectangle.right - view.bounds.left);
        height = Math.min(1000, rectangle.bottom - view.bounds.top);
        newSize = new Size(width, height);
        if (!view.viewSize.equals(newSize)) {
          topLeft = view.bounds.topLeft;
          view.viewSize = newSize;
          view.center = topLeft.add(newSize.multiply(0.5));
        }
        imagePosition = view.bounds.topLeft.clone();
        dataURL = g.canvas.toDataURL();
        finished = view.bounds.bottom >= rectangle.bottom && view.bounds.right >= rectangle.right;
        if (!finished) {
          if (view.bounds.right < rectangle.right) {
            view.center = view.center.add(1000, 0);
          } else {
            view.center = new Point(rectangle.left + view.viewSize.width * 0.5, view.bounds.bottom + view.viewSize.height * 0.5);
          }
        } else {
          g.areaToRasterize = null;
        }
        window.saveOnServer(dataURL, imagePosition.x, imagePosition.y, finished, g.city);
      };
      g.loopRasterize = window.loopRasterize;
      g.rasterizeAndSaveOnServer = function() {
        console.log("area rasterized");
        view.viewSize = Size.min(new Size(1000, 1000), g.areaToRasterize.size);
        view.center = g.areaToRasterize.topLeft.add(view.size.multiply(0.5));
        g.loopRasterize();
      };
      window.loadArea = function(args) {
        var area, areaObject, delta, div, _i, _len, _ref;
        console.log("load_area");
        if (g.areaToRasterize != null) {
          console.log("error: load_area while loading !!");
          return;
        }
        areaObject = JSON.parse(args);
        if (areaObject.city !== g.city) {
          g.unload();
          g.city = areaObject.city;
        }
        area = g.expandRectangleToInteger(g.rectangleFromBox(areaObject));
        g.areaToRasterize = area;
        delta = area.center.subtract(view.center);
        project.view.scrollBy(delta);
        _ref = g.divs;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          div = _ref[_i];
          div.updateTransform();
        }
        console.log("call load");
        g.load(area);
      };
      g.loadArea = window.loadArea;
      g.getAreasToUpdate = function() {
        if (g.areasToRasterize.length === 0 && g.imageSaved) {
          Dajaxice.draw.getAreasToUpdate(g.getAreasToUpdateCallback);
        }
      };
      g.loadNextArea = function() {
        var area;
        if (g.areasToRasterize.length > 0) {
          area = g.areasToRasterize.shift();
          g.areaToRasterizePk = area._id.$oid;
          g.imageSaved = false;
          g.loadArea(JSON.stringify(area));
        }
      };
      g.getAreasToUpdateCallback = function(areas) {
        g.areasToRasterize = areas;
        g.loadNextArea();
      };
      g.testSaveOnServer = function(imageDataURL, x, y, finished) {
        if (!imageDataURL) {
          console.log("no image data url");
        }
        g.rasterizedAreasJ.append($('<img src="' + imageDataURL + '" data-position="' + x + ', ' + y + '" finished="' + finished + '">').css({
          border: '1px solid black'
        }));
        console.log('position: ' + x + ', ' + y);
        console.log('finished: ' + finished);
        if (finished) {
          Dajaxice.draw.deleteAreaToUpdate(g.deleteAreaToUpdateCallback, {
            pk: g.areaToRasterizePk
          });
        } else {
          g.loopRasterize();
        }
      };
      g.deleteAreaToUpdateCallback = function(result) {
        g.checkError(result);
        g.imageSaved = true;
        g.loadNextArea();
      };
      return g.testRasterizer = function() {
        g.rasterizedAreasJ = $('<div class="rasterized-areas">');
        g.rasterizedAreasJ.css({
          position: 'absolute',
          top: 1000,
          left: 0
        });
        $('body').css({
          overflow: 'auto'
        }).prepend(g.rasterizedAreasJ);
        window.saveOnServer = g.testSaveOnServer;
        g.areasToRasterize = [];
        g.imageSaved = true;
        setInterval(g.getAreasToUpdate, 1000);
      };
    };
  });

}).call(this);

//# sourceMappingURL=mainRasterizer.map
