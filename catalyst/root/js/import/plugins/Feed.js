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

Paperpile.PluginPanelFeed = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title: this.title,
      iconCls: 'pp-icon-feed'
    });

    Paperpile.PluginPanelFeed.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridFeed(gridParams);
  }

});

Paperpile.PluginGridFeed = Ext.extend(Paperpile.PluginGridDB, {

  plugin_base_query: '',
  plugin_iconCls: 'pp-icon-feed',
  plugin_name: 'Feed',

  plugins: [
    new Paperpile.ImportGridPlugin()],

  initComponent: function() {
    this.getStore().setBaseParam('plugin_url', this.plugin_url);
    this.getStore().setBaseParam('plugin_id', this.plugin_id);

    this.getStore().on('beforeload', function(store, options) {

      // If this.plugin_reload is set, we want to force the backend to
      // re-download the feed. It is set to 0 here to allow "live"
      // search from the local database after that. 
      if (this.plugin_reload) {

        // First set variable for backend
        options.params.plugin_reload = 1;
        // Reset immediately to ensure the next time we do "live search"
        this.plugin_reload = 0;

        // Allow cancel and timeout when doing full load
        options.params.cancel_handle = 'grid_' + this.id;

        Paperpile.status.updateMsg({
          busy: true,
          msg: 'Loading Feed.',
          action1: 'Cancel',
          callback: function() {
            this.cancelLoad();
            Paperpile.status.clearMsg();

            clearTimeout(this.timeoutWarn);
            clearTimeout(this.timeoutAbort);
          },
          scope: this
        });

        // Warn after 10 sec
        this.timeoutWarn = (function() {
          Paperpile.status.setMsg('This is taking longer than usual. Still loading Feed.');
        }).defer(10000, this);

        // Abort after 35 sec
        this.timeoutAbort = (function() {
          this.cancelLoad();
          Paperpile.status.clearMsg();
          Paperpile.status.updateMsg({
            type: 'error',
            msg: 'Giving up. There may be problems with your network or the site hosting the Feed.',
            hideOnClick: true
          });
        }).defer(20000, this);
      } else {
        options.params.plugin_reload = 0;
      }
    },
    this);
    this.getStore().on('load', function() {
      if (!this.backgroundLoading) {
        Paperpile.status.clearMsg();
      }
      clearTimeout(this.timeoutWarn);
      clearTimeout(this.timeoutAbort);
    },
    this);

    this.getStore().on('loadexception',
      function(exception, options, response, error) {
        clearTimeout(this.timeoutWarn);
        clearTimeout(this.timeoutAbort);
      },
      this);

    Paperpile.PluginGridFeed.superclass.initComponent.call(this);
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridFeed.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;
    ids.remove('NEW');

    ids.insert(3, 'RELOAD_FEED');

  },

    allowBackgroundReload: function() {
	return false;
    }
});