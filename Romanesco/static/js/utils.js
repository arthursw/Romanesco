// Generated by CoffeeScript 1.7.1
(function() {
  define(['jquery'], function($) {
    var g, sqrtTwoPi;
    g = {};
    window.g = g;
    g.specialKeys = {
      8: 'backspace',
      9: 'tab',
      13: 'enter',
      16: 'shift',
      17: 'control',
      18: 'option',
      19: 'pause',
      20: 'caps-lock',
      27: 'escape',
      32: 'space',
      35: 'end',
      36: 'home',
      37: 'left',
      38: 'up',
      39: 'right',
      40: 'down',
      46: 'delete',
      91: 'command',
      93: 'command',
      224: 'command'
    };
    g.getParentPrototype = function(object, ParentClass) {
      var prototype;
      prototype = object.constructor.prototype;
      while (prototype !== ParentClass.prototype) {
        prototype = prototype.constructor.__super__;
      }
      return prototype;
    };
    g.sign = function(x) {
      if (typeof x === "number") {
        if (x) {
          if (x < 0) {
            return -1;
          } else {
            return 1;
          }
        } else {
          if (x === x) {
            return 0;
          } else {
            return NaN;
          }
        }
      } else {
        return NaN;
      }
    };
    g.clamp = function(min, value, max) {
      return Math.min(Math.max(value, min), max);
    };
    g.random = function(min, max) {
      return min + Math.random() * (max - min);
    };
    Array.prototype.remove = function(itemToRemove) {
      var i, item, _i, _len;
      for (i = _i = 0, _len = this.length; _i < _len; i = ++_i) {
        item = this[i];
        if (item === itemToRemove) {
          this.splice(i, 1);
          break;
        }
      }
    };
    Array.prototype.first = function() {
      return this[0];
    };
    Array.prototype.last = function() {
      return this[this.length - 1];
    };
    Array.prototype.random = function() {
      return this[Math.floor(Math.random() * this.length)];
    };
    Array.prototype.max = function() {
      var item, max, _i, _len;
      max = this[0];
      for (_i = 0, _len = this.length; _i < _len; _i++) {
        item = this[_i];
        if (item > max) {
          max = item;
        }
      }
      return max;
    };
    Array.prototype.min = function() {
      var item, min, _i, _len;
      min = this[0];
      for (_i = 0, _len = this.length; _i < _len; _i++) {
        item = this[_i];
        if (item < min) {
          min = item;
        }
      }
      return min;
    };
    Array.prototype.maxc = function(biggerThan) {
      var item, max, _i, _len;
      max = this[0];
      for (_i = 0, _len = this.length; _i < _len; _i++) {
        item = this[_i];
        if (biggerThan(item, max)) {
          max = item;
        }
      }
      return max;
    };
    Array.prototype.minc = function(smallerThan) {
      var item, min, _i, _len;
      min = this[0];
      for (_i = 0, _len = this.length; _i < _len; _i++) {
        item = this[_i];
        if (smallerThan(item, min)) {
          min = item;
        }
      }
      return min;
    };
    if (Array.isArray == null) {
      Array.isArray = function(array) {
        return array.constructor === Array;
      };
    }
    g.isArray = function(array) {
      return array.constructor === Array;
    };
    g.pushIfAbsent = function(array, item) {
      if (array.indexOf(item) < 0) {
        array.push(item);
      }
    };
    g.deferredExecution = function(callback, id, n) {
      var callbackWrapper;
      if (n == null) {
        n = 500;
      }
      if (id == null) {
        id = callback;
      }
      callbackWrapper = function() {
        delete g.updateTimeout[id];
        callback();
      };
      if (g.updateTimeout[id] != null) {
        clearTimeout(g.updateTimeout[id]);
      }
      g.updateTimeout[id] = setTimeout(callbackWrapper, n);
    };
    g.callNextFrame = function(callback, id, args) {
      var callbackWrapper, _base;
      if (id == null) {
        id = callback;
      }
      callbackWrapper = function() {
        delete g.requestedCallbacks[id];
        if (args == null) {
          callback();
        } else {
          callback.apply(window, args);
        }
      };
      if ((_base = g.requestedCallbacks)[id] == null) {
        _base[id] = window.requestAnimationFrame(callbackWrapper);
      }
    };
    g.cancelCallNextFrame = function(idToCancel) {
      window.cancelAnimationFrame(g.requestedCallbacks[idToCancel]);
      delete g.requestedCallbacks[idToCancel];
    };
    sqrtTwoPi = Math.sqrt(2 * Math.PI);
    g.gaussian = function(mean, sigma, x) {
      var expf;
      expf = -((x - mean) * (x - mean) / (2 * sigma * sigma));
      return (1.0 / (sigma * sqrtTwoPi)) * Math.exp(expf);
    };
    g.isEmpty = function(map) {
      var key, value;
      for (key in map) {
        value = map[key];
        if (map.hasOwnProperty(key)) {
          return false;
        }
      }
      return true;
    };
    g.linearInterpolation = function(v1, v2, f) {
      return v1 * (1 - f) + v2 * f;
    };
    g.ajax = function(url, callback, type) {
      var xmlhttp;
      if (type == null) {
        type = "GET";
      }
      xmlhttp = new RXMLHttpRequest();
      xmlhttp.onreadystatechange = function() {
        if (xmlhttp.readyState === 4 && xmlhttp.status === 200) {
          callback();
        }
      };
      xmlhttp.open(type, url, true);
      xmlhttp.send();
      return xmlhttp.onreadystatechange;
    };
    return {
      g: function() {
        return g;
      }
    };
  });

}).call(this);

//# sourceMappingURL=utils.map
