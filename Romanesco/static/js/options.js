// Generated by CoffeeScript 1.7.1
(function() {
  define(['utils', 'tinycolor', 'gui', 'colorpickersliders', 'jquery', 'paper'], function(utils, tinycolor, GUI) {
    var addItem, g;
    g = utils.g();
    window.tinycolor = tinycolor;
    g.initializeGlobalParameters = function() {
      var colorName, colorRGBstring;
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
          g.rasterizer.move();
          _ref = g.divs;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            div = _ref[_i];
            div.updateTransform();
          }
        },
        onFinishChange: function(value) {
          g.load();
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
      g.parameters.ignoreSockets = {
        type: 'checkbox',
        label: 'Ignore sockets',
        "default": false,
        onChange: function(value) {
          g.ignoreSockets = value;
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
      colorName = g.defaultColors.random();
      colorRGBstring = tinycolor(colorName).toRgbString();
      g.strokeColor = colorRGBstring;
      g.fillColor = "rgb(255,255,255,255)";
      g.displayGrid = false;
    };
    g.initParameters = function() {
      var controller, jqxhr, toggleGuiButtonJ;
      g.optionsJ = $(".option-list");
      dat.GUI.autoPace = false;
      g.gui = new dat.GUI();
      dat.GUI.toggleHide = function() {};
      g.generalFolder = g.gui.addFolder('General');
      controller = g.generalFolder.add({
        location: g.parameters.location["default"]
      }, 'location').name("Location").onFinishChange(g.parameters.location.onFinishChange);
      g.parameters.location.controller = controller;
      g.generalFolder.add({
        zoom: 100
      }, 'zoom', g.parameters.zoom.min, g.parameters.zoom.max).name("Zoom").onChange(g.parameters.zoom.onChange).onFinishChange(g.parameters.zoom.onFinishChange);
      g.generalFolder.add({
        displayGrid: g.parameters.displayGrid["default"]
      }, 'displayGrid', true).name("Display grid").onChange(g.parameters.displayGrid.onChange);
      g.generalFolder.add({
        ignoreSockets: g.parameters.ignoreSockets["default"]
      }, 'ignoreSockets', false).name(g.parameters.ignoreSockets.name).onChange(g.parameters.ignoreSockets.onChange);
      g.generalFolder.add(g.parameters.snap, 'snap', g.parameters.snap.min, g.parameters.snap.max).name(g.parameters.snap.label).step(g.parameters.snap.step).onChange(g.parameters.snap.onChange);
      g.addRasterizerParameters();
      g.templatesJ.find("button.dat-gui-toggle").clone().appendTo(g.gui.domElement);
      toggleGuiButtonJ = $(g.gui.domElement).find("button.dat-gui-toggle");
      toggleGuiButtonJ.click(function() {
        var parentJ;
        parentJ = $(g.gui.domElement).parent();
        if (parentJ.hasClass("dg-sidebar")) {
          $(".dat-gui.dg-right").append(g.gui.domElement);
          localStorage.optionsBarPosition = 'right';
        } else if (parentJ.hasClass("dg-right")) {
          $(".dat-gui.dg-sidebar").append(g.gui.domElement);
          localStorage.optionsBarPosition = 'sidebar';
        }
      });
      if ((localStorage.optionsBarPosition != null) && localStorage.optionsBarPosition === 'sidebar') {
        $(".dat-gui.dg-sidebar").append(g.gui.domElement);
      } else {
        $(".dat-gui.dg-right").append(g.gui.domElement);
      }
      g.generalFolder.open();
      g.gui.constructor.prototype.removeFolder = function(name) {
        this.__folders[name].close();
        this.__ul.removeChild(this.__folders[name].domElement.parentElement);
        delete this.__folders[name];
        return this.onResize();
      };
      g.availableFonts = [];
      g.usedFonts = [];
      jQuery.support.cors = true;
      jqxhr = $.getJSON("https://www.googleapis.com/webfonts/v1/webfonts?key=AIzaSyBVfBj_ugQO_w0AK1x9F6yiXByhcNgjQZU", g.initTextOptions);
      jqxhr.done(function(json) {
        console.log('done');
        g.initTextOptions(json);
      });
      jqxhr.fail(function(jqxhr, textStatus, error) {
        var err;
        err = textStatus + ", " + error;
        console.log('failed: ' + err);
      });
      return jqxhr.always(function(jqxhr, textStatus, error) {
        var err;
        err = textStatus + ", " + error;
        console.log('always: ' + err);
      });
    };
    g.addFont = function(fontFamily, effect) {
      var effects, font, fontAlreadyUsed, fontFamilyURL, _i, _len, _ref;
      if (fontFamily == null) {
        return;
      }
      fontFamilyURL = fontFamily.split(" ").join("+");
      fontAlreadyUsed = false;
      _ref = g.usedFonts;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        font = _ref[_i];
        if (font.family === fontFamilyURL) {
          if (font.effects.indexOf(effect) === -1 && (effect != null)) {
            font.effects.push(effect);
          }
          fontAlreadyUsed = true;
          break;
        }
      }
      if (!fontAlreadyUsed) {
        effects = [];
        if (effect != null) {
          effects.push(effect);
        }
        if (!fontFamilyURL || fontFamilyURL === '') {
          console.log('ERROR: font family URL is null or empty');
        }
        g.usedFonts.push({
          family: fontFamilyURL,
          effects: effects
        });
      }
    };
    g.loadFonts = function() {
      var effect, font, fontLink, i, newFont, _i, _j, _len, _len1, _ref, _ref1;
      $('head').remove("link.fonts");
      _ref = g.usedFonts;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        font = _ref[_i];
        newFont = font.family;
        if ($('head').find('link[data-font-family="' + font.family + '"]').length === 0) {
          if (font.effects.length > 0 && !(font.effects.length === 1 && font.effects.first() === 'none')) {
            newFont += "&effect=";
            _ref1 = font.effects;
            for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
              effect = _ref1[i];
              newFont += effect + '|';
            }
            newFont = newFont.slice(0, -1);
          }
          fontLink = $('<link class="fonts" data-font-family="' + font.family + '" rel="stylesheet" type="text/css">');
          fontLink.attr('href', "http://fonts.googleapis.com/css?family=" + newFont);
          $('head').append(fontLink);
        }
      }
    };
    g.initTextOptions = function(data, textStatus, jqXHR) {
      var fontFamilyNames, item, promise, _i, _len, _ref;
      fontFamilyNames = [];
      _ref = data.items;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        item = _ref[_i];
        fontFamilyNames.push({
          value: item.family
        });
      }
      g.typeaheadFontEngine = new Bloodhound({
        name: 'Font families',
        local: fontFamilyNames,
        datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
        queryTokenizer: Bloodhound.tokenizers.whitespace
      });
      promise = g.typeaheadFontEngine.initialize();
      g.availableFonts = data.items;
    };
    g.setControllerValueByName = function(name, value, item) {
      var checked, controller, folder, folderName, _i, _len, _ref, _ref1;
      checked = value != null;
      _ref = g.gui.__folders;
      for (folderName in _ref) {
        folder = _ref[folderName];
        _ref1 = folder.__controllers;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          controller = _ref1[_i];
          if (controller.property === name) {
            g.setControllerValue(controller, {
              min: controller.__min,
              max: controller.__max 
            }, value, item, checked);
            break;
          }
        }
      }
    };
    g.setControllerValue = function(controller, parameter, value, item, checked) {
      var onChange, onFinishChange;
      if (checked == null) {
        checked = false;
      }
      onChange = controller.__onChange;
      onFinishChange = controller.__onFinishChange;
      controller.__onChange = function() {};
      controller.__onFinishChange = function() {};
      if (parameter != null) {
        if (typeof controller.min === "function") {
          controller.min(parameter.min);
        }
        if (typeof controller.max === "function") {
          controller.max(parameter.max);
        }
      }
      controller.setValue(value);
      if (typeof controller.rSetValue === "function") {
        controller.rSetValue(value, item, checked);
      }
      controller.__onChange = onChange;
      return controller.__onFinishChange = onFinishChange;
    };
    addItem = function(name, parameter, item, datFolder, resetValues) {
      var checkboxJ, checked, colorPicker, controller, controllerBox, firstOptionalParameter, inputJ, obj, onParameterChange, updateItemControllers, value, _i, _len, _ref;
      if ((item != null) && datFolder.name !== 'General' && (item.data != null) && ((item.data[name] != null) || parameter.type === 'color')) {
        value = item.data[name];
      } else if (parameter.value != null) {
        value = parameter.value;
      } else if (parameter.defaultFunction != null) {
        value = parameter.defaultFunction();
      } else {
        value = parameter["default"];
      }
      updateItemControllers = function(parameter, name, item, controller) {
        var _base;
        if (parameter.addController) {
          if (item != null) {
            if (item.parameterControllers == null) {
              item.parameterControllers = {};
            }
            item.parameterControllers[name] = controller;
          } else {
            if ((_base = g.selectedTool).parameterControllers == null) {
              _base.parameterControllers = {};
            }
            g.selectedTool.parameterControllers[name] = controller;
          }
        }
      };
      _ref = datFolder.__controllers;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        controller = _ref[_i];
        if (controller.property === name && !parameter.permanent) {
          if (resetValues) {
            checked = item != null ? item.data[name] : parameter.defaultCheck;
            g.setControllerValue(controller, parameter, value, item, checked);
            updateItemControllers(parameter, name, item, controller);
          }
          g.unusedControllers.remove(controller);
          return;
        }
      }
      onParameterChange = function(value) {
        var _j, _len1, _ref1, _ref2;
        g.c = this;
        _ref1 = g.selectedItems;
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          item = _ref1[_j];
          if (typeof ((_ref2 = item.data) != null ? _ref2[name] : void 0) !== 'undefined') {
            item.setParameterCommand(name, value);
          }
        }
      };
      if (parameter.type === 'string' && !parameter.fireOnEveryChange) {
        if (parameter.onFinishChange == null) {
          parameter.onFinishChange = onParameterChange;
        }
      } else {
        if (parameter.onChange == null) {
          parameter.onChange = onParameterChange;
        }
      }
      obj = {};
      switch (parameter.type) {
        case 'color':
          obj[name] = '';
          controller = datFolder.add(obj, name).name(parameter.label);
          inputJ = $(datFolder.domElement).find("div.c > input:last");
          inputJ.addClass("color-input");
          checkboxJ = $('<input type="checkbox">');
          checkboxJ.insertBefore(inputJ);
          checkboxJ[0].checked = (item != null) && datFolder.name !== 'General' ? item.data[name] != null : parameter.defaultCheck;
          colorPicker = inputJ.ColorPickerSliders({
            title: parameter.label,
            placement: 'auto',
            size: 'sm',
            color: tinycolor(value != null ? value : parameter["default"]).toRgbString(),
            order: {
              hsl: 1,
              rgb: 2,
              opacity: 3,
              preview: 4
            },
            labels: {
              rgbred: 'Red',
              rgbgreen: 'Green',
              rgbblue: 'Blue',
              hslhue: 'Hue',
              hslsaturation: 'Saturation',
              hsllightness: 'Lightness',
              preview: 'Preview',
              opacity: 'Opacity'
            },
            customswatches: "different-swatches-groupname",
            swatches: false,
            onchange: function(container, color) {
              var colorPickerPopoverJ, gradient;
              colorPickerPopoverJ = $(".cp-popover-container .popover");
              gradient = colorPickerPopoverJ.find('.gradient-checkbox')[0].checked;
              if (gradient) {
                g.selectedGradientHandle.setColor(color.tiny.toRgbString());
              } else {
                parameter.onChange(color.tiny.toRgbString());
              }
              return checkboxJ[0].checked = true;
            }
          }).click(function() {
            var colorPickerPopoverJ, guiJ;
            guiJ = $(g.gui.domElement);
            colorPickerPopoverJ = $(".cp-popover-container .popover");
            checkboxJ = $("<label><input type='checkbox' class='gradient-checkbox' form-control>Gradient</label>");
            checkboxJ.insertBefore(colorPickerPopoverJ.find('.cp-preview'));
            checkboxJ.click(function(event) {
              if (this.checked) {
                g.initializeGradientTool();
              } else {
                g.removeGradientTool();
              }
            });
            if (guiJ.parent().hasClass("dg-sidebar")) {
              colorPickerPopoverJ.removeClass("left").addClass("right");
            }
          });
          checkboxJ.change(function() {
            if (this.checked) {
              return parameter.onChange(colorPicker.val());
            } else {
              return parameter.onChange(null);
            }
          });
          datFolder.__controllers[datFolder.__controllers.length - 1].rValue = function() {
            if (checkboxJ[0].checked) {
              return colorPicker.val();
            } else {
              return null;
            }
          };
          controller.rSetValue = function(value, item, checked) {
            if (checked) {
              if (value != null) {
                colorPicker.trigger("colorpickersliders.updateColor", value);
              }
            }
            checkboxJ[0].checked = checked;
          };
          break;
        case 'slider':
        case 'checkbox':
        case 'dropdown':
        case 'button':
        case 'button-group':
        case 'radio-button-group':
        case 'string':
        case 'input-typeahead':
          obj[name] = value;
          firstOptionalParameter = parameter.min != null ? parameter.min : parameter.values;
          controllerBox = datFolder.add(obj, name, firstOptionalParameter, parameter.max).name(parameter.label).onChange(parameter.onChange).onFinishChange(parameter.onFinishChange);
          controller = datFolder.__controllers.last();
          if (parameter.step != null) {
            if (typeof controller.step === "function") {
              controller.step(parameter.step);
            }
          }
          controller.rValue = controller.getValue;
          controller.rSetValue = parameter.setValue;
          updateItemControllers(parameter, name, item, controller);
          if (typeof parameter.initializeController === "function") {
            parameter.initializeController(controller, item);
          }
          break;
        default:
          console.log('unknown parameter type');
      }
    };
    g.updateParameters = function(tools, resetValues) {
      var controller, datFolder, folder, folderExists, folderName, item, name, parameter, tool, toolObject, unusedController, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
      if (resetValues == null) {
        resetValues = false;
      }
      g.unusedControllers = [];
      _ref = g.gui.__folders;
      for (folderName in _ref) {
        folder = _ref[folderName];
        _ref1 = folder.__controllers;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          controller = _ref1[_i];
          if (!((_ref2 = g.parameters[controller.property]) != null ? _ref2.permanent : void 0)) {
            g.unusedControllers.push(controller);
          }
        }
      }
      if (!Array.isArray(tools)) {
        tools = [tools];
      }
      for (_j = 0, _len1 = tools.length; _j < _len1; _j++) {
        toolObject = tools[_j];
        tool = toolObject.tool;
        item = toolObject.item;
        _ref3 = tool.parameters();
        for (folderName in _ref3) {
          folder = _ref3[folderName];
          folderExists = g.gui.__folders[folderName] != null;
          datFolder = folderExists ? g.gui.__folders[folderName] : g.gui.addFolder(folderName);
          for (name in folder) {
            parameter = folder[name];
            if (name !== 'folderIsClosedByDefault') {
              addItem(name, parameter, item, datFolder, resetValues);
            }
          }
          if (!folderExists && !folder.folderIsClosedByDefault) {
            datFolder.open();
          }
        }
      }
      _ref4 = g.unusedControllers;
      for (_k = 0, _len2 = _ref4.length; _k < _len2; _k++) {
        unusedController = _ref4[_k];
        _ref5 = g.gui.__folders;
        for (folderName in _ref5) {
          folder = _ref5[folderName];
          if (folder.__controllers.indexOf(unusedController) >= 0) {
            folder.remove(unusedController);
            folder.__controllers.remove(unusedController);
            if (folder.__controllers.length === 0) {
              g.gui.removeFolder(folderName);
            }
          }
        }
      }
      if ($(g.gui.domElement).parent().hasClass('dg-sidebar')) {
        setTimeout(function() {
          $(g.gui.domElement).find("ul:first").css({
            'height': 'initial'
          });
          return $(g.gui.domElement).css({
            'opacity': 1,
            'z-index': 'auto'
          });
        }, 500);
      }
    };
    g.updateParametersForSelectedItems = function() {
      g.callNextFrame(g.updateParametersForSelectedItemsCallback, 'updateParametersForSelectedItems');
    };
    g.updateParametersForSelectedItemsCallback = function() {
      var items;
      console.log('updateParametersForSelectedItemsCallback');
      items = g.selectedItems.map(function(item) {
        return {
          tool: item.constructor,
          item: item
        };
      });
      g.updateParameters(items, true);
    };
  });

}).call(this);

//# sourceMappingURL=options.map
