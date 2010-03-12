Paperpile.PluginPanelFolder = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title: this.title,
      iconCls: 'pp-icon-folder'
    });

    Paperpile.PluginPanelFolder.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFolder(gridParams);
  }

});

Paperpile.PluginGridFolder = Ext.extend(Paperpile.PluginGridDB, {

  plugin_iconCls: 'pp-icon-folder',
  plugin_name: 'DB',
  limit: 25,
  plugin_base_query: '',

  initComponent: function() {
    Paperpile.PluginGridFolder.superclass.initComponent.call(this);

    this.actions['REMOVE_FROM_FOLDER'] = new Ext.Action({
      text: 'Remove from folder',
      cls: 'x-btn-text-icon',
      icon: '/images/icons/folder_delete.png',
      handler: this.deleteFromFolder,
      scope: this
    });
  },

  initContextMenuItemIds: function() {
    Paperpile.PluginGridFolder.superclass.initContextMenuItemIds.call(this);
    var ids = this.contextMenuItemIds;

    var index = ids.indexOf('DELETE');
    ids.insert(index + 1, 'REMOVE_FROM_FOLDER');
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridFolder.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;

    var index = ids.indexOf('TB_FILL');
    ids.insert(index+1,'REMOVE_FROM_FOLDER');
  },    

  updateButtons: function() {
    Paperpile.PluginGridFolder.superclass.updateButtons.call(this);
    
    var selection = this.getSingleSelectionRecord();
    if (!selection) {
      this.actions['REMOVE_FROM_FOLDER'].disable();
    }
  },

  deleteFromFolder: function() {
    var sel = this.getSelection();
    var grid = this;
    var match = this.plugin_base_query.match('folder:(.*)$');
    var folder_id = match[1];
    var refreshView = true;
    Paperpile.main.deleteFromFolder(sel, grid, folder_id, refreshView);
  }
});