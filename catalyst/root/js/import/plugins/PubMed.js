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
    new Paperpile.ImportGridPlugin(),
    new Paperpile.OnlineSearchGridPlugin()],
  initComponent: function() {
    this.limit = 25;
    this.plugin_name = 'PubMed';
    this.plugin_iconCls = 'pp-icon-pubmed';

    Paperpile.PluginGridPubMed.superclass.initComponent.call(this);
  },

  getEmptyBeforeSearchTemplate: function() {
    var markup = [
      '<div class="pp-hint-box">',
      '  <h1>Search hints</h1>',
      '<p>For a simple search type keywords, authors, journal names or PubMed IDs:</p>',
      '  <ul>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">cell cycle</a></li>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">Watson JD</a></li>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">"Journal of molecular biology"</a></li>',
      '   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);">11237011</a></li>',
      '  </ul>',
      //'<p>For an advanced search specify and combine fields:</p>',
      //'  <ul>',
      //'   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);"><b>author:</b>"Watson JD" <b>author:</b>"Crick FH" <b>year:</b>1953 <b>journal:</b>Nature</a></li>',
      //'   <li><a href="#" class="search-example" onClick="Paperpile.main.setSearchQuery(this.innerHTML);"><b>title:</b>microRNA <b>journal:</b>Cell <b>year:</b>2000-2010</a></li>',
      //'  </ul>',
      '</div>'];
    return new Ext.XTemplate(markup).compile();
  }

});