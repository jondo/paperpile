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

Ext.define('Paperpile.pub.GridDB', {
  extend: 'Paperpile.pub.Grid',
  alias: 'widget.pubGridDB',
  plugin_base_query: '',
  plugin_iconCls: 'pp-icon-folder',
  plugin_name: 'DB',

  plugins: [],

  initComponent: function() {

    this.filterField = Ext.createByAlias('widget.filterfield', {
      itemId: 'FILTER_FIELD',
      emptyText: 'Search References',
      store: this.getStore(),
      base_query: this.plugin_base_query,
      hideLabel: true,
      width: 200
    });

    this.callParent(arguments);

    // Replace the 'handleHdOver' with an empty function to remove the 
    // build-in header highlighting.
    var view = this.getView();

    this.initialLoad();
  },

  loadKeyboardShortcuts: function() {
    this.callParent(arguments);
  },

  setSearchQuery: function(text) {
    this.filterField.setValue(text);
    this.filterField.onTrigger2Click();
  },

  createContextMenu: function() {
    this.callParent(arguments);
  },

  createToolbar: function() {
    var toolbar = this.callParent(arguments);

    toolbar.insert(0, this.filterField);
    toolbar.insert(1, '->');

    // Do some other stuff.
    return toolbar;
  },

  refreshCollections: function() {
    this.callParent(arguments);

  },

  updateButtons: function() {
    this.callParent(arguments);

    var tbar = this.getToolbar();
    var selectionCount = this.getSelectionModel().getCount();
    if (selectionCount > 1) {
      var item = tbar.getComponent('EDIT');
      if (item) {
        item.disable();
      }
      item = tbar.getComponent('VIEW_PDF');
      if (item) {
        item.disable();
      }
    }
  },

  showEmptyMessageBeforeStoreLoaded: function() {
    return false;
  },

  getEmptyBeforeSearchTemplate: function() {

    var markup = '<div class="pp-hint-box"><p>No results to show. <a href="#" class="pp-textlink" action="close-tab">Close tab</a>.</p></div>';

    // If tab is not filtered and still empty, the whole DB must be empty and we show welcome messae
    if (this.plugin_query == '' && this.plugin_base_query == '') {
      markup = [
        '<div class="pp-hint-box">',
        '<h1>Welcome to Paperpile</h1>',
        '<p>Your library is still empty. </p>',
        '<p>To get started, </p>',
        '<ul>',
        '<li>import your <a href="#" class="pp-textlink" onClick="Paperpile.main.pdfExtract();">PDF collection</a></li>',
        '<li>get references from a <a href="#" class="pp-textlink" onClick="Paperpile.main.fileImport();">bibliography file</a></li>',
        '<li>search for papers using ',
        '<a href="#" class="pp-textlink" onClick=',
        '"Paperpile.main.tabs.newPluginTab(\'PubMed\', {plugin_name: \'PubMed\', plugin_query:\'\'});">PubMed</a> or ',
        '<a href="#" class="pp-textlink" onClick=',
        '"Paperpile.main.tabs.newPluginTab(\'GoogleScholar\', {plugin_name: \'GoogleScholar\', plugin_query:\'\'});">Google Scholar</a></li>',
        '</ul>',
        '</div>'];
    }

    return new Ext.XTemplate(markup).compile();
  }
});

Ext.define('Paperpile.pub.ViewDB', {
  extend: 'Paperpile.pub.View',
  createGrid: function(params) {
    return new Paperpile.pub.GridDB(params);
  },

  createAboutPanel: function() {
    return undefined;
  }

});