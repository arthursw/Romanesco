// Generated by CoffeeScript 1.7.1
(function() {
  define(['utils', 'jquery', 'bootstrap', 'paper'], function(utils) {
    var RModal, g;
    g = utils.g();
    RModal = (function() {
      function RModal() {}

      RModal.extractors = [];

      RModal.modalJ = $('#customModal');

      RModal.modalBodyJ = RModal.modalJ.find('.modal-body');

      RModal.modalJ.on('shown.bs.modal', function(event) {
        return RModal.modalJ.find('input.form-control:visible:first').focus();
      });

      RModal.modalJ.find('.btn-primary').click(function(event) {
        return RModal.modalSubmit();
      });

      RModal.initialize = function(title, submitCallback, validation, hideOnSubmit) {
        this.submitCallback = submitCallback;
        this.validation = validation != null ? validation : null;
        this.hideOnSubmit = hideOnSubmit != null ? hideOnSubmit : true;
        this.modalBodyJ.empty();
        this.extractors = {};
        this.modalJ.find("h4.modal-title").html(title);
        this.modalJ.find(".modal-footer").show().find(".btn").show();
      };

      RModal.alert = function(message, title) {
        if (title == null) {
          title = 'Info';
        }
        this.initialize(title);
        this.addText(message);
        g.RModal.modalJ.find("[name='cancel']").hide();
        g.RModal.show();
      };

      RModal.addText = function(text) {
        this.modalBodyJ.append("<p>" + text + "</p>");
      };

      RModal.addTextInput = function(name, placeholder, type, className, label, submitShortcut, id, required, errorMessage) {
        var args, divJ, extractor, inputID, inputJ, labelJ;
        if (placeholder == null) {
          placeholder = null;
        }
        if (type == null) {
          type = null;
        }
        if (className == null) {
          className = null;
        }
        if (label == null) {
          label = null;
        }
        if (submitShortcut == null) {
          submitShortcut = false;
        }
        if (id == null) {
          id = null;
        }
        if (required == null) {
          required = false;
        }
        submitShortcut = submitShortcut ? 'submit-shortcut' : '';
        inputJ = $("<input type='" + type + "' class='" + className + " form-control " + submitShortcut + "' placeholder='" + placeholder + "'>");
        if (required) {
          if (errorMessage == null) {
            errorMessage = "<em>" + (label || name) + "</em> is invalid.";
          }
          inputJ.attr('data-error', errorMessage);
        }
        args = inputJ;
        extractor = function(data, inputJ, name, required) {
          if (required == null) {
            required = false;
          }
          data[name] = inputJ.val();
          return (!required) || ((data[name] != null) && data[name] !== '');
        };
        if (label) {
          inputID = 'modal-' + name + '-' + Math.random().toString();
          inputJ.attr('id', inputID);
          divJ = $("<div id='" + id + "' class='form-group " + className + "-group'></div>");
          labelJ = $("<label for='" + inputID + "'>" + label + "</label>");
          divJ.append(labelJ);
          divJ.append(inputJ);
          inputJ = divJ;
        }
        this.addCustomContent(name, inputJ, extractor, args, required);
        return inputJ;
      };

      RModal.addCheckbox = function(name, label, helpMessage) {
        var checkboxJ, divJ, extractor, helpMessageJ;
        if (helpMessage == null) {
          helpMessage = null;
        }
        divJ = $("<div>");
        checkboxJ = $("<label><input type='checkbox' form-control>" + label + "</label>");
        divJ.append(checkboxJ);
        if (helpMessage) {
          helpMessageJ = $("<p class='help-block'>" + helpMessage + "</p>");
          divJ.append(helpMessageJ);
        }
        extractor = function(data, checkboxJ, name) {
          data[name] = checkboxJ.is(':checked');
          return true;
        };
        this.addCustomContent(name, divJ, extractor, checkboxJ);
        return divJ;
      };

      RModal.addRadioGroup = function(name, radioButtons) {
        var checked, divJ, extractor, inputJ, labelJ, radioButton, radioJ, submitShortcut, _i, _len;
        divJ = $("<div>");
        for (_i = 0, _len = radioButtons.length; _i < _len; _i++) {
          radioButton = radioButtons[_i];
          radioJ = $("<div class='radio'>");
          labelJ = $("<label>");
          checked = radioButton.checked ? 'checked' : '';
          submitShortcut = radioButton.submitShortcut ? 'class="submit-shortcut"' : '';
          inputJ = $("<input type='radio' name='" + name + "' value='" + radioButton.value + "' " + checked + " " + submitShortcut + ">");
          labelJ.append(inputJ);
          labelJ.append(radioButton.label);
          radioJ.append(labelJ);
          divJ.append(radioJ);
        }
        extractor = function(data, divJ, name, required) {
          var choiceJ, _ref;
          if (required == null) {
            required = false;
          }
          choiceJ = divJ.find("input[type=radio][name=" + name + "]:checked");
          data[name] = (_ref = choiceJ[0]) != null ? _ref.value : void 0;
          return (!required) || (data[name] != null);
        };
        this.addCustomContent(name, divJ, extractor);
        return divJ;
      };

      RModal.addCustomContent = function(name, div, extractor, args, required) {
        if (args == null) {
          args = null;
        }
        if (required == null) {
          required = false;
        }
        if (args == null) {
          args = div;
        }
        div.attr('id', 'modal-' + name);
        this.modalBodyJ.append(div);
        this.extractors[name] = {
          extractor: extractor,
          args: args,
          div: div,
          required: required
        };
      };

      RModal.show = function() {
        this.modalJ.find('.submit-shortcut').keypress((function(_this) {
          return function(event) {
            if (event.which === 13) {
              event.preventDefault();
              _this.modalSubmit();
            }
          };
        })(this));
        this.modalJ.modal('show');
      };

      RModal.hide = function() {
        this.modalJ.modal('hide');
      };

      RModal.modalSubmit = function() {
        var data, errorMessage, extractor, name, valid, _ref;
        data = {};
        this.modalJ.find(".error-message").remove();
        valid = true;
        _ref = this.extractors;
        for (name in _ref) {
          extractor = _ref[name];
          valid &= extractor.extractor(data, extractor.args, name, extractor.required);
          if (!valid) {
            errorMessage = extractor.div.find("[data-error]").attr('data-error');
            if (errorMessage == null) {
              errorMessage = 'The field "' + name + '"" is invalid.';
            }
            this.modalBodyJ.append("<div class='error-message'>" + errorMessage + "</div>");
          }
        }
        if (!valid || (this.validation != null) && !this.validation(data)) {
          return;
        }
        if (typeof this.submitCallback === "function") {
          this.submitCallback(data);
        }
        this.extractors = {};
        if (this.hideOnSubmit) {
          this.modalBodyJ.empty();
          this.modalJ.modal('hide');
        }
      };

      return RModal;

    })();
    g.RModal = RModal;
  });

}).call(this);

//# sourceMappingURL=modal.map
