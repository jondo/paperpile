Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

IS_TITANIUM = !(window['Titanium'] == undefined);

Paperpile.Url = function(url) {
  return (IS_TITANIUM) ? 'http://127.0.0.1:3000' + url : url;
};

Paperpile.log = function() {
  if (window.console) {
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
                html: 'Paperpile 0.4 preview',
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

    this.tabs = Ext.getCmp('tabs');

    this.tagStore = new Ext.data.Store({
      proxy: new Ext.data.HttpProxy({
        url: Paperpile.Url('/ajax/misc/tag_list'),
        method: 'GET'
      }),
      storeId: 'tag_store',
      baseParams: {},
      reader: new Ext.data.JsonReader(),
      pruneModifiedRecords: true
    });
    this.tagStore.reload();

    this.runningJobs = [];

    //	this.loadKeys();
  },

  /*
    keyMap:null,
    loadKeys:function() {
      this.keyMap = new Ext.KeyMap(document,[
        {
	  key: [Ext.EventObject.TAB,Ext.EventObject.W,Ext.EventObject.A],
//	  ctrl:true,
	  stopEvent:true,
	  handler: this.controlPlus,
	  scope:this
	}
      ]);
    },

    controlPlus:function(e,t) {
      var key = e.getKey();
      log("Key!" + key);
      switch (key) {
      case Ext.EventManager.TAB:
	e.stopEvent();
	break;
      case Ext.EventObject.W:
	log("W!");
	var curTab = Paperpile.main.tabs.getActiveTab();
	Paperpile.main.tabs.remove(curTab);
	e.stopEvent();
	break;
      }
    },
*/

  // sel = 'ALL' or sha1s of selected pubs.
  deleteFromFolder: function(sel, grid, folder_id, refreshView) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_from_folder'),
      params: {
        selection: sel,
        grid_id: grid.id,
        folder_id: folder_id
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        // Update the status of the other views.
        Paperpile.main.onUpdate(json.data);

        if (refreshView && grid['getStore']) {
          // Reload this entire view, because the refs just got removed from the folder.
          grid.getView().holdPosition = true;
          grid.getStore().reload();
        }
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  },

  getSetting: function(key) {
    return this.globalSettings[key];
  },

  setSetting: function(key, value, commitToBackend) {
    if (commitToBackend === undefined) {
      commitToBackend = true;
    }
    this.globalSettings[key] = value;
    this.storeSettings({
      key: value
    });
  },

  storeSettings: function(newSettings, callback, scope) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/settings/set_settings'),
      params: newSettings,
      success: function(response) {
        for (var key in newSettings) {
          Paperpile.main.globalSettings[key] = newSettings[key];
        }
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

  pdfExtract: function() {

    win = new Paperpile.FileChooser({
      title: "Select single PDF file or directory to search for PDF files",
      currentRoot: Paperpile.main.globalSettings.user_home,
      showFilter: true,
      selectionMode: 'BOTH',
      filterOptions: [{
        text: 'PDF files',
        suffix: ['pdf']
      }],
      callback: function(button, path) {
        if (button == 'OK') {
          Ext.Ajax.request({
            url: Paperpile.Url('/ajax/pdfextract/submit'),
            params: {
              path: path
            },
            success: function(response) {
              Paperpile.main.queueUpdate();
            }
          });
        }
      }
    });

    win.show();

  },

  fileImport: function() {

    win = new Paperpile.FileChooser({
      showFilter: true,
      currentRoot: Paperpile.main.globalSettings.user_home,
      filterOptions: [{
        text: 'All supported formats',
        suffix: ['bib', 'ris', 'txt', 'lib', 'mods', 'xml', 'rss']
      },
      {
        text: 'BibTeX (.bib)',
        suffix: ['bib']
      },
      {
        text: 'RIS file (.ris)',
        suffix: ['ris']
      },
      {
        text: 'Endnote (.txt, .lib )',
        suffix: ['txt', 'lib']
      },
      {
        text: 'Endnote XML (.xml)',
        suffix: ['xml']
      },
      {
        text: 'Word 2007 XML (.xml)',
        suffix: ['xml']
      },
      {
        text: 'MODS (.mods, .xml)',
        suffix: ['mods', 'xml']
      },
      {
        text: 'RSS (.rss, .xml)',
        suffix: ['rss', 'xml']
      },
      // Paperpile import/export disabled at the moment
      // { 
      //   text: 'Paperpile (.ppl)',
      //   suffix: ['ppl']
      // },
      {
        text: 'All files',
        suffix: ['ALL']
      },
      ],

      callback: function(button, path) {
        if (button == 'OK') {
          var parts = Paperpile.utils.splitPath(path);
          Paperpile.main.tabs.newPluginTab('File', {
            plugin_file: path,
            plugin_name: 'File',
            plugin_mode: 'FULLTEXT',
            plugin_query: '',
            plugin_base_query: '',
          },
            parts.file, 'pp-icon-file');
        }
      }
    });

    win.show();

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

  updatePubGrid: function() {
    var tabs = Paperpile.main.tabs.items.items;
    for (var i = 0; i < tabs.length; i++) {
      var tab = tabs[i];
      tab.getGrid().getStore().reload();
    }
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
    if (this.queuePollStatus == 'null') {
      this.queuePollStatus = 'DONE';
    }

    if (this.queuePollStatus === 'WAITING') return;

    this.queuePollStatus = 'WAITING';

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/update'),
      params: {
        get_queue: true,
        ids: this.runningJobs,
      },
      method: 'GET',
      success: function(response) {
        this.queuePollStatus = 'DONE';
        var data = Ext.util.JSON.decode(response.responseText).data;
        if (data.queue.status != 'RUNNING' && data.queue.status != 'PAUSED') {
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
                  Paperpile.main.reportError(error);
                }
                Ext.MessageBox.buttonText.ok = "Ok";
              },
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

  reportError: function(error) {

    // Turn off logging to avoid logging the log when it is sent
    // to the backend...
    Paperpile.isLogging = false;
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/misc/report_error'),
      params: {
        error: error.msg,
        catalyst_log: Paperpile.serverLog,
      },
      scope: this,
      success: function() {
        // Turn on logging again
        Paperpile.isLogging = true;
      }
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
          sha1: data.sha1,
          times_read: data.times_read,
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

  check_updates: function(silent) {

    if (IS_TITANIUM) {

      if (!silent) {
        Paperpile.status.showBusy('Searching for updates');
      }

      var platform = Paperpile.utils.get_platform();
      var path = Titanium.App.getHome() + '/catalyst';

      var upgrader = Titanium.Process.createProcess({
        args: [path + "/perl5/" + platform + "/bin/perl", path + '/script/updater.pl', '--check'],
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
                    },
                  });
                }
              },
              hideOnClick: true,
            });
          }
        } else {
          if (results.update_available) {
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
              hideOnClick: true,
            });
          } else {
            if (!silent) {
              Paperpile.status.updateMsg({
                msg: 'Paperpile is up-to-date.',
                hideOnClick: true,
              });
            }
          }
        }
      });
      upgrader.launch();
    }
  }
});