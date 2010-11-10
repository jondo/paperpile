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
  },

  createAboutPanel: function() {
    return undefined;
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
      handler: this.removeFromFolder,
      scope: this
    });
  },

  showBaseQueryInfo: function() {
    return false;
  },

  // Almost the same stuff as the Labels panel to update the tab title.
  // Maybe we can reduce duplication by creating a Collection.js plugin type.
  // This will also come in handy if / when we turn Feeds into collections.
  refreshCollections: function() {
    Paperpile.PluginGridFolder.superclass.refreshCollections.call(this);

    var pp = this.getPluginPanel();
    var guid = this.getGUID();

    // If we're a Label grid, update our title...
    var itemId = this.getPluginPanel().itemId;
    var folders = Ext.StoreMgr.lookup('folder_store');
    var index = folders.findExact('guid', itemId);
    if (index !== -1) {
      var record = folders.getAt(index);
      var title = record.get('display_name');
      var tabDom = Paperpile.main.tabs.getTabEl(this.getPluginPanel());
      var tabEl = Ext.fly(tabDom);
      var textEl = tabEl.child('.x-tab-strip-text');
      textEl.dom.innerHTML = title;
    }
  },

  getGUID: function() {
    var match = this.plugin_base_query.match('folderid:(.*)$');
    var guid = match[1];
    return guid;
  },

  getEmptyBeforeSearchTemplate: function() {
    return new Ext.XTemplate(['<div class="pp-hint-box"><p>This folder is empty. <a href="#" class="pp-textlink" action="close-tab">Close tab</a>.</p></div>']).compile();
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
    ids.insert(index + 1, 'REMOVE_FROM_FOLDER');
  },

  updateButtons: function() {
    Paperpile.PluginGridFolder.superclass.updateButtons.call(this);

    var selection = this.getSingleSelectionRecord();
    if (!selection) {
      this.actions['REMOVE_FROM_FOLDER'].disable();
    }
  },

  removeFromFolder: function() {
    var sel = this.getSelection();
    var grid = this;
    var match = this.plugin_base_query.match('folderid:(.*)$');
    var folder_id = match[1];

    var firstRecord = this.getSelectionModel().getLowestSelected();
    var firstIndex = this.getStore().indexOf(firstRecord);
    this.doAfterNextReload.push(function() {
      this.getSelectionModel().selectRow(firstIndex);
    });
    Paperpile.main.removeFromFolder(sel, grid, folder_id);
  },

  onUpdate: function(data) {
    Paperpile.PluginGridFolder.superclass.onUpdate.call(this, data);

    var pubs = data.pubs;
    if (!pubs) {
      return;
    }

    var refreshMe = false;
    for (var guid in pubs) {
      var update = pubs[guid];
      if (update['folders'] !== undefined) {
        refreshMe = true;
      }
    }
    if (refreshMe) {
      this.getView().holdPosition = true;
      this.getStore().reload();
    }
  }
});