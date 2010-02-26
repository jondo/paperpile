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

    Paperpile.PluginGridFile.superclass.initComponent.call(this);

    Paperpile.status.showBusy('Parsing file.');
    this.getStore().on('load', function() {
      Paperpile.status.clearMsg();
    },
    this, {
      single: true
    });

  },

  createToolbarMenu: function() {
    Paperpile.PluginGridFile.superclass.createToolbarMenu.call(this);

    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
  },

  updateContextItem: function(menuItem, record) {
    var superShow = Paperpile.PluginGridFile.superclass.updateContextItem.call(this, menuItem, record);

    if (menuItem.itemId == this.actions['DELETE'].itemId) {
      menuItem.setVisible(false);
    }

    if (menuItem.itemId == this.actions['VIEW_PDF'].itemId) {
      menuItem.setVisible(false);
    }

    if (menuItem.itemId == this.actions['EDIT'].itemId) {
      menuItem.setVisible(false);
    }

    return superShow;
  }
});