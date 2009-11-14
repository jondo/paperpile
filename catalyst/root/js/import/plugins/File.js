Paperpile.PluginGridFile = Ext.extend(Paperpile.PluginGridDB, {

    plugins:new Paperpile.ImportGridPlugin(),
    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'File',
    
    initComponent:function() {
        Paperpile.PluginGridFile.superclass.initComponent.call(this);

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Parsing file.');
                      }, this);
        
        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

    },

    createToolbarMenu: function(item,index,length) {
      Paperpile.PluginGridFile.superclass.createToolbarMenu.call(this,arguments);

      this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
    },

    shouldShowContextItem: function(menuItem,record) {
      var superShow = Paperpile.PluginGridFile.superclass.shouldShowContextItem.call(this,menuItem,record);

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
