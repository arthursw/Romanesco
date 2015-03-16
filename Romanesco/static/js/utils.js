// Generated by CoffeeScript 1.7.1
(function() {
  var sqrtTwoPi;

  this.g = this;

  this.sign = function(x) {
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

  this.clamp = function(min, value, max) {
    return Math.min(Math.max(value, min), max);
  };

  this.random = function(min, max) {
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

  this.isArray = function(array) {
    return array.constructor === Array;
  };

  this.pushIfAbsent = function(array, item) {
    if (array.indexOf(item) < 0) {
      array.push(item);
    }
  };

  this.deferredExecution = function(callback, id, n) {
    if (n == null) {
      n = 500;
    }
    if (id == null) {
      id = callback;
    }
    if (g.updateTimeout[id] != null) {
      clearTimeout(g.updateTimeout[id]);
    }
    return g.updateTimeout[id] = setTimeout(callback, n);
  };

  sqrtTwoPi = Math.sqrt(2 * Math.PI);

  this.gaussian = function(mean, sigma, x) {
    var expf;
    expf = -((x - mean) * (x - mean) / (2 * sigma * sigma));
    return (1.0 / (sigma * sqrtTwoPi)) * Math.exp(expf);
  };

  this.isEmpty = function(map) {
    var key, value;
    for (key in map) {
      value = map[key];
      if (map.hasOwnProperty(key)) {
        return false;
      }
    }
    return true;
  };

  this.linearInterpolation = function(v1, v2, f) {
    return v1 * (1 - f) + v2 * f;
  };

}).call(this);

//# sourceMappingURL=utils.map
