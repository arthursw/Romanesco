// Generated by CoffeeScript 1.7.1
(function() {
  var RSound,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  RSound = (function() {
    window.AudioContext = window.AudioContext || window.webkitAudioContext;

    RSound.context = new AudioContext();

    function RSound(urlList, onLoadCallback) {
      this.urlList = urlList;
      this.onLoadCallback = onLoadCallback;
      this.bufferOnDecoded = __bind(this.bufferOnDecoded, this);
      this.bufferOnLoad = __bind(this.bufferOnLoad, this);
      this.context = this.constructor.context;
      this.load();
      return;
    }

    RSound.prototype.load = function() {
      this.loadBuffer(0);
    };

    RSound.prototype.loadBuffer = function(index) {
      var request, url;
      this.index = index;
      if (this.index >= this.urlList.length) {
        return;
      }
      url = this.urlList[this.index];
      request = new RXMLHttpRequest();
      request.open("GET", url, true);
      request.responseType = "arraybuffer";
      request.onload = (function(_this) {
        return function() {
          _this.bufferOnLoad(request.response);
        };
      })(this);
      request.onerror = function() {
        console.error('BufferLoader: XHR error');
      };
      request.send();
    };

    RSound.prototype.bufferOnLoad = function(response) {
      this.context.decodeAudioData(response, this.bufferOnDecoded, this.bufferOnError);
    };

    RSound.prototype.bufferOnDecoded = function(buffer) {
      this.buffer = buffer;
      if (!this.buffer) {
        console.log('Error decoding url number ' + this.index + ', trying next url.');
        if (this.index + 1 < this.urlList.length) {
          this.loadBuffer(this.index + 1);
        } else {
          console.error('Error decoding file data.');
        }
        return;
      }
      if (this.playOnLoad != null) {
        this.play(this.playOnLoad);
        this.playOnLoad = null;
      }
      if (typeof this.onLoadCallback === "function") {
        this.onLoadCallback();
      }
      console.log('Sound loaded using url: ' + this.urlList[this.index]);
    };

    RSound.prototype.bufferOnError = function(error) {
      return console.error('decodeAudioData', error);
    };

    RSound.prototype.play = function(time) {
      if (time == null) {
        time = 0;
      }
      if (this.buffer == null) {
        this.playOnLoad = time;
        return;
      }
      if (this.isPlaying) {
        return;
      }
      this.source = this.context.createBufferSource();
      this.source.buffer = this.buffer;
      this.source.connect(this.context.destination);
      this.source.loop = true;
      this.gainNode = this.context.createGain();
      this.source.connect(this.gainNode);
      this.gainNode.connect(this.context.destination);
      this.gainNode.gain.value = this.volume;
      this.source.start(time);
      this.isPlaying = true;
      this.source.onended = (function(_this) {
        return function() {
          _this.isPlaying = false;
        };
      })(this);
    };

    RSound.prototype.setLoopStart = function(start) {
      this.source.loopStart = start;
    };

    RSound.prototype.setLoopEnd = function(end) {
      this.source.loopEnd = end;
    };

    RSound.prototype.stop = function() {
      this.source.stop();
    };

    RSound.prototype.setRate = function(rate) {
      this.source.playbackRate.value = rate;
    };

    RSound.prototype.rate = function() {
      return this.source.playbackRate.value;
    };

    RSound.prototype.volume = function() {
      return this.volume;
    };

    RSound.prototype.setVolume = function(volume) {
      this.volume = volume;
      if (this.source == null) {
        return;
      }
      return this.gainNode.gain.value = this.volume;
    };

    return RSound;

  })();

  this.RSound = RSound;

}).call(this);

//# sourceMappingURL=sound.map