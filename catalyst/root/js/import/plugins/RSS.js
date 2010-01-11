Paperpile.PluginPanelRSS = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title:this.title,
      iconCls:'pp-icon-feed'
    });

    Paperpile.PluginPanelRSS.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridRSS(gridParams);
  }

});

Paperpile.PluginGridRSS = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-feed',
    plugin_name:'RSS',
    
    initComponent:function() {
        Paperpile.PluginGridRSS.superclass.initComponent.call(this);

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Parsing file.');
                      }, this);
        
        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

    },

    createToolbarMenu: function() {
      Paperpile.PluginGridRSS.superclass.createToolbarMenu.call(this);

      this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
    },

    updateToolbarItem: function(item) {
      Paperpile.PluginGridFolder.superclass.updateToolbarItem.call(this,item);

    }

});