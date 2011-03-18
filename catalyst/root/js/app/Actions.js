Ext.define('Paperpile.app.Actions', {
  statics: {
    execute: function(id, args) {
      var action = this.actions.get(id);
      if (action) {
        Paperpile.log("Executing action " + id + " with args " + args);
        Ext.Function.defer(action.execute, 10, action, args);
      } else {
        Paperpile.log("Action " + id + " not found!");
      }
    },
    get: function(id) {
      var action = this.actions.get(id);
      if (action) {
	  return action;
      } else {
        Paperpile.log("Action " + id + " not found!");
      }
    },
    loadActions: function() {
      if (this.actions !== undefined) {
        Paperpile.log("Actions already loaded once!");
      } else {
        Paperpile.log("Loading actions");
      }
      this.actions = new Ext.util.MixedCollection();
      this.actions.addAll(Paperpile.app.PubActions.getActions());
      this.actions.addAll(Paperpile.app.NavActions.getActions());
    }

  }
});