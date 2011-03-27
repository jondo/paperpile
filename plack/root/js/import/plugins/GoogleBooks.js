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

Paperpile.PluginPanelGoogleBooks = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'Google Books',
      iconCls: 'pp-icon-google'
    });
    Paperpile.PluginPanelGoogleBooks.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridGoogleBooks(params);
  },
  createAboutPanel: function() {
    return new Paperpile.PluginAboutPanel({
      markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-googlebooks-logo">&nbsp</div>',
        '<p class="pp-plugins-description">Google Books searches the full text of over seven million books.</p>',
        '<p><a target=_blank href="http://books.google.com/" class="pp-textlink">books.google.com/</a></p>',
        '</div>'],

      tabLabel: 'About GoogleBooks',

    });
  }
});

Paperpile.PluginGridGoogleBooks = Ext.extend(Paperpile.PluginGrid, {

  plugins: [
    new Paperpile.ImportGridPlugin(),
    new Paperpile.OnlineSearchGridPlugin()],
  plugin_title: 'GoogleBooks',
  plugin_iconCls: 'pp-icon-google',
  limit: 25,

  initComponent: function() {
    this.plugin_name = 'GoogleBooks';

    // Multiple selection behaviour and double-click import turned
    // out to be really difficult for plugins where we have a to
    // step process to get the data. Needs more thought, for now
    // we just turn these features off.
    this.sm = new Ext.grid.RowSelectionModel({
      singleSelect: true
    });
    this.onDblClick = function(grid, rowIndex, e) {
      Paperpile.status.updateMsg({
        msg: 'Hint: use the "Add" button to import papers to your library.',
        hideOnClick: true,
      });
    };

    Paperpile.PluginGridGoogleBooks.superclass.initComponent.call(this);
  }
});