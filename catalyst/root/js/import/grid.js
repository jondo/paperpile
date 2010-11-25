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

Paperpile.PluginGrid = function(config) {

  Ext.apply(this, config);

  Paperpile.PluginGrid.superclass.constructor.call(this, {});

  this.on('rowcontextmenu', this.onContextClick, this);
};

Ext.extend(Paperpile.PluginGrid, Ext.grid.GridPanel, {

  plugin_query: '',
  region: 'center',
  limit: 25,
  allImported: false,
  itemId: 'grid',
  overviewPanel: null,
  detailsPanel: null,
  labelStyles: {},
  isLocked: false,

  initComponent: function() {

    this.pager = new Paperpile.Pager({
      pageSize: this.limit,
      store: this.getStore(),
      grid: this,
      // Provide a reference back to this grid!
      displayInfo: true,
      displayMsg: '<span style="color:black;">Displaying {0} - {1} of {2}</span>',
      emptyMsg: "No references to display"
    });

    var renderPub = function(value, p, record) {
      record.data._notes_tip = Ext.util.Format.stripTags(record.data.annote);
      record.data._citekey = Ext.util.Format.ellipsis(record.data.citekey, 18);
      record.data._createdPretty = Paperpile.utils.prettyDate(record.data.created);

      if (record.data.doi) {
        var wrapped = record.data.doi;

        if (wrapped.length > 25) {
          wrapped = wrapped.replace(/\//, '/<br/>');
        }

        record.data._doiWrapped = wrapped;
      }

      // Shrink very long author lists.
      record.data._long_authorlist = 0;
      var ad = record.data._authors_display || '';
      var authors_array = ad.split(",");

      var n = authors_array.length;
      var author_length_threshold = 25;
      var author_keep_beginning = 5;
      var author_keep_end = 5;
      if (authors_array.length > author_length_threshold) {
        var authors_first_five = authors_array.slice(0, author_keep_beginning);
        var authors_middle = authors_array.slice(author_keep_beginning, n - author_keep_end);
        var hidden_n = authors_middle.length;
        var authors_last_five = authors_array.slice(n - author_keep_end, n);
        record.data._authors_display = [
          authors_first_five.join(", "),
          ' ... <a class="pp-authortip">',
          '(' + hidden_n + ' more)',
          '</a> ... ',
          authors_last_five.join(", ")].join("");

        var displayText = [
          '<b>' + n + ' authors:</b> ',
          authors_array.join(", ")].join("");
        record.data._authortip = displayText;
      }

      return this.getPubTemplate().apply(record.data);
    };

    var renderIcons = function(value, p, record) {
      record.data._notes_tip = Ext.util.Format.stripTags(record.data.annote);
      record.data._citekey = Ext.util.Format.ellipsis(record.data.citekey, 18);
      record.data._createdPretty = Paperpile.utils.prettyDate(record.data.created);

      if (record.data._imported) {
        if (record.data.last_read) {
          record.data._last_readPretty = 'Last read: ' + Paperpile.utils.prettyDate(record.data.last_read);
        } else {
          record.data._last_readPretty = 'Never read';
        }
      } else {
        record.data._last_readPretty = 'Click <i>Import</i> to add file to your library.';
      }

      if (record.data.attachments) {
        record.data._attachments_count = record.data.attachments.split(/,/).length;
      }

      return this.getIconTemplate().apply(record.data);
    };

    this.actions = {
      'EDIT': new Ext.Action({
        text: 'Edit',
        handler: function() {
          this.handleEdit(false);
        },
        scope: this,
        cls: 'x-btn-text-icon edit',
        icon: '/images/icons/pencil.png',
        itemId: 'EDIT',
        triggerKey: 'e',
        tooltip: 'Edit the selected reference'
      }),
      'AUTO_COMPLETE': new Ext.Action({
        text: 'Auto-complete Data',
        handler: this.updateMetadata,
        scope: this,
        cls: 'x-btn-text-icon edit',
        icon: '/images/icons/reload.png',
        itemId: 'AUTO_COMPLETE',
        tooltip: 'Auto-complete citation with data from online resources.'
      }),

      'DELETE': new Ext.Action({
        text: 'Move to Trash',
        iconCls: 'pp-icon-trash',
        handler: this.handleDelete,
        scope: this,
        cls: 'x-btn-text-icon',
        itemId: 'DELETE',
        triggerKey: 'd',
        tooltip: 'Move selected references to Trash'
      }),

      'EXPORT': new Ext.Action({
        text: 'Export',
        handler: this.handleExport,
        scope: this,
        triggerKey: 'x',
        itemId: 'EXPORT'
      }),

      'FORCE_SELECT_ALL': new Ext.Action({
        text: 'Select all',
        handler: this.forceSelectAll,
        scope: this,
        itemId: 'FORCE_SELECT_ALL'
      }),

      'SELECT_ALL': new Ext.Action({
        text: 'Select all',
        handler: function() {
	    this.selectAll();
	},
        scope: this,
        itemId: 'SELECT_ALL'
      }),

      'FORMAT': new Ext.Action({
        text: 'Format',
        handler: this.formatEntry,
        scope: this,
        itemId: 'FORMAT'
      }),
      'OPEN_PDF_FOLDER': new Ext.Action({
        text: 'Show in folder',
        handler: this.openPDFFolder,
        scope: this,
        icon: '/images/icons/folder.png',
        itemId: 'OPEN_PDF_FOLDER',
        tooltip: 'Show in folder',
        disabledTooltip: 'No PDF attached to this reference'
      }),
      'VIEW_PDF': new Ext.Action({
        handler: this.viewPDF,
        scope: this,
        iconCls: 'pp-icon-import-pdf',
        itemId: 'VIEW_PDF',
        text: 'View PDF',
        triggerKey: 'v',
        disabledTooltip: 'No PDF attached to this reference'
      }),
      'MORE_FROM_FIRST_AUTHOR': new Ext.Action({
        // Note: the text of these menu items will change dynamically depending on
        // the selected reference. See the 'updateContextMenuItem' method.
        text: 'First Author',
        handler: this.moreFromFirstAuthor,
        scope: this,
        itemId: 'MORE_FROM_FIRST_AUTHOR'
      }),
      'MORE_FROM_LAST_AUTHOR': new Ext.Action({
        text: 'Last Author',
        handler: this.moreFromLastAuthor,
        scope: this,
        itemId: 'MORE_FROM_LAST_AUTHOR'
      }),
      'MORE_FROM_JOURNAL': new Ext.Action({
        text: 'Journal',
        handler: this.moreFromJournal,
        scope: this,
        itemId: 'MORE_FROM_JOURNAL'
      }),
      'MORE_FROM_YEAR': new Ext.Action({
        text: 'Year',
        handler: this.moreFromYear,
        scope: this,
        itemId: 'MORE_FROM_YEAR'
      }),
      'LIVE_FOLDER': new Ext.Action({
        itemId: 'LIVE_FOLDER',
        text: 'Save as Live Folder',
        //iconCls: 'pp-icon-glasses',
        handler: this.handleSaveActive,
        scope: this
      }),
      'RELOAD_FEED': new Ext.Action({
        itemId: 'RELOAD_FEED',
        text: 'Reload',
        iconCls: 'pp-icon-reload',
        handler: this.reloadFeed,
        tooltip: 'Reload the content of the feed',
        scope: this
      }),
      'EXPORT_VIEW': new Ext.Action({
        itemId: 'EXPORT_VIEW',
        text: 'All',
        handler: this.handleExportView,
        scope: this
      }),
      'EXPORT_SELECTION': new Ext.Action({
        itemId: 'EXPORT_SELECTION',
        text: 'Selection',
        handler: this.handleExportSelection,
        triggerKey: 'x',
        scope: this
      }),
      'COPY_BIBTEX_KEY': new Ext.Action({
        itemId: 'COPY_BIBTEX_KEY',
        text: 'Copy LaTeX Citation',
        handler: this.handleCopyBibtexKey,
        scope: this
      }),
      'COPY_BIBTEX_CITATION': new Ext.Action({
        itemId: 'COPY_BIBTEX_CITATION',
        text: 'Copy as BibTeX',
        handler: this.handleCopyBibtexCitation,
        scope: this
      }),
      'COPY_FORMATTED': new Ext.Action({
        itemId: 'COPY_FORMATTED',
        text: 'Copy Citation',
        handler: this.handleCopyFormatted,
        scope: this
      }),
      'DOWN_ONE': new Ext.Action({
        itemId: 'DOWN_ONE',
        text: 'Move the cursor to the next reference',
        handler: this.handleDownOne,
        scope: this
      }),
      'UP_ONE': new Ext.Action({
        itemId: 'UP_ONE',
        text: 'Move the cursor to the previous reference',
        handler: this.handleUpOne,
        scope: this
      }),
      'MOVE_FIRST': new Ext.Action({
        itemId: 'MOVE_FIRST',
        text: 'Move the cursor to the first reference',
        handler: this.handleMoveFirst,
        scope: this
      }),
      'MOVE_LAST': new Ext.Action({
        itemId: 'MOVE_LAST',
        text: 'Move the cursor to the last reference',
        handler: this.handleMoveLast,
        scope: this
      }),

      'TB_SPACE': new Ext.Toolbar.Spacer({
        itemId: 'TB_SPACE',
        width: '10px'
      }),
      'TB_BREAK': new Ext.Toolbar.Separator({
        itemId: 'TB_BREAK'
      }),
      'TB_FILL': new Ext.Toolbar.Fill({
        itemId: 'TB_FILL'
      }),
      'FONT_SIZE': new Ext.Action({
        itemId: 'FONT_SIZE',
        handler: this.fontSize,
        scope: this
      })

    };

    this.actions['PDF_COMBINED_BUTTON'] = new Ext.ux.ButtonPlus({
      itemId: 'PDF_COMBINED_BUTTON',
      items: [
        this.actions['VIEW_PDF'],
        this.actions['OPEN_PDF_FOLDER']]
    });
    this.actions['PDF_COMBINED_BUTTON2'] = new Ext.ux.ButtonPlus({
      itemId: 'PDF_COMBINED_BUTTON2',
      items: [
        this.actions['VIEW_PDF'],
        this.actions['OPEN_PDF_FOLDER']]
    });

    this.actions['MORE_FROM_MENU'] = new Ext.menu.Item({
      text: 'More from...',
      itemId: 'MORE_FROM_MENU',
      menu: {
        items: [
          this.actions['MORE_FROM_FIRST_AUTHOR'],
          this.actions['MORE_FROM_LAST_AUTHOR'],
          this.actions['MORE_FROM_JOURNAL'],
          this.actions['MORE_FROM_YEAR']]
      }
    });

    this.actions['EXPORT_MENU'] = new Ext.Toolbar.SplitButton({
      text: 'Export to File',
      itemId: 'EXPORT_MENU',
      handler: this.handleExportView,
      //iconCls: 'pp-icon-save',
      scope: this,
      menu: {
        items: [
          this.actions['EXPORT_VIEW'],
          this.actions['EXPORT_SELECTION']]
      }
    });

    this.actions['SAVE_MENU'] = new Ext.Button({
      itemId: 'SAVE_MENU',
      iconCls: 'pp-icon-save',
      cls: 'x-btn-text-icon',
      menu: {
        items: [{
          text: 'Save as Live Folder',
          iconCls: 'pp-icon-glasses',
          handler: this.handleSaveActive,
          scope: this
        },
        {
          text: 'Export contents to file',
          iconCls: 'pp-icon-disk',
          handler: this.handleExport,
          scope: this
        }]
      }
    });

    Ext.apply(this, {
      ddGroup: 'gridDD',
      enableDragDrop: true,
      appendOnly: true,
      itemId: 'grid',
      store: this.getStore(),
      selModel: new Ext.ux.BetterRowSelectionModel(),
      bbar: this.pager,
      tbar: new Paperpile.Toolbar({
        itemId: 'toolbar',
        enableOverflow: true,
        menuBreakItemId: 'TB_BREAK'
      }),
      enableHdMenu: false,
      autoExpandColumn: 'publication',

      columns: [{
        header: "",
        id: 'icons',
        dataIndex: 'title',
        renderer: renderIcons.createDelegate(this),
        width: 50,
        sortable: false,
        resizable: false
      },
      {
        header: "",
        id: 'publication',
        dataIndex: 'title',
        renderer: renderPub.createDelegate(this),
        resizable: false,
        sortable: false,
        scope: this
      }]
    });

    if (this.plugins) {
      this.plugins.push(new Paperpile.BaseQueryInfoPlugin());
    } else {
      this.plugins = [new Paperpile.BaseQueryInfoPlugin()];
    }

    Paperpile.PluginGrid.superclass.initComponent.call(this);

    this.on('afterrender', this.installEvents, this);

    this.on({
      // Delegate to class methods.
      beforerender: {
        scope: this,
        fn: this.myBeforeRender
      },
      afterrender: {
        scope: this,
        fn: this.myAfterRender
      },
      beforedestroy: {
        scope: this,
        fn: this.onClose
      },
      rowdblclick: {
        scope: this,
        fn: this.onDblClick
      },
      nodedragover: {
        scope: this,
        fn: this.onNodeDrag
      }
    });

    this.mon(this.getStore(), 'load', this.onStoreLoad, this);
    this.mon(this.getStore(), 'loadexception', function(exception, options, response, error) {
      Paperpile.main.onError(response);
    },
    this);

    this.mon(this.getSelectionModel(), 'afterselectionchange', function() {
      if (Paperpile.status.messageToHideOnClick) {
        Paperpile.status.clearMessageNumber(Paperpile.status.messageToHideOnClick);
        Paperpile.status.messageToHideOnClick = null;
      }
    },
    this);

    this.mon(this.getSelectionModel(), 'pageselected', function() {this.onPageSelected()},this);
    this.mon(this.getSelectionModel(), 'allselected', function(){this.onAllSelected()},this);

    // Auto-select the first row when the store finally loads up.
    this.mon(this.getStore(), 'load', function() {
      if (this.getStore().getCount() > 0) {
        this.getSelectionModel().selectRowAndSetCursor(0);
        this.afterSelectionChange(this.getSelectionModel());
      }
    },
    this, {
      single: true
    });

    this.on('viewready', function() {
      this.getPluginPanel().updateView();
    },
    this);

  },

  installEvents: function() {
    this.mon(this.el, 'click', this.handleClick, this);
    this.loadKeyboardShortcuts();
  },

  loadKeyboardShortcuts: function() {
    this.keys = new Ext.ux.KeyboardShortcuts(this.getView().focusEl);

    // Standard grid shortcuts.
    this.keys.bindAction('ctrl-q', this.actions['FONT_SIZE']);
    this.keys.bindAction('ctrl-a', this.actions['SELECT_ALL']);
    this.keys.bindAction('[Del,46]', this.actions['DELETE']);

    // Copy shortcuts.
    this.keys.bindAction('ctrl-c', this.actions['COPY_FORMATTED']);
    this.keys.bindAction('ctrl-b', this.actions['COPY_BIBTEX_CITATION']);
    this.keys.bindAction('ctrl-k', this.actions['COPY_BIBTEX_KEY']);

    // Gmail-style n/p, j/k movements.
    this.keys.bindAction('n', this.actions['DOWN_ONE']);
    this.keys.bindAction('shift-n', this.actions['DOWN_ONE']);
    this.keys.bindAction('p', this.actions['UP_ONE']);
    this.keys.bindAction('shift-p', this.actions['UP_ONE']);
    this.keys.bindAction('j', this.actions['DOWN_ONE']);
    this.keys.bindAction('shift-j', this.actions['DOWN_ONE']);
    this.keys.bindAction('k', this.actions['UP_ONE']);
    this.keys.bindAction('shift-k', this.actions['UP_ONE']);

    this.keys.bindAction('[End,35]', this.actions['MOVE_LAST']);
    this.keys.bindAction('[Home,36]', this.actions['MOVE_FIRST']);
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    switch (el.getAttribute('action')) {
    case 'clear-search':
      if (this.filterField) {
        this.filterField.onTrigger1Click();
        this.filterField.getEl().focus();
      } else if (this.searchField) {
        this.searchField.selectText();
        this.searchField.getEl().focus();
        this.getEmptyBeforeSearchTemplate().overwrite(this.getView().mainBody);
      }
      break;
    case 'close-tab':
      Paperpile.main.tabs.remove(this.getPluginPanel());
      break;
    }
  },

  onPageSelected: function() {
    var num = this.getSelectionModel().getCount();
    var all = this.getStore().getTotalCount();
    if (all <= num) {
      return;
    }
    Paperpile.status.updateMsg({
      type: 'info',
      msg: 'All ' + num + ' references on this page are selected.',
      action1: 'Select all ' + all + ' references.',
      callback: function() {
        this.getSelectionModel().selectAll.defer(20, this.getSelectionModel());
      },
      scope: this
    });

    // Create a callback to clear this message if the selection changes.
    var messageNum = Paperpile.status.getMessageNumber();
    var clearMsg = function() {
      Paperpile.status.clearMessageNumber(messageNum);
    };
    this.mon(this.getSelectionModel(), 'afterselectionchange', clearMsg, this, {
      single: true
    });
  },

  onAllSelected: function() {
    var num = this.getSelectionModel().getCount();
    Paperpile.status.clearMsg();
    Paperpile.status.updateMsg({
      type: 'info',
      msg: 'All ' + num + ' references are selected.',
      action1: 'Clear selection',
      callback: function() {
        this.getSelectionModel().clearSelectionsAndUpdate();
        Paperpile.status.clearMsg();
      },
      scope: this
    });

    // Create a callback to clear this message if the selection changes.
    var messageNum = Paperpile.status.getMessageNumber();
    var clearMsg = function() {
      Paperpile.status.clearMessageNumber(messageNum);
    };
    this.mon(this.getSelectionModel(), 'afterselectionchange', clearMsg, this, {
      single: true
    });
  },

  // Base classes should return /false/ if the base query info should be hidden.
  showBaseQueryInfo: function() {
    return true;
  },

  fontSize: function() {
    Ext.getBody().setStyle({
      'font-size': '24px'
    });
  },

  setPageSize: function(pageSize) {
    this.limit = pageSize;
    this.getStore().baseParams.limit = pageSize;
    this.pager.pageSize = pageSize;
    this.pager.doRefresh();
  },

  onNodeOver: function(nodeData, source, e, data) {
    if (data.grid) {
      e.cancel = true;
    } else if (data.node) {
      e.cancel = false;
    }

    var retVal = '';
    if (e.cancel) {
      retVal = Ext.dd.DropZone.prototype.dropNotAllowed;
    } else {
      retVal = Ext.dd.DropZone.prototype.dropAllowed;
    }

    this.updateDragStatus(nodeData, source, e, data);
    return retVal;
  },

  allowBackgroundReload: function() {
    return true;
  },

  backgroundReload: function() {
    if (!this.allowBackgroundReload()) {
      return;
    }
    this.backgroundLoading = true;
    this.getStore().reload({
      callback: function() {
        this.backgroundLoading = false;
      },
      scope: this
    });
  },

  updateDragStatus: function(nodeData, source, e, data) {
    var proxy = source.proxy;
    if (source.dragData.node) {
      var myType = source.dragData.node.type;
      if (myType == 'LABEL') {
        //proxy.updateTip('Apply label to reference');
      } else if (myType == 'FOLDER') {
        //proxy.updateTip('Place reference in folder');
      }
    } else if (source.dragData.grid) {
      // We should never reach here -- no within-grid drag and drop!
    }
  },

  onNodeDrop: function(target, dd, e, data) {
    if (data.node != null) {
      // Get the index of the node being dropped upon.
      var r = e.getTarget(this.getView().rowSelector);
      var index = this.getView().findRowIndex(r);
      var record = this.getStore().getAt(index);
      // If this node is *outside* the *selection*, then drop on the node instead of
      // the whole selection.
      var sel = this.getSelection();
      if (!this.getSelectionModel().isSelected(index)) {
        sel = record.get('guid');
      }

      var labelName = data.node.text;

      if (data.node.type) {
        var type = data.node.type;
        if (type == 'FOLDER') {
          Paperpile.main.tree.addFolder(this, sel, data.node);
        } else if (type == 'LABEL') {
          Paperpile.main.tree.addLabel(this, sel, data.node);
        }
      }
      return true;
    }
    return false;
  },

  onStoreLoad: function() {
    if (this.getPluginPanel()) {
      this.getPluginPanel().updateView();
    }
  },

  isLoaded: function() {
    return this.getStore() !== undefined && this.getStore().isLoaded;
  },

  showEmptyMessageBeforeStoreLoaded: function() {
    return true;
  },

  onEmpty: function() {
    var tpl;
    if (this.isLoaded() && this.getSearchFieldValue() != '') {
      if (!this._noResultsTpl) {
        this._noResultsTpl = this.getNoResultsTemplate();
      }
      tpl = this._noResultsTpl;
    } else if (this.showEmptyMessageBeforeStoreLoaded() || this.isLoaded()) {
      if (!this._emptyBeforeSearchTpl) {
        this._emptyBeforeSearchTpl = this.getEmptyBeforeSearchTemplate();
      }
      tpl = this._emptyBeforeSearchTpl;
    }
    if (tpl) {
      tpl.overwrite(this.getView().mainBody);
    } else {
      //Paperpile.log("No tpl!");
    }
  },

  getSearchFieldValue: function() {
    var value = '';
    if (this.filterField) {
      value = this.filterField.getValue();
    } else if (this.searchField) {
      value = this.searchField.getValue();
    }
    return value;
  },

  getEmptyBeforeSearchTemplate: function() {
    return new Ext.XTemplate(['<div class="pp-hint-box"><p>Use the search bar above to find papers.</p></div>']).compile();
  },

  getNoResultsTemplate: function() {
    return new Ext.XTemplate(['<div class="pp-hint-box"><p>No results to show. <a href="#" class="pp-textlink" action="clear-search">Clear search</a>.</p></div>']).compile();
  },

  highlightNewArticles: function() {
    if (!this.highlightedArticles) {
      this.highlightedArticles = [];
    }

    var s = this.getStore();
    var v = this.getView();
    for (var i = 0; i < s.getCount(); i++) {
      var record = s.getAt(i);
      var el = v.getRow(i);
      if (record.data.created) {
        var secondsAgo = Paperpile.utils.secondsAgo(record.data.created);
        if (secondsAgo < 20) {
          if (!this.highlightedArticles[record.data.guid]) {
            this.highlightedArticles[record.data.guid] = 1;
            Ext.get(el).highlight("ffff9c", {
              duration: 3,
              easing: 'easeOut'
            });
          }
        }
      }
    }
  },

  myBeforeRender: function(ct) {
    this.createToolbarMenu();
    this.createContextMenu();

  },

  afterSelectionChange: function(sm) {
    this.getPluginPanel().updateDetails();
    if (sm.getCount() == 1) {
      this.completeEntry();
    }
  },

  refreshView: function() {
    if (!this.isVisible()) {
      //      return;
    }
    this.updateButtons();
    this.getPluginPanel().updateDetails();
    if (sm.getCount() == 1) {
      this.completeEntry();
    }
  },

  myAfterRender: function(ct) {
    this.mon(this.pager, 'beforechange', function(pager, params) {
      var lastParams = this.pager.store.lastOptions.params;
      if (params.start != lastParams.start) {
        this.mon(this.getView(), 'refresh', function() {
          this.getView().scrollToTop();
        },
        this, {
          single: true
        });
      }
    },
    this);

    // Note: the 'afterselectionchange' event is a custom selection model event.
    this.mon(this.getSelectionModel(), 'afterselectionchange', this.afterSelectionChange, this);

    this.dropZone = new Paperpile.GridDropZone(this, {
      ddGroup: this.ddGroup
    });

    Paperpile.GridDragZone = Ext.extend(Ext.grid.GridDragZone, {
      proxy: new Paperpile.StatusTipProxy()
    });
    this.dragZone = new Paperpile.GridDragZone(this, {
      ddGroup: this.ddGroup
    });

    this.createAuthorToolTip();

    this.getPluginPanel().updateView();
  },

  createAuthorToolTip: function() {
    this.authorTip = new Ext.ToolTip({
      maxWidth: 500,
      showDelay: 0,
      hideDelay: 0,
      target: this.getView().mainBody,
      delegate: '.pp-authortip',
      renderTo: document.body,
      listeners: {
        beforeshow: {
          fn: function updateTipBody(tip) {
            var rowIndex = this.getView().findRowIndex(tip.triggerElement);
            var record = this.getStore().getAt(rowIndex);
            tip.body.dom.innerHTML = record.data._authortip;
          },
          scope: this
        }
      }
    });
  },

  getDragDropText: function() {
    var num = this.getSelectionModel().getCount();

    if (num == 1) {
      var key = this.getSingleSelectionRecord().get('citekey');
      if (key) {
        return "[" + key + "]";
      } else {
        return " 1 selected reference";
      }
    } else {
      return num + " selected references";
    }
  },

  getStore: function() {
    if (this._store != null) {
      return this._store;
    }
    this._store = new Ext.data.Store({
      isLoaded: false,
      proxy: new Ext.data.HttpProxy({
        url: Paperpile.Url('/ajax/plugins/resultsgrid'),
        // We don't set timeout here but handle timeout separately in
        // specific plugins.
        timeout: 10000000,
        method: 'GET'
      }),
      baseParams: {
        grid_id: this.id,
        plugin_file: this.plugin_file,
        plugin_name: this.plugin_name,
        plugin_query: this.plugin_query,
        plugin_mode: this.plugin_mode,
        plugin_order: Paperpile.main.globalSettings['sort_field'],
        limit: this.limit
      },
      reader: new Ext.data.JsonReader()
    });

    // Add some callbacks to the store so we can maintain the selection between reloads.
    this.mon(this.getStore(), 'load', function(store, options) {
      this.getStore().isLoaded = true;
      if (!this.doAfterNextReload) {
        this.doAfterNextReload = [];
      }
      for (var i = 0; i < this.doAfterNextReload.length; i++) {
        var fn = this.doAfterNextReload[i];
        fn.defer(0, this);
      }
      this.doAfterNextReload = [];
    },
    this);

    return this._store;
  },

  onPageButtonClick: function() {
    this.doAfterNextReload.push(function() {
      if (!this.getSelectionModel().maintainSelectionBetweenReloads || this.getSelectionModel().getCount() <= 1) {
        this.getSelectionModel().selectRowAndSetCursor(0);
      }
    });
  },

  cancelLoad: function() {
    if (!this.store) {
      return;
    }
    // The refresh button does not get reset and keeps
    // spinning. It is resetted if an error occurs in the
    // proxy. Therefore I call the exception explicitly as a
    // workaround
    this.store.proxy.fireEvent('exception');

    this.store.proxy.getConnection().abort();

    // Kill process on the backend. Should not do any harm. On
    // the backend side a grid call just adds papers to the
    // _hash cache of the plugin object. I should not matter
    // if this data gets written or not as any subsequent call
    // will overwrite it or will never touch it because the
    // frontend does not know about it.
    Paperpile.Ajax({
      url: '/ajax/misc/cancel_request',
      params: {
        cancel_handle: 'grid_' + this.id,
        kill: 1
      }
    });
  },

  getByGUID: function(guid) {
    var index = this.getStore().find('guid', guid);
    if (index > -1) {
      return this.getStore().getAt(index);
    }
    return null;
  },

  gridTemplates: {},

  getPubTemplate: function() {
    if (this.pubTemplate == null) {
      this.pubTemplate = new Ext.XTemplate(
        '<div class="pp-grid-data {[this.isInactive(values.labels)]}" guid="{guid}">',
        '<div>',
        '<span class="pp-grid-title">{title}</span>{[this.labelStyle(values.labels, values.labels_tmp)]}',
        '</div>',
        '<tpl if="_authors_display">',
        '<p class="pp-grid-authors">{_authors_display}</p>',
        '</tpl>',
        '<tpl if="_citation_display">',
        '<p class="pp-grid-citation">{_citation_display}</p>',
        '</tpl>',
        '<tpl if="_snippets">',
        '<p class="pp-grid-snippets">{_snippets}</p>',
        '</tpl>',
        '</div>', {
          labelStyle: function(labels_guid, labels_tmp) {
            var returnMe = '';
            if (labels_tmp) {
              var labels = labels_tmp.split(/\s*,\s*/);
              for (var i = 0; i < labels.length; i++) {
                name = labels[i];
                style = '0';
                returnMe += '<div class="pp-label-grid-inline pp-label-style-' + style + '">' + name + '&nbsp;</div>&nbsp;';
              }
            } else {
              var labels = labels_guid.split(/\s*,\s*/);
              for (var i = 0; i < labels.length; i++) {
                var guid = labels[i];
                var style = Paperpile.main.labelStore.getAt(Paperpile.main.labelStore.findExact('guid', guid));
                if (style != null) {
                  name = style.get('display_name');
                  style = style.get('style');
                  returnMe += '<div class="pp-label-grid-inline pp-label-style-' + style + '">' + name + '&nbsp;</div>&nbsp;';
                }
              }
            }
            if (labels.length > 0) returnMe = "&nbsp;&nbsp;&nbsp;" + returnMe;
            return returnMe;
          },
          isInactive: function(label_string) {
            var labels = label_string.split(/\s*,\s*/);
            for (var i = 0; i < labels.length; i++) {
              var guid = labels[i];
              var label = Paperpile.main.labelStore.getAt(Paperpile.main.labelStore.findExact('guid', guid));
              if (label != null) {
                name = label.get('name');
                if (name === 'Incomplete') {
                  return ('pp-inactive');
                }
              }
            }
            return ('');
          }
        }).compile();
    }

    return this.pubTemplate;
  },

  getIconTemplate: function() {
    if (this.iconTemplate != null) {
      return this.iconTemplate;
    }
    this.iconTemplate = new Ext.XTemplate(
      '<div class="pp-grid-info">',
      '<tpl if="_imported">',
      '  <tpl if="trashed==0">',
      '    <div class="pp-grid-status pp-grid-status-imported" ext:qtip="[<b>{_citekey}</b>]<br>added {_createdPretty}"></div>',
      '  </tpl>',
      '  <tpl if="trashed==1">',
      '    <div class="pp-grid-status pp-grid-status-deleted" ext:qtip="[<b>{_citekey}</b>]<br>deleted {_createdPretty}"></div>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="pdf">',
      '  <div class="pp-grid-status pp-grid-status-pdf" ext:qtip="<b>{pdf_name}</b><br/>{_last_readPretty}"></div>',
      '</tpl>',
      '<tpl if="attachments">',
      '  <div class="pp-grid-status pp-grid-status-attachments" ext:qtip="{_attachments_count} attached file(s)"></div>',
      '</tpl>',
      '<tpl if="annote">',
      '  <div class="pp-grid-status pp-grid-status-notes" ext:qtip="{_notes_tip}"></div>',
      '</tpl>',
      '</div>').compile();
    return this.iconTemplate;
  },

  getSidebarTemplate: function() {
    if (this.sidebarTemplate == null) {
      this.sidebarTemplate = {
        singleSelection: new Ext.XTemplate(this.getSingleSelectionTemplate()).compile(),
        multipleSelection: new Ext.XTemplate(this.getMultipleSelectionTemplate()).compile(),
        noSelection: new Ext.XTemplate(this.getNoSelectionTemplate()).compile(),
        emptyGrid: new Ext.XTemplate(this.getEmptyGridTemplate()).compile(),
        details: new Ext.XTemplate(this.getDetailsTemplate()).compile()
      };
    }
    return this.sidebarTemplate;
  },

  getAllCopyLinks: function(type) {
    // Generates the conditional template strings to create hover-links for the identifier fields.
    var fields = ['doi', 'pmid', 'url', 'eprint', 'arxivid'];
    var labels = ['DOI', 'PubMed', 'URL', 'E-Print', 'arXiv'];
    var strings = [];
    for (var i = 0; i < labels.length; i++) {
      if (type == 'details') {
        strings = strings.concat(this.getDetailsCopyLinks(fields[i], labels[i]));
      } else if (type == 'overview') {
        strings = strings.concat(this.getOverviewCopyLinks(fields[i], labels[i]));
      }
    }
    return strings.join("\n");
  },

  getDetailsCopyLinks: function(field, label) {
    return[
    '          <tpl if="field == \'' + field + '\'">',
    '            <div class="pp-info-button pp-info-link pp-second-link" ext:qtip="Open ' + label + ' link in browser" action="' + field + '-link"></div>',
    '            <div class="pp-info-button pp-info-copy pp-second-link" ext:qtip="Copy ' + label + ' URL to clipboard" action="' + field + '-copy"></div>',
    '          </tpl>'];
  },

  getOverviewCopyLinks: function(field, label) {
    return[
    '<tpl if="' + field + '">',
    '<div class="link-hover">',
    '  <dt>' + label + ': </dt>',
    '  <div class="pp-info-button pp-info-link pp-second-link" ext:qtip="Open ' + label + ' link in browser" action="' + field + '-link"></div>',
    '  <div class="pp-info-button pp-info-copy pp-second-link" ext:qtip="Copy ' + label + ' URL to clipboard" action="' + field + '-copy"></div>',
    '<dd class="pp-info-' + field + '">{' + field + '}</dd>',
    '</div>',
    '</tpl>'];
  },

  getDetailsTemplate: function() {
    return[
    '<div id="main-container-{id}">',
    '<div class="pp-box pp-box-top pp-box-side-panel pp-box-style2">',
    '  <div class="ref-actions" style="float:right;">',
    '    <img src="/images/icons/pencil.png" class="pp-img-action" action="edit-ref" ext:qtip="Edit Reference"/>',
    '  </div>',
    '  <div style="margin:-5px 0px; clear:both;"></div>',
    '    <dl>',
    '      <tpl if="citekey"><dt>Key: </dt><dd class="pp-word-wrap">{citekey}</dd></tpl>',
    '      <dt>Type: </dt><dd>{_pubtype}</dd>',
    '      <tpl for="fields">',
    '        <div class="link-hover">',
    this.getAllCopyLinks('details'),
    '          <dt>{label}:</dt><dd class="pp-word-wrap pp-info-{field}">{value}</dd>',
    '        </div>',
    '      </tpl>',
    '    </dl>',
    '  </div>',

    '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style2">',
    '    <ul> ',
    '      <li><a  href="#" class="pp-textlink pp-action pp-action-clipboard" action="copy-text">Copy Citation</a> </li>',
    '      <tpl if="isBibtexMode">',
    '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-bibtex">Copy as BibTeX</a> </li>',
    '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-keys">Copy LaTeX citation</a> </li>',
    '      </tpl>',
    '    </ul>',
    '  </div>',
    '</div>'].join('');
  },

  getSingleSelectionTemplate: function() {
    var prefix = [
      '<div id="main-container-{id}">'];
    var suffix = [
      '</div>'];
    var referenceInfo = [
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<tpl if="_imported">',
      '  <div id="ref-actions" style="float:right;">',
      '  <tpl if="trashed==1">',
      '    <img src="/images/icons/arrow_rotate_anticlockwise.png" class="pp-img-action" action="restore-ref" ext:qtip="Restore Reference"/>',
      '    <img src="/images/icons/delete.png" class="pp-img-action" action="delete-ref" ext:qtip="Permanently Delete Reference"/>',
      '  </tpl>',
      '  <tpl if="trashed==0">',
      '    <img src="/images/icons/pencil.png" class="pp-img-action" action="edit-ref" ext:qtip="Edit Reference"/>',
      '    <img src="/images/icons/trash.png" class="pp-img-action" action="delete-ref" ext:qtip="Move Reference to Trash"/>',
      '  </tpl>',
      '  </div>',
      '</tpl>',
      '<h2>Reference Info</h2>',
      '<dl class="pp-ref-info">',
      '<tpl if="_pubtype_name">',
      '  <dt>Type: </dt><dd>{_pubtype_name}',
      '  <tpl if="howpublished">({howpublished})</tpl>',
      '</dd>',
      '</tpl>',
      '<tpl if="_imported">',
      '  <tpl if="trashed==0">',
      '    <dt>Added: </dt>',
      '  </tpl>',
      '  <tpl if="trashed==1">',
      '    <dt>Deleted: </dt>',
      '  </tpl>',
      '  <dd>{_createdPretty}</dd>',
      '</tpl>',
      this.getAllCopyLinks('overview'),
      '<tpl if="folders">',
      '  <dt>Folders: </dt>',
      '  <dd>',
      '    <ul class="pp-folders">',
      '    <tpl for="_folders_list">',
      '      <li class="pp-folder-list pp-folder-generic">',
      '        <a href="#" class="pp-textlink" action="open-folder" folder_id="{folder_id}" >{folder_name}</a> &nbsp;&nbsp;',
      '        <a href="#" class="pp-textlink pp-second-link" action="delete-folder" folder_id="{folder_id}" rowid="{rowid}">Remove</a>',
      '      </li>',
      '    </tpl>',
      '    </ul>',
      '  </dd>',
      '</tpl>',
      '<tpl if="_imported && !trashed">', // Don't show the labels widget if this article isn't imported.
      '  <dt>Labels: </dt>',
      '  <dd>',
      '  <div id="label-widget-{id}" class="pp-label-widget"></div>',
      '  </dd>',
      '</tpl>',
      '</dl>',
      '<tpl if="_details_link">',
      '<p class="pp-inactive">No data available.</p>',
      '</tpl>',
      '  <div style="clear:left;"></div>',
      '</div>'];

    var linkOuts = [
      '<tpl if="trashed==0">',
      '  <tpl if="linkout || doi">',
      '    <div class="pp-box pp-box-side-panel pp-box-bottom pp-box-style1">',
      '  </tpl>',
      '  <tpl if="!linkout && !doi">',
      '    <div class="pp-box pp-box-side-panel pp-box-bottom pp-box-style1">',
      '  </tpl>',
      '  <ul>',
      '  <tpl if="doi">',
      '    <li><a href="#" onClick="Paperpile.utils.openURL(\'http://dx.doi.org/{doi}\');" class="pp-textlink pp-action pp-action-go">Go to Publisher\'s site</a></li>',
      '   </tpl>',
      '   <tpl if="!doi && linkout">',
      '     <li><a href="#" onClick="Paperpile.utils.openURL(\'{linkout}\');" class="pp-textlink pp-action pp-action-go">Go to Publisher\'s site</a></li>',
      '   </tpl>',
      '   <tpl if="!linkout && !doi">',
      '   <li><a class="pp-action-inactive pp-action-go-inactive">No link to publisher available</a></li>',
      '   </tpl>',
      '   <li><a href="#" action="email" class="pp-textlink pp-action pp-action-email">E-mail Reference</a></li>',
      '  </ul>',
      '  </div>',
      // Attachments box.
      '  <div class="pp-box pp-box-side-panel pp-box-style2 pp-box-files"',
      '    <h2>PDF</h2>',
      '    <div id="search-download-widget-{id}" class="pp-search-download-widget"></div>',
      '    <tpl if="_imported || attachments">',
      '      <h2>Supplementary Material</h2>',
      '    </tpl>',
      '      <tpl if="_attachments_list">',
      '        <ul class="pp-attachments">',
      '          <tpl for="_attachments_list">',
      '            <li class="pp-attachment-list pp-file-generic {cls}">',
      '            <a href="#" class="pp-textlink" action="open-attachment" path="{path}">{file}</a>&nbsp;&nbsp;',
      '            <a href="#" class="pp-textlink pp-second-link" action="delete-file" guid="{guid}">Delete</a></li>',
      '          </tpl>',
      '       </ul>',
      '    </tpl>',
      '    <tpl if="_imported">',
      '      <ul>',
      '        <li id="attach-file-{id}"><a href="#" class="pp-textlink pp-action pp-action-attach-file" action="attach-file">Attach File</a></li>',
      '      </ul>',
      '    </tpl>',
      '  </div>',
      '</tpl>'];
    return[].concat(prefix, referenceInfo, linkOuts, suffix);
  },

  getEmptyGridTemplate: function() {
    var template = [
      '<div id="main-container-{id}">',
      '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style2">',
      '    <p class="pp-inactive">No references selected.</p>',
      '  </div>',
      '</div>'];
    return[].concat(template);
  },

  getNoSelectionTemplate: function() {
    var template = [
      '<div id="main-container-{id}">',
      '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style2">',
      '    <p class="pp-inactive">No references selected.</p>',
      '  </div>',
      '</div>'];
    return[].concat(template);
  },

  getMultipleSelectionTemplate: function() {
    var template = [
      '<div id="main-container-{id}">',
      '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '  <tpl if="numSelected &gt;0">',
      '    <p><b>{numSelected}</b> references selected.</p>',
      '    <div class="pp-vspace" style="height:5px;"></div>',
      '    <ul> ',
      '    <div style="clear:both;"></div>',
      '      <li><a href="#" class="pp-action pp-textlink pp-action-update-metadata" action="update-metadata">Auto-complete Data</a></li>',
      '      <li><a href="#" class="pp-action pp-textlink pp-action-search-pdf" action="batch-download">Download PDFs</a> </li>',
      '      <li><a  href="#" class="pp-textlink pp-action pp-action-trash" action="delete-ref">Move to Trash</a> </li>',
      '    </ul>',
      '    <ul> ',
      '    <div style="clear:both;margin-top:2em;"></div>',
      '      <li><a  href="#" class="pp-textlink pp-action pp-action-clipboard" action="copy-text">Copy Citation</a> </li>',
      '      <tpl if="isBibtexMode">',
      '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-bibtex">Copy BibTeX</a> </li>',
      '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-keys">Copy LaTeX Citation</a> </li>',
      '      </tpl>',
      '    </ul>',
      '    <ul>',
      '    <div style="clear:both;margin-top:2em;"></div>',
      '      <li><a  href="#" class="pp-textlink pp-action pp-action-email" action="email">E-mail References</a> </li>',
      '    </ul>',
      '    <div class="pp-vspace" style="height:5px;"></div>',
      '   <dl>',
      '     <dt style="width: 50px;">Labels: </dt>',
      '     <dd style="margin:0 0 0 50px;">',
      '       <div id="label-widget-{id}" class="pp-label-widget"></div>',
      '     </dd>',
      '   </dl>',
      '    <div class="pp-vspace" style="height:5px;"></div>',
      '  </tpl>',
      '  </div>',
      '</div>'];
    return[].concat(template);
  },

  toolbarMenuItemIds: [],

  // This method returns a list of itemIDs in the order we want them
  // to show up in the toolbar.
  // Subclasses or plugins should override this method (making sure to
  // call the superclass method) and add or remove items to / from the
  // this.toolbarMenuItemIds object to alter what shows up in the toolbar.
  initToolbarMenuItemIds: function() {
    this.toolbarMenuItemIds = new Ext.util.MixedCollection();
    this.toolbarMenuItemIds.addAll([
      'TB_FILL',
      'TB_BREAK',
      'PDF_COMBINED_BUTTON2',
      this.createSeparator('TB_VIEW_SEP'),
      'EDIT',
      'AUTO_COMPLETE',
      'SELECT_ALL',
      'DELETE',
      this.createSeparator('TB_DEL_SEP'),
      'LIVE_FOLDER',
      'EXPORT_MENU']);
  },

  // Same as above, but for the context menu.
  initContextMenuItemIds: function() {
    this.contextMenuItemIds = new Ext.util.MixedCollection();
    this.contextMenuItemIds.addAll([
    //      'VIEW_PDF',
    //	'OPEN_PDF_FOLDER',
    'PDF_COMBINED_BUTTON',
      this.createContextSeparator('CONTEXT_VIEW_SEP'),
      'EDIT',
      'AUTO_COMPLETE',
      'SELECT_ALL',
      'DELETE',
      this.createContextSeparator('CONTEXT_DEL_SEP'),
      'MORE_FROM_MENU',
      'EXPORT_SELECTION',
      this.createContextSeparator('CONTEXT_BIBTEX_SEP'),
      'COPY_FORMATTED',
      'COPY_BIBTEX_CITATION',
      'COPY_BIBTEX_KEY']);
  },

  createContextSeparator: function(itemId) {
    this.actions[itemId] = new Ext.menu.Separator({
      itemId: itemId
    });
    return itemId;
  },

  createSeparator: function(itemId) {
    this.actions[itemId] = new Ext.Toolbar.Separator({
      itemId: itemId
    });
    return itemId;
  },

  createToolbarMenu: function() {
    var tbar = this.getTopToolbar();
    tbar.removeAll();

    this.initToolbarMenuItemIds();
    var itemIds = this.toolbarMenuItemIds; // This is an Ext.util.MixedCollection.
    for (var i = 0; i < itemIds.length; i++) {
      var id = itemIds.itemAt(i);
      var obj = this.actions[id];
      tbar.insert(i, this.actions[id]);
    }
  },

  getContextMenu: function() {
    return this.context;
  },

  createContextMenu: function() {
    this.context = new Ext.menu.Menu({
      plugins: [new Ext.ux.TDGi.MenuKeyTrigger()],
      id: 'pp-grid-context-' + this.id,
      itemId: 'context',
      hideTooltips: true // Custom flag which hides tooltips in menu items.
    });
    var context = this.context;
    this.initContextMenuItemIds();
    var itemIds = this.contextMenuItemIds; // This is an Ext.util.MixedCollection.
    for (var i = 0; i < itemIds.length; i++) {
      var id = itemIds.itemAt(i);
      context.insert(i, this.actions[id]);
    }
  },

  onContextClick: function(grid, index, e) {
    if (!this.getSelectionModel().isSelected(index)) {
      this.getSelectionModel().selectRow(index);
    } else {
      this.getSelectionModel().setCursor(index);
    }

    this.refreshView();
    var xy = e.getXY();

    this.context.doLayout(false, true);
    this.context.showAt.defer(10, this.context, [xy]);
    e.preventDefault();
  },

  updateContextItem: function(menuItem, record) {
    // Recurse through sub-menus.
    if (menuItem.menu) {
      menuItem.menu.items.each(function(item, index, length) {
        this.updateContextItem(item, record);
      },
      this);
    }

    return;
  },

  updateMoreFrom: function() {
    this.actions['MORE_FROM_FIRST_AUTHOR'].setText(this.getFirstAuthorFromSelection());

    if (this.getLastAuthorFromSelection() != '') {
      this.actions['MORE_FROM_LAST_AUTHOR'].setText(this.getLastAuthorFromSelection());
      this.actions['MORE_FROM_LAST_AUTHOR'].show();
    } else {
      //this.actions['MORE_FROM_LAST_AUTHOR'].setText("Last author");
      //this.actions['MORE_FROM_LAST_AUTHOR'].disable();
      this.actions['MORE_FROM_LAST_AUTHOR'].hide();
    }

    var a = this.actions['MORE_FROM_JOURNAL'];
    if (this.getJournalFromSelection() != '') {
      a.show();
      a.setText(this.getJournalFromSelection());
    } else {
      a.hide();
    }
    a.each(function(item) {
      item.style = {
        'font-style': 'italic'
      };
      if (item.rendered) {
        item.textEl.setStyle('font-style', 'italic');
      }
    },
    this);

    a = this.actions['MORE_FROM_YEAR'];
    if (this.getYearFromSelection() != '') {
      a.show();
      a.setText(this.getYearFromSelection());
    } else {
      a.hide();
    }

  },

  // Private. Don't override.
  updateButtons: function() {
    this.getTopToolbar().items.each(function(item, index, length) {
      item.enable();
    },
    this);

    this.getContextMenu().items.each(function(item, index, length) {
      item.enable();
    });
    for (var key in this.actions) {
      var action = this.actions[key];
      if (action['setDisabled']) {
        action.setDisabled(false);
      }
    }

    var selection = this.getSingleSelectionRecord();

    this.actions['SELECT_ALL'].setText('Select All');
    this.actions['FORCE_SELECT_ALL'].setText('Select All (' + this.getStore().getTotalCount() + ')');
    if (this.getSelectionModel().isAllSelected() || this.getTotalCount() == 0) {
      this.actions['FORCE_SELECT_ALL'].disable();
      this.actions['SELECT_ALL'].disable();
    }

    if (!selection || selection.data.pdf == '') {
      this.actions['VIEW_PDF'].disable();
      this.actions['OPEN_PDF_FOLDER'].disable();
    }

    if (!selection) {
      this.actions['AUTO_COMPLETE'].disable();
      this.actions['EDIT'].disable();
      this.actions['DELETE'].disable();
      this.actions['COPY_FORMATTED'].disable();
    }

    if (selection) {
      this.updateMoreFrom();
    }

    var tbar = this.getTopToolbar();
    var context = this.getContextMenu();

    context.getComponent('EXPORT_SELECTION').setText("Export Selection...");

    var settings = Paperpile.main.globalSettings['bibtex'];
    if (settings.bibtex_mode == 1) {
      this.getContextByItemId('COPY_BIBTEX_CITATION').show();
      this.getContextByItemId('COPY_BIBTEX_KEY').show();
    } else {
      this.getContextByItemId('COPY_BIBTEX_CITATION').hide();
      this.getContextByItemId('COPY_BIBTEX_KEY').hide();
    }
  },

  updateToolbarItem: function(menuItem) {
    return;
  },

  getToolbarByItemId: function(itemId) {
    var tbar = this.getTopToolbar();
    return tbar.items.itemAt(this.getButtonIndex(itemId));
  },

  getContextByItemId: function(itemId) {
    return this.getContextMenu().items.itemAt(this.getContextIndex(itemId));
  },

  // Small helper functions to get the index of a given item in the toolbar configuration array
  // We have to use the text instead of itemId. Actions do not seem to support itemIds.
  // A better solution should be possible with ExtJS 3
  getContextIndex: function(itemId) {
    var context = this.getContextMenu();
    for (var i = 0; i < context.items.length; i++) {
      var item = context.items.itemAt(i);
      if (item.itemId == itemId) return i;
    }
    return -1;
  },

  getTopToolbar: function() {
    var tbar = Paperpile.PluginGrid.superclass.getTopToolbar.call(this);
    if (tbar == null) {
      tbar = this._tbar;
    }
    return tbar;
  },

  getButtonIndex: function(itemId) {
    var tbar = this.getTopToolbar();
    for (var i = 0; i < tbar.items.length; i++) {
      var item = tbar.items.itemAt(i);
      if (item.itemId == itemId) return i;
    }
    return -1;
  },

  getPluginPanel: function() {
    return this.findParentByType(Paperpile.PluginPanel);
  },

  getSelectionAsList: function(what) {
    if (!what) what = 'ALL';
    var selection = [];
    var sels = this.getSelectionModel().getSelections();
    for (var i = 0; i < sels.length; i++) {
      var record = sels[i];
      if ((what == 'ALL') || (what == 'IMPORTED' && record.get('_imported')) || (what == 'NOT_IMPORTED' && !record.get('_imported')) || (what == 'TRASHED' && record.get('trashed'))) {
        selection.push(record.get('guid'));
      }
    }
    return selection;
  },

  // Returns list of guids for the selected entries, either ALL, IMPORTED, NOT_IMPORTED
  getSelection: function(what) {
    if (this.getSelectionModel().isAllSelected()) {
      return 'ALL';
    } else {
      return this.getSelectionAsList(what);
    }
  },

  getSelectionCount: function() {
    var sm = this.getSelectionModel();
    var numSelected = sm.getCount();
    return numSelected;
  },

  getTotalCount: function() {
    return this.getStore().getTotalCount();
  },

  // Some plugins use a two-stage process for showing entries: First
  // only minimal info is scraped from site to build list quickly
  // without harassing the site too much. Then the details are
  // fetched only when user clicks the entry.
  completeEntry: function() {
    if (this.isLocked) return; // Call completeEntry only for one item at a time 
    var selection = this.getSelection();

    var sel = this.getSingleSelectionRecord();
    if (!sel) return;
    var data = sel.data;
    // _details_link indicates if an entry still needs to be completed or not
    if (data._details_link) {

      this.lookingUpData = true;

      // Don't allow other rows to be selected during load
      var blockingFunction = function() {
        return false;
      };
//      this.getSelectionModel().on('beforerowselect', blockingFunction, this);
      this.isLocked = true;

      var guid = data.guid;

      Paperpile.status.updateMsg({
        busy: true,
        msg: 'Lookup bibliographic data',
        action1: 'Cancel',
        callback: function() {
          Ext.Ajax.abort(transactionID);
          this.cancelCompleteEntry();
          Paperpile.status.clearMsg();
          this.getSelectionModel().un('beforerowselect', blockingFunction, this);
          this.isLocked = false;
        },
        scope: this
      });

      // Warn after 10 sec
      this.timeoutWarn = (function() {
        Paperpile.status.setMsg('This is taking longer than usual. Still looking up data.');
      }).defer(10000, this);

      // Abort after 20 sec
      this.timeoutAbort = (function() {
        Ext.Ajax.abort(transactionID);
        this.cancelCompleteEntry();
        Paperpile.status.clearMsg();
        Paperpile.status.updateMsg({
          msg: 'Giving up. There may be problems with your network or ' + this.plugin_name + '.',
          hideOnClick: true
        });
        this.getSelectionModel().un('beforerowselect', blockingFunction, this);
        this.isLocked = false;
      }).defer(20000, this);

      var transactionID = Paperpile.Ajax({
        url: '/ajax/crud/complete_entry',
        params: {
          selection: selection,
          grid_id: this.id,
          cancel_handle: this.id + '_lookup'
        },
        success: function(response) {
          var json = Ext.util.JSON.decode(response.responseText);

          this.getSelectionModel().un('beforerowselect', blockingFunction, this);
          this.isLocked = false;

          clearTimeout(this.timeoutWarn);
          clearTimeout(this.timeoutAbort);

          if (json.error) {
            Paperpile.main.onError(response);
            return;
          }

          Paperpile.status.clearMsg();

          this.updateButtons();
          this.getPluginPanel().updateDetails();
        },
        failure: function(response) {
          this.getSelectionModel().un('beforerowselect', blockingFunction, this);
          this.isLocked = false;
          clearTimeout(this.timeoutWarn);
          clearTimeout(this.timeoutAbort);
        },
        scope: this
      });
    }
  },

  cancelCompleteEntry: function() {

    clearTimeout(this.timeoutWarn);
    clearTimeout(this.timeoutAbort);

    Paperpile.Ajax({
      url: '/ajax/misc/cancel_request',
      params: {
        cancel_handle: this.id + '_lookup',
        kill: 1
      }
    });
  },

  updateDetail: function() {
    // Override with other plugin methods to do things necessary on detail update.
  },

  handleDownOne: function(keyCode, event) {
    var sm = this.getSelectionModel();
    var t = this.pager;
    var activePage = Math.ceil((t.cursor + t.pageSize) / t.pageSize);
    if (sm.getCount() == 1 && this.getStore().indexOf(sm.getSelected()) == this.pager.pageSize - 1 && !this.pager.next.disabled) {
      this.pager.moveNext();
      this.doAfterNextReload.push(function() {
        this.getSelectionModel().selectRowAndSetCursor(0);
      });
    } else {
      this.getSelectionModel().keyNavMove(1, event);
    }
  },
  handleUpOne: function(keyCode, event) {
    var sm = this.getSelectionModel();
    if (sm.getCount() == 1 && this.getStore().indexOf(sm.getSelected()) == 0 && !this.pager.prev.disabled) {
      this.pager.movePrevious();
      this.doAfterNextReload.push(function() {
        this.getSelectionModel().selectRowAndSetCursor(this.pager.pageSize - 1);
      });
    } else {
      this.getSelectionModel().keyNavMove(-1, event);
    }
  },
  handleMoveFirst: function(keyCode, event) {
    this.getSelectionModel().selectRowAndSetCursor(0);
  },
  handleMoveLast: function(keyCode, event) {
    this.getSelectionModel().selectRowAndSetCursor(this.getStore().getCount() - 1);
  },

  // If trash is set entries are moved to trash, otherwise they are
  // deleted completely
  // mode: TRASH ... move to trash
  //       RESTORE ... restore from trash
  //       DELETE ... delete permanently
  handleDelete: function() {
    this.deleteEntry('TRASH');
  },

  handleSaveActive: function() {
    Paperpile.main.tree.newActive();
  },

  handleExportSelection: function() {
    selection = this.getSelection();
    Paperpile.main.handleExport(this.id, selection);
  },

  handleExportView: function() {
    Paperpile.main.handleExport(this.id, 'all');
  },

  handleCopy: function(module, format, msg) {
    if (this.getSelectionCount() == 0) {
	return;
    }
    var isMultiple = this.getSelectionCount() > 1;
    var s = '';
    var n = '';
    if (isMultiple) {
      s = 's';
      n = this.getSelectionCount();
    }
    msg = msg.replace("{n}", n);
    msg = msg.replace("{s}", s);

    var myFn = function(string) {
      if (IS_QT) {
        QRuntime.setClipboard(string);
        Paperpile.status.updateMsg({
          msg: msg,
          duration: 1.5,
          fade: true
        });
      } else {
        // Not in Qt -- use Flash if available...
        Paperpile.status.updateMsg({
          msg: msg,
          duration: 1.5,
          fade: true
        });
      }
    };
    this.getFormattedText(module, format, myFn);
  },

  getFormattedText: function(module, format, callback) {
    Paperpile.Ajax({
      url: '/ajax/plugins/export',
      params: {
        grid_id: this.id,
        selection: this.getSelection(),
        export_name: module,
        export_out_format: format,
        get_string: true
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        var string = json.data.string;
        callback.call(this, string);
      },
      scope: this
    });
  },

  handleEmail: function() {
    var n = this.getSelectionCount();

    var myFunc = function(string) {
      var subject = "Papers for you";
      if (n == 1) {
        subject = "Paper for you";
      }
      var body = 'I thought you might be interested in the following:';

      var attachments = [];
      // Attachments in e-mail links aren't very well supported. Skip them for now.
      /* 
	var sels = this.getSelectionModel().getSelections();
	for (var i=0; i < sels.length; i++) {
	  if (sels[i].data.pdf) {
	      var pdf = sels[i].data.pdf_name;
	      var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
	    attachments.push('&Attachment='+path);
	  }
	}
*/

      string = string.replace(/%0A/g, "\n");

      // The QRuntime appears capable of sending URLs of very long lengths, at least to Thunderbird.
      // So we don't need to use as low of a cut-off threshold as before...
      if (string.length > 1024 * 50) {
        QRuntime.setClipboard(string);
        var platform = Paperpile.utils.get_platform();
        if (platform == 'osx') {
          string = "(Hit Command-V to paste citations here)";
        } else if (platform == 'windows') {
          string = "(Hit Ctrl-V to paste citations here)";
        } else {
          string = "(Use the paste command to insert citations here)";
        }
      }

      var link = [
        'mailto:?',
        'subject=' + subject,
        '&body=' + body + "\n\n" + string,
        "\n\n--\nShared with Paperpile\nhttp://paperpile.com",
        attachments.join('')].join('');
      Paperpile.utils.openURL.defer(10, this, [link]);
    };

    this.getFormattedText('Bibfile', 'EMAIL', myFunc);
  },

  handleCopyBibtexCitation: function() {
    this.handleCopy('Bibfile', 'BIBTEX', 'BibTeX copied');
  },
  handleCopyBibtexKey: function() {
    this.handleCopy('Bibfile', 'CITEKEYS', 'LaTeX citation{s} copied');
  },
  handleCopyFormatted: function() {
    this.handleCopy('Bibfile', 'CITATIONS', '{n} Citation{s} copied');
  },
  deleteEntry: function(mode, deleteAll) {

    var selection = this.getSelection();
    if (deleteAll) {
      selection = 'ALL';
    }

    if (this.getSelectionCount() == 0) {
	return;
    }

    // Find the lowest index of the current selection.
    var firstRecord = this.getSelectionModel().getLowestSelected();
    var firstIndex = this.getStore().indexOf(firstRecord);

    this.getSelectionModel().lock();

    if (mode == 'DELETE') {
      Paperpile.status.showBusy('Deleting references from library');
    }
    if (mode == 'TRASH') {
      Paperpile.status.showBusy('Moving references to Trash');
    }
    if (mode == 'RESTORE') {
      Paperpile.status.showBusy('Restoring references');
    }

    Paperpile.Ajax({
      url: '/ajax/crud/delete_entry',
      params: {
        selection: selection,
        grid_id: this.id,
        mode: mode
      },
      timeout: 10000000,
      success: function(response) {
        var data = Ext.util.JSON.decode(response.responseText);
        var num_deleted = data.num_deleted;

        // Does what it says: adds to the list of functions to call when the grid is next reloaded. This is handled in the customized 'onload' handler up at the top of the file.
        if (!this.doAfterNextReload) {
          this.doAfterNextReload = [];
        }
        this.getSelectionModel().unlock();
        this.doAfterNextReload.push(function() {
          this.getSelectionModel().selectRowAndSetCursor(firstIndex);
        });
        if (mode == 'TRASH') {
          var msg = num_deleted + ' references moved to Trash';
          if (num_deleted == 1) {
            msg = "1 reference moved to Trash";
          }

          Paperpile.status.updateMsg({
            msg: msg,
            action1: 'Undo',
            callback: function(action) {
              // TODO: does not show up, don't know why:
              Paperpile.status.showBusy('Undo...');
              Paperpile.Ajax({
                url: '/ajax/crud/undo_trash',
                success: function(response) {
                  Paperpile.status.clearMsg();
                },
                scope: this
              });
            },
            scope: this,
            hideOnClick: true
          });
        } else {
          Paperpile.status.clearMsg();
        }
      },
	  failure: function() {
	      this.getSelectionModel().unlock();
	  },
      scope: this
    });

  },

  handleEdit: function(isNew, autoComplete) {
    var selection = this.getSingleSelectionRecord();

    if (selection) {
      var rowid = selection.get('_rowid');
      var guid = selection.data.guid;
    }

    win = new Ext.Window({
      title: isNew ? 'Add new reference' : 'Edit reference',
      modal: true,
      floating: true,
      layout: 'fit',
      width: 800,
      height: 600,
      resizable: false,
      closable: true,
      items: [new Paperpile.MetaPanel({
        data: isNew ? {
          pubtype: 'ARTICLE'
        } : this.getSingleSelectionRecord().data,
        autoComplete: autoComplete,
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

    win.show(this);
  },

  updateMetadata: function() {
    var selection = this.getSelection();
    var selectionCount = this.getSelectionCount();

    if (selectionCount == 1) {
      this.handleEdit(false, true);
      return;
    }

    if (selection.length > 1) {

      Ext.MessageBox.buttonText.ok = "Start Update";

      Ext.Msg.show({
        title: 'Auto-complete',
        msg: 'Data for ' + selectionCount + ' references will be matched to online resources and automatically updated. Backup copies of the old data will be copied to the Trash. Continue?',
        animEl: 'elId',
        icon: Ext.MessageBox.INFO,
        buttons: Ext.Msg.OKCANCEL,
        fn: function(btn) {
          if (btn === 'ok') {
            if (selection.length > 30) {
              Ext.getCmp('queue-widget').onUpdate({
                submitting: true
              });
            }
            Paperpile.Ajax({
              url: '/ajax/crud/batch_update',
              params: {
                selection: selection,
                grid_id: this.id
              },
              success: function(response) {
                // Trigger a thread to start requesting queue updates.
                Paperpile.main.queueUpdate();
              }
            });
          }
          Ext.MessageBox.buttonText.ok = "Ok";
        },
        scope: this
      });
    }

  },

  batchDownload: function() {
    selection = this.getSelection();
    if (selection.length > 30) {
      Ext.getCmp('queue-widget').onUpdate({
        submitting: true
      });
    }
    Paperpile.Ajax({
      url: '/ajax/crud/batch_download',
      params: {
        selection: selection,
        grid_id: this.id
      },
      success: function(response) {
        // Trigger a thread to start requesting queue updates.
        Paperpile.main.queueUpdate();
      }
    });
  },

  cancelDownload: function() {
    var selected_id = this.getSingleSelectionRecord().data._search_job.id;
    Paperpile.Ajax({
      url: '/ajax/queue/cancel_jobs',
      params: {
        ids: selected_id
      }
    });
  },

  retryDownload: function() {
    var selected_id = this.getSingleSelectionRecord().data._search_job.id;
    Paperpile.Ajax({
      url: '/ajax/queue/retry_jobs',
      params: {
        ids: selected_id
      },
      success: function(response) {
        Paperpile.main.queueJobUpdate();
      }
    });

    // TODO: Do a more immediate update to the record so we don't have a delay there.
  },

  clearDownload: function() {
    var selected_id = this.getSingleSelectionRecord().data._search_job.id;
    Paperpile.Ajax({
      url: '/ajax/queue/remove_jobs',
      params: {
        ids: selected_id
      }
    });

    // TODO: Do a more immediate update to the record so we don't have a delay there.
  },

  formatEntry: function() {

    selection = this.getSelection();

    Paperpile.main.tabs.add(new Paperpile.Format({
      grid_id: this.id,
      selection: selection
    }));
  },

  refreshCollections: function() {
    // Go through each record and re-render it if it has some improperly styled labels.
    var n = this.getStore().getCount();
    for (var i = 0; i < n; i++) {
      var record = this.getStore().getAt(i);
      if (record.get('labels') || record.get('folders')) {
        this.getStore().fireEvent('update', this.getStore(), record, Ext.data.Record.EDIT);
      }
    }

    var overview = this.getPluginPanel().getOverviewPanel();
    if (overview.rendered) {
      overview.forceUpdate();
    }
  },

  // Update specific fields of specific entries to avoid complete
  // reload of everything.
  onUpdate: function(data) {
    var pubs = data.pubs;
    if (!pubs) {
      pubs = [];
    }

    var store = this.getStore();
    var selected_guid = '';
    var sel = this.getSingleSelectionRecord();
    if (sel) selected_guid = sel.data.guid;

    var updateSidePanel = false;
    for (var guid in pubs) {
      var record = store.getAt(store.findExact('guid', guid));
      if (!record) {
        continue;
      }
      var needsUpdating = false;
      var update = pubs[guid];
      record.editing = true; // Set the 'editing' flag.
      for (var field in update) {
        record.set(field, update[field]);
      }

      // Unset the 'editing' flag. Using the flag directly avoids calling store.afterEdit() for every record.
      record.editing = false;
      if (record.dirty) {
        needsUpdating = true;
        if (guid == selected_guid) updateSidePanel = true;
      }

      if (needsUpdating) {
        store.fireEvent('update', store, record, Ext.data.Record.EDIT);
      }
    }

    if (data.updateSidePanel) updateSidePanel = true;
    if (updateSidePanel) {
      this.refreshView.defer(20, this);
    }
  },

  forceSelectAll: function() {
    // Force immediate selection of ALL items.
    this.getSelectionModel().selectAll(true);
  },

  selectAll: function() {
    // First select page, then all.
    this.getSelectionModel().selectAll(false);
  },

  setSearchQuery: function() {
    // To be implemented by subclasses.
  },

  getSingleSelectionRecord: function() {
    return this.getSelectionModel().getSelected();
  },

  getFirstAuthorFromSelection: function() {
    var authors = this.getSingleSelectionRecord().data.authors || '';
    var arr = authors.split(/\s+and\s+/);
    var author = '';
    if (arr.length > 0) {
      author = arr[0];
    }
    return author;
  },

  getLastAuthorFromSelection: function() {
    var authors = this.getSingleSelectionRecord().data.authors || '';
    // Remove author entries enclosed in brackets, e.g. {et al.}
    authors = authors.replace(/{.*}/g, "");
    var arr = authors.split(/\s+and\s+/);
    var author = '';
    if (arr.length > 1) {
      author = arr[arr.length - 1];
    }
    return author;
  },

  getJournalFromSelection: function() {
    var journal = this.getSingleSelectionRecord().data.journal || '';
    return journal;
  },

  getYearFromSelection: function() {
    var year = this.getSingleSelectionRecord().data.year || '';
    return year;
  },

  moreFromLastAuthor: function() {
    var authors = this.getSingleSelectionRecord().data._authors_display || '';
    var arr = authors.split(/,\s+/);
    var author = '';
    if (arr.length > 0) {
      author = arr[arr.length - 1];
    }
    this.setSearchQuery('author:' + '"' + author + '"');
  },

  moreFromFirstAuthor: function() {
    var authors = this.getSingleSelectionRecord().data._authors_display || '';
    var arr = authors.split(/,\s+/);
    var author = '';
    if (arr.length > 0) {
      author = arr[0];
    }
    this.setSearchQuery('author:' + '"' + author + '"');
    /*
 	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'author:'+'"'+first_author+'"'},
					 first_author,
					 '',
					 first_author
					);
    */
  },
  moreFromYear: function() {
    var year = this.getYearFromSelection();
    if (year) {
      this.setSearchQuery('year:' + '"' + year + '"');
      /*	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'year:'+'"'+year+'"'},
					 year,
					 '',
					 year
					);
*/
    }
  },
  moreFromJournal: function() {
    var journal = this.getJournalFromSelection();
    if (journal) {
      this.setSearchQuery('journal:' + '"' + journal + '"');
      /*	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'journal:'+'"'+journal+'"'},
					 journal,
					 '',
					 journal
					);
*/
    }
  },

  openPDFFolder: function() {
    var sm = this.getSelectionModel();
    var record = this.getSingleSelectionRecord();
    if (record.data.pdf) {
      var pdf = record.data.pdf_name;
      var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
      var parts = Paperpile.utils.splitPath(path);
      // Need to defer this call, otherwise the context menu jumps to the upper-left side of screen... no idea why but this works!
      Paperpile.utils.openFile.defer(20, Paperpile.utils, [parts.dir]);
    }
  },

  viewPDF: function() {
    var sm = this.getSelectionModel();
    var record = this.getSingleSelectionRecord();
    if (record.data.pdf) {
      var pdf = record.data.pdf_name;
      var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
      Paperpile.main.tabs.newPdfTab({
        file: path,
        title: pdf
      });
      Paperpile.main.inc_read_counter(sm.getSelected().data);
    }
  },

  reloadFeed: function() {
    this.plugin_reload = 1;
    this.getStore().reload();
  },

  onDblClick: function(grid, rowIndex, e) {
    var sm = this.getSelectionModel();
    var record = sm.getSelected();
    if (record) {
      if (record.data._imported) {
        this.viewPDF();
      }
    }
  },

  onClose: function(cont, comp) {
    Paperpile.Ajax({
      url: '/ajax/plugins/delete_grids',
      params: {
        grid_ids: this.id
      }
    });
  },

  onDestroy: function() {
    Ext.destroy(this.getSelectionModel());
    Ext.destroy(this.getStore());
    Ext.destroy(this.keys);
    Ext.destroy(this.pager);
    Ext.destroy(this.context);

    Paperpile.PluginGrid.superclass.onDestroy.call(this);

  }
});

Paperpile.GridDropZone = function(grid, config) {
  this.grid = grid;
  Paperpile.GridDropZone.superclass.constructor.call(this, grid.view.scroller.dom, config);
};

Ext.extend(Paperpile.GridDropZone, Ext.dd.DropZone, {
  getTargetFromEvent: function(e) {
    return e.getTarget(this.grid.getView().rowSelector);
  },

  onNodeEnter: function(target, dd, e, data) {},

  onNodeOver: function(target, dd, e, data) {
    return this.grid.onNodeOver(target, dd, e, data);
  },

  onNodeDrop: function(target, dd, e, data) {
    var retVal = this.grid.onNodeDrop(target, dd, e, data);
    return retVal;
  },

  destroy: function() {
    Paperpile.GridDropZone.superclass.destroy.call();
    this.grid = null;
  },
  containerScroll: true
});

Ext.reg('pp-plugin-grid', Paperpile.PluginGrid);
/*
// Saving this one for later -- we could try and do some nice animation features when the user does batch imports using this code.
Ext.grid.AnimatedGridView = Ext.extend(Ext.grid.GridView, {
  initComponent: function() {
    Ext.grid.AnimatedGridView.superclass.initComponent.apply(this, arguments);
  },
  insertRows: function(dm, firstRow, lastRow, isUpdate) {
    Ext.grid.AnimatedGridView.superclass.insertRows.apply(this, arguments);
    var rowAdded = Ext.get(this.getRow(firstRow));
    if (rowAdded) {
      rowAdded.slideIn();
    }
  },
  removeRow: function(rowIndex) {
    var rowToRemove = Ext.get(this.getRow(rowIndex));
    var gridView = this;

    rowToRemove.slideOut('t', {
      remove: true
    });
  }
});
*/

Paperpile.Pager = Ext.extend(Ext.PagingToolbar, {
  initComponent: function() {
    Paperpile.Pager.superclass.initComponent.call(this);

    var items = [this.first, this.inputItem, this.afterTextItem, this.last, this.refresh];
    items = items.concat(this.findByType(Ext.Toolbar.Spacer));
    items = items.concat(this.findByType(Ext.Toolbar.Separator));
    for (var i = 0; i < items.length; i++) {
      this.remove(items[i], true);
    }

    var pageText = this.findBy(function(item, container) {
      if (item.text == this.beforePageText) {
        return true;
      } else {
        return false;
      }
    },
    this);
    //('text',this.beforePageText);
    this.remove(1, true);

    this.on('render', this.myOnRender, this);

  },
  myOnRender: function() {
    this.tip = new Ext.Tip({
      minWidth: 10,
      offsets: [0, -10],
      pager: this,
      renderTo: document.body,
      style: {
        'z-index': 100
      },
      updatePage: function(page, string) {
        this.dragging = true;
        this.body.update(string);
        this.doAutoWidth();
        var x = this.pager.getPositionForPage(page) - this.getBox().width / 2;
        var y = this.pager.getBox().y - this.getBox().height;
        this.setPagePosition(x, y);
      }
    });

    this.progressBar = new Ext.ProgressBar({
      text: '',
      width: 50,
      height: 10,
      animate: {
        duration: 1,
        easing: 'easeOutStrong'
      },
      cls: 'pp-toolbar-progress'
    });
    this.mon(
      this.progressBar, 'render', function(pb) {
        this.mon(pb.getEl(), 'mousedown', this.handleProgressBarClick, this);
        this.mon(pb.getEl(), 'mousemove', this.handleMouseMove, this);
        this.mon(pb.getEl(), 'mouseover', this.handleMouseOver, this);
        this.mon(pb.getEl(), 'mouseout', this.handleMouseOut, this);
      },
      this);
    this.insert(2, this.progressBar);
    this.insert(2, new Ext.Toolbar.Spacer({
      width: 5
    }));

    this.grid.mon(this.next, 'click', this.grid.onPageButtonClick, this.grid);
    this.grid.mon(this.prev, 'click', this.grid.onPageButtonClick, this.grid);

  },
  handleMouseOver: function(e) {
    this.tip.show();
  },
  handleMouseOut: function(e) {
    this.tip.hide();
  },
  handleMouseMove: function(e) {
    var page = this.getPageForPosition(e.getXY());
    if (page > 0) {
      //var string = page+" ("+page*this.pageSize+" - "+(page+1)*this.pageSize+")";
      var string = "Page " + page + " of " + Math.ceil(this.store.getTotalCount() / this.pageSize);
      this.tip.updatePage(page, string);
    } else {
      this.tip.hide();
    }
  },
  handleProgressBarClick: function(e) {
    this.changePage(this.getPageForPosition(e.getXY()));
    this.grid.onPageButtonClick();
  },
  getPositionForPage: function(page) {
    var pages = Math.ceil(this.store.getTotalCount() / this.pageSize);
    var position = Math.floor(page * (this.progressBar.width / pages));
    return this.progressBar.getBox().x + position;
  },
  getPageForPosition: function(xy) {
    var position = xy[0] - this.progressBar.getBox().x;
    var pages = Math.ceil(this.store.getTotalCount() / this.pageSize);
    var newpage = Math.ceil(position / (this.progressBar.width / pages));
    return newpage;
  },
  updateInfo: function() {
    Paperpile.Pager.superclass.updateInfo.call(this);
    var count = this.store.getCount();
    var pgData = this.getPageData();
    var pageNum = this.readPage(pgData);
    pageNum = pgData.activePage;
    var high = pageNum / pgData.pages;
    var low = (pageNum - 1) / pgData.pages;
    this.progressBar.updateRange(low, high, '');
    if (high == 1 && low == 0) {
      this.progressBar.disable();
      this.progressBar.getEl().applyStyles('cursor:normal');
    } else {
      this.progressBar.enable();
      this.progressBar.getEl().applyStyles('cursor:pointer');
    }
  }
});