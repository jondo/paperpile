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

Paperpile.Tabs = Ext.extend(Ext.TabPanel, {
  initComponent: function() {

    Ext.apply(this, {
      id: 'pp-tabs',
      //margins: '2 2 2 2',
      layoutOnCardChange: true,
      layoutOnTabChange: true,
      monitorResize: false
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

        if (tab instanceof Paperpile.PluginPanel) {
          tab.restoreScrollState();
        }
      }
    },
    this);
  },

  closeTabByTitle: function(title) {
    var tabs = this.items.items;
    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      if (tab.title == title) {
        this.remove(tab);
      }
    }
  },

  newDBtab: function(query, itemId) {
    if (this.findAndActivateOpenTabByItemId(itemId)) {
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
    if (this.findAndActivateOpenTabByItemId(trashItemId)) {
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

  // If itemId is given it is checked if the same tab already is
  // open and it activated instead of creating a new one
  newPluginTab: function(name, pars, title, iconCls, itemId) {
    var javascript_ui = pars.plugin_name || name;
    if (pars.plugin_query != null && pars.plugin_query.indexOf('folder:') > -1) {
      javascript_ui = "Folder";
    }

    //var newGrid=new Paperpile['Plugin'+javascript_ui](pars);
    if (this.findAndActivateOpenTabByItemId(itemId)) {
      return;
    }
    var viewParams = {
      title: title,
      iconCls: iconCls,
      gridParams: pars,
      closable: true,
      itemId: itemId
    };
    if (iconCls) viewParams.iconCls = iconCls;
    if (title) viewParams.title = title;
    var newView = this.add(new Paperpile['PluginPanel' + javascript_ui](viewParams));
    newView.show();
  },

  // Opens a new tab with some specialized screen. Name is either the name of a preconficured panel-class, or
  // an object specifying url and title of the tab.
  newScreenTab: function(name, itemId) {
    if (this.findAndActivateOpenTabByItemId(itemId)) {
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
    if (this.findAndActivateOpenTabByItemId('queue-tab')) {
      return;
    }

    var panel = Paperpile.main.tabs.add(new Paperpile.QueuePanel({
      itemId: 'queue-tab'
    }));

    panel.show();
    var qs = Ext.StoreMgr.lookup('queue_store');
    if (qs != null) {
      qs.reload();
    }
  },

  findAndActivateOpenTabByItemId: function(itemId) {
    var openTab = this.getItem(itemId);
    if (openTab) {
      this.activate(openTab);
      return openTab;
    }
    return null;
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

    var panel = Paperpile.main.tabs.add(new Paperpile.PDFviewer(params));
    panel.show();
  }
}

);

Ext.reg('tabs', Paperpile.Tabs);