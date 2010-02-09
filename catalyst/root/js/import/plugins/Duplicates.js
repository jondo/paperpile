Paperpile.PluginPanelDuplicates = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title: this.title,
      iconCls: 'pp-icon-duplicates'
    });
    Paperpile.PluginPanelDuplicates.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridDuplicates(gridParams);
  }

});

Paperpile.PluginGridDuplicates = Ext.extend(Paperpile.PluginGridDB, {
  plugin_iconCls: 'pp-icon-duplicates',
  plugin_name: 'Duplicates',
  limit: 25,
  plugin_base_query: '',

  emptyMsg: [
    '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-welcome"',
    '<h2>Duplicate Search</h2>',
    '<p>Your library was searched and no duplicate references were found.<p>',
    '</div>'],

  initComponent: function() {
    Paperpile.PluginGridDuplicates.superclass.initComponent.call(this);

    this.store.on('beforeload',
      function() {
        Paperpile.status.showBusy('Searching duplicates');
      },
      this);

    this.store.on('load',
      function() {
        Paperpile.status.clearMsg();
        if (this.store.getCount() == 0) {
	  this.getPluginPanel().onEmpty(this.emptyMsg);
        }
      },
      this);

    this.on('render', this.myOnRender, this);
  },

  createToolbarMenu: function() {
    Paperpile.PluginGridDuplicates.superclass.createToolbarMenu.call(this);

    this.actions['CLEAN_ALL_DUPLICATES'] = new Ext.Action({
      text: 'Clean all duplicates',
      handler: this.cleanDuplicates,
      scope: this,
      iconCls: 'pp-icon-clean',
      itemId: 'remove_duplicates',
      tooltip: 'Automatically clean all duplicates'
    });

    var tbar = this.getTopToolbar();

    // Hide the add button.
    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);

    var filterFieldIndex = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
    tbar.insertButton(filterFieldIndex + 1, this.actions['CLEAN_ALL_DUPLICATES']);
    tbar.insertButton(filterFieldIndex + 1, this.actions['DELETE']);
  },

  updateToolbarItem: function(item) {
    Paperpile.PluginGridDuplicates.superclass.updateToolbarItem.call(this, item);

    if (item.itemId == this.actions['DELETE'].itemId) {
      item.setIconClass('pp-icon-trash');
      item.setText('Move to Trash');
      var selected = this.getSelection().length;
      (selected > 0 ? item.enable() : item.disable());
    }
  },

  myOnRender: function() {
    this.store.load({
      params: {
        start: 0,
        limit: this.limit,
	// Cause the duplicate cache to be cleared each time the grid is reloaded.
	// This is very slow, and will need backend optimization in Duplicates.pm.
	plugin_clear_duplicate_cache: true
      }
    });

    this.store.on('load', function() {
      this.getSelectionModel().selectFirstRow();
    },
    this, {
      single: true
    });
  },

  cleanDuplicates: function() {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/misc/clean_duplicates'),
      params: {
        grid_id: this.id
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  }
});