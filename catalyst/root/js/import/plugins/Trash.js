Paperpile.PluginGridTrash = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGridTrash.superclass.constructor.call(this, {

  });

};

Ext.extend(Paperpile.PluginGridTrash, Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-trash',
    plugin_name:'Trash',
    
    initComponent:function() {
        Paperpile.PluginGridTrash.superclass.initComponent.apply(this, arguments);

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

      
      this.on({afterrender:{scope:this,fn:this.myOnRender}});
    },

    myOnRender: function() {
      var tbar = this.getTopToolbar();
      var index = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
      
      tbar.insertButton(index+1,this.actions['RESTORE']);
      tbar.insertButton(index+1,this.actions['DELETE']);
      tbar.insertButton(index+1,this.actions['EMPTY_TRASH']);

      index = this.getButtonIndex(this.actions['SAVE_MENU']);

    },
    
    shouldShowButton: function(menuItem) {
      var superShow = Paperpile.PluginGridTrash.superclass.shouldShowButton.call(this,menuItem);

      if (menuItem.itemId == this.actions['DELETE'].itemId) {
	menuItem.setTooltip('Permanently delete selected references.');
	menuItem.setIconClass('pp-icon-delete');
      }

      if (menuItem.itemId == this.actions['SAVE_MENU'].itemId) {
	this.getTopToolbar().remove(menuItem);
	this.getTopToolbar().doLayout();
//	menuItem.setVisible(false);
      }

      return superShow;
    },

    shouldShowContextItem: function(menuItem,record) {
      var superShow = Paperpile.PluginGridTrash.superclass.shouldShowContextItem.call(this,menuItem,record);
      
      if (menuItem.itemId == this.actions['DELETE'].itemId) {
	menuItem.setIconClass('pp-icon-delete');
	menuItem.setText('Delete permanently');
      }

      return superShow;
    },

    handleDelete: function() {
      this.deleteEntry('DELETE');
    }

});
