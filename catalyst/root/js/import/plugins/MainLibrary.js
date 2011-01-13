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

Paperpile.PluginGridMainLibrary = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGridMainLibrary.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.PluginGridMainLibrary, Paperpile.PluginGridDB, {

  initComponent: function() {

    Paperpile.PluginGridMainLibrary.superclass.initComponent.call(this);

    this.actions['ADD_MENU'] = {
      text: 'Add to Library',
      itemId: 'ADD_MENU',
      iconCls: 'pp-icon-add',
      menu: {
        items: [
          this.actions['NEW'],
          this.actions['FILE_IMPORT'],
          this.actions['PDF_IMPORT']]
      }
    };

  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridMainLibrary.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;

    var index = ids.indexOf('TB_FILL');
    ids.insert(index + 1, 'ADD_MENU');
  }
});

Paperpile.PluginPanelMainLibrary = Ext.extend(Paperpile.PluginPanelDB, {
  createGrid: function(params) {
    return new Paperpile.PluginGridMainLibrary(params);
  },

  createAboutPanel: function() {
    return undefined;
  }
});