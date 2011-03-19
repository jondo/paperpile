
// This is a wrapper around the Ext.Ajax.request function call.
// If we need to add any global behavior to Ajax calls, put it
// here.
Paperpile.Ajax = function(config) {

  // A method which will run *before* the success function defined
  // by the passed config.
  var success = function(response) {
    var json = Ext.JSON.decode(response.responseText);
    if (json.data) {
      Paperpile.main.updateFromServer(json.data);
    }
    if (json.callback) {
      Paperpile.main.onCallback(json.callback);
    }
  };

  var failure = function() {
    Paperpile.log("Ajax call failed.");
  };
  if (Paperpile.main != undefined) {
    failure = Paperpile.main.onError;
  }

  if (!config.suppressDefaults) {

    if (config.success) {
      config.success = Ext.Function.createInterceptor(config.success, success);
    } else {
      config.success = success;
    }
    if (config.failure) {
      config.failure = Ext.Function.createInterceptor(config.failure, failure);
    } else {
      config.failure = failure;
    }
  }

  config.url = Paperpile.Url(config.url);

  config.xdomain = true;

  if (!config.method) {
    config.method = 'GET';
  }

  if (!config.scope) {
    config.scope = Paperpile.main;
  }

  if (config.debug) {
    Paperpile.log(config);
  }

  return Ext.Ajax.request(config);
};
