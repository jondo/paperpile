Paperpile.PluginPanelFile = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginPanelFile.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.PluginPanelFile, Paperpile.PluginPanelDB, {

  iconCls: 'pp-icon-folder',

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFile(gridParams);
  }

});

Paperpile.PluginGridFile = Ext.extend(Paperpile.PluginGridDB, {

  plugins: [new Paperpile.ImportGridPlugin()],
  plugin_base_query: '',
  plugin_name: 'File',

  initComponent: function() {
    this.getStore().on('beforeload', function() {
      Paperpile.status.showBusy("Parsing file");
    },
    this);
    this.getStore().on('load', function() {
      Paperpile.status.clearMsg();
    },
    this);

    Paperpile.PluginGridFile.superclass.initComponent.call(this);
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridFile.superclass.initToolbarMenuItemIds.call(this);
    
    var ids = this.toolbarMenuItemIds;

    ids.remove('NEW');
    ids.remove('DELETE');
  },

  initContextMenuItemIds: function() {
    Paperpile.PluginGridFile.superclass.initContextMenuItemIds.call(this);
    
    var ids = this.contextMenuItemIds;

    ids.remove('DELETE');
  }

});