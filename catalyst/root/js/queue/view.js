Paperpile.QueuePanel = Ext.extend(Ext.Panel, {
  tabType: 'QUEUE',
  closable: true,
  title: 'Background Tasks',
  iconCls: 'pp-icon-queue',

  initComponent:function() {        
    this.queueList = new Paperpile.QueueList(this,
        {
          region: 'center',
	  itemId:'grid'
        });


  this.queueOverview = new Paperpile.QueueOverview(this,
	{
	  region: 'east',
	  width:300,
	  itemId: 'overview',
	  split: false
	});

    Ext.apply(this, {
      layout: 'border',
      items:[
	this.queueList,
	this.queueOverview
      ]
    });
       
    Paperpile.QueuePanel.superclass.initComponent.call(this);
  },

  getGrid: function() {
    return this.queueList;
  },

  getOverview: function() {
    return this.queueOverview;
  },

  onUpdate: function(data) {
    if (data.queue) {
      this.getOverview().onUpdate(data);
    }
    if (data.jobs) {
      this.getGrid().onUpdate(data);
    }

    if (data.job_delta) {
      Paperpile.main.queueJobUpdate();
      this.getOverview().requestUpdate();
      this.getGrid().getView().holdPosition = true;
      this.getGrid().getStore().reload();
    }
  },

  clearJobs: function(sel) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/clean_jobs'),
      method: 'GET',
      params: {
	ids:sel
      },
      success: function(response) {
	var json = Ext.util.JSON.decode(response.responseText);
	Paperpile.main.onUpdate(json);
      },
      failure: function() {
      },
      scope:this
    });
  },

  cancelJobs: function(selection) {
    if (!selection) {
      selection = this.queueList.getSelectedIds();
    }
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/cancel_jobs'),
      method: 'GET',
      params: {ids:selection},
      success: function(response,opts) {
	this.getGrid().getStore().reload();
      },
      failure: function() {},
      scope:this
    });      
  },

  retryJobs: function(selection) {
    if (!selection) {
      selection = this.queueList.getSelectedIds();
    }
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/retry_jobs'),
      method: 'GET',
      params: {ids:selection},
      success: function(response,opts) {
	this.getGrid().getStore().reload();
      },
      failure: function() {},
      scope:this
    });      
  }

});

Paperpile.QueueList = Ext.extend(Ext.grid.GridPanel, {
  
  constructor: function(queuePanel,config) {
    this.queuePanel = queuePanel;
    Paperpile.QueueList.superclass.constructor.call(this,config);

    this.on('contextmenu', this.onContextClick, this);
  },

    onContextClick: function(grid,index,e) {
      e.stopEvent();
      var record = this.store.getAt(index);
      if (!this.isSelected(index)) {
	this.select(index,false,true);
      }

      if (this.context == null) {
	this.createContextMenu();
      }

      this.context.items.each(function(item,index,length) {
	item.enable();
	this.updateContextItem(item,record);
      },this);
      
      (function(){
	 this.context.showAt(e.getXY());
	 this.updateButtons();
       }).defer(20,this);
    },

    getContextMenu: function() {
      if (this.context != null) {
	return this.context;
      }
      this.context = new Ext.menu.Menu({
	  itemId:'context'
      });
      var c = this.context;
      return c;
    },

    getToolbar: function() {
      if (this._tbar != null) {
	return this._tbar;
      }

      var tbar = new Ext.Toolbar({itemId:'toolbar'});
      tbar.insert(0,this.actions['RETRY']);
      tbar.insert(0,this.actions['REMOVE']);
      tbar.insert(0,this.actions['TB_FILL']);
//      tbar.insert(0,this.actions['HIDE_SUCCESS']);
      this._tbar = tbar;
      return tbar;
    },

    updateToolbar: function() {
      var sel = this.getSelectedRecords();
      var tbar = this.getToolbar();

//      Paperpile.log(sel);
      if (sel.length == 0) {
	tbar.items.each(function(item,index,length) {
	  item.disable();
	  if (item.itemId == this.actions['HIDE_SUCCESS'].itemId)
	    item.enable();
	},this);
      } else {
	tbar.items.each(function(item,index,length){
	    item.enable();
	},this);
      }
    },
/*
    refresh : function(){
      Paperpile.log("??");
      // Get a list of selected IDs.
      var sel = this.getSelectedRecords();
      
        this.clearSelections(false, false);
        var el = this.getTemplateTarget();
        el.update("");
        var records = this.store.getRange();
        if(records.length < 1){
            if(!this.deferEmptyText || this.hasSkippedEmptyText){
                el.update(this.emptyText);
            }
            this.all.clear();
        }else{
            this.tpl.overwrite(el, this.collectData(records, 0));
            this.all.fill(Ext.query(this.itemSelector, el.dom));	    
            this.updateIndexes(0);
        }
        this.hasSkippedEmptyText = true;

      for (var i=0; i < sel.length; i++) {
	var record = sel[i];
	var index = this.store.indexOf(record);
	this.select(index,true,false);
      }
    },
*/      
      
  initComponent: function() {

    this.actions = {
    'RETRY':new Ext.Action({
      text: 'Retry Tasks',
      handler:function(){this.queuePanel.retryJobs();},
      scope:this,
      iconCls:'pp-icon-retry'
    }),
    'REMOVE': new Ext.Action({
      text: 'Cancel Tasks',
      handler:function(){this.queuePanel.cancelJobs();},
      scope:this,
      cls: 'x-btn-text-icon',
      iconCls:'pp-icon-delete'
    }),
    'HIDE_SUCCESS':new Ext.Button({
      text: 'Hide Finished',
      itemId:'hide-success',
      handler:this.successButtonPress,
      scope:this,
      enableToggle:true
    }),
    'TB_FILL': new Ext.Toolbar.Fill({
	width:'10px',
	itemId:'search_tb_fill'
    })
    };

    this._store = new Ext.data.JsonStore({
      storeId: 'queue_store',
      autoDestroy: true,
      url: Paperpile.Url('/ajax/queue/grid'),
      method: 'GET',
      baseParams:{limit:50}
    });
    this.pager=new Ext.PagingToolbar({
      pageSize: 100,
      store: this._store,
      displayInfo: true,
      displayMsg: 'Tasks {0} - {1} of {2}',
      emptyMsg: "No tasks"
    });

    this.expander = new Ext.ux.grid.RowExpander({
	enableCaching:false,
	lazyRender:false,
	tpl: new Ext.Template(
	    '<p>{message}</p>'
	)
    });

    var statusColumn = {
      header: '',
      dataIndex: 'status',
      width:30,
      renderer: function(value, metaData, record, rowIndex, colIndex, store) {
	var status = value;
	var output = '';
	var icon = '';
	if (status == 'PENDING') {
	  icon = 'hourglass.png';
	} else if (status == 'RUNNING') {
	  icon = 'job-running.gif';
	} else if (status == 'DONE') {
	  icon = 'tick.png';
	} else if (status == 'ERROR') {
	  icon = 'cross.png';
	}
	output = '<img src="/images/icons/'+icon+'" ext:qtip="'+status+'"/>';
	return output;
      }
    };

    var typeColumn = {
      header: '',
      dataIndex: 'type',
      width:25,
      renderer: function(value, metaData, record, rowIndex, colIndex, store) {
	var output = '';
	var icon = '';
	if (value == 'PDF_SEARCH') {
	  icon = 'page_white_acrobat.png';
	} else if (value == 'PDF_IMPORT') {
	  icon = 'job-pdf-import.png';
	}
	output = '<img src="/images/icons/'+icon+'" ext:qtip="'+value+'"/>';
	return output;
      }
    };

    var authorColumn = {
      header: 'Author',
      dataIndex: 'authors',
      renderer: function(value, metaData, record, rowIndex, colIndex, store) {
	if (value == null)
	  return 'Unknown';
	var list = value.split(',');
	if (list.length >= 1) {
	  return list[0];
	}
	return value;
      }
    };

    var titleColumn = {
      header: 'Title',
      dataIndex: 'title',
      id:'title',
      renderer: function(value, metaData, record, rowIndex, colIndex, store) {
	if (value == null) {
	  if (record.data.pdf) {
	    var pdf = record.data.pdf;
	    var max_length = 30;
	    if (pdf.length > max_length) {
	      pdf = "..."+pdf.substring(pdf.length-max_length);
	    }
	    return "File: "+record.data.pdf;
	  }
	}
	var output = Ext.util.Format.ellipsis(value,200);
	return output;
      }
    };

    Ext.apply(this, {
      store: this._store,
      bbar: this.pager,
      tbar: this.getToolbar(),
      multiSelect: true,
      cm: new Ext.grid.ColumnModel({
	defaults: {
	  menuDisabled:true,
	  sortable:false
	},
	columns: [
	 this.expander,
	 statusColumn,
	 typeColumn,
	 titleColumn,
	 authorColumn
	]
      }),
      autoExpandColumn:'title',
      plugins:this.expander,
      hideHeaders:false
    });
    this.store.load();

    Paperpile.QueueList.superclass.initComponent.call(this);    

    this.on('afterrender', function() {
      this.getSelectionModel().on('afterselectionchange',this.selChanged,this);
      this.selChanged();
    },this);

  },

/*  successButtonPress: function(b,e) {
    var hide = 0;
    if (b.pressed)
      hide = 1;
  },
*/
  getSelectedRecords: function() {
    return this.getSelectionModel().getSelections();
  },

  getSelectedIds: function() {
    var sel = this.getSelectedRecords();
    var ids = [];
    for (var i=0; i < sel.length; i++) {
      ids.push(sel[i].data.id);
    }
    return ids;
  },

  selChanged: function(selections) {
    this.updateToolbar();
  },

  // onUpdate function for the Queue grid view.
  onUpdate: function(data) {
    var jobs = data.jobs;
    if (!jobs) {
      return;
    }

    //    this.store.suspendEvents();
    for (var id in jobs) {
      var index = this.store.find('id',id);
      var record=this.store.getAt(index);
      if (!record) {
//	Paperpile.log("Record "+id+" not found!");
	continue;
      }
      var needsUpdating = false;
      var update=jobs[id];
      record.editing = true;
      for (var field in update) {
	record.set(field,update[field]);
      }
      record.editing = false;
      if (record.dirty) {
	needsUpdating = true;
	// Auto-expand jobs when they give an error.
	if (field == 'status' && update[field] == 'ERROR') {
	  this.expander.expandRow(index);
	}
      }
      if (needsUpdating) {
	  this.store.fireEvent('update',this.store, record, Ext.data.Record.EDIT);
      }
    }
  }
				   
});

Paperpile.QueueOverview = Ext.extend(Ext.Panel, {
  layout: 'vbox',
			
  constructor: function(queuePanel,config) {
    this.queuePanel = queuePanel;
    Paperpile.QueueOverview.superclass.constructor.call(this,config);
  },
	    
  initComponent: function() {
    Ext.apply(this,{
      bodyStyle: {
	background: '#ffffff',
	padding: '7px'
      },
      autoScroll: true
    });

    Paperpile.QueueOverview.superclass.initComponent.call(this);

    this.tableTemplate = new Ext.XTemplate(
      '<div id="queue-table">',
      '<tpl for="queue.types">',
      '  <b>{name}</b><br/>',
      '  <div style="margin-top:3px;">',
      '  <div class="pp-job-table-div" style="margin-left:1em;"><img src="/images/icons/tick.png"/>Finished: {num_done}</div>',
      '  <div class="pp-job-table-div"><img src="/images/icons/cross.png"/>Failed: {num_error}</div>',
      '  <div class="pp-job-table-div"><img src="/images/icons/hourglass.png"/>Waiting: {num_pending}</div>',
      '  </div>',
      '</tpl>',
      '</div>',
      {
	compiled:true
      }
    );

    this.emptyTable = new Ext.XTemplate(
      '<div id="queue-table">',
      '  <p><b>The queue is empty.</b></p>',
      '</div>',
      {
	compiled:true
      }
    );

    this.shellTemplate = new Ext.XTemplate(
	    '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-top">',
	    '<h2>Overview</h2>',
	    '<div id="queue-table"></div>',
	    '<p>&nbsp;</p>',
	    '<h2>Progress</h2>',
	    '<div id="queue-progress"></div>',
	    '</div>',
	    
	    '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-bottom">',
	      //      '<h2>Actions</h2>',
	    '<table width="100%"><tr>',
	    '  <td><div id="pause-button"></div></td>',
	    '  <td><div id="cleanup-button"></div></td>',
	    '  <td><div id="cancel-button"></div></td>',
	    '</tr></table>',
	    '</div>'
    );

    this.pauseButton = new Ext.Button({
      text: 'Pause',
      cls: 'x-btn-text-icon pause',
      handler:this.pauseQueue,
      scope:this
    });
    this.cleanupButton = new Ext.Button({
      text: 'Clean Up',
      cls: 'x-btn-text-icon clean',
      handler:this.cleanQueue,
      scope:this
    });
    this.cancelButton = new Ext.Button({
      text: 'Cancel All',
      cls: 'x-btn-text-icon delete',
      handler:this.cancelAll,
      scope:this
    });
    this.queueProgress = new Ext.ProgressBar({ cls: 'pp-basic'});
    
    this.reloadTask = {
      run: function() {
        this.requestUpdate();
      },
      interval: 2000,
      scope:this
    };
    this.on('beforedestroy', function(){Ext.TaskMgr.stop(this.reloadTask);},this);
  },

  onRender: function(ct,position) {
    Paperpile.QueueOverview.superclass.onRender.call(this,ct,position);

    this.shellTemplate.overwrite(this.body);
    this.pauseButton.render('pause-button');
    this.cleanupButton.render('cleanup-button');
    this.cancelButton.render('cancel-button');
    this.queueProgress.render('queue-progress');

    Ext.TaskMgr.start(this.reloadTask);
  },

  pauseQueue: function() {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/pause_resume'),
      method: 'GET',
      params: {
      },
      success: function(response,opts) {
	var json = Ext.util.JSON.decode(response.responseText);
	Paperpile.main.onUpdate(json);
      },
      failure: function() {
      },
      scope:this
    });

  },

  cleanQueue: function() {
    this.queuePanel.clearJobs('all');
  },

  cancelAll: function() {
    this.queuePanel.cancelJobs('all');
  },

  // onUpdate for the Queue Overview.
  onUpdate: function(data) {
    var queue = data.queue;
    var types = data.queue.types

    if (types) {
      if (types.length == 0) {
	this.emptyTable.overwrite(Ext.get('queue-table'),data);
	this.queueProgress.updateProgress(0, 'No remaining tasks.');
      } else {
	this.tableTemplate.overwrite(Ext.get('queue-table'),data);
      }
    }

    if (queue) {
      var num_done = parseInt(queue.num_done);
      var num_pending = parseInt(queue.num_pending);
      var num_all = num_done + num_pending;
      var eta = queue.eta;
      
      if (queue.status == 'PAUSED') {
	this.queueProgress.updateProgress(0, 'Queue is paused.');
	this.pauseButton.setText('Resume');
	this.pauseButton.setIcon('/images/icons/resume.png');
      } else {
	this.pauseButton.setText('Pause');
	this.pauseButton.setIcon('/images/icons/pause.png');
      }

      if (queue.status == 'WAITING') {
	this.queueProgress.updateProgress(1, 'Queue processing complete.');
	this.pauseButton.setDisabled(true);
      } else {
	this.pauseButton.setDisabled(false );
	if (queue.status != 'PAUSED') {
	  this.queueProgress.updateProgress(num_done/num_all, num_done+ ' of '+num_all+' tasks completed');
	}
      }
    }
  },

  requestUpdate: function() {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/overview'),
      method: 'GET',
      params: {
      },
      success: function(response) {
	var obj = Ext.util.JSON.decode(response.responseText);
	this.onUpdate(obj);

	if (obj.queue) {
	  if (obj.queue.status == 'WAITING') {
	      //Ext.TaskMgr.stop(this.reloadTask);
	  }
	}
      },
      failure: function() {
      },
      scope:this
    });
  }
});