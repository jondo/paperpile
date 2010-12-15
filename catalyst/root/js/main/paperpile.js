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

IS_QT = !(window['QRuntime'] == undefined);
IS_CHROME = navigator.userAgent.toLowerCase().indexOf('chrome') > -1;

Ext.BLANK_IMAGE_URL = 'ext/resources/images/default/s.gif';

Ext.ns('Paperpile');

Paperpile.Url = function(url) {
  if (url.match("127.0.0.1")) {
    return url;
  }
  return (IS_QT) ? 'http://127.0.0.1:3210' + url : url;
};

Paperpile.log = function() {
  if (IS_QT) {
    QRuntime.log(obj2str(arguments[0]));
  } else if (IS_CHROME) {
    console.log(arguments[0]);
  } else if (window.console) {
    console.log(arguments);
  }
};

function obj2str(o) {
  if (typeof o !== 'object') {
    return o;
  }
  var out = '{';
  for (var p in o) {
    if (!o.hasOwnProperty(p)) {
      continue;
    }
    out += '\n ';
    out += p + ': ' + o[p];
  }
  out += '\n}';
  return out;
}

// This is a wrapper around the Ext.Ajax.request function call.
// If we need to add any global behavior to Ajax calls, put it
// here.
Paperpile.Ajax = function(config) {

  // A method which will run *before* the success function defined
  // by the passed config.
  var success = function(response) {
    var json = Ext.util.JSON.decode(response.responseText);
    if (json.data) {
      Paperpile.main.onUpdate(json.data);
    }
    if (json.callback) {
      Paperpile.main.onCallback(json.callback);
    }
  };

  var failure = function() {
    Paperpile.log("Ajax call failed.");
  };
  if (Paperpile.main != undefined) {
    failure = Paperpile.main.onError;
  }

  if (!config.suppressDefaults) {

    if (config.success) {
      config.success = config.success.createInterceptor(success);
    } else {
      config.success = success;
    }
    if (config.failure) {
      config.failure = config.failure.createInterceptor(failure);
    } else {
      config.failure = failure;
    }
  }

  config.url = Paperpile.Url(config.url);

  config.xdomain = true;

  if (!config.method) {
    config.method = 'GET';
  }

  if (!config.scope) {
    config.scope = Paperpile.main;
  }

  if (config.debug) {
    Paperpile.log(config);
  }

  return Ext.Ajax.request(config);
};

Paperpile.Viewport = Ext.extend(Ext.Viewport, {

  globalSettings: {},
  splitFraction: 1 / 5,

  initComponent: function() {

    this.tabs = new Paperpile.Tabs({
      border: false,
      region: 'center',
      xtype: 'tabs',
      id: 'pp-tabs',
      activeItem: 0
    });

    this.tree = new Paperpile.Tree({
      xtype: 'pp-tree',
      rootVisible: false,
      id: 'treepanel',
      itemId: 'treepanel',
      region: 'west',
    });

    this.queueWidget = new Paperpile.QueueWidget();

    this.tree.flex = 1;
    this.tabs.flex = 3;

    Ext.apply(this, {
      layout: 'border',
      border: false,
      enableKeyEvents: true,
      keys: {},
      plugins: [new Ext.ux.PanelSplit(this.tree, this.updateSplitFraction, this)],
      items: [{
        xtype: 'panel',
        layout: 'hbox',
        layoutConfig: {
          align: 'stretch'
        },
        region: 'center',
        tbar: new Ext.Toolbar({
          id: 'main-toolbar',
          cls: 'pp-main-toolbar',
          items: [
            new Ext.BoxComponent({
              autoEl: {
                cls: 'pp-main-toolbar-label',
                tag: 'div',
                id: 'version-tag'
              }
            }), {
              xtype: 'tbfill'
            },
	    this.queueWidget,
	    new Ext.BoxComponent({
              autoEl: {
                tag: 'a',
                href: '#',
                html: '<div class="pp-dashboard-button"></div>'
              },
              id: 'dashboard-button'
            })]
        }),
        items: [this.tree,
          this.tabs]
      }]
    });

    Paperpile.Viewport.superclass.initComponent.call(this);

    this.on('afterlayout', this.resizeToSplitFraction, this);

    this.mon(Ext.getBody(), 'click', function(event, target, options) {
      if (target.href) {
        if (!target.href.match(/(app|paperpile|localhost)/i)) {
          event.stopEvent();
          Paperpile.utils.openURL(target.href);
        }
      }
    });

    this.dd = new Paperpile.DragDropManager();
    this.dd.initListeners();

    this.labelStore = new Paperpile.CollectionStore({
      collectionType: 'LABEL',
      listeners: {
        load: {
          fn: this.onLabelStoreLoad,
          scope: this
        }
      },
      storeId: 'label_store'
    });


    this.folderStore = new Paperpile.CollectionStore({
      collectionType: 'FOLDER',
      listeners: {
        load: {
          fn: this.onFolderStoreLoad,
          scope: this
        }
      },
      storeId: 'folder_store'
    });


    this.runningJobs = [];
    this.loadKeys();

    this.fileSyncStatus = {
      busy: false,
      collections: [],
      task: new Ext.util.DelayedTask(this.fireFileSync, this)
    };

    // Used in startup sequence
    this.addEvents({'mainGridLoaded':true});

  },

  getZoom: function() {
    return parseFloat(Ext.getBody().getStyle('zoom'));
  },

  updateSplitFraction: function(newFraction) {
    this.splitFraction = newFraction;
    Paperpile.main.setSetting('split_fraction_tree', this.splitFraction, true);
    this.resizeToSplitFraction();
  },

  resizeToSplitFraction: function() {
    var fraction = this.splitFraction; // Fraction of left to right panel.
    if (Paperpile.main) {
      var set_fraction = Paperpile.main.getSetting('split_fraction_tree');
      if (set_fraction) {
        fraction = set_fraction;
      }
    }

    var width = this.getWidth();
    var w1 = width * (fraction); // tree width
    var w2 = width * (1 - fraction); // panel width
    // Minimum tree width.
    var min1 = 200;
    // Minimum panel width.
    var min2 = 550;
    // Maximum tree width.
    var max1 = 270;
    // Maximum panel width.
    var max2 = 9999;

    // Respect max sizes
    if (w1 > max1) {
      w1 = max1;
      w2 = width - max1;
    }
    if (w2 > max2) {
      w2 = max2;
      w1 = width - max2;
    }

    // Respect minimum sizes.
    if (w2 < min2) {
      w2 = min2;
      w1 = width - min2;
    }
    // Top priority -- keep tree above min size!
    if (w1 < min1) {
      w1 = min1;
      w2 = width - min1;
    }

    this.tree.setWidth(w1);
    this.tabs.setWidth(w2);
    this.tree.setPosition(0, 0);
    this.tabs.setPosition(w1, 0);
  },

  onZoomChange: function(zoomLevel) {
    var oldZoomLevel = this.getZoom();

    if (oldZoomLevel == zoomLevel) {
      return;
    }
    var zoomRatio = zoomLevel / oldZoomLevel;

    Ext.getBody().setStyle('zoom', zoomLevel);
    // Now resize the body element.
    this.resizeWithZoom(this.getWidth(), this.getHeight());
  },

  resizeWithZoom: function(w, h) {
    var item = this.items.get(0);
    var zoom = Ext.getBody().getStyle('zoom');
    item.setSize(w / zoom, h / zoom);
  },

  fireResize: function(w, h) {
    Paperpile.Viewport.superclass.fireResize.call(this, w, h);
    this.resizeWithZoom(w, h);
  },

  afterLoadSettings: function() {

    this.resizeToSplitFraction();

    var grid = this.getCurrentGrid();
    if (grid) {
      grid.getPluginPanel().resizeToSplitFraction();
    }

    /*
    var zoom = this.getSetting('zoom_level');
	if (zoom === undefined) {
	  zoom = 1
	}
	zoom = zoom.replace("%","");
	if (zoom > 2) {
	  zoom = zoom / 100;
	}
	this.onZoomChange(zoom);
*/
  },

  loadKeys: function() {

    // Borrowed from Window.js
    this.focusEl = this.el.createChild({
      tag: 'a',
      href: '#',
      cls: 'pp-focus',
      tabIndex: '1',
      html: '&#160;'
    });

    // This will hold keyboard shortcuts that should only be active when nothing else has
    // keyboard focus. Mostly for forwarding stuff on to the currently active grid.
    this.sometimesKeys = new Ext.ux.KeyboardShortcuts(this.focusEl, {
      disableOnBlur: true
    });

    // Hold keyboard shortcuts that are *always* active. Mostly for closing / switching tabs.
    this.alwaysKeys = new Ext.ux.KeyboardShortcuts(this.el, {
      disableOnBlur: false
    });

    var keys = ['ctrl-a', 'ctrl-c', 'ctrl-b', 'ctrl-k', 'n', 'p', 'shift-n', 'shift-p', 'j', 'k', 'shift-j', 'shift-k', '[End,35]', '[Home,36]', '[Del,46]', '[Del,8]', '[/,191]', 'ctrl-f'];
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      this.sometimesKeys.bindCallback(key, this.forwardToGrid, this);
    }

    this.sometimesKeys.bindCallback('ctrl-r', this.keyControlR, this);

    this.alwaysKeys.bindCallback('ctrl-x', this.keyControlX, this);
    this.alwaysKeys.bindCallback('ctrl-y', this.keyControlY, this);
    this.alwaysKeys.bindCallback('ctrl-tab', this.keyControlTab, this);
    this.alwaysKeys.bindCallback('ctrl-w', this.keyControlW);
    this.alwaysKeys.bindCallback('shift-[?,191]', this.keys.showKeyHelp);

  },

  keyControlX: function() {
    var itemId = 'pp-dash';
    for (var i = 0; i < 3; i++) {
      this.tabs.newScreenTab('Dashboard', itemId);
    }
  },

  grabFocus: function() {
    this.focusEl.focus(10);
  },

  keyQuesionMark: function() {
    //Paperpile.log("What's your problem?");
  },

  forwardToGrid: function(e) {
    if (this.getCurrentGrid()) {
      this.getCurrentGrid().keys.keyMap.handleKeyDown(e);
    }
  },

  keyControlY: function() {
    Paperpile.main.tabs.newScreenTab('CatalystLog', 'catalyst-log');
  },

  keyControlR: function() {
    if (this.getCurrentGrid()) {
      this.getCurrentGrid().getStore().reload();
    }
  },

  keyControlC: function() {
    if (this.getCurrentGrid()) {
      this.getCurrentGrid().handleCopyFormatted();
    }
  },

  keyControlShiftK: function() {
    var tab = Paperpile.main.tabs.getActiveTab();
    var grid = tab.getGrid();
    grid.handleCopyBibtexKey();
  },

  keyControlShiftB: function() {
    var tab = Paperpile.main.tabs.getActiveTab();
    var grid = tab.getGrid();
    grid.handleCopyBibtexCitation();
  },

  keyControlA: function() {
    var tab = Paperpile.main.tabs.getActiveTab();
    var grid = tab.getGrid();
    grid.selectAll();
  },

  keyControlTab: function() {
    var tabs = Paperpile.main.tabs;
    var items = tabs.items;
    var currentTabIndex = items.indexOf(tabs.getActiveTab());

    if (currentTabIndex == items.getCount() - 1) {
      tabs.setActiveTab(0);
    } else {
      tabs.setActiveTab(currentTabIndex + 1);
    }
  },

  keyControlW: function() {
    var curTab = Paperpile.main.tabs.getActiveTab();
    if (curTab.closable) {
      Paperpile.main.tabs.remove(curTab, true);
    }
  },

  removeFromFolder: function(sel, grid, guid, callback) {
    this.removeFromCollection(sel, grid, guid, 'FOLDER', callback);
  },
  removeFromLabel: function(sel, grid, guid, callback) {
    this.removeFromCollection(sel, grid, guid, 'LABEL', callback);
  },

  // sel = 'ALL' or guids of selected pubs.
  removeFromCollection: function(sel, grid, guid, type, callback) {
    Paperpile.Ajax({
      url: '/ajax/crud/remove_from_collection',
      params: {
        selection: sel,
        grid_id: grid.id,
        collection_guid: guid,
        type: type
      },
      success: function(response) {
        if (callback) {
          callback.call(grid);
        }
      },
      scope: this
    });

  },

  getSetting: function(key) {
    return this.globalSettings[key];
  },

  setSettings: function(settings, commitToBackend) {
    for (key in settings) {
      this.setSetting(key, settings[key], commitToBackend);
    }
  },

  setSetting: function(key, value, commitToBackend) {
    if (commitToBackend === undefined) {
      commitToBackend = true;
    }
    this.globalSettings[key] = value;

    var s = {};
    s[key] = Ext.util.JSON.encode(value);

    if (commitToBackend) {
      this.storeSettings(s);
    }
  },

  storeSettings: function(newSettings, callback, scope) {
    Paperpile.Ajax({
      url: '/ajax/settings/set_settings',
      params: newSettings,
      success: function(response) {
        if (callback) {
          callback.createDelegate(scope)();
        }
      },
      scope: this
    });
  },

  loadSettings: function(callback, scope) {
    Paperpile.Ajax({
      url: '/ajax/misc/get_settings',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        this.globalSettings = json.data;
        if (callback) {
          callback.createDelegate(scope)();
        }
      },
      scope: this
    });
  },

  onPDFtabToggle: function(button, pressed) {

    if (button.id == 'pdf_manager_tab_button' && pressed) {
      this.canvas_panel.getLayout().setActiveItem('pdf_manager');
    }

    if (button.id == 'pdf_view_tab_button' && pressed) {
      this.canvas_panel.getLayout().setActiveItem('pdf_viewer');
    }
  },

  openPdfInExternalViewer: function(filename, data) {
    var path = filename;

    // If it is an absolute path it is the temporary copy in the tmp
    // folder, otherwise it is stored under the paper_root folder and
    // we need to append the paper_root
    if (!Paperpile.utils.isAbsolute(path)) {
      path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, path);
    }

    Paperpile.utils.openFile(path);
    if (data !== null) {
      Paperpile.main.inc_read_counter(data);
    }
  },

  getTree: function() {
    return this.tree;
  },

  getTabs: function() {
    return this.tabs;
  },

  getCurrentGrid: function() {
    var activeTab = Paperpile.main.tabs.getActiveTab();
    if (activeTab instanceof Paperpile.PluginPanel) {
      return activeTab.getGrid();
    }
    return null;
  },

  getMainLibraryGrid: function() {
    var mainTab = this.tabs.getMainLibraryTab();
    return mainTab.getGrid();
  },

  getCurrentlySelectedRow: function() {
    var activeTab = Paperpile.main.tabs.getActiveTab();
    if (activeTab instanceof Paperpile.PluginPanel) {
      var grid = activeTab.getGrid();
      if (grid.getSelectionCount() == 1) {
        return grid.getSingleSelectionRecord();
      }
    }
    return null;
  },

  showReferenceInLibrary: function(record) {
    var grid;
    if (record.data.trashed) {
      this.tabs.showTrashTab();
      grid = this.tabs.getItem('trash').getGrid();
    } else {
      // Activate the library tab.
      this.tabs.showMainLibraryTab();
    
      // Get the library grid and set the query.
      grid = this.getMainLibraryGrid();
    }
    grid.setSearchQuery('key:'+record.data.citekey);
    var selectSet = function() {
      this.getSelectionModel().selectRowAndSetCursor(0);
    };
    grid.doAfterNextReload.push(selectSet);
  },

  folderExtract: function() {
    var callback = function(filenames) {
      if (filenames.length > 0) {
        var folder = filenames[0];
        Paperpile.main.countFilesAndTriggerExtraction(folder);
      }
      this.pdfExtractChoice.close();
      this.pdfExtractChoice = undefined;
    };
    var options = {
      title: 'Choose a folder containing PDFs to import',
      dialogType: 'load',
      selectionType: 'folder',
      scope: this
    };
    Paperpile.fileDialog(callback, options);
  },

  fileExtract: function() {
    var callback = function(filenames) {
      if (filenames.length > 0) {
        for (var i = 0; i < filenames.length; i++) {
          var file = filenames[i];
          Paperpile.main.submitPdfExtractionJobs(file);
        }
      }
      this.pdfExtractChoice.close();
      this.pdfExtractChoice = undefined;
    };
    var options = {
      title: 'Choose PDF file(s) to import',
      selectionType: 'file',
      types: ['pdf'],
      multiple: true,
      typesDescription: 'PDF Files',
      nameFilters: ["PDF (*.pdf)"],
      scope: this
    };
    Paperpile.fileDialog(callback, options);
  },

  pdfExtract: function() {

    var divDef = '<div style="width:200px;white-space:normal;">';
    var justCreated = false;
    if (!this.pdfExtractChoice) {
      justCreated = true;
      this.pdfExtractChoice = new Ext.Window({
        title: 'Choose type of PDF import',
        closeAction: 'hide',
        layout: 'vbox',
        bodyStyle: 'background-color:#FFFFFF !important;',
        width: 220,
        height: 175,
        plain: true,
        modal: true,
        buttonAlign: 'center',
        layoutConfig: {
          align: 'center',
          defaultMargins: '5px'
        },
        items: [{
          xtype: 'label',
          text: ' ',
          height: 5
        },
        {
          xtype: 'subtlebutton',
          id: 'folder_extract_button',
          text: 'PDF Folder',
          tooltip: 'The selected folder and its subdirectories will be searched for PDFs to import',
          align: 'center',
          width: 150,
          height: 30,
          handler: this.folderExtract,
          scope: this
        },
        {
          xtype: 'label',
          text: 'or'
        },
        {
          width: 150,
          height: 30,
          id: 'file_extract_button',
          xtype: 'subtlebutton',
          text: 'PDF File(s)',
          tooltip: 'Select one or more files to import.',
          handler: this.fileExtract,
          scope: this
        },
        {
          xtype: 'textbutton',
          text: 'Cancel',
          itemId: 'cancel_button',
          style: {
            position: 'absolute',
            top: '0px',
            left: '0px'
          },
          handler: function() {
            this.pdfExtractChoice.close();
            this.pdfExtractChoice = undefined;
          },
          scope: this
        }]
      });

      this.pdfExtractChoice.on('show', function(window) {
        var b = window.get('cancel_button');
        b.getEl().alignTo(window.getEl(), 'br-br', [-10, -10]);
      });
    }

    this.pdfExtractChoice.show();

    /*
    if (justCreated) {
      var folderTip = new Ext.ToolTip({
        html: 'The selected folder and its subdirectories will be searched for PDFs to import',
        target: Ext.get('folder_extract_button').child('tbody')
      });
      Ext.getCmp('folder_extract_button').setTooltip(folderTip);

      var fileTip = new Ext.ToolTip({
        html: 'The selected folder and its subdirectories will be searched for PDFs to import',
        target: Ext.get('file_extract_button').child('tbody')
      });
      Ext.getCmp('file_extract_button').setTooltip(fileTip);
    }
*/
  },

  // Submit a PDF extraction job, optionally including the tree node
  // representing the target collection for import.
  submitPdfExtractionJobs: function(path, treeNode) {
    Paperpile.Ajax({
      url: '/ajax/pdfextract/submit',
      params: {
        path: path,
        collection_guids: [treeNode ? treeNode.id : null]
      }
    });
  },

  attachFile: function(grid, guid, path, isPDF) {
    Paperpile.Ajax({
      url: '/ajax/crud/attach_file',
      params: {
        guid: guid,
        grid_id: grid.id,
        file: path,
        is_pdf: (isPDF) ? 1 : 0
      },
      success: function(response) {
        // TODO: add a status message and an undo function.
      },
      scope: this
    });

  },

  countFilesAndTriggerExtraction: function(path) {
    // First count the PDFs
    Paperpile.Ajax({
      url: '/ajax/pdfextract/count_files',
      params: {
        path: path
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        // Show error message and stop if no PDFs found
        if (json.count == 0) {
          Paperpile.status.updateMsg({
            type: 'error',
            msg: 'No PDFs found in the selected folder.',
            hideOnClick: true
          });
          return;
        }
        // Warn user before large batch of PDFs is imported
        if (json.count > 10) {
          Ext.MessageBox.buttonText.ok = "Start import";

          Ext.Msg.show({
            title: 'PDF Import',
            msg: json.count + ' PDF files found. Do you want to import them now?',
            animEl: 'elId',
            icon: Ext.MessageBox.INFO,
            buttons: Ext.Msg.OKCANCEL,
            fn: function(btn) {
              if (btn === 'ok') {
                this.submitPdfExtractionJobs(path);
              }
              Ext.MessageBox.buttonText.ok = "Ok";
            },
            scope: this
          });
        } else {
          // Start import silently if less than 10 PDFs
          this.submitPdfExtractionJobs(path);
        }
      },
      scope: this
    });
  },

  createFileImportTab: function(filename) {
    var parts = Paperpile.utils.splitPath(filename);

    Paperpile.main.tabs.newPluginTab('File', {
      plugin_file: filename,
      plugin_name: 'File',
      plugin_mode: 'FULLTEXT',
      plugin_query: '',
      plugin_base_query: ''
    },
      parts.file, 'pp-icon-file');

  },

  fileImport: function() {
    var callback = function(filenames) {
      if (filenames.length > 0) {
        var path = filenames[0];
        this.createFileImportTab(path);
      }
    };

    var types = null;
    if (Paperpile.utils.get_platform() != 'osx') {
      types = ['*'];
    }

    var options = {
      title: 'Choose a bibliography file to import',
      types: ['*'],
      typesDescription: 'Bibliography files (BibTeX, RIS, EndNote, and others)',
      nameFilters: ["All supported files (*)",
        "BibTeX (*.bib)",
        "RIS (*.ris)",
        //"Endnote XML (*.xml)", //Backend does not work at the moment
        "ISI (*.isi)",
        "MODS (*.xml)",
        "RSS (*.xml)",
        "Zotero (*.sqlite)",
        "Mendeley (*.sqlite)"],
      scope: this
    };
    Paperpile.fileDialog(callback, options);
  },

  // Reloads DB grids upon insert/entries; it is possible to avoid
  // reload of a grid by passing the id via ignore
  getActiveView: function() {
    return Paperpile.main.tabs.getActiveTab();
  },

  getActiveGrid: function() {
    var panel = Paperpile.main.tabs.getActiveTab();
    var grid = panel.items.get('center_panel').items.get('grid');
    return grid;
  },

  setSearchQuery: function(text) {

    //Strip <b></b> tags that are used for clarity in some templates
    text = text.replace(/<\/?b>/g, '');

    var grid = this.getActiveGrid();
    grid.setSearchQuery(text);
  },

  isLabelTab: function(panel) {
    if (panel.gridParams === undefined) {
      return false;
    }
    var plugin_query = panel.gridParams.plugin_query;
    if (plugin_query && plugin_query.indexOf("label") != -1) {
      return true;
    } else {
      return false;
    }
  },

  // Go through all the grids and update specifically the single publication.
  // Requires each grid to have an "updateData" function.
  onUpdate: function(data) {
    if (data === undefined) return;

    // Update this part of the code when the new label widget is in
    // place. Right now the label list does not get updated. There
    // might be also a race condition when the labelStore response comas
    // after the subsequent grid updates. 
    if (data.collection_delta) {
      this.labelStore.reload();
    }

    this.queueWidget.onUpdate(data);
    if (data.job_delta) {
      this.queueUpdate();
    }

    if (this.tabs) {
      var tabs = this.tabs.items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (!tab['onUpdate']) continue;
        tab.onUpdate(data);
      }
    }

    // Even if the queue tab isn't showing, collect and dispatch callbacks.
    if (data.jobs) {
      this.doCallbacks(data);
    }

    // If the user is currently dragging, update the dragdrop targets.
    if (Paperpile.main.dd.dragPane && Paperpile.main.dd.dragPane.isVisible() && !Paperpile.main.dd.effectBlock) {
      Paperpile.main.dd.hideDragPane();
    }

    if (data.file_sync_delta) {
      if (data.file_sync_delta.length > 0 && this.bibtexModeIsEnabled()) {
        this.triggerFileSync(data.file_sync_delta);
      }
    }
  },

  handleExport: function(gridId, selection, sourceNode) {

    var callback = function(filenames, filter) {

      if (filenames.length == 0) {
        return;
      }

      var formatsMap = {
        'BibTeX (*.bib)': 'BIBTEX',
        'RIS (.ris)': 'RIS',
        'EndNote (.txt)': 'ENDNOTE',
        'MODS (.xml)': 'MODS',
        'ISI Web of Science (.isi)': 'ISI',
        'Word 2007 XML (.xml)': 'WORD2007'
      };

      var format = formatsMap[filter];

      var file = filenames[0];

      var collection_id = null;
      var node_id = null;
      var grid_id = null;
      if (sourceNode && (sourceNode.type == 'FOLDER' || sourceNode.type == 'LABEL')) {
	collection_id = sourceNode.id;
      } else if (sourceNode) {
	node_id = sourceNode.id;
      } else if (gridId) {
	grid_id = gridId;
      } else {
	return;
      }

      Paperpile.status.showBusy('Exporting to ' + file + '...');
      Paperpile.Ajax({
        url: Paperpile.Url('/ajax/plugins/export'),
        params: {
          source_node: node_id,
	  collection_id: collection_id,
          selection: selection,
          grid_id: grid_id,
          export_name: 'Bibfile',
          export_out_format: format,
          export_out_file: file
        },
        success: function() {
          Paperpile.status.clearMsg();
        },
        scope: this
      });
    };

    Paperpile.fileDialog(callback, {
      'title': 'Choose file and format for export',
      'dialogType': 'save',
      'selectionType': 'file',
      'nameFilters': ["BibTeX (*.bib)",
        'RIS (.ris)',
        'EndNote (.txt)',
        'MODS (.xml)',
        'ISI Web of Science (.isi)',
        'Word 2007 XML (.xml)']
    });
  },

  bibtexModeIsEnabled: function() {
    var bibtex = this.getSetting('bibtex');
    if (bibtex.bibtex_mode == 1) {
      return true;
    } else {
      return false;
    }
  },

  onCallback: function(callback) {
    Paperpile.log(callback);
  },

  // Trigger an update of file synchronization for a list of guids of
  // collections. The guids are queued in the global object
  // this.fileSyncStatus.collections. The actual update is fired after
  // 5 seconds without new collections added to the queue.
  triggerFileSync: function(collections) {

    // Call the function without collections to trigger a new file
    // sync for collections in the queue.
    if (!collections) {
      collections = [];
    }

    this.fileSyncStatus.collections = this.fileSyncStatus.collections.concat(collections);

    if (!this.fileSyncStatus.busy) {
      this.fileSyncStatus.task.delay(5000);
    }
  },

  // Start file sync for queued collections in the backend. Empties
  // the queue. If in the meantime new collections are added a new
  // update is triggered vie triggerFileSync
  fireFileSync: function() {

    // Don't fire anything if bibtex mode is off.
    var collections = this.fileSyncStatus.collections;
    for (var i = 0; i < collections.length; i++) {
      var guid = collections[i];
      var node = this.tree.getNodeById(guid);
      node.getUI().updateWorking('Syncing with external file');
    }

    Paperpile.Ajax({
      url: '/ajax/crud/sync_files',
      params: {
        collections: this.fileSyncStatus.collections.join(',')
      },
      success: function(response) {
        var data = Ext.util.JSON.decode(response.responseText).data;

        // When an error occurs warnings are stored in the hash
        // data.warnings with the guid of the collection as key.
        for (var i = 0; i < collections.length; i++) {
          var guid = collections[i];
          var node = this.tree.getNodeById(guid);
          if (data.warnings[guid]) {
            var error = "<b>Sync error:</b> ";
            error += data.warnings[guid];
            error += "<br/><span class='pp-smallprint'>Click to dismiss.</span>";
            node.getUI().updateError(error);
          } else {
            node.getUI().updateNone.defer(300, node.getUI());
          }
        }

        this.fileSyncStatus.busy = false;

        if (this.fileSyncStatus.collections.length > 0) {
          this.triggerFileSync();
        }

      },
      scope: this
    });

    this.fileSyncStatus.busy = true;
    this.fileSyncStatus.collections = [];

  },

  triggerFolderStoreReload: function() {
    Ext.StoreMgr.lookup('folder_store').reload();
  },

  triggerLabelStoreReload: function() {
    Ext.StoreMgr.lookup('label_store').reload();
  },

  onFolderStoreLoad: function() {
    // Do the tree.
    if (this.tree) {
      this.tree.refreshFolders();
    }

    // Now tab panel and grids.
    if (this.tabs) {
      var tabs = this.tabs.items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (tab instanceof Paperpile.PluginPanel) {
          tab.getGrid().refreshCollections();
        }
      }
    }
  },

  onLabelStoreLoad: function() {
    // Do the tree.
    if (Paperpile.main.tree) {
      Paperpile.main.tree.refreshLabels();
    }

    // Now tab panel and grids.
    if (this.tabs) {
      var tabs = this.tabs.items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (tab instanceof Paperpile.PluginPanel) {
          tab.getGrid().refreshCollections();
        }
      }
    }

  },

  doCallbacks: function(data) {
    if (!this.callbacksRun) {
      this.callbacksRun = [];
    }

    var callbacksToRun = [];
    if (data.jobs) {
      for (var id in data.jobs) {
        var job = data.jobs[id];
        // Skip if we've already run this job's callback.
        if (this.callbacksRun[job.id]) continue;
        var info = job.info;
        if (info) {
          var callback = info.callback;
          if (callback) {
            var fn = callback.fn;
            var args = callback.args;
            if (this[fn]) {
              // Collect the name of each callback to run by hashing the function name.
              // This avoids the same grid udpate function being called a million times
              // in a row, but maybe there's a better solution using DelayedTask...
              callbacksToRun[fn] = 1;
              this.callbacksRun[job.id] = 1;
            }
          }
        }
      }
    }

    for (var fn in callbacksToRun) {
      this[fn]();
    }

  },

  // This function is currently only used as a target for the callback
  // when a new PDF was matched and imported. At the moment it just
  // updates the main grid which is sufficient since new PDFs are not
  // tagged or in any folders.
  updatePubGrid: function() {
    var tab = Paperpile.main.tabs.items.items[0];
    var store = tab.getGrid().getStore();
    var lastOptions = store.lastOptions;
    Ext.apply(lastOptions.params, {
      plugin_update_total: true
    });
    store.reload(lastOptions);
  },

  stopQueueUpdate: function() {
    if (!this.queueUpdateTask) return;
    Ext.TaskMgr.stop(this.queueUpdateTask);
    this.queueUpdateTask = null;
  },

  queueUpdate: function() {
    if (this.queueUpdateTask) {
      Ext.TaskMgr.stop(this.queueUpdateTask);
    }

    // Recreate task object every time this function is calle. If
    // re-used it did not get called a second time for some reason...
    this.queueUpdateTask = {
      run: this.queueUpdateFn,
      interval: 1000,
      scope: this
    };
    Ext.TaskMgr.start(this.queueUpdateTask);
  },

  queueUpdateFn: function() {
    // Make sure that request is only sent after the previous got
    // back.
    if (this.queuePollStatus == null) {
      this.queuePollStatus = 'DONE';
    }

    if (this.queuePollStatus === 'WAITING') {
      return;
    }

    this.queuePollStatus = 'WAITING';

    Paperpile.Ajax({
      url: '/ajax/queue/update',
      params: {
        get_queue: true,
        ids: this.runningJobs
      },
      success: function(response) {
        this.queuePollStatus = 'DONE';
        var data = Ext.util.JSON.decode(response.responseText).data;

        if (data.queue.status === 'WAITING' || (data.queue.status == 'PAUSED' && data.queue.running_jobs.length == 0)) {
          this.stopQueueUpdate();
        }

        this.currentQueueData = data;
        this.runningJobs = data.queue.running_jobs;
      },
      scope: this
    });
  },

  unfinishedTasks: function() {
    if (Paperpile.main.currentQueueData) {
      if (Paperpile.main.currentQueueData.queue.status === 'RUNNING') {
        return (true);
      }
    }
  },

  onError: function(response,options) {

    var error;

    //Timed out errors come back empty otherwise fill in error
    //data from backend
    if (response.responseText) {
      error = Ext.util.JSON.decode(response.responseText).error;
    } else {
      error = {
        type: "Unknown",
        msg: "Empty response or timeout."
      };

      if (options){
        error.msg += "<br>URL: " + options.url;
        error.msg += "<br>Timeout set: " + options.timeout;
      }
    }

    if (error.type == 'Unknown') {

      Paperpile.status.updateMsg({
        type: 'error',
        msg: 'An unexpected error has occured.',
        action1: 'Details',
        callback: function(action) {

          if (action === 'ACTION1') {

            Ext.MessageBox.buttonText.ok = "Send error report";
            Ext.Msg.show({
              title: 'Error',
              msg: Ext.util.Format.ellipsis(error.msg, 1000),
              animEl: 'elId',
              icon: Ext.MessageBox.ERROR,
              buttons: Ext.Msg.OKCANCEL,
              fn: function(btn) {
                if (btn === 'ok') {
                  Paperpile.main.reportError('CRASH', {
                    info: error.msg
                  });
                }
                Ext.MessageBox.buttonText.ok = "Ok";
              }
            });
          }
        },
        hideOnClick: true
      });
    } else {
      Paperpile.status.updateMsg({
        type: 'error',
        msg: error.msg,
        hideOnClick: true
      });
    }
  },

  reportPdfDownloadError: function(data) {

    Ext.MessageBox.buttonText.ok = "Send error report";
    Ext.Msg.show({
      title: 'Feedback',
      msg: 'Paperpile failed to download a PDF. If you have full-text access to that PDF this should not have happened.\
            Please help us to get this fixed by sending an error report.',
      animEl: 'elId',
      icon: 'pp-messagebox-feedback',
      buttons: Ext.Msg.OKCANCEL,
      fn: function(btn) {
        if (btn === 'ok') {
          Paperpile.main.reportError('PDF_DOWNLOAD', data);
        }
        Ext.MessageBox.buttonText.ok = "Ok";
      }
    });
  },

  reportPdfMatchError: function(data) {

    Ext.MessageBox.buttonText.ok = "Send error report";
    Ext.Msg.show({
      title: 'Feedback',
      msg: 'Paperpile failed to automatically import your PDF. Please help us to get this fixed by sending an error report.<br>\
            Note: This will upload the PDF to our bug-tracking system. We will only use it to identify the problem and delete it afterwards.',
      animEl: 'elId',
      icon: 'pp-messagebox-feedback',
      buttons: Ext.Msg.OKCANCEL,
      fn: function(btn) {
        if (btn === 'ok') {
          Paperpile.main.reportError('PDF_MATCH', data);
        }
        Ext.MessageBox.buttonText.ok = "Ok";
      }
    });
  },

  addPDFManually: function(jobID, gridID) {

    var data = Ext.getCmp(gridID).getStore().getById(jobID).data;

    data.match_job = data.id;

    data.pubtype = 'ARTICLE';

    win = new Ext.Window({
      title: "Edit Reference",
      modal: true,
      shadow: false,
      layout: 'fit',
      width: 800,
      height: 600,
      resizable: false,
      closable: true,
      items: [new Paperpile.MetaPanel({
        data: data,
        isNew: false,
        callback: function(status, data) {
          if (status == 'SAVE') {
            Paperpile.main.onUpdate(data);
            Paperpile.status.clearMsg();
          }
          win.close();
        },
        scope: this
      })]
    });

    win.show(this);
  },

  // Type: CRASH, PDF_DOWNLOAD, PDF_IMPORT
  reportError: function(type, data) {

    var url = '/ajax/misc/report_crash';

    if (type === 'PDF_DOWNLOAD') {
      url = '/ajax/misc/report_pdf_download_error';
    }

    if (type === 'PDF_MATCH') {
      url = '/ajax/misc/report_pdf_match_error';
    }
    var number = Paperpile.status.showBusy("Sending error report");
    // First call line_feed to make sure all of the relevant catalyst
    // log is flushed. Wait 5 seconds to make sure it is sent to the
    // frontend before we send it back to the backend. 
    Paperpile.Ajax({
      url: '/ajax/misc/line_feed',
      success: function(response) {
        (function() {

          var params = Ext.apply(data, {
            catalyst_log: Paperpile.serverLog
          });
          // Turn off logging to avoid logging the log when it is sent
          // to the backend...
          Paperpile.isLogging = 0;
          Paperpile.Ajax({
            url: url,
            method: 'POST',
            // GET did mess up the parameters so we use POST
            params: params,
            scope: this,
            success: function() {
              // Turn on logging again. Wait 10 seconds to make sure it is
              // turned off when the actual log is written.
              Paperpile.status.clearMessageNumber(number, true);
              (function() {
                Paperpile.isLogging = 1;
              }).defer(10000);
            }
          });
        }).defer(3000);
      },
      scope: this
    });
  },

  startHeartbeat: function() {

    this.heartbeatTask = {
      run: this.pollServer,
      scope: this,
      interval: 5000
    };
    //Ext.TaskMgr.start(this.heartbeatTask);
  },

  pollServer: function() {

    Paperpile.Ajax({
      url: '/ajax/app/heartbeat',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        for (var jobID in json.queue) {
          var callback = json.queue[jobID].callback;
          if (callback) {
            if (callback.notify) {
              Paperpile.status.clearMsg();
              Paperpile.status.updateMsg({
                msg: callback.notify,
                hideOnClick: true
              });
            }
            if (callback.updatedb) {
              this.onUpdateDB();
            }
          }
        }
      },
      failure: function(response) {
        // do something reasonable here when server contact breaks down.
      }
    });
  },

  inc_read_counter: function(data) {
    if (data._rowid) {
      Paperpile.Ajax({
        url: '/ajax/misc/inc_read_counter',
        params: {
          rowid: data._rowid,
          guid: data.guid,
          times_read: data.times_read
        },
        scope: this
      });
    }
  },

  userVoice: function() {

    if (window.UserVoice) {
      UserVoice.Popin.show();
    } else {
      Paperpile.status.clearMsg();
      Paperpile.status.updateMsg({
        type: 'info',
        msg: 'Retry with an active network connection or visit paperpile.uservoice.com',
        duration: 5
      });
    }
  },

  checkForUpdates: function(silent) {

    if ((Paperpile.main.globalSettings['check_updates'] == 0) && silent) {
      return;
    }

    if (!IS_QT) {
      if (!silent) {
        Paperpile.status.updateMsg({
          msg: 'The auto-update feature is not available from within a browser.',
          hideOnClick: true
        });
      }
      return;
    }

    QRuntime.log("Searching for updates.");

    if (!silent) {
      Paperpile.status.showBusy('Searching for updates');
    }

    var results;

    var readLineCallback = function(string) {
      results = Ext.util.JSON.decode(string);
    };

    var exitCallback = function(string) {
      Paperpile.status.clearMsg();
      QRuntime.updaterReadLine.disconnect(readLineCallback);
      QRuntime.updaterExit.disconnect(exitCallback);

      if (results.error) {
        if (!silent) {
          Paperpile.status.updateMsg({
            type: 'error',
            msg: 'Update check failed.',
            action1: 'Details',
            callback: function(action) {
              if (action === 'ACTION1') {
                Ext.Msg.show({
                  title: 'Error',
                  msg: results.error,
                  animEl: 'elId',
                  icon: Ext.MessageBox.ERROR,
                  buttons: Ext.Msg.OK,
                  fn: function(btn) {
                    //Ext.Msg.close();
                  }
                });
              }
            },
            hideOnClick: true
          });
        }
      } else {
        if (!Paperpile.status.el.isVisible()) {
          if (results.update_available) {
            // Don't bother the user with this message again
            // during this session
            //Ext.TaskMgr.stop(Paperpile.updateCheckTask);

            Paperpile.status.updateMsg({
              msg: 'An updated version of Paperpile is available',
              action1: 'Install Updates',
              action2: 'Not now',
              callback: function(action) {
                if (action === 'ACTION1') {
                  Paperpile.updateInfo = results;
                  Paperpile.main.tabs.newScreenTab('Updates', 'updates');
                }
                Paperpile.status.clearMsg();
              }
            });
          } else {
            if (!silent) {
              Paperpile.status.updateMsg({
                msg: 'Paperpile is up-to-date.',
                hideOnClick: true
              });
            }
          }
        }
      }
    };

    QRuntime.updaterReadLine.connect(readLineCallback);
    QRuntime.updaterExit.connect(exitCallback);
    QRuntime.updaterStart("check");

  }
});
