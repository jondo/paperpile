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

Paperpile.QueueList = function(config) {
  Ext.apply(this, config);
  Paperpile.QueueList.superclass.constructor.call(this, {});

  this.on('rowcontextmenu', this.onContextClick, this);

  this.on('rowclick', this.onRowClick, this);

};

Ext.extend(Paperpile.QueueList, Ext.grid.GridPanel, {

  onRowClick: function(grid, rowIndex, e) {
    var el = e.getTarget();
    var record = this.getStore().getAt(rowIndex);
    var data = record.data;
    switch (el.getAttribute('action')) {
    case 'pdf-match-error-report':
      data.reportString = Paperpile.utils.hashToString(data);
      data.file = record.data['_pdf_tmp'];
      Paperpile.main.reportPdfMatchError(data);
      break;
    case 'pdf-match-insert-manually':
      Paperpile.main.addPDFManually(data.id, data.gridID);
      break;
    case 'pdf-download-error-report':
      var string = Paperpile.utils.hashToString(data);
      var job = Paperpile.utils.hashToString(data._search_job);
      data.reportString = string + "\n\n" + job;
      Paperpile.main.reportPdfDownloadError(data);
      break;
    case 'pdf-download-open-url':
      Paperpile.utils.openURL(data.publisherLink);
      break;
    case 'pdf-view':
      var path;
      // Find the right field depending on the circumstances...
      if (data._pdf_tmp) {
        path = data._pdf_tmp;
      } else {
        if (data.pdf_name){
          path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, data.pdf_name);
        } else {
          path = data.pdf;
        }
      }
      Paperpile.utils.openFile(path);
      break;
    case 'cancel-task':
      this.getQueuePanel().cancelJobs();
      break;
    case 'retry-task':
      this.getQueuePanel().retryJobs();
      break;
    }
  },

  onContextClick: function(grid, index, e) {
    e.stopEvent();
    return;
    var record = this.getStore().getAt(index);
    if (!this.isSelected(index)) {
      this.select(index, false, true);
    }

    if (this.context == null) {
      this.createContextMenu();
    }

    this.context.items.each(function(item, index, length) {
      item.enable();
      this.updateContextItem(item, record);
    },
    this);

    (function() {
      this.context.showAt(e.getXY());
      this.updateButtons();
    }).defer(20, this);
  },

  getQueuePanel: function() {
    return this.findParentByType(Paperpile.QueuePanel);
  },

  getContextMenu: function() {
    if (this.context != null) {
      return this.context;
    }
    this.context = new Ext.menu.Menu({
      itemId: 'context'
    });
    var c = this.context;
    return c;
  },

  renderData: function(value, meta, record) {

    var data = record.data;

    Paperpile.log(data.message);

    if (data.size && data.downloaded && data.status === 'RUNNING') {
      data.message = 'Downloading (' + Math.round((data.downloaded / data.size) * 100) + '%)';
    }

    if (data.authors) {
      data.shortAuthors = this.shortAuthors(data.authors_display);
    } else {
      data.shortAuthors = null;
    }

    if (data.title) {
      data.shortTitle = Ext.util.Format.ellipsis(data.title, 65, true);
    } else {
      data.shortTitle = null;
    }

    data.publisherLink = null;

    if (data.doi) {
      data.publisherLink = 'http://dx.doi.org/' + data.doi;
    } else {
      if (data.linkout) {
        data.publisherLink = data.linkout;
      }
    }

    data.gridID = this.id;

    return this.dataTemplate.apply(data);
  },

  renderStatus: function(value, meta, record) {
    var data = record.data;
    return this.statusTemplate.apply(data);
  },

  renderType: function(value, meta, record) {
    var data = record.data;
    return this.typeTemplate.apply(data);
  },

  initComponent: function() {

    this.actions = {
      'RETRY': new Ext.Action({
        text: 'Retry Tasks',
        tooltip: 'Run selected tasks again',
        handler: function() {
          this.getQueuePanel().retryJobs();
        },
        scope: this,
        iconCls: 'pp-icon-retry'
      }),
      'CANCEL': new Ext.Action({
        text: 'Cancel Tasks',
        tooltip: 'Cancel selected tasks',
        handler: function() {
          this.getQueuePanel().cancelJobs();
        },
        scope: this,
        cls: 'x-btn-text-icon',
        iconCls: 'pp-icon-cancel'
      }),
      'TB_FILL': new Ext.Toolbar.Fill({
        width: '10px',
        itemId: 'search_tb_fill'
      })
    };

    var pager = new Ext.PagingToolbar({
      pageSize: 100,
      store: this.getStore(),
      displayInfo: true,
      displayMsg: 'Tasks {0} - {1} of {2}',
      emptyMsg: "No tasks"
    });


    this.dataTemplate = new Ext.XTemplate(
      
      '<div>',
      '    <tpl if="type==\'PDF_SEARCH\'||type==\'METADATA_UPDATE\'">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}"><b>{shortTitle}</b></div>',
      '      <div class="pp-queue-list-citation">{shortAuthors} <tpl if="year">({year}) </tpl> <i>{journal}</i></div></div>',
      '    </tpl>',
      '    <tpl if="type==\'PDF_IMPORT\'">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}"><b>{_pdf_tmp}</b></div>',
      '       <tpl if="status==\'DONE\'">',
      '         <div class="pp-queue-list-citation"><b>{shortTitle}</b> {shortAuthors} <tpl if="year">({year}) </tpl> <i>{journal}</i></div></div>',
      '       </tpl>',
      '    </tpl>',
      '     <div class="pp-queue-list-status-container"><span class="pp-queue-list-status pp-queue-list-status-{status}">{message}</span></div>',
      '     <div class="pp-queue-list-action">',
      '       <tpl if="status==\'DONE\'">',
      '         <tpl if="type==\'PDF_SEARCH\'||type==\'PDF_IMPORT\'"><a href="#" class="pp-textlink" action="pdf-view">View PDF</a></tpl>',
      '       </tpl>',
      '       <tpl if="status==\'ERROR\'">',
      '         <tpl if="type==\'PDF_SEARCH\'">',
      '           <tpl if="publisherLink">',
      '               <a href="#" class="pp-textlink" action="pdf-download-open-url">Go to publisher site</a> | ',
      '            </tpl>',
      '            <a href="#" class="pp-textlink" action="pdf-download-error-report">Send Error Report</a> |',
      '         </tpl>',
      '         <tpl if="type==\'PDF_IMPORT\'">',
      '            <a href="#" class="pp-textlink" action="pdf-match-insert-manually">Insert Data Manually</a> |',
      '            <a href="#" class="pp-textlink" action="pdf-match-error-report">Send Error Report</a> ',
      '         </tpl>',
      '        <tpl if="type==\'PDF_SEARCH\'||type==\'METADATA_UPDATE\'"><a href="#" class="pp-textlink" action="retry-task"> Retry</a></tpl>',
      '       </tpl>',
      '       <tpl if="status==\'RUNNING\'||status==\'PENDING\'">',
      '          <a href="#" class="pp-textlink" action="cancel-task">Cancel</a>',
      '       </tpl>',
      '     </div> ',
      '</div>'
      
    ).compile();
    
    /*
    this.dataTemplate = new Ext.XTemplate(
      '<div style="padding: 4px 0;">',
      '  <tpl if="type==\'PDF_SEARCH\'">',
      '    <div class="pp-queue-list-data">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}"><b>{shortTitle}</b><br><span class="pp-inactive">{shortAuthors} <tpl if="year">({year}) </tpl> <i>{journal}</i></span></div>',
      '<div class="pp-queue-list-box">',
      '      <div class="pp-queue-list-status pp-queue-list-status-{status}">',
      '        {message}',
      '      <tpl if="status==\'DONE\'"><div class="pp-queue-list-action"><a href="#" class="pp-textlink" action="pdf-view">View PDF</a></div></tpl>',
      '      </div>',
      '      <tpl if="status==\'ERROR\'">',
      '        <div class="pp-queue-list-action">',
      '           <tpl if="publisherLink">',
      '             <a href="#" class="pp-textlink" action="pdf-download-open-url">Go to publisher site</a> | ',
      '           </tpl>',
      '           <a href="#" class="pp-textlink" action="pdf-download-error-report">Send Error Report</a>',
      '         </div> ',
      '      </tpl>',
      ' {[this.drawStatus(values.status)]} </div>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="type==\'PDF_IMPORT\'">',
      '    <div class="pp-queue-list-data">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}">',
      '      <tpl if="status!=\'DONE\'">{_pdf_tmp} </tpl> ',
      '      <tpl if="status!=\'ERROR\'">',
      '        <tpl if="shortAuthors">{shortAuthors} </tpl> <tpl if="shortTitle"><b>{shortTitle}</b></tpl> <tpl if="journal"><i>{journal}</i></tpl>',
      '      </tpl> ',
      '      </div>',
      '      <div class="pp-queue-list-status pp-queue-list-status-{status}">',
      '      {message}',
      '      </div>',
      '      <tpl if="status==\'ERROR\'">',
      '        <p>',
      '          <a href="#" class="pp-textlink" action="pdf-match-insert-manually">Insert data manually</a> | ',
      '          <a href="#" class="pp-textlink" action="pdf-view">View PDF</a> | ',
      '          <a href="#" class="pp-textlink" action="pdf-match-error-report">Send Error Report</a>',
      '       </p>',
      '      </tpl>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="type==\'METADATA_UPDATE\'">',
      '    <div class="pp-queue-list-data">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}">{shortAuthors} <b>{shortTitle}</b> <i>{journal}</i></div>',
      '      <div class="pp-queue-list-status pp-queue-list-status-{status}">',
      '        {message}',
      '      </div>',
      '      <tpl if="status==\'ERROR\'">',
      '        <p>',
      '           <tpl if="publisherLink">',
      '             <a href="#" class="pp-textlink" onclick="Paperpile.utils.openURL(\'{publisherLink}\')">Go to publisher site</a> | ',
      '           </tpl>',
      '       </p> ',
      '      </tpl>',
      '    </div>',
      '  </tpl>',
      '</div>', {
        drawStatus: function(status) {
          var content = '<div class="pp-queue-list-icon pp-queue-list-icon-'+status+'">';
          if (status === 'PENDING') {
            content += 'Waiting';
          }
          if (status === 'PENDING') {
            content += '<div style="padding: 0 0 0 30px"><a href="#" class="pp-textlink" action="cancel-task">Cancel</a></div>';
          }
          return ('<div style="float:right;">'+content+'</div>');
        }
      }).compile();*/


    this.typeTemplate = new Ext.XTemplate(
      '<div style="padding: 4px 0;">',
      '  <tpl if="type==\'PDF_SEARCH\'">',
      '    <span class="pp-queue-type-label-{type}">Download PDF</span>',
      '  </tpl>',
      '  <tpl if="type==\'PDF_IMPORT\'">',
      '    <span class="pp-queue-type-label-{type}">Import PDF</span>',
      '  </tpl>',
      '  <tpl if="type==\'METADATA_UPDATE\'">',
      '    <span class="pp-queue-type-label-{type}">Auto-complete</span>',
      '  </tpl>',
      '</div>').compile();

    this.statusTemplate = new Ext.XTemplate(
      '<div class="pp-queue-list-icon pp-queue-list-icon-{status}"><tpl if="status==\'PENDING\'">Waiting</tpl>').compile();
    
    Ext.apply(this, {
      store: this.getStore(),
      bbar: pager,
      multiSelect: true,
      selModel: new Ext.ux.BetterRowSelectionModel(),
      cm: new Ext.grid.ColumnModel({
        defaults: {
          menuDisabled: true,
          sortable: false
        },
        columns: [{
          header: "Task",
          id: 'type',
          dataIndex: 'type',
          renderer: this.renderType.createDelegate(this),
          sortable: false,
          resizable: false
        },
        {
          header: "Data",
          id: 'title',
          dataIndex: 'title',
          renderer: this.renderData.createDelegate(this),
          sortable: false,
          resizable: false
        },
        {
          header: "Icon",
          id: 'status',
          dataIndex: 'status',
          renderer: this.renderStatus.createDelegate(this),
          sortable: false,
          resizable: false,
          width: 70,
        }]
      }),
      autoExpandColumn: 'title',
      hideHeaders: true
    });
    Paperpile.QueueList.superclass.initComponent.call(this);

    this.getStore().load();

    this.on('afterrender', function() {
      this.mon(this.getSelectionModel(), 'afterselectionchange', this.selChanged, this);
      this.selChanged();
    },
    this);

  },

  getSelectedRecords: function() {
    return this.getSelectionModel().getSelections();
  },

  getSelectedIds: function() {
    var sel = this.getSelectedRecords();
    var ids = [];
    for (var i = 0; i < sel.length; i++) {
      ids.push(sel[i].data.id);
    }
    return ids;
  },

  selChanged: function(selections) {

  },

  // onUpdate function for the Queue grid view.
  onUpdate: function(data) {
    var jobs = data.jobs;
    if (!jobs) {
      return;
    }

    var store = this.getStore();
    for (var id in jobs) {
      var record = store.getAt(this.store.findExact('id', id));
      if (!record) {
        continue;
      }

      var needsUpdating = false;
      var update = jobs[id];
      record.editing = true;
      for (var field in update) {
        record.set(field, update[field]);
      }
      record.set('size', update.info.size);
      record.set('downloaded', update.info.downloaded);
      record.editing = false;

      if (record.dirty) {
        needsUpdating = true;
      }
      if (needsUpdating) {
        store.fireEvent('update', store, record, Ext.data.Record.EDIT);
      }
    }
  },

  backgroundReload: function() {
    this.backgroundLoading = true;

    this.getStore().reload({
      callback: function() {
        this.backgroundLoading = false;
      },
      scope: this
    });
  },

  getStore: function() {
    if (this._store != null) {
      return this._store;
    }
    this._store = new Ext.data.Store({
      proxy: new Ext.data.HttpProxy({
        url: Paperpile.Url('/ajax/queue/grid'),
        method: 'GET'
      }),
      baseParams: {
        limit: 100
      },
      reader: new Ext.data.JsonReader()
    });
    return this._store;
  },

  shortAuthors: function(names) {
    var list = names.split(',');
    if (list.length > 1) {
      return list[0] + " <i>et al.</i>";
    } else {
      return names;
    }
  },

  destroy: function() {
    Paperpile.QueueList.superclass.destroy.call(this);

    if (this._store) {
      this._store.destroy();
    }

    if (this.context) {
      this.context.destroy();
    }
  }

});