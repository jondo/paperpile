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

Ext.define('Paperpile.main.Viewport', {
  extend: 'Ext.container.Viewport',
  alias: 'widget.pp-viewport',
  initComponent: function() {
    this.createStores();

    //    this.status = Ext.createByAlias('widget.status');
    this.hoverButtons = Ext.createByAlias('pp-hover-copylink');

    Ext.apply(this, {
      layout: {
        type: 'border'
      },
      enableKeyEvents: true,
      //      autoScroll: false,
      items: [this.createTabs(), this.createTree()],
    });

    this.callParent(arguments);

    Ext.getBody().on({
      click: {
        element: 'body',
        fn: this.onActionClick,
        delegate: '.pp-action',
        scope: this
      },
    });

    //    this.on('afterlayout', this.resizeToSplitFraction, this);
    this.mon(Ext.getBody(), 'click', function(event, target, options) {
      if (target.href) {
        if (!target.href.match(/(app|paperpile|localhost|127\.0\.0\.1)/i)) {
          event.stopEvent();
          Paperpile.utils.openURL(target.href);
        }
      }
    });

    this.runningJobs = [];
    this.loadKeys();
    this.fileSyncStatus = {
      busy: false,
      collections: [],
      task: new Ext.util.DelayedTask(this.fireFileSync, this)
    };
  },

  onActionClick: function(event, target, o) {
    var el = Ext.fly(target);
    if (el.hasCls('pp-action')) {
      var id = el.getAttribute('action');
      var args = el.getAttribute('args');
      var array = [];
      if (args && args !== '') {
        array.push(args.split(','));
      }
      var eventCopy = new Ext.EventObjectImpl(event.browserEvent);
      Paperpile.app.Actions.lastTriggerEvent = eventCopy;
      Paperpile.app.Actions.execute(id, array);
    }
  },

  createTree: function() {
    this.tree = Ext.createByAlias('widget.pp-tree', {
      region: 'north',
      flex: 1
    });
    return this.tree;
  },

  createTabs: function() {
    this.tabs = Ext.createByAlias('widget.pp-tabs', {
      region: 'center',
      split: true,
      border: false,
      flex: 5
    });
    Paperpile.log("Tabs!");
    return this.tabs;
  },

  createQueue: function() {
    this.queue = Ext.createByAlias('widget.queuewidget', {
      dock: 'top'
    });
    return this.queue;
  },

  createStores: function() {
    var me = this;
    this.labelStore = new Paperpile.net.CollectionStore({
      collectionType: 'LABEL',
      listeners: {
        load: {
          fn: function(store, records, success) {
            me.onLabelStoreLoad();
          }
        }
      },
      storeId: 'labels'
    });

    this.folderStore = new Paperpile.net.CollectionStore({
      collectionType: 'FOLDER',
      listeners: {
        load: {
          fn: function() {
            me.onFolderStoreLoad();
          }
        }
      },
      storeId: 'folders'
    });

    this.feedStore = new Paperpile.net.CollectionStore({
      collectionType: 'FEED',
      listeners: {
        load: {
          fn: function() {
            //me.onFeedStoreLoad()
          }
        }
      },
      storeId: 'feeds'
    });

    var me = this;
    this.folderStore.load({
      scope: me,
      callback: function() {
        this.labelStore.load({
          scope: me,
          callback: function() {
            this.feedStore.load();
          }
        });
      }
    });

  },

  getTabs: function() {
    return this.tabs;
  },

  updateSplitFraction: function(newFraction) {
    this.splitFraction = newFraction;
    Paperpile.main.setSetting('split_fraction_tree', this.splitFraction, true);
    this.resizeToSplitFraction();
  },

  resizeToSplitFraction: function() {
    return;
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

    if (this.tree) {
      this.tree.setWidth(w1);
      this.tree.setPosition(0, 0);
      if (this.getTabs()) {
        this.getTabs().setWidth(w2);
        this.getTabs().setPosition(w1, 0);
      }
    }
  },

  onFontSizeChange: function(fontSize) {
    fontSize = fontSize.toLowerCase();

    if (fontSize == 'normal') {
      this.loadCssFile('/css/normal-fonts.css');
    } else if (fontSize == 'large') {
      this.loadCssFile('/css/large-fonts.css');
    } else if (fontSize == 'x-large') {
      this.loadCssFile('/css/x-large-fonts.css');
    }
  },

  afterLoadSettings: function() {

  },

  focusCurrentPanel: function() {
    var tab = Paperpile.main.getTabs().getActiveTab();
    tab.focus();
  },

  loadKeys: function() {
    // Borrowed from Window.js
    this.focusEl = this.el.createChild({
      tag: 'a',
      href: '#',
      cls: 'pp-focus',
      style: {
	display: 'none',
      },
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

    this.alwaysKeys.bindCallback('ctrl-shift-x', this.keyControlShiftX, this);
    this.alwaysKeys.bindCallback('ctrl-y', this.keyControlY, this);
    this.alwaysKeys.bindCallback('ctrl-tab', this.keyControlTab, this);
    this.alwaysKeys.bindCallback('ctrl-w', this.keyControlW);
    this.alwaysKeys.bindCallback('shift-[?,191]', this.showKeyHelp);
    this.alwaysKeys.bindCallback('ctrl-n', this.forwardToGrid, this);
  },

  showKeyHelp: function() {

  },

  keyControlShiftX: function() {
    this.getTabs().showDashboardTab();
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
    Paperpile.main.getTabs().newScreenTab('widget.catalystlog');
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
    var tab = Paperpile.main.getTabs().getActiveTab();
    var grid = tab.getGrid();
    grid.handleCopyBibtexKey();
  },

  keyControlShiftB: function() {
    var tab = Paperpile.main.getTabs().getActiveTab();
    var grid = tab.getGrid();
    grid.handleCopyBibtexCitation();
  },

  keyControlA: function() {
    var tab = Paperpile.main.getTabs().getActiveTab();
    var grid = tab.getGrid();
    grid.selectAll();
  },

  keyControlTab: function() {
    var tabs = Paperpile.main.getTabs();
    var items = tabs.items;
    var currentTabIndex = items.indexOf(tabs.getActiveTab());

    if (currentTabIndex == items.getCount() - 1) {
      tabs.setActiveTab(0);
    } else {
      tabs.setActiveTab(currentTabIndex + 1);
    }
  },

  keyControlW: function() {
    var curTab = Paperpile.main.getTabs().getActiveTab();
    if (curTab.closable) {
      // Fire the tab's beforeclose event to trigger any 'warning' dialogs before closing.
      if (curTab.fireEvent('beforeclose', curTab) !== false) {
        Paperpile.main.getTabs().remove(curTab, true);
      }
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
    return Paperpile.Settings.get(key);
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
      path = Paperpile.utils.catPath(Paperpile.Settings.get('paper_root'), path);
    }

    Paperpile.utils.openFile(path);
    if (data !== null) {
      Paperpile.main.inc_read_counter(data);
    }
  },

  getTree: function() {
    return this.tree;
  },

  getCurrentGrid: function() {
    if (!Paperpile.main.getTabs()) {
      return;
    }
    var activeTab = Paperpile.main.getTabs().getActiveTab();
    if (activeTab instanceof Paperpile.pub.View) {
      return activeTab.grid;
    }
    return null;
  },

  getMainLibraryGrid: function() {
    var mainTab = this.getTabs().getMainLibraryTab();
    return mainTab.getGrid();
  },

  getCurrentlySelectedRow: function() {
    var activeTab = Paperpile.main.getTabs().getActiveTab();
    if (activeTab instanceof Paperpile.pub.View) {
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
      this.getTabs().showTrashTab();
      grid = this.getTabs().getItem('trash').getGrid();
    } else {
      // Activate the library tab.
      this.getTabs().showMainLibraryTab();

      // Get the library grid and set the query.
      grid = this.getMainLibraryGrid();
    }
    grid.setSearchQuery('key:' + record.data.citekey);
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
        // Create new array because the "filenames" parameter coming
        // back from the file dialog behaves strange. It seems to be
        // an array but when sent as Ajax parameter in
        // submitPdfExtractionJobs it is not transferred as array.
        var newFiles = [];
        for (var i = 0; i < filenames.length; i++) {
          newFiles.push(filenames[i]);
        }
        Paperpile.main.submitPdfExtractionJobs(newFiles);
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
  // representing the target collection for import. paths can either
  // be a single PDF file/folder or an array of files/folders 
  submitPdfExtractionJobs: function(paths, treeNode) {
    Ext.getCmp('queue-widget').onUpdate({
      submitting: true
    });
    Paperpile.Ajax({
      url: '/ajax/pdfextract/submit',
      params: {
        paths: paths,
        collection_guids: [treeNode ? treeNode.id : null]
      }
    });
  },

  attachFile: function(grid, guid, path, isPDF) {},

  countFilesAndTriggerExtraction: function(path) {
    // First count the PDFs
    Paperpile.Ajax({
      url: '/ajax/pdfextract/count_files',
      params: {
        path: path
      },
      success: function(response) {
        var json = Ext.JSON.decode(response.responseText);

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

    // Contingency plan for when a PDF file is accidentally
    // selected in the file import dialog.
    if (parts.extension.match(/pdf/i)) {
      Paperpile.main.submitPdfExtractionJobs(filename);
      return;
    }

    Paperpile.main.getTabs().newPluginTab('File', {
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
      typesDescription: 'Bibliography files (BibTeX, RIS, and others)',
      nameFilters: ["All supported files (*)",
        "BibTeX (*.bib)",
        "RIS (*.ris)",
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
    return Paperpile.main.getTabs().getActiveTab();
  },

  getActiveGrid: function() {
    var panel = Paperpile.main.getTabs().getActiveTab();
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
  updateFromServer: function(data) {
    if (data === undefined) return;
    //    Paperpile.logFull(data);
    if (this.labelStore) {
      this.labelStore.updateFromServer(data);
    }
    if (this.folderStore) {
      this.folderStore.updateFromServer(data);
    }

    // update the queue widget with the current data.
    //this.queueWidget.onUpdate(data);
    // If this update contains new or deleted jobs, trigger the queue update loop.
    if (data.job_delta) {
      this.queueUpdate();
    }

    if (this.tree) {
      //this.tree.updateFromServer(data);
    }

    if (this.tabs) {
      var tabs = this.tabs.items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (!tab['updateFromServer']) {
          continue;
        } else {
          tab.updateFromServer(data);
        }
      }
    }

    // Even if the queue tab isn't showing, collect and dispatch callbacks.
    if (data.jobs) {
      this.doCallbacks(data);
    }
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
        var data = Ext.JSON.decode(response.responseText).data;

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
    // Now tab panel and grids.
    if (this.getTabs()) {
      var tabs = this.getTabs().items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (tab instanceof Paperpile.pub.View) {
          tab.getGrid().refresh();
        }
      }
    }
  },

  onLabelStoreLoad: function() {
    // Now tab panel and grids.
    if (this.getTabs()) {
      var tabs = this.getTabs().items.items;
      for (var i = 0; i < tabs.length; i++) {
        var tab = tabs[i];
        if (tab instanceof Paperpile.pub.View) {
          tab.getGrid().refresh();
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
    var tab = Paperpile.main.getTabs().items.items[0];
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
      interval: 500,
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
        var data = Ext.JSON.decode(response.responseText).data;

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

  onError: function(response, options) {

    var error;

    //Timed out errors come back empty otherwise fill in error
    //data from backend
    if (response.responseText) {
      error = Ext.decode(response.responseText).error;
    } else {
      error = {
        type: "Unknown",
        msg: "Empty response or timeout."
      };

      if (options) {
        error.msg += "<br>URL: " + options.url;
        error.msg += "<br>Timeout set: " + options.timeout;
      }
    }

    Paperpile.log(error);

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

    // Get data from queue grid
    var data = Ext.getCmp(gridID).getStore().getById(jobID).data;

    data.match_job = data.id;

    data.pubtype = 'ARTICLE';

    // After cancel we have not imported the PDF yet and we have to
    // treat it differently from the case when it already has been
    // imported
    var isNew;
    if (!data.guid) {
      isNew = true;
      data._pdf_tmp = data.pdf;
    } else {
      isNew = false;
    }

    // This is almost direct copy-pasted from import/grid.js. Need to refactor out at some point.
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
        isNew: isNew,
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
    win.on('close', function() {
      Paperpile.main.focusCurrentPanel();
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
        var json = Ext.JSON.decode(response.responseText);

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

    if ((Paperpile.Settings.get('check_updates') == 0) && silent) {
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
      results = Ext.JSON.decode(string);
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
                  Paperpile.main.getTabs().newScreenTab('Updates', 'updates');
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