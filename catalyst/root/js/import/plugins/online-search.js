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
      createToolbarMenu: grid.createToolbarMenu.createSequence(function() {
        var tbar = this.getTopToolbar();
        this.searchField = new Ext.app.SearchField({
          emptyText: 'Search ' + this.plugin_name,
          width: 200,
          store: this.store
        });

        tbar.insert(0, this.searchField);
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

  },
});