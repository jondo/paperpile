/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU Affero General Public License as
   published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Affero General Public License for more details.  You should have
   received a copy of the GNU Affero General Public License along with
   Paperpile.  If not, see http://www.gnu.org/licenses. */

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
  },

  createAboutPanel: function() {
    return undefined;
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
      handler: this.handleEmptyTrash,
      scope: this,
      iconCls: 'pp-icon-clean',
      itemId: 'empty_button',
      tooltip: 'Delete all references in Trash permanently form your library.'
    });
    this.actions['RESTORE'] = new Ext.Action({
      text: 'Restore',
      handler: this.handleRestore,
      scope: this,
      iconCls: 'pp-icon-restore',
      itemId: 'restore_button',
      tooltip: 'Restore selected references from Trash'
    });
  },

  getEmptyBeforeSearchTemplate: function() {
    return new Ext.XTemplate(['<div class="pp-hint-box"><p>No items in the Trash. <a href="#" class="pp-textlink" action="close-tab">Close tab</a>.</p></div>']).compile();
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridTrash.superclass.initToolbarMenuItemIds.call(this);

    var ids = this.toolbarMenuItemIds;

    ids.remove('TB_DEL_SEP');
    ids.remove('NEW');
    ids.remove('EDIT');
    ids.remove('DELETE');
    ids.remove('LIVE_FOLDER');

    var index = ids.indexOf('TB_BREAK');
    ids.insert(index, 'EMPTY_TRASH');
    ids.insert(index, 'RESTORE');
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
      if (item.ownerCt && item.ownerCt.itemId == 'context') {
        item.setText('Delete Permanently');
      }
    },
    this);

    var selected = this.getSingleSelectionRecord();
    if (!selected) {
      this.actions['DELETE'].disable();
      this.actions['RESTORE'].disable();
    }

    if (this.getTotalCount() == 0) {
      this.actions['EMPTY_TRASH'].disable();
    }
  },

  handleRestore: function() {
    this.deleteEntry('RESTORE');
  },

  handleDelete: function() {
    this.deleteEntry('DELETE');
  },

  handleEmptyTrash: function() {
    this.deleteEntry('DELETE', true);
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