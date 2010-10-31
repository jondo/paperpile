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

Paperpile.OnlineSearchGridPlugin = function(config) {
  Ext.apply(this, config);

  Paperpile.OnlineSearchGridPlugin.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.OnlineSearchGridPlugin, Ext.util.Observable, {
  init: function(grid) {

    this.searchField = new Ext.app.SearchField({
      itemId: 'SEARCH_FIELD',
      emptyText: 'Search ' + grid.plugin_name,
      width: 250,
      store: grid.getStore()
    });
    grid.actions['SEARCH_FIELD'] = this.searchField;
    grid.searchField = this.searchField;

    grid.getStore().baseParams.cancel_handle = 'grid_' + grid.id;

    grid.store.on('beforeload',
      function() {
        if (this.backgroundLoading) {
          return;
        }

        // Show waiting message and allow canceling
        Paperpile.status.updateMsg({
          busy: true,
          msg: 'Searching ' + this.plugin_name,
          action1: 'Cancel',
          callback: function() {
            grid.cancelLoad();
            Paperpile.status.clearMsg();

            clearTimeout(this.timeoutWarn);
            clearTimeout(this.timeoutAbort);

            this.timeoutWarn = null;
            this.timeoutAbort = null;
          },
          scope: this
        });

        // Warn after 15 sec
        this.timeoutWarn = (function() {
          Paperpile.status.setMsg('This is taking longer than usual. Still searching ' + grid.plugin_name + '...');
        }).defer(15000);

        // Abort after 35 sec
        this.timeoutAbort = (function() {
          grid.cancelLoad();
          Paperpile.status.clearMsg();

          Paperpile.status.updateMsg({
            type: 'error',
            msg: 'Giving up. There may be problems with your network or ' + grid.plugin_name + '.',
            hideOnClick: true
          });
        }).defer(35000);
      },
      grid);

    grid.store.on('load',
      function() {
        // Clear status message and timeout timers
        if (!this.backgroundLoading) {
          Paperpile.status.clearMsg();
        }

        clearTimeout(this.timeoutWarn);
        clearTimeout(this.timeoutAbort);

        this.timeoutWarn = null;
        this.timeoutAbort = null;

        this.getSelectionModel().selectFirstRow.defer(10, this.getSelectionModel());
      },
      grid);

    // Make sure timeouts are cleared on error 
    grid.store.on('loadexception',
      function(exception, options, response, error) {
        clearTimeout(this.timeoutWarn);
        clearTimeout(this.timeoutAbort);
        this.timeoutWarn = null;
        this.timeoutAbort = null;
      },
      grid);

    grid.store.on('destroy', function() {
      if (this.isLoading) {
        clearTimeout(this.timeoutWarn);
        clearTimeout(this.timeoutAbort);
        this.cancelLoad();
        Paperpile.status.clearMsg();
      }
    },
    grid);

    Ext.apply(grid, {
      hideHeaders: true,
      initToolbarMenuItemIds: grid.initToolbarMenuItemIds.createSequence(function() {
        var ids = this.toolbarMenuItemIds;
        ids.insert(0, 'SEARCH_FIELD');
      },
      grid),
      initContextMenuItemIds: grid.initContextMenuItemIds.createSequence(function() {
        var ids = this.contextMenuItemIds;
        ids.remove('AUTO_COMPLETE');

      },
      grid),
      setSearchQuery: function(text) {
        this.searchField.setValue(text);
        this.searchField.onTrigger2Click();
      },
      getNoResultsTemplate: function() {
        return new Ext.XTemplate(['<div class="pp-hint-box"><p>No results found. Try a <a href="#" class="pp-textlink" action="clear-search"> new search</a>.</p></div>']).compile();
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