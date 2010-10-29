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

Paperpile.PluginPanelGoogleScholar = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'Google Scholar',
      iconCls: 'pp-icon-google'
    });
    Paperpile.PluginPanelGoogleScholar.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridGoogleScholar(params);
  },
  createAboutPanel: function() {
    return new Paperpile.PluginAboutPanel({
      markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-googlescholar-logo">&nbsp</div>',
        '<p class="pp-plugins-description">Google Scholar searches across many disciplines and sources: peer-reviewed papers, theses, books, abstracts and articles, from academic publishers, professional societies, preprint repositories, universities and other scholarly organizations.</p>',
        '<p><a target=_blank href="http://scholar.google.com" class="pp-textlink">scholar.google.com</a></p>',
        '</div>'],
      tabLabel: 'About GoogleScholar'
    });
  }

});

Paperpile.PluginGridGoogleScholar = Ext.extend(Paperpile.PluginGrid, {

  plugins: [
    new Paperpile.OnlineSearchGridPlugin(),
    new Paperpile.ImportGridPlugin()],
  limit: 10,

  initComponent: function() {
    this.plugin_name = 'GoogleScholar';
    this.plugin_iconCls = 'pp-icon-google';

    Paperpile.PluginGridGoogleScholar.superclass.initComponent.call(this);
  },
  getEmptyBeforeSearchTemplate: function() {
    var markup = [
      '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-center">',
      '  <h2>Example searches:</h2>',
      '  <ul>',
      '    <li><a href="#" class="pp-textlink" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">author:lipman "basic local alignment search tool"</a></li>',
      '  </ul>',
      '</div>'];
    return new Ext.XTemplate(markup).compile();
  },

  isLongImport: function() {
    return true;
  }

});