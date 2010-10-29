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
      data.reportString = string+"\n\n"+job;
      Paperpile.main.reportPdfDownloadError(data);
      break;
    case 'pdf-download-open-url':
      Paperpile.utils.openURL(data.publisherLink);
      break;
    case 'pdf-view':
      var path;
      if (data._pdf_tmp){
        path = data._pdf_tmp;
      } else {
        path = data.pdf;
      }
      Paperpile.utils.openFile(path);
      break;
    }
  },

  onContextClick: function(grid, index, e) {
    e.stopEvent();
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

  getToolbar: function() {
    if (this._tbar != null) {
      return this._tbar;
    }

    var tbar = new Ext.Toolbar({
      itemId: 'toolbar'
    });
    tbar.insert(0, this.actions['REMOVE']);
    tbar.insert(0, this.actions['RETRY']);
    tbar.insert(0, this.actions['TB_FILL']);

    this._tbar = tbar;
    return tbar;
  },

  updateToolbar: function() {
    var sel = this.getSelectedRecords();
    var tbar = this.getToolbar();

    if (sel.length == 0) {
      tbar.items.each(function(item, index, length) {
        item.disable();
      },
      this);
    } else {
      tbar.items.each(function(item, index, length) {
        item.enable();
      },
      this);
    }
  },

  renderData: function(value, meta, record) {

    var data = record.data;

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

  renderType: function(value, meta, record) {
    var data = record.data;
    return this.typeTemplate.apply(data);
  },

  renderStatus: function(value, meta, record) {
    var data = record.data;
    return this.statusTemplate.apply(data);
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
      'REMOVE': new Ext.Action({
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
      '<div style="padding: 4px 0;">',
      '  <tpl if="type==\'PDF_SEARCH\'">',
      '    <div class="pp-queue-list-data">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}">{shortAuthors} <b>{shortTitle}</b> <i>{journal}</i></div>',
      '      <div class="pp-queue-list-status pp-queue-list-status-{status}">',
      '        {message}',
      '      </div>',
      '      <tpl if="status==\'ERROR\'">',
      '        <p>',
      '           <tpl if="publisherLink">',
      '             <a href="#" class="pp-textlink" action="pdf-download-open-url">Go to publisher site</a> | ',
      '           </tpl>',
      '           <a href="#" class="pp-textlink" action="pdf-download-error-report">Send Error Report</a>',
      '       </p> ',
      '      </tpl>',
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

      '</div>').compile();

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
      tbar: this.getToolbar(),
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
          resizable: false
        },
        ]
      }),
      autoExpandColumn: 'title',
      hideHeaders: true
    });
    Paperpile.QueueList.superclass.initComponent.call(this);

    this.getStore().load();

    this.on('afterrender', function() {
      this.getSelectionModel().on('afterselectionchange', this.selChanged, this);
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
    this.updateToolbar();
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