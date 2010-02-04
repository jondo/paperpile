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

    renderItem: function(value, meta, record, row, col, store) {

        var data = record.data;

        if (data.size && data.downloaded && data.status === 'RUNNING') {
            data.message = 'Downloading (' + Math.round((data.downloaded / data.size) * 100) + '%)';
        }

        if (data.authors) {
            data.shortAuthors = this.shortAuthors(data.authors);
        } else {
            data.shortAuthors = null;
        }

        if (data.title) {
            data.shortTitle = Ext.util.Format.ellipsis(data.title, 100, true);
        } else {
            data.shortTitle = null;
        }

        return this.itemTemplate.apply(data);
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

        this.itemTemplate = new Ext.XTemplate('<div class="pp-queue-list-container">', '  <tpl if="type==\'PDF_SEARCH\'">', '    <div class="pp-queue-list-type"><span class="pp-queue-type-label-{type}">Search PDF</span></div>', '    <div class="pp-queue-list-data">', '      <div class="pp-queue-list-title pp-queue-list-title-{status}">{shortAuthors} <b>{shortTitle}</b></div>', '      <div class="pp-queue-list-status pp-queue-list-status-{status}">', '        {message}', '      </div>', '    </div>', '  </tpl>', '  <tpl if="type==\'PDF_IMPORT\'">', '    <div class="pp-queue-list-type"><span class="pp-queue-type-label-{type}">Import PDF</span></div>', '    <div class="pp-queue-list-data">', '      <div class="pp-queue-list-title pp-queue-list-title-{status}">', '      <tpl if="status!=\'DONE\'">{pdf} </tpl> ', '      <tpl if="shortAuthors">{shortAuthors} </tpl> <tpl if="shortTitle"><b>{shortTitle}</b></tpl>', '      </div>', '      <div class="pp-queue-list-status pp-queue-list-status-{status}">', '      {message}', '      </div>', '    </div>', '  </tpl>', '  <div class="pp-queue-list-icon pp-queue-list-icon-{status}"><tpl if="status==\'PENDING\'">Waiting</tpl></div>', '</div>').compile();

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
                    header: "Tasks",
                    id: 'title',
                    dataIndex: 'title',
                    renderer: this.renderItem.createDelegate(this),
                    sortable: false,
                    resizable: false
                },
                ]
            }),
            autoExpandColumn: 'title',
            hideHeaders: false
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