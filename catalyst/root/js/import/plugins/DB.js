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

Ext.define('Paperpile.PluginGridDB', {
	extend: 'Paperpile.PluginGrid',
  plugin_base_query: '',
  plugin_iconCls: 'pp-icon-folder',
  plugin_name: 'DB',

  plugins: [],

  initComponent: function() {

    Paperpile.PluginGridDB.superclass.initComponent.call(this);

    // Replace the 'handleHdOver' with an empty function to remove the 
    // build-in header highlighting.
    var view = this.getView();
    view.handleHdOver = Ext.emptyFn;

    this.limit = Paperpile.main.globalSettings['pager_limit'] || 25;

    var store = this.getStore();

    store.load({
      params: {
        start: 0,
        limit: this.limit
      }
    });
  },

  loadKeyboardShortcuts: function() {
    Paperpile.PluginGridDB.superclass.loadKeyboardShortcuts.call(this);
  },

  toggleFilter: function(item, checked) {

    var filter_button = this.filterButton;

    // Toggle 'search_pdf' option 
    this.getStore().baseParams['plugin_search_pdf'] = 1;

    // Specific fields
    if (item.itemId != 'all') {
      if (checked) {
        this.filterField.singleField = item.itemId;
        this.getStore().baseParams['plugin_search_pdf'] = 0;
      } else {
        if (this.filterField.singleField == item.itemId) {
          this.filterField.singleField = "";
        }
      }
    }

    if (!filter_button.oldIcon) {
      filter_button.useSetClass = false;
      filter_button.oldIcon = filter_button.icon;
    }

    if (checked) {
      if (item.itemId == 'all') {
        delete filter_button.minWidth;
        filter_button.setText(null);
        filter_button.setIcon(filter_button.oldIcon);
        filter_button.el.addClass('x-btn-icon');
        filter_button.el.removeClass('x-btn-noicon');
      } else {
        delete filter_button.minWidth;
        filter_button.setIcon(null);
        filter_button.setText(item.text);
        filter_button.el.addClass('x-btn-noicon');
        filter_button.el.removeClass('x-btn-icon');
      }
      this.filterField.onTrigger2Click();
    }

  },

  setSearchQuery: function(text) {
    this.filterField.setValue(text);
    this.filterField.onTrigger2Click();
  },

  createContextMenu: function() {
    Paperpile.PluginGridDB.superclass.createContextMenu.call(this);
  },

  createToolbarMenu: function() {
	    /*
    this.filterMenu = new Ext.menu.Menu({
      defaults: {
        checked: false,
        group: 'filter' + this.id,
        checkHandler: this.toggleFilter,
        scope: this
      },
      items: [{
        text: 'All fields',
        itemId: 'all'
      },
        {
          text: 'Author',
          itemId: 'author'
        },
        {
          text: 'Title',
          itemId: 'title'
        },
        {
          text: 'Journal',
          itemId: 'journal'
        },
        {
          text: 'Abstract',
          itemId: 'abstract'
        },
        {
          text: 'Fulltext',
          itemId: 'text'
        },
        {
          text: 'Notes',
          itemId: 'notes'
        },
        {
          text: 'Year',
          itemId: 'year'
        }]
    });

    this.actions['FILTER_BUTTON'] = new Ext.Button({
      itemId: 'FILTER_BUTTON',
      icon: '/images/icons/magnifier.png',
      tooltip: 'Choose field(s) to search',
      menu: this.filterMenu
    });
    this.filterButton = this.actions['FILTER_BUTTON'];
    this.actions['FILTER_FIELD'] = new Ext.app.FilterField({
      itemId: 'FILTER_FIELD',
      emptyText: 'Search References',
      store: this.getStore(),
      base_query: this.plugin_base_query,
      width: 200
    });
    this.filterField = this.actions['FILTER_FIELD'];

    this.mon(this.filterField, 'specialkey', function(f, e) {
      if (e.getKey() == e.ENTER) {
        // Select the first grid row on Enter.
        this.getSelectionModel().selectRowAndSetCursor(0);
      }
    },
    this);
    */
    Paperpile.PluginGridDB.superclass.createToolbarMenu.call(this);
  },

  refreshCollections: function() {
    Paperpile.PluginGridDB.superclass.refreshCollections.call(this);

  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridDB.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;

    ids.insert(0, 'FILTER_FIELD');
    ids.insert(1, 'FILTER_BUTTON');

    index = ids.indexOf('SELECT_ALL');
    ids.insert(index + 0, 'EDIT');
    //    ids.insert(index + 1, 'EDIT');
  },

  isContextItem: function(item) {
    if (item.ownerCt.itemId == 'context') {
      return true;
    }
    return false;
  },
  isToolbarItem: function(item) {
    return true;
  },

  updateButtons: function() {
    Paperpile.PluginGridDB.superclass.updateButtons.call(this);

    var tbar = this.getTopToolbar();

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

  onUpdate: function(data) {
    Paperpile.PluginGridDB.superclass.onUpdate.call(this, data);

    // If the update has to do with collections and we are 
    // a collection tab, refresh the whole view.
    if (this.collection_type) {
      if (data.collection_delta) {
        this.getStore().reload();
      }
    }
  },

  showEmptyMessageBeforeStoreLoaded: function() {
    return false;
  },

  getEmptyBeforeSearchTemplate: function() {

    var markup = '<div class="pp-hint-box"><p>No results to show. <a href="#" class="pp-textlink" action="close-tab">Close tab</a>.</p></div>';

    // If tab is not filtered and still empty, the whole DB must be empty and we show welcome message
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


Ext.define('Paperpile.PluginPanelDB', {
	extend: 'Paperpile.PluginPanel',
  createGrid: function(params) {
    return new Paperpile.PluginGridDB(params);
  },

  createAboutPanel: function() {
    return undefined;
  }

});