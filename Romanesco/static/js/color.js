// Generated by CoffeeScript 1.7.1
(function() {
  define(['utils', 'tinycolor', 'gui', 'colorpickersliders', 'jquery', 'paper'], function(utils, tinycolor, GUI) {
    var g;
    g = utils.g();
    g.initializeColorPicker = function() {
      var checkboxJ, colorPicker, controller, inputJ;
      switch (parameter.type) {
        case 'color':
          obj[name] = '';
          controller = datFolder.add(obj, name).name(parameter.label);
          inputJ = $(datFolder.domElement).find("div.c > input:last");
          inputJ.addClass("color-input");
          checkboxJ = $('<input type="checkbox">');
          checkboxJ.insertBefore(inputJ);
          checkboxJ[0].checked = (typeof item !== "undefined" && item !== null) && datFolder.name !== 'General' ? item.data[name] != null : parameter.defaultCheck;
          return colorPicker = inputJ.ColorPickerSliders({
            title: parameter.label,
            placement: 'auto',
            size: 'sm',
            color: tinycolor(typeof value !== "undefined" && value !== null ? value : parameter["default"]).toRgbString(),
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
      }
    };
    g.initializeGradientTool = function() {
      g.gradientTool = new GradientTool();
    };
    g.removeGradientTool = function() {
      g.gradientTool.remove();
      g.gradientTool = null;
    };
  });

}).call(this);

//# sourceMappingURL=color.map
