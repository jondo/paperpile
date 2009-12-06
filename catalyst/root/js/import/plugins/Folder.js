Paperpile.PluginPanelFolder = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title:this.title,
      iconCls:'pp-icon-folder'
    });

    Paperpile.PluginPanelFolder.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFolder(gridParams);
  }

});

Paperpile.PluginGridFolder = Ext.extend(Paperpile.PluginGridDB, {

  plugin_iconCls: 'pp-icon-folder',
  plugin_name:'DB',
  limit: 25,
  plugin_base_query:'',

  initComponent: function() {
    Paperpile.PluginGridFolder.superclass.initComponent.call(this);

  },

  createToolbarMenu: function() {
    Paperpile.PluginGridFolder.superclass.createToolbarMenu.call(this);

    this.actions['REMOVE_FROM_FOLDER'] = new Ext.Action({
      text:'Remove from folder',
      cls:'x-btn-text-icon',
      icon:'/images/icons/folder_delete.png',
      handler:this.deleteFromFolder,
      scope:this
    });
    
    var tbar = this.getTopToolbar();
    
    // Hide the add button.
    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);

    var filterFieldIndex = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
    tbar.insertButton(filterFieldIndex+1,this.actions['REMOVE_FROM_FOLDER']);
  },

  updateToolbarItem: function(item) {
    Paperpile.PluginGridFolder.superclass.updateToolbarItem.call(this,item);

    if (item.itemId == this.actions['REMOVE_FROM_FOLDER'].itemId) {
      var selected = this.getSelection().length;
      (selected > 0 ? item.enable() : item.disable());
    }

  },

  updateContextItem: function(item,record) {
    Paperpile.PluginGridFolder.superclass.updateContextItem.call(this,item,record);

  },

  deleteFromFolder: function(){
    var selection=this.getSelection();
    var match=this.plugin_base_query.match('folder:(.*)$');

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_from_folder'),
      params: { selection: selection,
	grid_id: this.id,
        folder_id: match[1]
      },
      method: 'GET',
      success: function(){
	this.updateGrid();
      },
      failure: Paperpile.main.onError,
      scope:this
    });
  }
});
