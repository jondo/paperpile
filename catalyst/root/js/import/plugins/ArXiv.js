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

Paperpile.PluginPanelArXiv = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'ArXiv',
      iconCls: 'pp-icon-arxiv'
    });
    Paperpile.PluginPanelArXiv.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridArXiv(params);
  },
  createAboutPanel: function() {
    return new Paperpile.PluginAboutPanel({

      markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-arxiv-logo">&nbsp</div>',
        '<p class="pp-plugins-description">arXiv is an e-print service in the fields of physics, mathematics, non-linear science, computer science, quantitative biology and statistics. It currently offers open access to more than 570,000 e-prints.</p>',
        '<p><a target=_blank href="http://arxiv.org/" class="pp-textlink">arxiv.org</a></p>',
        '</div>'],

      tabLabel: 'About ArXiv'
    });
  }
});

Paperpile.PluginGridArXiv = Ext.extend(Paperpile.PluginGrid, {

  plugins: [
    new Paperpile.OnlineSearchGridPlugin(),
    new Paperpile.ImportGridPlugin()],
  limit: 25,

  initComponent: function() {
    this.plugin_name = 'ArXiv';
    this.plugin_iconCls = 'pp-icon-arxiv';

    Paperpile.PluginGridArXiv.superclass.initComponent.call(this);
  }

});

Paperpile.AboutArXiv = Ext.extend(Paperpile.PluginAboutPanel, {

});