Paperpile.PluginPanelFeed = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title: this.title,
      iconCls: 'pp-icon-feed'
    });

    Paperpile.PluginPanelFeed.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFeed(gridParams);
  }

});

Paperpile.PluginGridFeed = Ext.extend(Paperpile.PluginGridDB, {

  plugin_base_query: '',
  plugin_iconCls: 'pp-icon-feed',
  plugin_name: 'Feed',

  plugins: [
    new Paperpile.ImportGridPlugin()],

  initComponent: function() {
    this.getStore().setBaseParam('plugin_url', this.plugin_url);
    this.getStore().setBaseParam('plugin_id', this.plugin_id);
    this.getStore().on('beforeload', function() {
      Paperpile.status.showBusy("Parsing feed");
    },
    this);
    this.getStore().on('load', function() {
      Paperpile.status.clearMsg();
    },
    this);

    Paperpile.PluginGridFeed.superclass.initComponent.call(this);


  },

  createToolbarMenu: function() {
    Paperpile.PluginGridFeed.superclass.createToolbarMenu.call(this);

    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
  },

  updateToolbarItem: function(item) {
    Paperpile.PluginGridFolder.superclass.updateToolbarItem.call(this, item);
  }

});