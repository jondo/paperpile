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

Paperpile.PluginPanelJSTOR = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'JSTOR',
      iconCls: 'pp-icon-jstor'
    });
    Paperpile.PluginPanelJSTOR.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridJSTOR(params);
  },
  createAboutPanel: function() {
    return new Paperpile.PluginAboutPanel({
      markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-jstor-logo">&nbsp</div>',
        '<p class="pp-plugins-description">JSTOR (short for Journal Storage) is a online system for archiving academic journals. It provides full-text searches of digitized back issues of several hundred well-known journals.</p>',
        '<p><a target=_blank href="http://www.jstor.org" class="pp-textlink">	jstor.org</a></p>',
        '</div>'],
      tabLabel: 'About JSTOR'
    });
  }

});

Paperpile.PluginGridJSTOR = Ext.extend(Paperpile.PluginGrid, {

  plugins: [
    new Paperpile.OnlineSearchGridPlugin(),
    new Paperpile.ImportGridPlugin()],
  limit: 25,

  initComponent: function() {
    this.plugin_name = 'JSTOR';

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

    Paperpile.PluginGridJSTOR.superclass.initComponent.call(this);
  }
});