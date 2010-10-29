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

Paperpile.PluginPanelPubMed = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'PubMed',
      iconCls: 'pp-icon-pubmed'
    });
    Paperpile.PluginPanelPubMed.superclass.initComponent.call(this);
  },
  createGrid: function(gridParams) {
    return new Paperpile.PluginGridPubMed(gridParams);
  },

  createAboutPanel: function() {
    return new Paperpile.PluginAboutPanel({

      markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-pubmed-logo">&nbsp</div>',
        '<p>The PubMed database comprises more than 19 million citations for biomedical articles from MEDLINE and life science journals.</p>',
        '<p><a target=_blank href="http://pubmed.gov" class="pp-textlink">pubmed.gov</a></p>',
        '</div>'],

      tabLabel: 'About PubMed'
    });
  }
});

Paperpile.PluginGridPubMed = Ext.extend(Paperpile.PluginGrid, {

  plugins: [
    new Paperpile.OnlineSearchGridPlugin(),
    new Paperpile.ImportGridPlugin()],
  initComponent: function() {
    this.limit = 25;
    this.plugin_name = 'PubMed';
    this.plugin_iconCls = 'pp-icon-pubmed';

    Paperpile.PluginGridPubMed.superclass.initComponent.call(this);
  },
  getEmptyBeforeSearchTemplate: function() {
    var markup = [
      '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-center">',
      '  <h2>Example searches:</h2>',
      '  <ul>',
      '    <li><a href="#" class="pp-textlink" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">1953[publication date] nature[journal] "Watson JD"[author] "Crick FH"[author]</a></li>',
      '    <li><a href="#" class="pp-textlink" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">"lander es"[au] "linton lm"[au] 2001[publication date] nature[journal]</a></li>',
      '  </ul>',
      '</div>'];
    return new Ext.XTemplate(markup).compile();
  }

});