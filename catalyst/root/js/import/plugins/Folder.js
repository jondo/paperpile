Paperpile.PluginGridFolder = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'DB',
    limit: 25,

  initComponent: function() {
    Paperpile.PluginGridFolder.superclass.initComponent.call(this);

    this.actions['REMOVE_FROM_FOLDER'] = new Ext.Action({
      text:'Remove from folder',
      cls:'x-btn-text-icon',
      icon:'/images/icons/folder_delete.png',
      handler:this.deleteFromFolder,
      scope:this
    });

    this.on({afterrender:{scope:this,fn:this.myOnRender}});
  },

  myOnRender: function() {
    var tbar = this.getTopToolbar();
    var filterFieldIndex = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
    tbar.insertButton(filterFieldIndex+1,this.actions['REMOVE_FROM_FOLDER']);
  },

  updateButtons: function() {
    Paperpile.PluginGridFolder.superclass.updateButtons.call(this);
    
    var selected = this.getSelection().length;
    if (selected > 0) {
      this.actions['REMOVE_FROM_FOLDER'].enable();
    } else {
      this.actions['REMOVE_FROM_FOLDER'].disable();
    }
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
