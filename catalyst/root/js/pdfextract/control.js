Paperpile.PdfExtractControl = Ext.extend(Ext.Panel, {

    matchPlugin: 'PubMed',

    statusMsgTpl: ['<tpl if="number">', '<b>{number}</b> PDFs in the list are not yet in your library and can be automatically imported.', '</tpl>', '<tpl if="!number">', 'All files imported.', '</tpl>', ],

    markup: ['<div class="pp-box pp-box-style1"', '<h2>Import PDFs</h2>', '<p id="status-msg-{id}"></p>', '<div class="pp-control-container">', '<table><tr>', '</tr></table>', '</div>', '<div id="start-container-{id}" class="pp-control-container"></div>', '<p>&nbsp;</p>', '<div id="pbox-container-{id}" class="pp-control-container"></div>', '</div>', ],

    initComponent: function() {
        Ext.apply(this, {
            cancelProcess: 0,
            bodyStyle: {
                background: '#ffffff',
                padding: '7px'
            },
            autoScroll: true,
        });

        Paperpile.PdfExtractControl.superclass.initComponent.call(this);
    },

    getUnimportedList: function() {

        var list = [];

        this.grid.store.each(
        function(record) {
            if (record.get('status') != 'IMPORTED') {
                list.push(record);
            }
        });

        return list;
    },

    updateView: function() {
        var list = this.getUnimportedList();

        var tpl = new Ext.XTemplate(this.statusMsgTpl);
        tpl.overwrite('status-msg-' + this.id, {
            number: list.length
        });

        if (list.length == 0) {
            this.startButton.disable();
        }

    },

    initControls: function(data) {
        this.grid = this.ownerCt.ownerCt.items.get('center_panel').items.get('grid');

        var list = this.getUnimportedList();

        var tpl = new Ext.XTemplate(this.markup);

        tpl.overwrite(this.body, {
            number: list.length,
            id: this.id
        });

        this.startButton = new Ext.Button({
            renderTo: "start-container-" + this.id,
            text: 'Match and import all PDFs',
            handler: function() {
                this.importAll();
            },
            scope: this,
        });

        this.updateView();

    },

    importAll: function() {

        var list = this.getUnimportedList();

        this.pbox = new Paperpile.ProgressBox({
            el: "pbox-container-" + this.id,
            totalItems: list.length,
            pbarWidth: 200,
            onCancel: function() {
                this.cancelProcess = 1;
                this.pbox.destroy();
                this.startButton.enable();
            },
            formatStatus: function(item) {
                return item.get('file_name');
            },
            scope: this
        });

        this.startButton.disable();

        this.processList(
        list, 0, this.importPDF, function() {
            this.cancelProcess = 0;
            this.pbox.destroy();
            this.updateView();
            this.startButton.enable();
        },
        this, this.pbox);
    },

    processList: function(list, index, fn, callback, scope, pbox) {

        var item = list[index++];

        if (index <= list.length && !this.cancelProcess) {
            pbox.update(index, item);
            fn.createDelegate(scope, [item, function() {
                this.processList(list, index, fn, callback, scope, pbox);
            },
            this])();
        } else {
            callback.createDelegate(scope)();
        }
    },

    importPDF: function(record, callback, scope) {

        var file_name = record.get('file_name');

        var row = this.grid.store.indexOfId(file_name);

        Ext.DomHelper.overwrite(this.grid.getView().getCell(row, 4), '<div class="pp-icon-loading">Matching...</div>');

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/pdfextract/import'),
            params: {
                root: this.grid.root,
                grid_id: this.grid.id,
                match_plugin: this.matchPlugin,
                file_name: file_name,
            },
            method: 'GET',
            success: function(response) {
                var json = Ext.util.JSON.decode(response.responseText);
                var record = this.grid.store.getAt(row);
                Ext.DomHelper.overwrite(this.grid.getView().getCell(row, 4), '');
                record.beginEdit();
                for (var i in json.data) {
                    record.set(i, json.data[i]);
                }
                record.endEdit();

                Paperpile.main.onUpdateDB();

                if (callback) {
                    callback.createDelegate(scope)();
                }
            },
            failure: this.importPDFError,
            scope: this,
            timeout: 600000,
        });
    },

    importPDFError: function() {
        Paperpile.main.onError(arguments);
        this.startButton.enable();
    }
});

Paperpile.ProgressBox = Ext.extend(Ext.BoxComponent, {

    pbarWidth: 100,

    initComponent: function() {
        Ext.apply(this, {
            bodyStyle: {
                background: '#ffffff',
                padding: '7px'
            },
            autoScroll: true,
        });

        Paperpile.ProgressBox.superclass.initComponent.call(this);

        Ext.DomHelper.append(this.el, '<table><tr>' + '<td><div id="pbar-' + this.id + '" style="width:' + this.pbarWidth + '"></div></td>' + '<td><div id="cancel-' + this.id + '" class="pp-basic pp-textlink-control">' + '<a href="#">Cancel</a>' + '</div></td>' + '</tr></table>' + '<div id="status-' + this.id + '"></div>');

        this.pbar = new Ext.ProgressBar({
            cls: 'pp-basic'
        });

        this.pbar.render('pbar-' + this.id, 0);

        Ext.get('cancel-' + this.id).first().on('click', this.onCancel.createDelegate(this.scope));

    },

    update: function(n, currentItem) {

        this.pbar.updateProgress(n / this.totalItems, n + ' of ' + this.totalItems);

        var text = this.formatStatus(currentItem);

        Ext.DomHelper.overwrite('status-' + this.id, {
            tag: 'div',
            cls: 'pp-basic pp-progress-box-status',
            html: text,
        });

    },

    destroy: function() {
        this.pbar.destroy();

        var el;
        while (el = Ext.get(this.el).first()) {
            el.remove();
        }

    }

});