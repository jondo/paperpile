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

Paperpile.QueueList = Ext.extend(Ext.grid.GridPanel, {

  constructor: function(queuePanel, config) {
    this.queuePanel = queuePanel;
    Paperpile.QueueList.superclass.constructor.call(this, config);
  },

  onContextClick: function(grid, index, e) {
    e.stopEvent();
    var record = this.store.getAt(index);
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
      data.shortTitle = Ext.util.Format.ellipsis(data.title, 70, true);
    } else {
      data.shortTitle = null;
    }

    data.errorReportInfo = data.title + ' | ' + data.authors + ' | ';
    data.errorReportInfo += data.citation + ' | ' + data.doi + ' | ' + data.linkout;

    data.gridID=this.id;

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
          this.queuePanel.retryJobs();
        },
        scope: this,
        iconCls: 'pp-icon-retry'
      }),
      'REMOVE': new Ext.Action({
        text: 'Cancel Tasks',
        tooltip: 'Cancel selected tasks',
        handler: function() {
          this.queuePanel.cancelJobs();
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

    this._store = new Ext.data.JsonStore({
      storeId: 'queue_store',
      autoDestroy: true,
      url: Paperpile.Url('/ajax/queue/grid'),
      method: 'GET',
      baseParams: {
        limit: 50
      }
    });
    this.pager = new Ext.PagingToolbar({
      pageSize: 100,
      store: this._store,
      displayInfo: true,
      displayMsg: 'Tasks {0} - {1} of {2}',
      emptyMsg: "No tasks"
    });

    this.dataTemplate = new Ext.XTemplate(
      '<div style="padding: 4px 0;">',
      '  <tpl if="type==\'PDF_SEARCH\'">',
      '    <div class="pp-queue-list-data">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}">{shortAuthors} <b>{shortTitle}</b></div>',
      '      <div class="pp-queue-list-status pp-queue-list-status-{status}">',
      '        {message}',
      '      </div>',
      '      <tpl if="status==\'ERROR\'">',
      '        <p><a href="#" class="pp-textlink" onclick="Paperpile.main.reportPdfDownloadError(\'{errorReportInfo}\');">Send Error Report</a></p> ',
      '      </tpl>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="type==\'PDF_IMPORT\'">',
      '    <div class="pp-queue-list-data">',
      '      <div class="pp-queue-list-title pp-queue-list-title-{status}">',
      '      <tpl if="status!=\'DONE\'">{pdf} </tpl> ',
      '      <tpl if="shortAuthors">{shortAuthors} </tpl> <tpl if="shortTitle"><b>{shortTitle}</b></tpl>',
      '      </div>',
      '      <div class="pp-queue-list-status pp-queue-list-status-{status}">',
      '      {message}',
      '      </div>',
      '      <tpl if="status==\'ERROR\'">',
      '        <p>',
      '          <a href="#" class="pp-textlink" onclick="Paperpile.main.addPDFManually(\'{id}\',\'{gridID}\');">Insert data manually</a> | ',
      '          <a href="#" class="pp-textlink" onclick="Paperpile.main.reportPdfMatchError(\'{pdf}\');">Send Error Report</a>',
      '       </p>',
      '      </tpl>',
      '    </div>',
      '  </tpl>',
      '</div>').compile();

    this.typeTemplate = new Ext.XTemplate(
      '<div style="padding: 4px 0;">',
      '  <tpl if="type==\'PDF_SEARCH\'">',
      '    <span class="pp-queue-type-label-{type}">Search PDF</span>',
      '  </tpl>',
      '  <tpl if="type==\'PDF_IMPORT\'">',
      '    <span class="pp-queue-type-label-{type}">Match PDF</span>',
      '  </tpl>',
      '</div>').compile();

    this.statusTemplate = new Ext.XTemplate(
      '<div class="pp-queue-list-icon pp-queue-list-icon-{status}"><tpl if="status==\'PENDING\'">Waiting</tpl>').compile();

    Ext.apply(this, {
      store: this._store,
      bbar: this.pager,
      tbar: this.getToolbar(),
      multiSelect: true,
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
    this.store.load();

    Paperpile.QueueList.superclass.initComponent.call(this);

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

    for (var id in jobs) {
      var index = this.store.find('id', id);
      var record = this.store.getAt(index);
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
        this.store.fireEvent('update', this.store, record, Ext.data.Record.EDIT);
      }
    }
  },

  shortAuthors: function(names) {
    var list = names.split(',');
    if (list.length > 1) {
      return list[0] + " <i>et al.</i>";
    } else {
      return names;
    }
  }

});