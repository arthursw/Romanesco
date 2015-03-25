// Generated by CoffeeScript 1.7.1

/*
 * Romanesco documentation #

Romanesco is an experiment about freedom, creativity and collaboration.

tododoc
tododoc: define RItems

The source code is divided in files:
 - [main.coffee](http://main.html) which is where the initialization
 - [path.coffee](http://path.html)
 - etc

Notations:
 - override means that the method extends functionnalities of the inherited method (super is called at some point)
 - redefine means that it totally replace the method (super is never called)
 */

(function() {
  var init, initPosition, initTools;

  initTools = function() {
    var defaultFavoriteTools, error, initToolTypeahead, pathClass, sortStart, sortStop, _i, _len;
    g.toolsJ = $(".tool-list");
    g.favoriteToolsJ = $("#FavoriteTools .tool-list");
    g.allToolsContainerJ = $("#AllTools");
    g.allToolsJ = g.allToolsContainerJ.find(".all-tool-list");
    g.favoriteTools = [];
    if (typeof localStorage !== "undefined" && localStorage !== null) {
      try {
        g.favoriteTools = JSON.parse(localStorage.favorites);
      } catch (_error) {
        error = _error;
        console.log(error);
      }
    }
    defaultFavoriteTools = [PrecisePath, ThicknessPath, Meander, GeometricLines, RectangleShape, EllipseShape, StarShape, SpiralShape];
    while (g.favoriteTools.length < 8) {
      g.pushIfAbsent(g.favoriteTools, defaultFavoriteTools.pop().rname);
    }
    g.tools = new Object();
    new MoveTool();
    new CarTool();
    new SelectTool();
    new CodeTool();
    new LockTool(RLock);
    new TextTool(RText);
    new MediaTool(RMedia);
    new ScreenshotTool();
    for (_i = 0, _len = pathClasses.length; _i < _len; _i++) {
      pathClass = pathClasses[_i];
      new PathTool(pathClass);
    }
    initToolTypeahead = function() {
      var promise, tool, toolValues, _j, _len1, _ref;
      toolValues = [];
      _ref = g.allToolsJ.children();
      for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
        tool = _ref[_j];
        toolValues.push({
          value: $(tool).attr("data-type")
        });
      }
      g.typeaheadToolEngine = new Bloodhound({
        name: 'Tools',
        local: toolValues,
        datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
        queryTokenizer: Bloodhound.tokenizers.whitespace
      });
      promise = g.typeaheadToolEngine.initialize();
      g.searchToolInputJ = g.allToolsContainerJ.find("input.search-tool");
      g.searchToolInputJ.keyup(function(event) {
        var query;
        query = g.searchToolInputJ.val();
        if (query === "") {
          g.allToolsJ.children().show();
          return;
        }
        g.allToolsJ.children().hide();
        g.typeaheadToolEngine.get(query, function(suggestions) {
          var suggestion, _k, _len2, _results;
          _results = [];
          for (_k = 0, _len2 = suggestions.length; _k < _len2; _k++) {
            suggestion = suggestions[_k];
            console.log(suggestion);
            _results.push(g.allToolsJ.children("[data-type='" + suggestion.value + "']").show());
          }
          return _results;
        });
      });
    };
    Dajaxice.draw.getTools(function(result) {
      var script, scripts, _j, _len1;
      scripts = JSON.parse(result.tools);
      for (_j = 0, _len1 = scripts.length; _j < _len1; _j++) {
        script = scripts[_j];
        g.runScript(script);
      }
      initToolTypeahead();
    });
    sortStart = function(event, ui) {
      $("#sortable1, #sortable2").addClass("drag-over");
    };
    sortStop = function(event, ui) {
      var li, names, tool, toolValues, _j, _k, _len1, _len2, _ref, _ref1;
      $("#sortable1, #sortable2").removeClass("drag-over");
      if (typeof localStorage === "undefined" || localStorage === null) {
        return;
      }
      names = [];
      _ref = g.favoriteToolsJ.children();
      for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
        li = _ref[_j];
        names.push($(li).attr("data-type"));
      }
      localStorage.favorites = JSON.stringify(names);
      toolValues = [];
      _ref1 = g.allToolsJ.children();
      for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
        tool = _ref1[_k];
        toolValues.push({
          value: $(tool).attr("data-type")
        });
      }
      g.typeaheadToolEngine.clear();
      g.typeaheadToolEngine.add(toolValues);
    };
    $("#sortable1, #sortable2").sortable({
      connectWith: ".connectedSortable",
      appendTo: g.sidebarJ,
      helper: "clone",
      start: sortStart,
      stop: sortStop,
      delay: 250
    }).disableSelection();
    g.tools['Move'].select();
    g.wacomPlugin = document.getElementById('wacomPlugin');
    if (g.wacomPlugin != null) {
      g.wacomPenAPI = wacomPlugin.penAPI;
      g.wacomTouchAPI = wacomPlugin.touchAPI;
      g.wacomPointerType = {
        0: 'Mouse',
        1: 'Pen',
        2: 'Puck',
        3: 'Eraser'
      };
    }
  };

  initPosition = function() {
    var box, boxRectangle, boxString, br, controller, folder, folderName, loadEntireArea, planet, pos, site, siteString, tl, _i, _len, _ref, _ref1;
    boxString = g.canvasJ.attr("data-box");
    if (!boxString || boxString.length === 0) {
      window.onhashchange();
      return;
    }
    box = JSON.parse(boxString);
    planet = new Point(box.planetX, box.planetY);
    tl = posOnPlanetToProject(box.box.coordinates[0][0], planet);
    br = posOnPlanetToProject(box.box.coordinates[0][2], planet);
    boxRectangle = new Rectangle(tl, br);
    pos = boxRectangle.center;
    g.RMoveTo(pos);
    loadEntireArea = g.canvasJ.attr("data-load-entire-area");
    if (loadEntireArea) {
      g.entireArea = boxRectangle;
      g.load(boxRectangle);
    }
    siteString = g.canvasJ.attr("data-site");
    site = JSON.parse(siteString);
    if (site.restrictedArea) {
      g.restrictedArea = boxRectangle;
    }
    g.tools['Select'].select();
    if (site.disableToolbar) {
      g.sidebarJ.hide();
    } else {
      g.sidebarJ.find("div.panel.panel-default:not(:last)").hide();
      _ref = g.gui.__folders;
      for (folderName in _ref) {
        folder = _ref[folderName];
        _ref1 = folder.__controllers;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          controller = _ref1[_i];
          if (controller.name !== 'Zoom') {
            folder.remove(controller);
            folder.__controllers.remove(controller);
          }
        }
        if (folder.__controllers.length === 0) {
          g.gui.removeFolder(folderName);
        }
      }
      g.sidebarHandleJ.click();
    }
  };

  this.initializeGlobalParameters = function() {
    g.parameters = {};
    g.parameters.location = {
      type: 'string',
      label: 'Location',
      "default": '0.0, 0.0',
      permanent: true,
      onFinishChange: function(value) {
        g.ignoreHashChange = false;
        location.hash = value;
      }
    };
    g.parameters.zoom = {
      type: 'slider',
      label: 'Zoom',
      min: 1,
      max: 500,
      "default": 100,
      permanent: true,
      onChange: function(value) {
        var div, _i, _len, _ref;
        g.project.view.zoom = value / 100.0;
        g.updateGrid();
        _ref = g.divs;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          div = _ref[_i];
          div.updateTransform();
        }
      },
      onFinishChange: function(value) {
        return g.load();
      }
    };
    g.parameters.displayGrid = {
      type: 'checkbox',
      label: 'Display grid',
      "default": false,
      permanent: true,
      onChange: function(value) {
        g.displayGrid = !g.displayGrid;
        g.updateGrid();
      }
    };
    g.parameters.fastMode = {
      type: 'checkbox',
      label: 'Fast mode',
      "default": g.fastMode,
      permanent: true,
      onChange: function(value) {
        g.fastMode = value;
      }
    };
    g.parameters.strokeWidth = {
      type: 'slider',
      label: 'Stroke width',
      min: 1,
      max: 100,
      "default": 1
    };
    g.parameters.strokeColor = {
      type: 'color',
      label: 'Stroke color',
      "default": g.defaultColors.random(),
      defaultFunction: function() {
        return g.defaultColors.random();
      },
      defaultCheck: true
    };
    g.parameters.fillColor = {
      type: 'color',
      label: 'Fill color',
      "default": g.defaultColors.random(),
      defaultCheck: false
    };
    g.parameters["delete"] = {
      type: 'button',
      label: 'Delete items',
      "default": function() {
        var item, _i, _len, _ref, _results;
        _ref = g.selectedItems;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item.deleteCommand());
        }
        return _results;
      }
    };
    g.parameters.duplicate = {
      type: 'button',
      label: 'Duplicate items',
      "default": function() {
        var item, _i, _len, _ref, _results;
        _ref = g.selectedItems;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          item = _ref[_i];
          _results.push(item.duplicateCommand());
        }
        return _results;
      }
    };
    g.parameters.snap = {
      type: 'slider',
      label: 'Snap',
      min: 0,
      max: 100,
      step: 5,
      "default": 0,
      snap: 0,
      permanent: true,
      onChange: function() {
        return g.updateGrid();
      }
    };
    g.parameters.align = {
      type: 'button-group',
      label: 'Align',
      value: '',
      initializeController: function(controller) {
        var align, alignJ;
        $(controller.domElement).find('input').remove();
        align = function(type) {
          var avgX, avgY, bottom, bounds, item, items, left, right, top, xMax, xMin, yMax, yMin, _i, _j, _k, _l, _len, _len1, _len10, _len11, _len2, _len3, _len4, _len5, _len6, _len7, _len8, _len9, _m, _n, _o, _p, _q, _r, _s, _t;
          items = g.selectedItems;
          switch (type) {
            case 'h-top':
              yMin = NaN;
              for (_i = 0, _len = items.length; _i < _len; _i++) {
                item = items[_i];
                top = item.getBounds().top;
                if (isNaN(yMin) || top < yMin) {
                  yMin = top;
                }
              }
              items.sort(function(a, b) {
                return a.getBounds().top - b.getBounds().top;
              });
              for (_j = 0, _len1 = items.length; _j < _len1; _j++) {
                item = items[_j];
                bounds = item.getBounds();
                item.moveTo(new Point(bounds.centerX, top + bounds.height / 2));
              }
              break;
            case 'h-center':
              avgY = 0;
              for (_k = 0, _len2 = items.length; _k < _len2; _k++) {
                item = items[_k];
                avgY += item.getBounds().centerY;
              }
              avgY /= items.length;
              items.sort(function(a, b) {
                return a.getBounds().centerY - b.getBounds().centerY;
              });
              for (_l = 0, _len3 = items.length; _l < _len3; _l++) {
                item = items[_l];
                bounds = item.getBounds();
                item.moveTo(new Point(bounds.centerX, avgY));
              }
              break;
            case 'h-bottom':
              yMax = NaN;
              for (_m = 0, _len4 = items.length; _m < _len4; _m++) {
                item = items[_m];
                bottom = item.getBounds().bottom;
                if (isNaN(yMax) || bottom > yMax) {
                  yMax = bottom;
                }
              }
              items.sort(function(a, b) {
                return a.getBounds().bottom - b.getBounds().bottom;
              });
              for (_n = 0, _len5 = items.length; _n < _len5; _n++) {
                item = items[_n];
                bounds = item.getBounds();
                item.moveTo(new Point(bounds.centerX, bottom - bounds.height / 2));
              }
              break;
            case 'v-left':
              xMin = NaN;
              for (_o = 0, _len6 = items.length; _o < _len6; _o++) {
                item = items[_o];
                left = item.getBounds().left;
                if (isNaN(xMin) || left < xMin) {
                  xMin = left;
                }
              }
              items.sort(function(a, b) {
                return a.getBounds().left - b.getBounds().left;
              });
              for (_p = 0, _len7 = items.length; _p < _len7; _p++) {
                item = items[_p];
                bounds = item.getBounds();
                item.moveTo(new Point(xMin + bounds.width / 2, bounds.centerY));
              }
              break;
            case 'v-center':
              avgX = 0;
              for (_q = 0, _len8 = items.length; _q < _len8; _q++) {
                item = items[_q];
                avgX += item.getBounds().centerX;
              }
              avgX /= items.length;
              items.sort(function(a, b) {
                return a.getBounds().centerY - b.getBounds().centerY;
              });
              for (_r = 0, _len9 = items.length; _r < _len9; _r++) {
                item = items[_r];
                bounds = item.getBounds();
                item.moveTo(new Point(avgX, bounds.centerY));
              }
              break;
            case 'v-right':
              xMax = NaN;
              for (_s = 0, _len10 = items.length; _s < _len10; _s++) {
                item = items[_s];
                right = item.getBounds().right;
                if (isNaN(xMax) || right > xMax) {
                  xMax = right;
                }
              }
              items.sort(function(a, b) {
                return a.getBounds().right - b.getBounds().right;
              });
              for (_t = 0, _len11 = items.length; _t < _len11; _t++) {
                item = items[_t];
                bounds = item.getBounds();
                item.moveTo(new Point(xMax - bounds.width / 2, bounds.centerY));
              }
          }
        };
        g.templatesJ.find("#align").clone().appendTo(controller.domElement);
        alignJ = $("#align:first");
        alignJ.find("button").click(function() {
          return align($(this).attr("data-type"));
        });
      }
    };
    g.parameters.distribute = {
      type: 'button-group',
      label: 'Distribute',
      value: '',
      initializeController: function(controller) {
        var distribute, distributeJ;
        $(controller.domElement).find('input').remove();
        distribute = function(type) {
          var bottom, bounds, center, i, item, items, left, right, step, top, xMax, xMin, yMax, yMin, _i, _j, _k, _l, _len, _len1, _len10, _len11, _len2, _len3, _len4, _len5, _len6, _len7, _len8, _len9, _m, _n, _o, _p, _q, _r, _s, _t;
          items = g.selectedItems;
          switch (type) {
            case 'h-top':
              yMin = NaN;
              yMax = NaN;
              for (_i = 0, _len = items.length; _i < _len; _i++) {
                item = items[_i];
                top = item.getBounds().top;
                if (isNaN(yMin) || top < yMin) {
                  yMin = top;
                }
                if (isNaN(yMax) || top > yMax) {
                  yMax = top;
                }
              }
              step = (yMax - yMin) / (items.length - 1);
              items.sort(function(a, b) {
                return a.getBounds().top - b.getBounds().top;
              });
              for (i = _j = 0, _len1 = items.length; _j < _len1; i = ++_j) {
                item = items[i];
                bounds = item.getBounds();
                item.moveTo(new Point(bounds.centerX, yMin + i * step + bounds.height / 2));
              }
              break;
            case 'h-center':
              yMin = NaN;
              yMax = NaN;
              for (_k = 0, _len2 = items.length; _k < _len2; _k++) {
                item = items[_k];
                center = item.getBounds().centerY;
                if (isNaN(yMin) || center < yMin) {
                  yMin = center;
                }
                if (isNaN(yMax) || center > yMax) {
                  yMax = center;
                }
              }
              step = (yMax - yMin) / (items.length - 1);
              items.sort(function(a, b) {
                return a.getBounds().centerY - b.getBounds().centerY;
              });
              for (i = _l = 0, _len3 = items.length; _l < _len3; i = ++_l) {
                item = items[i];
                bounds = item.getBounds();
                item.moveTo(new Point(bounds.centerX, yMin + i * step));
              }
              break;
            case 'h-bottom':
              yMin = NaN;
              yMax = NaN;
              for (_m = 0, _len4 = items.length; _m < _len4; _m++) {
                item = items[_m];
                bottom = item.getBounds().bottom;
                if (isNaN(yMin) || bottom < yMin) {
                  yMin = bottom;
                }
                if (isNaN(yMax) || bottom > yMax) {
                  yMax = bottom;
                }
              }
              step = (yMax - yMin) / (items.length - 1);
              items.sort(function(a, b) {
                return a.getBounds().bottom - b.getBounds().bottom;
              });
              for (i = _n = 0, _len5 = items.length; _n < _len5; i = ++_n) {
                item = items[i];
                bounds = item.getBounds();
                item.moveTo(new Point(bounds.centerX, yMin + i * step - bounds.height / 2));
              }
              break;
            case 'v-left':
              xMin = NaN;
              xMax = NaN;
              for (_o = 0, _len6 = items.length; _o < _len6; _o++) {
                item = items[_o];
                left = item.getBounds().left;
                if (isNaN(xMin) || left < xMin) {
                  xMin = left;
                }
                if (isNaN(xMax) || left > xMax) {
                  xMax = left;
                }
              }
              step = (xMax - xMin) / (items.length - 1);
              items.sort(function(a, b) {
                return a.getBounds().left - b.getBounds().left;
              });
              for (i = _p = 0, _len7 = items.length; _p < _len7; i = ++_p) {
                item = items[i];
                bounds = item.getBounds();
                item.moveTo(new Point(xMin + i * step + bounds.width / 2, bounds.centerY));
              }
              break;
            case 'v-center':
              xMin = NaN;
              xMax = NaN;
              for (_q = 0, _len8 = items.length; _q < _len8; _q++) {
                item = items[_q];
                center = item.getBounds().centerX;
                if (isNaN(xMin) || center < xMin) {
                  xMin = center;
                }
                if (isNaN(xMax) || center > xMax) {
                  xMax = center;
                }
              }
              step = (xMax - xMin) / (items.length - 1);
              items.sort(function(a, b) {
                return a.getBounds().centerX - b.getBounds().centerX;
              });
              for (i = _r = 0, _len9 = items.length; _r < _len9; i = ++_r) {
                item = items[i];
                bounds = item.getBounds();
                item.moveTo(new Point(xMin + i * step, bounds.centerY));
              }
              break;
            case 'v-right':
              xMin = NaN;
              xMax = NaN;
              for (_s = 0, _len10 = items.length; _s < _len10; _s++) {
                item = items[_s];
                right = item.getBounds().right;
                if (isNaN(xMin) || right < xMin) {
                  xMin = right;
                }
                if (isNaN(xMax) || right > xMax) {
                  xMax = right;
                }
              }
              step = (xMax - xMin) / (items.length - 1);
              items.sort(function(a, b) {
                return a.getBounds().right - b.getBounds().right;
              });
              for (i = _t = 0, _len11 = items.length; _t < _len11; i = ++_t) {
                item = items[i];
                bounds = item.getBounds();
                item.moveTo(new Point(xMin + i * step - bounds.width / 2, bounds.centerY));
              }
          }
        };
        g.templatesJ.find("#distribute").clone().appendTo(controller.domElement);
        distributeJ = $("#distribute:first");
        distributeJ.find("button").click(function() {
          return distribute($(this).attr("data-type"));
        });
      }
    };
  };

  paper.install(window);

  init = function() {
    var hueRange, i, minHue, step, _i;
    g.romanescoURL = 'http://localhost:8000/';
    g.windowJ = $(window);
    g.stageJ = $("#stage");
    g.sidebarJ = $("#sidebar");
    g.canvasJ = g.stageJ.find("#canvas");
    g.canvas = g.canvasJ[0];
    g.backgroundCanvasJ = g.stageJ.find("#background-canvas");
    g.backgroundCanvas = g.backgroundCanvasJ[0];
    g.backgroundCanvas.width = window.innerWidth;
    g.backgroundCanvas.height = window.innerHeight;
    g.backgroundCanvasJ.width(window.innerWidth);
    g.backgroundCanvasJ.height(window.innerHeight);
    g.context = g.canvas.getContext('2d');
    g.backgroundContext = g.backgroundCanvas.getContext('2d');
    g.templatesJ = $("#templates");
    g.me = null;
    g.selectionLayer = null;
    g.polygonMode = false;
    g.selectionBlue = '#2fa1d6';
    g.updateTimeout = {};
    g.restrictedArea = null;
    g.OSName = "Unknown OS";
    g.currentPaths = {};
    g.loadingBarTimeout = null;
    g.entireArea = null;
    g.entireAreas = [];
    g.loadedAreas = [];
    g.paths = new Object();
    g.items = new Object();
    g.locks = [];
    g.divs = [];
    g.sortedPaths = [];
    g.sortedDivs = [];
    g.animatedItems = [];
    g.cars = {};
    g.fastMode = false;
    g.fastModeOn = false;
    g.alerts = null;
    g.scale = 1000.0;
    g.previousPoint = null;
    g.draggingEditor = false;
    g.rasters = {};
    g.areasToUpdate = {};
    g.rastersToUpload = [];
    g.areasToRasterize = [];
    g.isUpdatingRasters = false;
    g.viewUpdated = false;
    g.previouslySelectedItems = [];
    g.currentDiv = null;
    g.areasToUpdateRectangles = {};
    g.catchErrors = false;
    g.previousMousePosition = null;
    g.initialMousePosition = null;
    g.previousViewPosition = null;
    g.backgroundRectangle = null;
    g.limitPathV = null;
    g.limitPathH = null;
    g.selectedItems = [];
    g.itemListsJ = $("#RItems .layers");
    g.pathList = g.itemListsJ.find(".rPath-list");
    g.pathList.sortable({
      stop: g.zIndexSortStop,
      delay: 250
    });
    g.pathList.disableSelection();
    g.divList = g.itemListsJ.find(".rDiv-list");
    g.divList.sortable({
      stop: g.zIndexSortStop,
      delay: 250
    });
    g.divList.disableSelection();
    g.itemListsJ.find('.title').click(function(event) {
      $(this).parent().toggleClass('closed');
    });
    g.commandManager = new CommandManager();
    Dajaxice.setup({
      'default_exception_callback': function(error) {
        console.log('Dajaxice error!');
        romanesco_alert("Connection error", "error");
      }
    });
    if (navigator.appVersion.indexOf("Win") !== -1) {
      g.OSName = "Windows";
    }
    if (navigator.appVersion.indexOf("Mac") !== -1) {
      g.OSName = "MacOS";
    }
    if (navigator.appVersion.indexOf("X11") !== -1) {
      g.OSName = "UNIX";
    }
    if (navigator.appVersion.indexOf("Linux") !== -1) {
      g.OSName = "Linux";
    }
    paper.setup(canvas);
    g.mainLayer = project.activeLayer;
    g.debugLayer = new Layer();
    g.carLayer = new Layer();
    g.lockLayer = new Layer();
    g.selectionLayer = new Layer();
    g.mainLayer.activate();
    paper.settings.hitTolerance = 5;
    g.grid = new Group();
    g.grid.name = 'grid group';
    view.zoom = 1;
    g.previousViewPosition = view.center;
    Point.prototype.toJSON = function() {
      return {
        x: this.x,
        y: this.y
      };
    };
    Point.prototype.exportJSON = function() {
      return JSON.stringify(this.toJSON());
    };
    Rectangle.prototype.toJSON = function() {
      return {
        x: this.x,
        y: this.y,
        width: this.width,
        height: this.height
      };
    };
    Rectangle.prototype.exportJSON = function() {
      return JSON.stringify(this.toJSON());
    };
    g.defaultColors = [];
    hueRange = g.random(10, 180);
    minHue = g.random(0, 360 - hueRange);
    step = hueRange / 10;
    for (i = _i = 0; _i <= 10; i = ++_i) {
      g.defaultColors.push(Color.HSL(minHue + i * step, g.random(0.3, 0.9), g.random(0.5, 0.7)).toCSS());
    }
    g.alertsContainer = $("#Romanesco_alerts");
    g.alerts = [];
    g.currentAlert = -1;
    g.alertTimeOut = -1;
    g.alertsContainer.find(".btn-up").click(function() {
      return showAlert(g.currentAlert - 1);
    });
    g.alertsContainer.find(".btn-down").click(function() {
      return showAlert(g.currentAlert + 1);
    });
    g.sidebarHandleJ = g.sidebarJ.find(".sidebar-handle");
    g.sidebarHandleJ.click(function() {
      g.toggleSidebar();
    });
    $(".mCustomScrollbar.sidebar-scrollbar").mCustomScrollbar({
      keyboard: false
    });
    g.sound = new RSound(['/static/sounds/viper.ogg']);
    $.ajax({
      url: g.romanescoURL + "static/coffee/path.coffee"
    }).done(function(data) {
      var classMap, expression, expressions, lines, pathClass, _j, _k, _len, _len1, _ref, _ref1;
      lines = data.split(/\n/);
      expressions = CoffeeScript.nodes(data).expressions;
      classMap = {};
      _ref = g.pathClasses;
      for (_j = 0, _len = _ref.length; _j < _len; _j++) {
        pathClass = _ref[_j];
        classMap[pathClass.name] = pathClass;
      }
      for (_k = 0, _len1 = expressions.length; _k < _len1; _k++) {
        expression = expressions[_k];
        if ((_ref1 = classMap[expression.variable.base.value]) != null) {
          _ref1.source = lines.slice(expression.locationData.first_line, +expression.locationData.last_line + 1 || 9e9).join("\n");
        }
      }
    });
    initializeGlobalParameters();
    initParameters();
    initCodeEditor();
    initTools();
    initSocket();
    initPosition();
    updateGrid();
  };

  $(document).ready(function() {
    init();
    g.canvasJ.mousedown(g.mousedown);
    g.stageJ.mousedown(g.mousedown);
    $(window).mousemove(g.mousemove);
    $(window).mouseup(g.mouseup);
    g.stageJ.mousewheel(function(event) {
      g.RMoveBy(new Point(-event.deltaX, event.deltaY));
    });
    canvasJ.dblclick(function(event) {
      var _base;
      return typeof (_base = g.selectedTool).doubleClick === "function" ? _base.doubleClick(event) : void 0;
    });
    canvasJ.keydown(function(event) {
      if (event.key === 46) {
        event.preventDefault();
        return false;
      }
    });
    g.tool = new Tool();
    g.tool.onMouseDown = function(event) {
      var _ref;
      if ((_ref = g.wacomPenAPI) != null ? _ref.isEraser : void 0) {
        tool.onKeyUp({
          key: 'delete'
        });
        return;
      }
      $(document.activeElement).blur();
      return g.selectedTool.begin(event);
    };
    g.tool.onMouseDrag = function(event) {
      var _ref;
      if ((_ref = g.wacomPenAPI) != null ? _ref.isEraser : void 0) {
        return;
      }
      if (g.currentDiv != null) {
        return;
      }
      event = g.snap(event);
      return g.selectedTool.update(event);
    };
    g.tool.onMouseUp = function(event) {
      var _ref;
      if ((_ref = g.wacomPenAPI) != null ? _ref.isEraser : void 0) {
        return;
      }
      if (g.currentDiv != null) {
        return;
      }
      event = g.snap(event);
      return g.selectedTool.end(event);
    };
    g.tool.onKeyDown = function(event) {
      if ($(document.activeElement).parents(".sidebar").length || $(document.activeElement).is("textarea") || $(document.activeElement).parents(".dat-gui").length) {
        return;
      }
      if (event.key === 'delete') {
        event.preventDefault();
        return false;
      }
      if (event.key === 'space' && g.selectedTool.name !== 'Move') {
        return g.tools['Move'].select();
      }
    };
    g.tool.onKeyUp = function(event) {
      var delta, item, selectedItems, _base, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _m, _ref, _ref1, _ref2, _ref3, _ref4, _ref5, _ref6;
      if ($(document.activeElement).parents(".sidebar").length || $(document.activeElement).is("textarea") || $(document.activeElement).parents(".dat-gui").length) {
        return;
      }
      if ((_ref = event.key) === 'left' || _ref === 'right' || _ref === 'up' || _ref === 'down') {
        delta = event.modifiers.shift ? 50 : event.modifiers.option ? 5 : 1;
      }
      switch (event.key) {
        case 'right':
          _ref1 = g.selectedItems;
          for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
            item = _ref1[_i];
            item.moveBy(new Point(delta, 0), true);
          }
          break;
        case 'left':
          _ref2 = g.selectedItems;
          for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
            item = _ref2[_j];
            item.moveBy(new Point(-delta, 0), true);
          }
          break;
        case 'up':
          _ref3 = g.selectedItems;
          for (_k = 0, _len2 = _ref3.length; _k < _len2; _k++) {
            item = _ref3[_k];
            item.moveBy(new Point(0, -delta), true);
          }
          break;
        case 'down':
          _ref4 = g.selectedItems;
          for (_l = 0, _len3 = _ref4.length; _l < _len3; _l++) {
            item = _ref4[_l];
            item.moveBy(new Point(0, delta), true);
          }
          break;
        case 'enter':
        case 'escape':
          if (typeof (_base = g.selectedTool).finishPath === "function") {
            _base.finishPath();
          }
          break;
        case 'space':
          if ((_ref5 = g.previousTool) != null) {
            _ref5.select();
          }
          break;
        case 'v':
          g.tools['Select'].select();
          break;
        case 'delete':
        case 'backspace':
          selectedItems = g.selectedItems.slice();
          for (_m = 0, _len4 = selectedItems.length; _m < _len4; _m++) {
            item = selectedItems[_m];
            if (((_ref6 = item.selectionState) != null ? _ref6.segment : void 0) != null) {
              item.deletePointCommand();
            } else {
              item.deleteCommand();
            }
          }
      }
      return event.preventDefault();
    };
    view.onFrame = function(event) {
      var car, direction, item, username, _base, _i, _len, _ref, _ref1;
      TWEEN.update(event.time);
      if (typeof (_base = g.selectedTool).onFrame === "function") {
        _base.onFrame(event);
      }
      _ref = g.animatedItems;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        item.onFrame(event);
      }
      _ref1 = g.cars;
      for (username in _ref1) {
        car = _ref1[username];
        direction = new Point(1, 0);
        direction.angle = car.rotation - 90;
        car.position = car.position.add(direction.multiply(car.speed));
        if (Date.now() - car.rLastUpdate > 1000) {
          g.cars[username].remove();
          delete g.cars[username];
        }
      }
    };
    g.windowJ.resize(function(event) {
      g.backgroundCanvas.width = window.innerWidth;
      g.backgroundCanvas.height = window.innerHeight;
      updateGrid();
      $(".mCustomScrollbar").mCustomScrollbar("update");
      return view.draw();
    });
  });

  this.mousedown = function(event) {
    var _base;
    switch (event.which) {
      case 2:
        g.tools['Move'].select();
        break;
      case 3:
        if (typeof (_base = g.selectedTool).finishPath === "function") {
          _base.finishPath();
        }
    }
    if (g.selectedTool.name === 'Move') {
      g.selectedTool.beginNative(event);
      return;
    }
    g.initialMousePosition = g.jEventToPoint(event);
    g.previousMousePosition = g.initialMousePosition.clone();
  };

  this.mousemove = function(event) {
    var paperEvent, _base;
    if (g.selectedTool.name === 'Move' && g.selectedTool.dragging) {
      g.selectedTool.updateNative(event);
      return;
    }
    if (g.draggingEditor) {
      g.editorJ.css({
        right: g.windowJ.width() - event.pageX
      });
    }
    if (g.currentDiv != null) {
      paperEvent = g.jEventToPaperEvent(event, g.previousMousePosition, g.initialMousePosition, 'mousemove');
      if (typeof (_base = g.currentDiv).updateSelect === "function") {
        _base.updateSelect(paperEvent);
      }
      g.previousMousePosition = paperEvent.point;
    }
  };

  this.mouseup = function(event) {
    var paperEvent, _base, _ref;
    if (g.selectedTool.name === 'Move') {
      g.selectedTool.endNative(event);
      return;
    }
    if (event.which === 2) {
      if ((_ref = g.previousTool) != null) {
        _ref.select();
      }
    }
    if (g.currentDiv != null) {
      paperEvent = g.jEventToPaperEvent(event, g.previousMousePosition, g.initialMousePosition, 'mouseup');
      if (typeof (_base = g.currentDiv).endSelect === "function") {
        _base.endSelect(paperEvent);
      }
      g.previousMousePosition = paperEvent.point;
    }
    g.draggingEditor = false;
  };

}).call(this);

//# sourceMappingURL=main.map
