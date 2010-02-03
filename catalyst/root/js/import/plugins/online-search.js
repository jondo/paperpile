Paperpile.OnlineSearchGridPlugin = function(config) {
  Ext.apply(this, config);

  Paperpile.OnlineSearchGridPlugin.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.OnlineSearchGridPlugin, Ext.util.Observable, {
  init: function(grid) {

    grid.store.on('beforeload',
      function() {
        Paperpile.status.showBusy('Searching ' + this.plugin_name);
      },
      grid);

    grid.store.on('load',
      function() {
        Paperpile.status.clearMsg();
        this.getSelectionModel().selectFirstRow();
      },
      grid);

    Ext.apply(grid, {
      createToolbarMenu: grid.createToolbarMenu.createSequence(function() {
        var tbar = this.getTopToolbar();
        this.searchField = new Ext.app.SearchField({
          emptyText: 'Search '+this.plugin_name,
          width: 200,
          store: this.store
        });

        tbar.insert(0, this.searchField);
      },
      grid),
      setSearchQuery: function(text) {
        this.searchField.setValue(text);
        this.searchField.onTrigger2Click();
      }
    });

    if (grid.plugin_query != '') {
      grid.store.load({
        params: {
          start: 0,
          limit: this.limit
        }
      });
    }

  },
});