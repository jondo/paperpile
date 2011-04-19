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
      this.globalSettings[key] = value;

      var s = {};
      s[key] = Ext.JSON.encode(value);

      if (commitToBackend) {
        this.storeSettings(s);
      }
    },

    get: function(key) {
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