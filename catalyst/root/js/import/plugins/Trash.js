Paperpile.PluginPanelTrash = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title:this.title,
      iconCls: 'pp-icon-trash'
    });

    Paperpile.PluginPanelTrash.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridTrash(gridParams);
  }

});

Paperpile.PluginGridTrash = Ext.extend(Paperpile.PluginGridDB, {

  plugin_iconCls: 'pp-icon-trash',
  plugin_name:'Trash',
  limit:50,
  plugin_base_query:'',    

  initComponent:function() {
    Paperpile.PluginGridTrash.superclass.initComponent.call(this);
  },

  createToolbarMenu: function() {
    Paperpile.PluginGridTrash.superclass.createToolbarMenu.call(this);

    this.actions['EMPTY_TRASH']= new Ext.Action({
      text: 'Empty Trash',
      handler: function(){
        this.allSelected=true;
        this.deleteEntry('DELETE');
        this.allSelected=false;
      },
      scope: this,
      iconCls: 'pp-icon-clean',
      itemId:'empty_button',
      tooltip: 'Delete all references in Trash permanently form your library.'
    });

    this.actions['RESTORE']= new Ext.Action({
      text: 'Restore',
      handler: function(){
        this.deleteEntry('RESTORE');
      },
      scope: this,
      iconCls: 'pp-icon-restore',
      itemId: 'restore_button',
      tooltip: 'Restore selected references from Trash'
    });      

    var tbar = this.getTopToolbar();

    var index = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
    tbar.insert(index+1,new Ext.Button(this.actions['RESTORE']));
    tbar.insert(index+1,new Ext.Button(this.actions['DELETE']));
    tbar.insert(index+1,new Ext.Button(this.actions['EMPTY_TRASH']));

    var item = this.getToolbarByItemId(this.actions['DELETE'].itemId);
    item.setTooltip('Permanently delete selected references.');
    item.setIconClass('pp-icon-delete');

    this.getToolbarByItemId(this.actions['SAVE_MENU'].itemId).setVisible(false);
    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
  },

  updateToolbarItem: function(item) {
    Paperpile.PluginGridTrash.superclass.updateToolbarItem.call(this,item);

    if (item.itemId == this.actions['DELETE'].itemId || item.itemId == this.actions['RESTORE'].itemId) {
      var selected = this.getSelection().length;
      if (selected > 0) {
	item.enable();
      } else {
	item.disable();
      }
    }
  },

  updateContextItem: function(item,record) {
    Paperpile.PluginGridTrash.superclass.updateContextItem.call(this,item,record);

    if (item.itemId == this.actions['DELETE'].itemId) {
      item.setIconClass('pp-icon-delete');
      item.setText('Delete permanently');
    }
  },

  handleDelete: function() {
    this.deleteEntry('DELETE');
  }

});
