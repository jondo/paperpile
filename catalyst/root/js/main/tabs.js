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

Paperpile.Tabs = Ext.extend(Ext.TabPanel, {
  initComponent: function() {

    Ext.apply(this, {
      id: 'pp-tabs',
      //margins: '2 2 2 2',
      layoutOnCardChange: true,
      layoutOnTabChange: true,
      monitorResize: false,
      enableTabScroll: true
    });

    Paperpile.Tabs.superclass.initComponent.call(this);

    this.on('beforetabchange', function(tabs, newTab, oldTab) {
      if (oldTab instanceof Paperpile.PluginPanel) {
        oldTab.saveScrollState();
      }
    },
    this);

    this.on('tabchange', function(tabs, tab) {
      // Force the grid view to re-layout on tab change. Fixes a weird bug
      // where grids re-loaded in the background lose their DOM.
      if (tab instanceof Paperpile.PluginPanel) {

        var grid = tab.getGrid();
        grid.view.layout();

	// This can't have a delay on it -- we need to focus completely before
	// restoring the scroll state.
        grid.getView().focusEl.focus();

	// This needs to come last.
        tab.restoreScrollState();
      }
    },
    this);
  },

  closeTabById: function(guid) {
    var tabs = this.items.items;
    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      if (tab.itemId == guid) {
        this.remove(tab, true);
      }
    }
  },

  closeTabByTitle: function(title) {
    var tabs = this.items.items;
    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      if (tab.title == title) {
        this.remove(tab, true);
      }
    }
  },

  newDBtab: function(query, itemId) {
    if (this.findAndActivateOpenTab(itemId)) {
      return;
    }

    var gridParams = {
      plugin_name: 'DB',
      plugin_mode: 'FULLTEXT',
      plugin_query: query,
      plugin_base_query: ''
    };

    var newView = this.add(new Paperpile.PluginPanelDB({
      title: 'All Papers',
      iconCls: 'pp-icon-page',
      itemId: itemId,
      gridParams: gridParams
    }));
    newView.show();
  },

  newTrashTab: function() {
    var trashItemId = 'trash';
    if (this.findAndActivateOpenTab(trashItemId)) {
      return;
    }

    var gridParams = {
      plugin_name: 'Trash',
      plugin_mode: 'FULLTEXT',
      plugin_query: '',
      plugin_base_query: ''
    };

    var newView = this.add(new Paperpile.PluginPanelTrash({
      gridParams: gridParams,
      title: 'Trash',
      closable: true,
      itemId: trashItemId
    }));
    newView.show();
  },

  newCollectionTab: function(node, type) {

    var javascript_ui;
    var iconCls;
    if (type == 'FOLDER') {
      iconCls = 'pp-icon-folder';
      javascript_ui = 'Folder';
    } else {
      iconCls = 'pp-label-style-tab ' + 'pp-label-style-' + node.style;
      javascript_ui = 'Label';
    }

    this.newPluginTab(node.plugin_name, node, node.display_name, iconCls, node.id);
  },

  // If itemId is given it is checked if the same tab already is
  // open and it activated instead of creating a new one
  newPluginTab: function(name, origPars, title, iconCls, itemId) {
    var pars = {};
    for (var key in origPars) {
      if (key.match('plugin_')) {
        pars[key] = origPars[key];
      }
    }

    var plugin_name = pars.plugin_name || name;
    if (pars.plugin_query != null && pars.plugin_query.indexOf('folderid:') > -1) {
      plugin_name = "Folder";
    }
    if (pars.plugin_query != null && pars.plugin_query.indexOf('labelid:') > -1) {
      plugin_name = "Label";
    }

    var found_existing = false;
    if (this.isUniqueByItemId(plugin_name)) {
      found_existing = this.findAndActivateOpenTab(itemId);
    } else {
      found_existing = this.findAndActivateOpenTab(plugin_name);
    }
    if (found_existing) {
      return;
    }

    var viewParams = {
      plugin_name: plugin_name,
      title: title,
      iconCls: iconCls ? iconCls : pars.plugin_iconCls,
      gridParams: pars,
      closable: true,
      itemId: itemId
    };

    if (this.isMultiInstancePlugin(plugin_name) && !this.isUniqueByItemId()) {
      delete viewParams.itemId;
    }

    var newView = this.add(new Paperpile['PluginPanel' + plugin_name](viewParams));
    newView.show();
  },

  // Opens a new tab with some specialized screen. Name is either the name of a preconficured panel-class, or
  // an object specifying url and title of the tab.
  newScreenTab: function(name, itemId) {
    if (this.findAndActivateOpenTab(itemId)) {
      return;
    }

    var panel;

    // Pre-configured class
    if (Paperpile[name]) {
      panel = Paperpile.main.tabs.add(new Paperpile[name]({
        itemId: itemId
      }));

      // Generic panel
    } else {

      panel = Paperpile.main.tabs.add(new Ext.Panel({
        closable: true,
        autoLoad: {
          url: Paperpile.Url(name.url),
          callback: this.setupFields,
          scope: this
        },
        autoScroll: true,
        title: name.title,
        iconCls: name.iconCls ? name.iconCls : ''
      }));
    }
    panel.show();
  },

  showQueueTab: function() {
    if (this.findAndActivateOpenTab('queue-tab')) {
      return;
    }

    var panel = Paperpile.main.tabs.add(new Paperpile.QueuePanel({
      itemId: 'queue-tab'
    }));

    panel.show();
  },

  isUniqueByItemId: function(plugin_name) {
    return (plugin_name == 'Label' || plugin_name == 'Folder' || plugin_name == 'Feed');
  },

  isMultiInstancePlugin: function(plugin_name) {
    var multiInstancePlugins = {
      PubMed: true,
      GoogleScholar: true,
      ArXiV: true,
      GoogleBooks: true,
      JSTOR: true,
      SpringerLink: true,
      ACM: true
    };
    if (multiInstancePlugins[plugin_name] === true) {
      return true;
    } else {
      return false;
    }
  },

  findAndActivateOpenTab: function(itemId) {
    var openTab = this.getItem(itemId);

    if (!openTab) {
      // Didn't find by itemId -- search by plugin_name instead.
      var plugin_name = itemId;
      var tabs = this.items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (tab.plugin_name === itemId) {
          openTab = tab;
          break;
        }
      }
    }

    if (openTab && openTab.plugin_name) {
      // We've found a matching plugin -- if it's allowed to be multi-instance, return false
      // to indicate that the caller should be allowed to create a new tab.
      if (this.isMultiInstancePlugin(openTab.plugin_name)) {
        return false;
      }
    }

    if (openTab) {
      this.activate(openTab);
      return true;
    }
    return false;
  },

  findOpenPdfByFile: function(file) {
    var tabs = Paperpile.main.tabs.items.items;
    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      if (tab instanceof Paperpile.PDFviewer) {
        if (tab.file == file) return tab;
      }
    }
    return null;
  },

  pdfViewerCounter: 0,
  newPdfTab: function(config) {
    this.pdfViewerCounter++;
    var params = {
      id: 'pdf_viewer_' + this.pdfViewerCounter,
      region: 'center',
      search: '',
      zoom: 'width',
      columns: 1,
      pageLayout: 'flow',
      closable: true,
      iconCls: 'pp-icon-import-pdf'
    };

    Ext.apply(params, config);

    // Look for a tab already open with this filename.
    var existingTab = this.findOpenPdfByFile(params.file);
    if (existingTab != null) {
      this.activate(existingTab);
      return;
    }

//    var panel = Paperpile.main.tabs.add(new Paperpile.PDFPanel(params));
    var panel = Paperpile.main.tabs.add(new Paperpile.PDFviewer(params));
    panel.show();
  }
}

);

Ext.reg('tabs', Paperpile.Tabs);