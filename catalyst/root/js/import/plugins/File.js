/* Copyright 2009-2011 Paperpile

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

Paperpile.PluginPanelFile = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginPanelFile.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.PluginPanelFile, Paperpile.PluginPanelDB, {

  iconCls: 'pp-icon-folder',

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFile(gridParams);
  },

  createAboutPanel: function() {
    return undefined;
  }

});

Paperpile.PluginGridFile = Ext.extend(Paperpile.PluginGridDB, {

  plugins: [new Paperpile.ImportGridPlugin()],
  plugin_base_query: '',
  plugin_name: 'File',

  initComponent: function() {

    this.getStore().on('beforeload', function() {
			   Paperpile.log("asdf");
      Paperpile.status.showBusy("Loading File");
    },
    this, {
      single: true
    });
    this.getStore().on('load', function() {
			   Paperpile.log("Done loading");
      Paperpile.status.clearMsg();
    },
    this, {
      single: true
    });

    Paperpile.PluginGridFile.superclass.initComponent.call(this);

    this.actions['IMPORT_ALL'] = new Ext.Action({
      itemId: 'IMPORT_ALL',
      text: 'Import all',
      handler: function() {
        this.insertEntry(true);
      },
      scope: this,
      iconCls: 'pp-icon-add-all',
      tooltip: 'Import all references to your library.'
    });

  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridFile.superclass.initToolbarMenuItemIds.call(this);

    var ids = this.toolbarMenuItemIds;

    var index = ids.indexOf('TB_BREAK');
    ids.insert(index, 'IMPORT_ALL');

    ids.remove('NEW');
    ids.remove('DELETE');
  },

  initContextMenuItemIds: function() {
    Paperpile.PluginGridFile.superclass.initContextMenuItemIds.call(this);

    var ids = this.contextMenuItemIds;

    ids.remove('DELETE');
  },

  updateButtons: function() {
    Paperpile.PluginGridFile.superclass.updateButtons.call(this);

    if (this.getTotalCount() == 0) {
      this.actions['IMPORT_ALL'].disable();
    }

  },

  getNoResultsTemplate: function() {
    return new Ext.XTemplate(['<div class="pp-hint-box"><p>No references to show. <a href="#" class="pp-textlink" action="close-tab">Close tab</a>.</p></div>']).compile();
  },

});