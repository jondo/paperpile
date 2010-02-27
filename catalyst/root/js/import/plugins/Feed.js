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
    this.getStore().on('beforeload', function() {
      Paperpile.status.showBusy("Parsing feed");
    },
    this);
    this.getStore().on('load', function() {
      Paperpile.status.clearMsg();
    },
    this);

    Paperpile.PluginGridFeed.superclass.initComponent.call(this);


  },

  createToolbarMenu: function() {
    Paperpile.PluginGridFeed.superclass.createToolbarMenu.call(this);

    this.getToolbarByItemId(this.actions['NEW'].itemId).setVisible(false);
  },

  updateToolbarItem: function(item) {
    Paperpile.PluginGridFolder.superclass.updateToolbarItem.call(this, item);
  }

});