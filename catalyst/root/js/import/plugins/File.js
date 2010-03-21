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

Paperpile.PluginPanelFile = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginPanelFile.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.PluginPanelFile, Paperpile.PluginPanelDB, {

  iconCls: 'pp-icon-folder',

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFile(gridParams);
  }

});

Paperpile.PluginGridFile = Ext.extend(Paperpile.PluginGridDB, {

  plugins: [new Paperpile.ImportGridPlugin()],
  plugin_base_query: '',
  plugin_name: 'File',

  initComponent: function() {
    this.getStore().on('beforeload', function() {
      Paperpile.status.showBusy("Loading File");
    },
    this);
    this.getStore().on('load', function() {
      if (!this.backgroundLoading) {
        Paperpile.status.clearMsg();
      }
    },
    this);

    Paperpile.PluginGridFile.superclass.initComponent.call(this);
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridFile.superclass.initToolbarMenuItemIds.call(this);

    var ids = this.toolbarMenuItemIds;

    ids.remove('NEW');
    ids.remove('DELETE');
  },

  initContextMenuItemIds: function() {
    Paperpile.PluginGridFile.superclass.initContextMenuItemIds.call(this);

    var ids = this.contextMenuItemIds;

    ids.remove('DELETE');
  }

});