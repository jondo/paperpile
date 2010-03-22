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
      if (this.plugin_reload){
        Paperpile.status.showBusy("Loading Feed");
        options.params.plugin_reload = 1;
        this.plugin_reload=0;
      } else {
        options.params.plugin_reload = 0;
      }
    },
    this);
    this.getStore().on('load', function() {
      if (!this.backgroundLoading) {
        Paperpile.status.clearMsg();
      }
    },
    this);

    Paperpile.PluginGridFeed.superclass.initComponent.call(this);
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridFeed.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;
    ids.remove('NEW');

    ids.insert(3,'RELOAD_FEED');

  }
});