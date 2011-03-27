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
    new Paperpile.ImportGridPlugin(),
    new Paperpile.OnlineSearchGridPlugin()],
  limit: 25,

  initComponent: function() {
    this.plugin_name = 'ArXiv';
    this.plugin_iconCls = 'pp-icon-arxiv';

    Paperpile.PluginGridArXiv.superclass.initComponent.call(this);
  },

  getEmptyBeforeSearchTemplate: function() {

    var markup = [
      '<div class="pp-hint-box">',
      '  <h1>Search hints</h1>',
      '<p>For a simple search type authors, keywords or arXiv IDs:</p>',
      '  <ul>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">T Bhattacharya</a></li>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">spin glass</a></li>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">1010.4601</a></li>',
      '  </ul>',
      '</div>'];
    return new Ext.XTemplate(markup).compile();
  },

});

Paperpile.AboutArXiv = Ext.extend(Paperpile.PluginAboutPanel, {

});