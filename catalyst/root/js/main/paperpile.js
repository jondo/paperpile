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

Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

IS_TITANIUM = !(window['Titanium'] == undefined);

IS_CHROME = navigator.userAgent.toLowerCase().indexOf('chrome') > -1;

Paperpile.Url = function(url) {
  return (IS_TITANIUM) ? 'http://127.0.0.1:3210' + url : url;
};

Paperpile.log = function() {
  if (IS_TITANIUM) {
    Titanium.API.debug(arguments[0]);
  } else if (IS_CHROME) {
    console.log(arguments[0]);
  } else if (window.console) {
    console.log(arguments);
  }
};

Paperpile.Viewport = Ext.extend(Ext.Viewport, {

  globalSettings: {},

  initComponent: function() {

    Ext.apply(this, {
      layout: 'border',
      renderTo: Ext.getBody(),
      enableKeyEvents: true,
      keys: {},
      items: [{
        xtype: 'panel',
        layout: 'border',
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
            new Paperpile.QueueWidget(), new Ext.BoxComponent({
              autoEl: {
                tag: 'a',
                href: '#',
                html: '<div class="pp-dashboard-button"></div>'
              },
              id: 'dashboard-button'
            })]
        }),
        items: [{
          border: 0,
          xtype: 'tree',
          rootVisible: false,
          id: 'treepanel',
          itemId: 'navigation',
          region: 'west',
          margins: '2 2 2 2',
          cmargins: '5 5 0 5',
          width: 200
        },
        {
          region: 'center',
          border: false,
          border: false,
          xtype: 'tabs',
          id: 'tabs',
          activeItem: 0
        }]
      }]
    });

    Paperpile.Viewport.superclass.initComponent.call(this);

    this.mon(Ext.getBody(),'click', function(event,target,options) {
      if (target.href) {
	if (!target.href.match(/(app|paperpile)/i)) {
	event.stopEvent();
	Paperpile.utils.openURL(target.href);
	}
      }
    });

    this.tabs = Ext.getCmp('tabs');
    this.dd = new Paperpile.DragDropManager();
    this.dd.initListeners();

    this.tagStore = new Ext.data.Store({
      proxy: new Ext.data.HttpProxy({
        url: Paperpile.Url('/ajax/crud/list_labels'),
        method: 'GET'
      }),
      storeId: 'tag_store',
      baseParams: {},
      reader: new Ext.data.JsonReader(),
      pruneModifiedRecords: true,
      listeners: {
        load: {
          fn: this.updateTagStyles,
          scope: this
        }
      }
    });
    this.tagStore.reload();

    this.runningJobs = [];

    this.loadKeys();

    this.fileSyncStatus = {
      busy: false,
      collections: [],
      task: new Ext.util.DelayedTask(this.fireFileSync, this)
    };

    Ext.apply(Ext.QuickTips.getQuickTip(), {
      showDelay: 0,
      dismissDelay: 0,
      hideDelay: 0,
      anchor: 'left'
    });
  },

  onRender: function() {

  },

  loadKeys: function() {
    this.keys = new Ext.ux.KeyboardShortcuts(this.getEl());

    this.keys.bindCallback('ctrl-tab', this.keyControlTab, this);
    this.keys.bindCallback('ctrl-w', this.keyControlW);
    this.keys.bindCallback('shift-[?,191]', this.keys.showKeyHelp);
  },
  keyQuesionMark: function() {
    Paperpile.log("What's your problem?");
  },
  keyControlC: function() {
    var tab = Paperpile.main.tabs.getActiveTab();
    var grid = tab.getGrid();
    grid.handleCopyFormatted();
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

  // sel = 'ALL' or guids of selected pubs.
  deleteFromFolder: function(sel, grid, folder_id, callback) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/remove_from_collection'),
      params: {
        selection: sel,
        grid_id: grid.id,
        collection_guid: folder_id,
        type: 'FOLDER',
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        // Update the status of the other views.
        Paperpile.main.onUpdate(json.data);

        if (callback) {
          callback.call(grid);
        }
      },
      failure: Paperpile.main.onError,
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
    Paperpile.log('[' + key + '] => [' + value + ']');
    this.globalSettings[key] = value;

    var s = {};
    s[key] = Ext.util.JSON.encode(value);

    this.storeSettings(s);
  },

  storeSettings: function(newSettings, callback, scope) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/settings/set_settings'),
      params: newSettings,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        for (var key in newSettings) {}
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  loadSettings: function(callback, scope) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/misc/get_settings'),
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        this.globalSettings = json.data;
        if (callback) {
          callback.createDelegate(scope)();
        }
      },
      failure: Paperpile.main.onError,
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

  folderExtract: function() {
    var callback = function(filenames) {
      if (filenames.length > 0) {
        var folder = filenames[0];
        Paperpile.main.countFilesAndTriggerExtraction(folder);
      }
      this.pdfExtractChoice.close();
    };
    var options = {
      title: 'Choose a folder containing PDFs to import',
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
    };
    var options = {
      title: 'Choose PDF file(s) to import',
      selectionType: 'file',
      types: ['pdf'],
      multiple: true,
      typesDescription: 'PDF Files',
      scope: this
    };
    Paperpile.fileDialog(callback, options);
  },

  pdfExtract: function() {

    var divDef = '<div style="width:200px;white-space:normal;">';
    this.pdfExtractChoice = new Ext.Window({
      title: 'Choose type of PDF import',
      layout: 'vbox',
      bodyStyle: 'background-color:#FFFFFF !important;',
      width: 250,
      height: 190,
      plain: true,
      modal: true,
      buttonAlign: 'center',
      layoutConfig: {
        align: 'center',
        defaultMargins: '5px'
      },
      items: [{
        xtype: 'label',
        text: '',
        width: '100%',
        style: 'text-align:left;'
      },
      {
        xtype: 'subtlebutton',
        text: 'PDF Folder',
        align: 'center',
        width: 150,
        height: 30,
        tooltip: {
          text: 'The selected folder and its subdirectories will be searched for PDFs to import',
          width: 175,
          anchor: 'left'
        },
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
        xtype: 'subtlebutton',
        text: 'PDF File(s)',
        tooltip: {
          text: 'Select one or more files to import.',
          anchor: 'left',
          width: 175
        },
        handler: this.fileExtract,
        scope: this
      }],
      bbar: [{
        xtype: 'tbfill'
      },
      {
        text: 'Cancel',
        itemId: 'cancel_button',
        handler: function() {
          this.pdfExtractChoice.close();
        },
        scope: this
      }]
    });
    this.pdfExtractChoice.show();
  },

  // Submit a PDF extraction job, optionally including the tree node
  // representing the target collection for import.
  submitPdfExtractionJobs: function(path, treeNode) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/pdfextract/submit'),
      params: {
        path: path,
        collection_guids: [treeNode ? treeNode.id : null]
      },
      success: function(response) {
        Paperpile.main.queueUpdate();
      },
      failure: Paperpile.main.onError
    });
  },

  attachFile: function(grid, guid, path, isPDF) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/attach_file'),
      params: {
        guid: guid,
        grid_id: grid.id,
        file: path,
        is_pdf: (isPDF) ? 1 : 0
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);

        // TODO: add a status message and an undo function.
      },
      failure: Paperpile.main.onError,
      scope: this,
    });

  },

  countFilesAndTriggerExtraction: function(path) {
    // First count the PDFs
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/pdfextract/count_files'),
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
      scope: this,
      failure: Paperpile.main.onError
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
    var options = {
      title: 'Choose a library file to import',
      types: ['*'],
      typesDescription: 'Library files (Bibtex, RIS, EndNote, etc)',
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
    var tabs = Paperpile.main.tabs.items.items;

    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      if (!tab['onUpdate']) continue;
      tab.onUpdate(data);
    }

    // Even if the queue tab isn't showing, collect and dispatch callbacks.
    if (data.jobs) {
      this.doCallbacks(data);
    }

    Ext.getCmp('queue-widget').onUpdate(data);

    // If the user is currently dragging, update the dragdrop targets.
    if (Paperpile.main.dd.dragPane && Paperpile.main.dd.dragPane.isVisible() && !Paperpile.main.dd.effectBlock) {
      Paperpile.main.dd.hideDragPane();
    }

    if (data.file_sync_delta) {
      if (data.file_sync_delta.length > 0) {
        this.triggerFileSync(data.file_sync_delta);
      }
    }
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

    var collections = this.fileSyncStatus.collections;
    for (var i = 0; i < collections.length; i++) {
      var guid = collections[i];
      var node = this.tree.getNodeById(guid);
      node.getUI().updateWorking('Syncing with external file');
    }

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/sync_files'),
      params: {
        collections: this.fileSyncStatus.collections.join(',')
      },
      method: 'GET',
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
      failure: Paperpile.main.onError,
      scope: this
    });

    this.fileSyncStatus.busy = true;
    this.fileSyncStatus.collections = [];

  },

  reloadTagStyles: function() {
    this.tagStore.reload();
  },

  getStyleForTag: function(guid) {
    var record = this.tagStore.getAt(this.tagStore.findExact('guid', guid));
    if (record == null) return '';
    var style = record.get('style');
    return style;
  },

  updateTagStyles: function() {
    // First, deal with the styling for the tree nodes.
    if (!this.tree) return;

    // Collect all the possible tag style classes into an array.
    var allTagStyles = [];
    var n = this.tree.stylePickerMenu.getStyleCount();
    for (var i = 0; i < n; i++) {
      allTagStyles.push('pp-tag-tree-style-' + i);
      allTagStyles.push('pp-tag-style-' + i);
    }
    var nodes = this.tree.getAllLeafNodes();
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (node.type != 'TAGS' || !this.tree.isNodeDraggable(node)) continue;

      // Remove all possible styling from this tree node.
      node.getUI().removeClass(allTagStyles);
      // Add the correct style.
      var tag = node.text;
      node.getUI().addClass('pp-tag-tree-style-' + this.getStyleForTag(node.id));
    }

    // Now, move on to the tab panel and grids.
    var tabs = Paperpile.main.tabs.items.items;
    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      if (this.isLabelTab(tab)) {
        // The label's GUID is currently stored in the tab's itemId property, but 
        // this feels like a hack...
        tab.setIconClass('pp-tag-style-tab pp-tag-style-' + this.getStyleForTag(tab.itemId));
      }
      // Force a re-render on any grid items containing the given tag.
      if (tab instanceof Paperpile.PluginPanel) {
        tab.getGrid().updateTagStyles();
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

    if (this.queuePollStatus === 'WAITING') return;

    this.queuePollStatus = 'WAITING';

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/update'),
      params: {
        get_queue: true,
        ids: this.runningJobs
      },
      method: 'GET',
      success: function(response) {
        this.queuePollStatus = 'DONE';
        var data = Ext.util.JSON.decode(response.responseText).data;

        if (data.queue.status === 'WAITING' || (data.queue.status == 'PAUSED' && data.queue.running_jobs.length == 0)) {
          this.stopQueueUpdate();
        }

        Paperpile.main.onUpdate(data);
        this.currentQueueData = data;
        this.runningJobs = data.queue.running_jobs;
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  onError: function(response) {
    var error = {
      type: "Unknown",
      msg: "Empty response or timeout."
    };

    //Timed out errors come back empty otherwise fill in error
    //data from backend
    if (response.responseText) {
      error = Ext.util.JSON.decode(response.responseText).error;
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
                  Paperpile.main.reportError('CRASH', error.msg);
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

  // Use this simple function here for now. We can think about a more
  // sophisticated tab panel with PDF view later.
  addPDFManually: function(jobID, gridID) {

    var data = Ext.getCmp(gridID).getStore().getById(jobID).data;

    data.match_job = data.id;

    data.pubtype = 'ARTICLE';

    win = new Ext.Window({
      title: "Import " + data.pdf,
      modal: true,
      shadow: false,
      layout: 'fit',
      width: 800,
      height: 600,
      resizable: false,
      closable: true,
      items: [new Paperpile.MetaPanel({
        data: data,
        grid_id: null,
        callback: function(status, data) {
          if (status == 'SAVE') {
            Paperpile.main.onUpdate(data);
            Paperpile.status.clearMsg();
          }
          win.close();
        },
        scope: this
      })],
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
    var number = Paperpile.status.showBusy("Reporting error");
    // First call line_feed to make sure all of the relevant catalyst
    // log is flushed. Wait 5 seconds to make sure it is sent to the
    // frontend before we send it back to the backend. 
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/misc/line_feed'),
      success: function(response) {
        (function() {
          var params = Ext.apply(data, {
            catalyst_log: Paperpile.serverLog
          });
          // Turn off logging to avoid logging the log when it is sent
          // to the backend...
          Paperpile.isLogging = 0;
          Ext.Ajax.request({
            url: Paperpile.Url(url),
            params: params,
            scope: this,
            success: function() {
              // Turn on logging again. Wait 10 seconds to make sure it is
              // turned off when the actual log is written.
		Paperpile.status.clearMessageNumber(number,true);
              (function() {
                Paperpile.isLogging = 1;
              }).defer(10000);
            },
            failure: Paperpile.main.onError
          })
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

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/app/heartbeat'),
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
      Ext.Ajax.request({
        url: Paperpile.Url('/ajax/misc/inc_read_counter'),
        params: {
          rowid: data._rowid,
          guid: data.guid,
          times_read: data.times_read
        },
        success: function(response) {
          var json = Ext.util.JSON.decode(response.responseText);
          Paperpile.main.onUpdate(json.data);
        },
        failure: Paperpile.main.onError,
        scope: this
      });
    }
  },

  userVoice: function() {

    if (window.UserVoice) {
      UserVoice.Popin.show()
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

    if (!IS_TITANIUM) {
      if (!silent) {
        Paperpile.status.updateMsg({
          msg: 'The auto-update feature is not available from within a browser.',
          hideOnClick: true
        });
      }
      return;
    }

    Titanium.API.notice("Searching for updates.");

    if (!silent) {
      Paperpile.status.showBusy('Searching for updates');
    }

    var platform = Paperpile.utils.get_platform();
    var path = Titanium.App.getHome() + '/catalyst';

    var upgrader = Titanium.Process.createProcess({
      args: [path + "/perl5/" + platform + "/bin/perl", path + '/script/updater.pl', '--check']
    });

    upgrader.setEnvironment("PERL5LIB", "");

    var results;

    upgrader.setOnReadLine(function(line) {
      results = Ext.util.JSON.decode(line);
    });

    upgrader.setOnExit(function() {
      Paperpile.status.clearMsg();
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
                    Ext.Msg.close();
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
            Ext.TaskMgr.stop(Paperpile.updateCheckTask);

            Paperpile.status.updateMsg({
              msg: 'An updated version of Paperpile is available',
              action1: 'Install Updates',
              action2: 'Not now',
              callback: function(action) {
                if (action === 'ACTION1') {
                  Paperpile.updateInfo = results;
                  Paperpile.main.tabs.newScreenTab('Updates', 'updates');
                } else {
                  Paperpile.status.clearMsg();
                }
              },
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
    });
    upgrader.launch();
  }
});