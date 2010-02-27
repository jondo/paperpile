/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */


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
  },

  createToolbarMenu: function() {
    Paperpile.PluginGridTrash.superclass.createToolbarMenu.call(this);

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

    var tbar = this.getTopToolbar();

    var index = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
    tbar.insert(index + 1, new Ext.Button(this.actions['RESTORE']));
    tbar.insert(index + 1, new Ext.Button(this.actions['DELETE']));
    tbar.insert(index + 1, new Ext.Button(this.actions['EMPTY_TRASH']));

    var item = this.getToolbarByItemId(this.actions['DELETE'].itemId);
    item.setTooltip('Permanently delete selected references.');
    item.setIconClass('pp-icon-delete');

    this.getToolbarByItemId(this.actions['SAVE_MENU'].itemId).setVisible(false);
    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
  },

  updateToolbarItem: function(item) {
    Paperpile.PluginGridTrash.superclass.updateToolbarItem.call(this, item);

    if (item.itemId == this.actions['DELETE'].itemId || item.itemId == this.actions['RESTORE'].itemId) {
      var selected = this.getSelection().length;
      if (selected > 0) {
        item.enable();
      } else {
        item.disable();
      }
    }
  },

  updateContextItem: function(item, record) {
    Paperpile.PluginGridTrash.superclass.updateContextItem.call(this, item, record);

    if (item.itemId == this.actions['DELETE'].itemId) {
      item.setIconClass('pp-icon-delete');
      item.setText('Delete permanently');
    }
  },

  handleDelete: function() {
    this.deleteEntry('DELETE');
  },

  getMultipleSelectionTemplate: function() {

    var template = [
      '<div id="main-container-{id}">',
      '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '  <tpl if="numSelected==0">',
      '  <p>No references in here.</p>',
      '  </tpl>',
      '  <tpl if="numSelected &gt;0">',
      '    <p><b>{numSelected}</b> references selected.</p>',
      '    <div class="pp-vspace"></div>',
      '    <ul> ',
      '      <li class="pp-action pp-action-delete"> <a  href="#" class="pp-textlink" action="delete-ref">Delete permanently</a> </li>',
      '      <li class="pp-action pp-action-restore"> <a  href="#" class="pp-textlink" action="restore-ref">Restore</a> </li>',
      '    </ul>',
      '  </tpl>',
      '  </div>',
      '</div>'];
    return[].concat(template);
  },

});