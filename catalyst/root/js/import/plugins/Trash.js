Paperpile.PluginPanelTrash = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title: this.title,
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
  plugin_name: 'Trash',
  limit: 50,
  plugin_base_query: '',

  initComponent: function() {
    Paperpile.PluginGridTrash.superclass.initComponent.call(this);

    this.actions['EMPTY_TRASH'] = new Ext.Action({
      text: 'Empty Trash',
      handler: function() {
        this.allSelected = true;
        this.deleteEntry('DELETE');
        this.allSelected = false;
      },
      scope: this,
      iconCls: 'pp-icon-clean',
      itemId: 'empty_button',
      tooltip: 'Delete all references in Trash permanently form your library.'
    });
    this.actions['RESTORE'] = new Ext.Action({
      text: 'Restore',
      handler: function() {
        this.deleteEntry('RESTORE');
      },
      scope: this,
      iconCls: 'pp-icon-restore',
      itemId: 'restore_button',
      tooltip: 'Restore selected references from Trash'
    });
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridTrash.superclass.initToolbarMenuItemIds.call(this);

    var ids = this.toolbarMenuItemIds;

    ids.remove('NEW');
    ids.remove('EDIT');
    ids.remove('EXPORT_MENU');
    ids.remove('DELETE');

    var index = ids.indexOf('TB_FILL');
    ids.insert(index + 1, 'RESTORE');
    ids.insert(index + 2, 'DELETE');
    ids.insert(index + 3, 'EMPTY_TRASH');
  },

  initContextMenuItemIds: function() {
    Paperpile.PluginGridTrash.superclass.initContextMenuItemIds.call(this);

    var ids = this.contextMenuItemIds;

    ids.remove('EDIT');
    ids.remove('DELETE');
    ids.remove('MORE_FROM_MENU');

    ids.insert(0, 'RESTORE');
    ids.insert(1, 'DELETE');
    ids.insert(2, this.createContextSeparator('TRASH_SPACE'));
  },

  updateButtons: function() {
    Paperpile.PluginGridTrash.superclass.updateButtons.call(this);

    // Fix up the delete button to reflext the permanency of deleting from trash.
    this.actions['DELETE'].setText('Delete');
    this.actions['DELETE'].setIconClass('pp-icon-delete');
    this.actions['DELETE'].each(function(item) {
      if (item['setTooltip']) {
	item.setTooltip('Permanently delete selected references.');
      }
      if (item.ownerCt.itemId == 'context') {
	item.setText('Delete Permanently');
      }
    },this);

    var selected = this.getSingleSelectionRecord();
    if (!selected) {
      this.actions['DELETE'].disable();
      this.actions['RESTORE'].disable();
    }

    if (this.getTotalCount() == 0) {
      this.actions['EMPTY_TRASH'].disable();
    }
  },

  handleDelete: function() {
    this.deleteEntry('DELETE');
  },

  getMultipleSelectionTemplate: function() {
    var template = [
      '<div id="main-container-{id}">',
      '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '    <p><b>{numSelected}</b> references selected.</p>',
      '    <div class="pp-vspace"></div>',
      '    <ul> ',
      '      <li class="pp-action pp-action-delete"> <a  href="#" class="pp-textlink" action="delete-ref">Delete permanently</a> </li>',
      '      <li class="pp-action pp-action-restore"> <a  href="#" class="pp-textlink" action="restore-ref">Restore</a> </li>',
      '    </ul>',
      '  </div>',
      '</div>'];
    return[].concat(template);
  },

});