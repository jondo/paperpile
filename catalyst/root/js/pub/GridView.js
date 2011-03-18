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

Ext.define('Paperpile.pub.Grid', {
  extend: 'Ext.Panel',
  alias: 'widget.pubgrid',
  plugin_query: '',
  region: 'center',
  labelStyles: {},
  isLocked: false,
  doAfterNextReload: [],

  initComponent: function() {

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
        //        cls: 'x-btn-text-icon edit',
        icon: '/images/icons/pencil.png',
        itemId: 'EDIT',
        triggerKey: 'e',
        tooltip: 'Edit the selected reference'
      }),
      'AUTO_COMPLETE': new Ext.Action({
        text: 'Auto-complete Data',
        handler: this.updateMetadata,
        scope: this,
        //        cls: 'x-btn-text-icon edit',
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

      'SELECT_ALL': new Ext.Action({
        text: 'Select all',
        handler: function(keyCode, event) {
          event.stopEvent();
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
      'UP_HOME': new Ext.Action({
        itemId: 'UP_HOME',
        text: 'Move the cursor to the top',
        handler: this.handleHome,
        scope: this
      }),
      'DOWN_END': new Ext.Action({
        itemId: 'DOWN_END',
        text: 'Move the cursor to the bottom',
        handler: this.handleEnd,
        scope: this
      }),
      'DOWN_PAGE': new Ext.Action({
        itemId: 'DOWN_PAGE',
        text: 'Move the cursor down one page',
        handler: this.handlePageDown,
        scope: this
      }),
      'UP_PAGE': new Ext.Action({
        itemId: 'UP_PAGE',
        text: 'Move the cursor up one page',
        handler: this.handlePageUp,
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
      'FOCUS_SEARCH': new Ext.Action({
        text: 'Search',
        handler: function() {
          this.handleFocusSearch();
        },
        scope: this,
        itemId: 'FOCUS_SEARCH'
      }),

      'TB_SPACE': new Ext.toolbar.Spacer({
        itemId: 'TB_SPACE',
        width: '10px'
      }),
      'TB_BREAK': new Ext.toolbar.Separator({
        itemId: 'TB_BREAK'
      }),
      'TB_FILL': new Ext.toolbar.Fill({
        itemId: 'TB_FILL'
      }),
      'TEST': new Ext.Action({
        handler: function() {
          if (this.templateKey === 'gallery') {
            this.setTemplate('list');
            this.templateKey = 'list';
          } else {
            this.setTemplate('gallery');
            this.templateKey = 'gallery';
          }
        },
        scope: this
      }),
      'FONT_SIZE': new Ext.Action({
        itemId: 'FONT_SIZE',
        handler: function() {
          this.fontSize();
        },
        scope: this
      }),
      'SETTINGS': new Ext.Action({
        itemId: 'SETTINGS',
        text: 'Settings',
        iconCls: 'pp-icon-dashboard',
        tooltip: 'Change your settings and view library stats',
        handler: function() {
          Paperpile.main.tabs.showDashboardTab();
        }
      })

    };

    this.actions['PDF_COMBINED_BUTTON'] = new Ext.menu.Menu({
      itemId: 'PDF_COMBINED_BUTTON',
      items: [
        this.actions['VIEW_PDF'],
        this.actions['OPEN_PDF_FOLDER']]
    });
    this.actions['PDF_COMBINED_BUTTON2'] = new Ext.menu.Menu({
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

    this.actions['EXPORT_MENU'] = new Ext.button.Split({
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

    var me = this;
    this.view = new Ext.DataView({
      itemId: 'grid',
      autoheight: true,
      multiSelect: true,
      trackOver: true,
      overItemCls: 'pp-grid-over',
      selectedItemCls: 'pp-grid-selected',
      store: this.getStore(),
      tpl: Paperpile.grid.GridTemplates.list(),
      itemSelector: 'div.pp-grid-item',
      listeners: {
        contextmenu: {
          fn: me.onContextClick,
          scope: me
        }
      },
      getSelectionModel: function() {
        if (!this.selModel) {
          var me = this;
          this.selModel = new Paperpile.grid.SelectionModel();
        }
        return this.selModel;
      },
      focus: function() {
        me.focus();
      },
      focusRow: function(rowIndex) {
        me.focusRow(rowIndex);
      }
    });

    this.relayEvents(this.getSelectionModel(), ['selectionchange']);
    this.relayEvents(this.getSelectionModel(), ['afterselectionchange']);

    this.pager = new Ext.PagingToolbar({
      dock: 'bottom',
      pageSize: this.limit,
      store: this.getStore(),
      displayInfo: true,
      displayMsg: '<span style="color:black;">Displaying {0} - {1} of {2}</span>',
      emptyMsg: "No references to display"
    });
    this.pager.on('pagebutton', function(pager) {
      this.onPageButtonClick();
    },
    this);

    this.tbar = new Ext.toolbar.Toolbar({
      itemId: 'toolbar',
      dock: 'top',
      enableOverflow: true,
      menuBreakItemId: 'TB_BREAK',
      items: [{
        xtype: 'button',
        text: 'heyo!'
      }]
    });

    var dockItems = [this.tbar];

    Ext.apply(this, {
      itemId: 'grid',
      autoScroll: true,
      items: [this.view],
      dockedItems: dockItems
    });

    this.callParent(arguments);

    this.createContextMenu();

    this.on({
      // Delegate to class methods.
      beforerender: {
        scope: this,
        fn: this.myBeforeRender
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
      Paperpile.main.onError(response, options);
    },
    this);

    this.mon(this.getSelectionModel(), 'afterselectionchange', function() {

      if (Paperpile.status.messageToHideOnClick) {
        //        Paperpile.status.clearMessageNumber(Paperpile.status.messageToHideOnClick);
        //        Paperpile.status.messageToHideOnClick = null;
      }
    },
    this);

    this.mon(this.getSelectionModel(), 'allselected', function() {
      this.onAllSelected();
    },
    this);

    // Auto-select the first row when the store finally loads up.
    this.mon(this.getStore(), 'load', function() {
      if (this.getStore().getCount() > 0) {
        this.selectRowAndSetCursor(0);
        //        this.afterSelectionChange(this.getSelectionModel());
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

  getTemplate: function() {
    return this.getPubTemplate();
  },

  getSelector: function() {
    return 'div.pp-grid-item';
  },

  getSelectionModel: function() {
    return this.getView().getSelectionModel();
  },

  getView: function() {
    // Returns an ext.DataView
    return this.view;
  },

  installEvents: function() {
    this.mon(this.el, 'click', this.handleClick, this);
  },

  // Overriding the default Component method.
  getFocusEl: function() {
    return this.focusEl;
  },

  focusRow: function(rowIdx) {
    var node = this.view.getNode(rowIdx),
    el = this.body,
    adjustment = 0,
    elRegion = el.getRegion(),
    gridpanel = this.up('gridpanel'),
    rowRegion,
    record;

    if (node) {
      rowRegion = Ext.fly(node).getRegion();
      // row is above
      if (rowRegion.top < elRegion.top) {
        adjustment = rowRegion.top - elRegion.top;
        // row is below
      } else if (rowRegion.bottom > elRegion.bottom) {
        adjustment = rowRegion.bottom - elRegion.bottom;
      }
      if (adjustment) {
        el.dom.scrollTop += adjustment;
      }
    }
  },

  loadKeyboardShortcuts: function() {
    this.keys = new Ext.ux.KeyboardShortcuts(this.getFocusEl());

    this.keys.bindAction('ctrl-t', this.actions['TEST']);

    // Standard grid shortcuts.
    this.keys.bindAction('ctrl-q', this.actions['FONT_SIZE']);
    this.keys.bindAction('ctrl-a', this.actions['SELECT_ALL']);
    this.keys.bindAction('[Del,46]', this.actions['DELETE']);
    this.keys.bindAction('[Del,8]', this.actions['DELETE']);

    // Copy shortcuts.
    this.keys.bindAction('ctrl-c', this.actions['COPY_FORMATTED']);
    this.keys.bindAction('ctrl-b', this.actions['COPY_BIBTEX_CITATION']);
    this.keys.bindAction('ctrl-k', this.actions['COPY_BIBTEX_KEY']);

    // Gmail-style n/p, j/k movements.
    this.keys.bindAction('home', this.actions['UP_HOME']);
    this.keys.bindAction('end', this.actions['DOWN_END']);
    this.keys.bindAction('page_down', this.actions['DOWN_PAGE']);
    this.keys.bindAction('page_up', this.actions['UP_PAGE']);
    this.keys.bindAction('down', this.actions['DOWN_ONE']);
    this.keys.bindAction('n', this.actions['DOWN_ONE']);
    this.keys.bindAction('shift-n', this.actions['DOWN_ONE']);
    this.keys.bindAction('up', this.actions['UP_ONE']);
    this.keys.bindAction('p', this.actions['UP_ONE']);
    this.keys.bindAction('shift-p', this.actions['UP_ONE']);
    this.keys.bindAction('j', this.actions['DOWN_ONE']);
    this.keys.bindAction('shift-j', this.actions['DOWN_ONE']);
    this.keys.bindAction('k', this.actions['UP_ONE']);
    this.keys.bindAction('shift-k', this.actions['UP_ONE']);

    this.keys.bindAction('[End,35]', this.actions['MOVE_LAST']);
    this.keys.bindAction('[Home,36]', this.actions['MOVE_FIRST']);

    this.keys.bindAction('[/,191]', this.actions['FOCUS_SEARCH']);
    this.keys.bindAction('ctrl-f', this.actions['FOCUS_SEARCH']);
  },

  handleFocusSearch: function() {
    // To be implemented by subclasses or plugins.
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
    case 'locate-ref':
      this.locateInLibrary();
      break;
    case 'import-ref':
      this.insertEntry();
      break;
    case 'lookup-details':
      this.lookupDetails();
      break;
    }
  },

  onAllSelected: function() {
    var num = this.getSelectionModel().getCount();
    /*
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
    */
    // Create a callback to clear this message if the selection changes.
    /*
    var messageNum = Paperpile.status.getMessageNumber();
    var clearMsg = function() {
      Paperpile.status.clearMessageNumber(messageNum);
    };
    this.mon(this.getSelectionModel(), 'afterselectionchange', clearMsg, this, {
      single: true
    });
    */
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
    var dragAllowed = true;

    if (data.grid) {
      e.cancel = true;
      dragAllowed = false;
    } else if (data.node) {
      e.cancel = false;
      dragAllowed = true;
    }

    dragAllowed = this.updateDragStatus(nodeData, source, e, data);

    var retVal = '';
    if (!dragAllowed) {
      retVal = Ext.dd.DropZone.prototype.dropNotAllowed;
    } else {
      retVal = Ext.dd.DropZone.prototype.dropAllowed;
    }

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
        return true;
        //proxy.updateTip('Apply label to reference');
      } else if (myType == 'FOLDER') {
        return true;
        //proxy.updateTip('Place reference in folder');
      } else {
        return false;
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
    // Used to indicate complete loading during startup
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
  },

  afterSelectionChange: function(sm) {
    //    this.getPluginPanel().updateDetails();
  },

  refreshView: function() {
    if (!this.isVisible()) {
      //      return;
    }
  },

  afterRender: function(ct) {
    var me = this;
    me.callParent(arguments);
    me.focusEl = me.el.createChild({
      tag: 'a',
      cls: 'pp-grid-focus',
      href: '#',
      html: '&#160;'
    });

    this.installEvents();
    this.loadKeyboardShortcuts();
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
    //this.mon(this.getSelectionModel(), 'afterselectionchange', this.afterSelectionChange, this);
    this.createAuthorToolTip();
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
      var key = this.getSingleSelection().get('citekey');
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
    if (this._store) {
      return this._store;
    }
    this._store = new Ext.data.Store({
      autoLoad: true,
      model: 'Publication',
      proxy: new Ext.data.HttpProxy({
        model: 'Publication',
        idProperty: 'guid',
        url: Paperpile.Url('/ajax/plugins/resultsgrid'),
        // We don't set timeout here but handle timeout separately in
        // specific plugins.
        timeout: 10000000,
        method: 'GET',
        extraParams: {
          grid_id: this.id,
          plugin_file: this.plugin_file,
          plugin_name: this.plugin_name,
          plugin_query: this.plugin_query,
          plugin_mode: this.plugin_mode,
          plugin_order: Paperpile.main.globalSettings['sort_field'],
          limit: this.limit
        },
      }),
    });

    // Add some callbacks to the store so we can maintain the selection between reloads.
    this.mon(this.getStore(), 'load', function(store, options) {
      this.getStore().isLoaded = true;
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
        this.selectRowAndSetCursor(0);
      }
    });
  },

  selectRowAndSetCursor: function(index) {
    // Do nothing for now.
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

  setTemplate: function(key) {
    var tpl = Paperpile.grid.GridTemplates[key].call(Paperpile.grid.GridTemplates);
    this.view.tpl = tpl;
    this.view.refresh();
  },

  getPubTemplate: function() {
    return Paperpile.grid.GridTemplates.list();
  },

  getImportedIconTemplate: function() {
    var tpl = [
      '  <tpl if="trashed==0">',
      '    <div class="pp-grid-status pp-grid-status-imported" ext:qtip="[<b>{_citekey}</b>]<br>added {_createdPretty}"></div>',
      '  </tpl>',
      '  <tpl if="trashed==1">',
      '    <div class="pp-grid-status pp-grid-status-deleted" ext:qtip="[<b>{_citekey}</b>]<br>deleted {_createdPretty}"></div>',
      '  </tpl>'];
    return tpl.join('');
  },

  getIconTemplate: function() {
    if (this.iconTemplate != null) {
      return this.iconTemplate;
    }
    this.iconTemplate = new Ext.XTemplate(
      '<div class="pp-grid-info">',
      '<tpl if="_imported">',
      this.getImportedIconTemplate(),
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
      /*
 * Hover-buttons over the grid -- save it for the ext4 rewrite...
 * 
      '<tpl if="_needs_details_lookup == 1">',
      '  <div class="pp-grid-status pp-grid-status-lookup" ext:qtip="Lookup details" action="lookup-details"></div>',
      '</tpl>',
      '<tpl if="!_imported">',
      '  <div class="pp-grid-status pp-grid-status-import" ext:qtip="Import reference" action="import-ref"></div>',
      '</tpl>',
*/
      '</div>').compile();
    return this.iconTemplate;
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
      'EXPORT_MENU',
      this.createSeparator('TB_SETTINGS_SEP'),
      'SETTINGS']);
  },

  // Same as above, but for the context menu.
  initContextMenuItemIds: function() {
    this.contextMenuItemIds = new Ext.util.MixedCollection();
    this.contextMenuItemIds.addAll([
      'VIEW_PDF',
      'OPEN_PDF_FOLDER',
      //				        'PDF_COMBINED_BUTTON',
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
    this.actions[itemId] = new Ext.toolbar.Separator({
      itemId: itemId
    });
    return itemId;
  },

  getTopToolbar: function() {
    return this.tbar;
    //return this.getDockedItems.child('toolbar');
  },

  createToolbarMenu: function() {
    return;

    var tbar = this.getTopToolbar();
    tbar.removeAll();

    this.initToolbarMenuItemIds();
    var itemIds = this.toolbarMenuItemIds; // This is an Ext.util.MixedCollection.
    for (var i = 0; i < itemIds.length; i++) {
      var id = itemIds.getAt(i);
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
      var id = itemIds.getAt(i);
      context.insert(i, this.actions[id]);
      if (this.actions[id] && this.actions[id] instanceof Ext.Action) {
        this.actions[id].addComponent(context.items.getAt(i));
      }
    }
  },

  onContextClick: function(view, index, node, event) {
    if (!this.getSelectionModel().isSelected(index)) {
      this.getSelectionModel().selectRow(index);
    } else {
      this.getSelectionModel().setCursor(index);
    }

    //    this.refreshView();
    var xy = event.getXY();
    this.context.show();
    this.context.setPosition(xy[0], xy[1]);
    event.preventDefault();
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
    var docked = this.getDockedItems();

    Ext.Array.forEach(docked, function(item, index, length) {
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

    var selection = this.getSingleSelection();

    this.actions['SELECT_ALL'].setText('Select All');
    if (this.isAllSelected() || this.getTotalCount() == 0) {
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

    //    var tbar = this.getTopToolbar();
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

    if (this.getStore().getCount() == 0) {
      this.actions['EXPORT_MENU'].disable();
      this.actions['EXPORT_SELECTION'].disable();
      this.actions['EXPORT_VIEW'].disable();
    }
  },

  updateToolbarItem: function(menuItem) {
    return;
  },

  getToolbarByItemId: function(itemId) {
    return this.getDockedComponent(itemId);
  },

  getContextByItemId: function(itemId) {
    return this.getContextMenu().items.getAt(this.getContextIndex(itemId));
  },

  // Small helper functions to get the index of a given item in the toolbar configuration array
  // We have to use the text instead of itemId. Actions do not seem to support itemIds.
  // A better solution should be possible with ExtJS 3
  getContextIndex: function(itemId) {
    var context = this.getContextMenu();
    for (var i = 0; i < context.items.length; i++) {
      var item = context.items.getAt(i);
      if (item.itemId == itemId) return i;
    }
    return -1;
  },

  getButtonIndex: function(itemId) {
    var tbar = this.getDockedComponents();
    for (var i = 0; i < tbar.items.length; i++) {
      var item = tbar.items.getAt(i);
      if (item.itemId == itemId) return i;
    }
    return -1;
  },

  getPluginPanel: function() {
    return this.up('widget.pp-pluginpanel');
  },

  getSelectionAsList: function(what) {
    if (!what) what = 'ALL';
    var selection = [];
    var sels = this.getSelectionModel().getSelection();
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
    if (this.isAllSelected()) {
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
  lookupDetails: function() {
    if (this.lookupDetailsLock) return; // Call completeEntry only for one item at a time 
    this.lookupDetailsLock = true;

    // We only look up details for a single record.
    var sel = this.getSingleSelection();
    if (!sel) return;

    var data = sel.data;

    if (!data._needs_details_lookup) {
      Paperpile.log("Details lookup was called on a publication that apparently doesn't need it -- this is a problem!");
    }

    if (data._needs_details_lookup) {
      var guid = data.guid;

      Paperpile.status.updateMsg({
        busy: true,
        msg: 'Looking up bibliographic data',
        action1: 'Cancel',
        callback: function() {
          Ext.Ajax.abort(this.lookupDetailsTransaction);
          this.cancelLookupDetails();
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
        Ext.Ajax.abort(this.lookupDetailsTransaction);
        this.cancelLookupDetails();
        Paperpile.status.clearMsg();
        Paperpile.status.updateMsg({
          msg: 'Data lookup failed. There may be problems with your network or ' + this.plugin_name + '.',
          hideOnClick: true
        });
        this.lookupDetailsLock = false;
      }).defer(20000, this);

      this.lookupDetailsTransaction = Paperpile.Ajax({
        url: '/ajax/crud/complete_entry',
        params: {
          selection: sel.id,
          grid_id: this.id,
          cancel_handle: this.id + '_lookup'
        },
        success: function(response, options) {
          var json = Ext.util.JSON.decode(response.responseText);
          this.lookupDetailsLock = false;

          clearTimeout(this.timeoutWarn);
          clearTimeout(this.timeoutAbort);

          if (json.error) {
            Paperpile.main.onError(response, options);
            return;
          }

          Paperpile.status.clearMsg();
          this.updateButtons();
          this.getPluginPanel().updateDetails();
        },
        failure: function(response, options) {
          this.lookupDetailsLock = false;
          clearTimeout(this.timeoutWarn);
          clearTimeout(this.timeoutAbort);
        },
        scope: this
      });
    }
  },

  cancelLookupDetails: function() {

    clearTimeout(this.timeoutWarn);
    clearTimeout(this.timeoutAbort);

    Ext.Ajax.abort(this.lookupDetailsTransaction);
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

  getVisibleRows: function() {
    var visibleRows = [];
    var gridBox = this.body.getBox();
    var rowCount = this.getStore().getCount();
    for (var i = 0; i < rowCount; i++) {
      var row = this.view.getNode(i);
      var xy = Ext.fly(row).getOffsetsTo(this.getEl());
      if (xy[1] < 0) {
        // If we're above the toolbar, we're too high and out of view.
        continue;
      }
      if (xy[1] < gridBox.height) {
        // If we're less than the grid's box height below the toolbar, we're probably OK.
        visibleRows.push(i);
      }
    }
    return visibleRows;
  },

  handleHome: function(keyCode, event) {
    var cursor = this.getSelectionModel().getCursor();
    if (cursor !== null) {
      var distance = -cursor;
      this.getSelectionModel().keyNavMove(distance, event);
    } else {
      this.getSelectionModel().selectFirstRow();
    }
  },

  handleEnd: function(keyCode, event) {
    var rowCount = this.getStore().getCount();
    var cursor = this.getSelectionModel().getCursor();
    if (cursor !== null) {
      var distance = rowCount - cursor;
      this.getSelectionModel().keyNavMove(distance, event);
    } else {
      this.getSelectionModel().selectLastRow();
    }
  },

  handlePageDown: function(keyCode, event) {
    var rows = this.getVisibleRows();
    this.getSelectionModel().keyNavMove(rows.length, event);
  },

  handlePageUp: function(keyCode, event) {
    var rows = this.getVisibleRows();
    this.getSelectionModel().keyNavMove(-rows.length, event);
  },

  handleDownOne: function(keyCode, event) {
    var sm = this.getSelectionModel();
    var t = this.pager;
    var activePage = Math.ceil((t.cursor + t.pageSize) / t.pageSize);
    if (sm.getCount() == 1 && this.getStore().indexOf(this.getSingleSelection()) == this.pager.pageSize - 1 && !this.pager.next.disabled) {
      this.pager.moveNext();
      this.doAfterNextReload.push(function() {
        this.selectRowAndSetCursor(0);
      });
    } else {
      this.getSelectionModel().keyNavMove(1, event);
    }
  },
  handleUpOne: function(keyCode, event) {
    var sm = this.getSelectionModel();
    if (sm.getCount() == 1 && this.getStore().indexOf(this.getSingleSelection()) == 0 && !this.pager.prev.disabled) {
      this.pager.movePrevious();
      this.doAfterNextReload.push(function() {
        this.selectRowAndSetCursor(this.pager.pageSize - 1);
      });
    } else {
      this.getSelectionModel().keyNavMove(-1, event);
    }
  },
  handleMoveFirst: function(keyCode, event) {
    this.selectRowAndSetCursor(0);
  },
  handleMoveLast: function(keyCode, event) {
    this.selectRowAndSetCursor(this.getStore().getCount() - 1);
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

  handleViewOnline: function() {
    // Chooses which data source to use to link to the article online.
    var selection = this.getSingleSelection();

    var url;
    var data = selection.data;
    if (data.pmid) {
      url = 'http://www.ncbi.nlm.nih.gov/pubmed/' + data.pmid;
    } else if (data.doi) {
      url = 'http://dx.doi.org/' + data.doi;
    } else if (data.eprint) {
      url = data.eprint;
    } else if (data.arxivid) {
      url = 'http://arxiv.org/abs/' + data.arxivid;
    } else if (data.url) {
      url = data.url;
    }
    Paperpile.utils.openURL(url);
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
        this.getSelectionModel().unlock();
        this.doAfterNextReload.push(function() {
          this.selectRowAndSetCursor(firstIndex);
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
    var selection = this.getSingleSelection();

    if (selection) {
      var rowid = selection.get('_rowid');
      var guid = selection.data.guid;
    }

    win = new Ext.Window({
      title: isNew ? 'Add new reference' : 'Edit reference',
      modal: true,
      shadow: false,
      layout: 'fit',
      width: 800,
      height: 600,
      resizable: false,
      closable: true,
      items: [new Paperpile.MetaPanel({
        data: isNew ? {
          pubtype: 'ARTICLE'
        } : this.getSingleSelection().data,
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
    win.on('close', function() {
      Paperpile.main.focusCurrentPanel();
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
            Paperpile.main.queueWidget.setSubmitting();
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

  locateInLibrary: function() {
    var record = this.getSingleSelection();
    Paperpile.main.showReferenceInLibrary(record);
  },

  batchDownload: function() {
    var selection = this.getSelection();
    if (selection.length > 1) {
      Paperpile.main.queueWidget.setSubmitting();
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
    var selected_id = this.getSingleSelection().data._search_job.id;
    Paperpile.Ajax({
      url: '/ajax/queue/cancel_jobs',
      params: {
        ids: selected_id
      }
    });
  },

  retryDownload: function() {
    var selected_id = this.getSingleSelection().data._search_job.id;
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
    var selected_id = this.getSingleSelection().data._search_job.id;
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
    return;
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
    var sel = this.getSingleSelection();
    if (sel) selected_guid = sel.data.guid;

    // Track the rowIndex of the row that the mouse is currently hovering (if any).
    var mouseOverRow = undefined;

    var updateSidePanel = false;
    for (var guid in pubs) {
      var rowIndex = store.findExact('guid', guid);
      var record = store.getAt(rowIndex);
      if (!record) {
        continue;
      }
      var needsUpdating = false;
      var update = pubs[guid];
      record.editing = true; // Set the 'editing' flag.
      for (var field in update) {
        if (update[field] != record.get(field)) {
          record.set(field, update[field]);
        }
      }

      // Unset the 'editing' flag. Using the flag directly avoids calling store.afterEdit() for every record.
      record.editing = false;
      if (record.dirty) {
        needsUpdating = true;
        if (guid == selected_guid) updateSidePanel = true;
      }

      // Store this rowIndex if the mouse is hovering here.
      var r = this.getView().getRow(rowIndex);
      if (Ext.fly(r).hasClass('x-grid3-row-over')) {
        mouseOverRow = rowIndex;
      }
      if (needsUpdating) {
        store.fireEvent('update', store, record, Ext.data.Record.EDIT);
      }
    }

    if (data.updateSidePanel) updateSidePanel = true;
    if (updateSidePanel) {
      this.refreshView.defer(20, this);
    }

    if (mouseOverRow !== undefined) {
      // Re-apply the hover effect to get rid of the flickering during updates.
      var r = this.getView().getRow(mouseOverRow);
      Ext.fly(r).addClass('x-grid3-row-over');
    }
  },

  selectAll: function() {
    this.getSelectionModel().selectAll();
    this._allSelected = true;
  },

  isAllSelected: function() {
    if (this._allSelected) {
      return true;
    } else {
      return false;
    }
  },

  setSearchQuery: function() {
    // To be implemented by subclasses.
  },

  getSingleSelection: function() {
    var selections = this.getSelectionModel().getSelection();
    if (selections.length > 0) {
      return selections[0];
    } else {
      return undefined;
    }
  },

  // Return a list of whatever's selected. Could be an empty list.
  getSelectionRecords: function() {
    return this.getSelectionModel().getSelection();
  },

  getFirstAuthorFromSelection: function() {
    var authors = this.getSingleSelection().data.authors || '';
    var arr = authors.split(/\s+and\s+/);
    var author = '';
    if (arr.length > 0) {
      author = arr[0];
    }
    return author;
  },

  getLastAuthorFromSelection: function() {
    var authors = this.getSingleSelection().data.authors || '';
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
    var journal = this.getSingleSelection().data.journal || '';
    return journal;
  },

  getYearFromSelection: function() {
    var year = this.getSingleSelection().data.year || '';
    return year;
  },

  moreFromLastAuthor: function() {
    var authors = this.getSingleSelection().data._authors_display || '';
    var arr = authors.split(/,\s+/);
    var author = '';
    if (arr.length > 0) {
      author = arr[arr.length - 1];
    }
    this.setSearchQuery('author:' + '"' + author + '"');
  },

  moreFromFirstAuthor: function() {
    var authors = this.getSingleSelection().data._authors_display || '';
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
    var record = this.getSingleSelection();
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
    var record = this.getSingleSelection();
    if (record.data.pdf) {
      var pdf = record.data.pdf_name;
      var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
      Paperpile.main.tabs.newPdfTab({
        file: path,
        filename: pdf
      });
      Paperpile.main.inc_read_counter(this.getSingleSelection().data);
    }
  },

  reloadFeed: function() {
    this.plugin_reload = 1;
    this.getStore().reload();
  },

  onDblClick: function(grid, rowIndex, e) {
    var sm = this.getSelectionModel();
    var record = this.getSingleSelection();
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

    this.callParent(arguments);

  }
});