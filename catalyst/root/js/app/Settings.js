Ext.define('Paperpile.Settings', {
  statics: {
    _settings: {},
    apply: function(settings, commitToBackend) {
      for (key in settings) {
        this.setSetting(key, settings[key], commitToBackend);
      }
    },

    set: function(key, value, commitToBackend) {
      if (commitToBackend === undefined) {
        commitToBackend = true;
      }
      this._settings[key] = value;

      var s = {};
      s[key] = Ext.JSON.encode(value);

      if (commitToBackend) {
        this.store(s);
      }
    },

    get: function(key, defaultValue) {
      if (this._settings[key] === undefined && defaultValue !== undefined) {
	  Paperpile.log("Setting ["+key+"] undefined, and has default value -- storing default!");
	  this.set(key, defaultValue, true);
      }
      return this._settings[key];
    },

    getAll: function() {
      return this._settings;
    },

    store: function(newSettings, callback, scope) {
      Paperpile.Ajax({
        url: '/ajax/settings/set_settings',
        params: newSettings,
        success: function(response) {
          if (callback) {
            callback.createDelegate(scope)();
          }
        },
        scope: this
      });
    },

    load: function(callback, scope) {
      Paperpile.Ajax({
        url: '/ajax/misc/get_settings',
        success: function(response) {
          var json = Ext.decode(response.responseText);
          this._settings = json.data;
          if (callback) {
            var f = Ext.Function.bind(callback, scope);
            f();
          }
        },
        scope: this
      });
    }
  }
});