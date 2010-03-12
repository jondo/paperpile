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


Paperpile.OnlineSearchGridPlugin = function(config) {
  Ext.apply(this, config);

  Paperpile.OnlineSearchGridPlugin.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.OnlineSearchGridPlugin, Ext.util.Observable, {
  init: function(grid) {
    this.searchField = new Ext.app.SearchField({
      itemId:'SEARCH_FIELD',
      emptyText: 'Search ' + grid.plugin_name,
      width: 200,
      store: grid.getStore()
    });
    grid.actions['SEARCH_FIELD'] = this.searchField;
    grid.searchField = this.searchField;

    grid.store.on('beforeload',
      function() {
        Paperpile.status.showBusy('Searching ' + this.plugin_name);
      },
      grid);

    grid.store.on('load',
      function() {
        Paperpile.status.clearMsg();
        this.getSelectionModel().selectFirstRow();
      },
      grid);

    Ext.apply(grid, {
      hideHeaders: true,
      initToolbarMenuItemIds: grid.initToolbarMenuItemIds.createSequence(function() {
	var ids = this.toolbarMenuItemIds;
	ids.insert(0,'SEARCH_FIELD');
      },
      grid),
      setSearchQuery: function(text) {
        this.searchField.setValue(text);
        this.searchField.onTrigger2Click();
      }
    });

    if (grid.plugin_query != '') {
      grid.store.load({
        params: {
          start: 0,
          limit: this.limit
        }
      });
    }

  }
});