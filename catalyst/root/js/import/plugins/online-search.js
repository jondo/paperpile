Paperpile.OnlineSearchGridPlugin = function(config) {
  Ext.apply(this, config);

  Paperpile.OnlineSearchGridPlugin.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.OnlineSearchGridPlugin, Ext.util.Observable, {
  init: function(grid) {
    this.searchField = new Ext.app.SearchField({
      itemId:'SEARCH_FIELD',
      emptyText: 'Search ' + grid.plugin_name,
      width: 200,
      store: grid.getStore()
    });
    grid.actions['SEARCH_FIELD'] = this.searchField;
    grid.searchField = this.searchField;

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
      hideHeaders: true,
      initToolbarMenuItemIds: grid.initToolbarMenuItemIds.createSequence(function() {
	var ids = this.toolbarMenuItemIds;
	ids.insert(0,'SEARCH_FIELD');
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

  }
});