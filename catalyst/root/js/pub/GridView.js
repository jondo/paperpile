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
  doAfterNextReload: [],

  initComponent: function() {
    this.extraActions = {
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
    };

    var me = this;
    this.view = new Ext.DataView({
      itemId: 'grid',
      autoheight: true,
      multiSelect: true,
      trackOver: true,
      // Remove the loading text to kill the loading mask.
      loadingText: null,
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

    this.pager = this.createPager();
    this.toolbar = this.createToolbar();
    var dockItems = [this.pager, this.toolbar];

    Ext.apply(this, {
      itemId: 'grid',
      autoScroll: true,
      items: [this.view],
      dockedItems: dockItems
    });

    this.callParent(arguments);

    this.createContextMenu();
    this.mon(this.getStore(), 'loadexception', function(exception, options, response, error) {
      Paperpile.main.onError(response, options);
    },
    this);

  },

  createPager: function() {
    var pager = new Paperpile.grid.Pager({
      dock: 'bottom',
      store: this.getStore(),
      displayInfo: true
    });
    pager.on('pagebutton', function(pager) {
      this.onPageButtonClick();
    },
    this);
    return pager;
  },

  initialLoad: function() {
    if (this.isLoaded()) {
      Paperpile.log("Calling initialLoad on an already loaded store -- for shame...");
    }
    var store = this.getStore();
    var limit = Paperpile.Settings.get('pager_limit') || 25;
    store.pageSize = limit;
    store.load();
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

  refresh: function() {
    this.getView().refresh();
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

    a = Paperpile.app.Actions;

    this.keys.bindAction('ctrl-t', this.getAction('TEST'));

    // Standard grid shortcuts.
    this.keys.bindAction('ctrl-a', a.get('SELECT_ALL'));
    this.keys.bindAction('[Del,46]', a.get('TRASH'));
    this.keys.bindAction('[Del,8]', a.get('TRASH'));

    // Copy shortcuts.
    this.keys.bindAction('ctrl-c', a.get('COPY_FORMATTED'));
    this.keys.bindAction('ctrl-b', a.get('COPY_BIBTEX_CITATION'));
    this.keys.bindAction('ctrl-k', a.get('COPY_BIBTEX_KEY'));

    // Gmail-style n/p, j/k movements.
    this.keys.bindAction('home', a.get('UP_HOME'));
    this.keys.bindAction('end', a.get('DOWN_END'));
    this.keys.bindAction('page_down', a.get('DOWN_PAGE'));
    this.keys.bindAction('page_up', a.get('UP_PAGE'));
    this.keys.bindAction('down', a.get('DOWN_ONE'));
    this.keys.bindAction('n', a.get('DOWN_ONE'));
    this.keys.bindAction('shift-n', a.get('DOWN_ONE'));
    this.keys.bindAction('up', a.get('UP_ONE'));
    this.keys.bindAction('p', a.get('UP_ONE'));
    this.keys.bindAction('shift-p', a.get('UP_ONE'));
    this.keys.bindAction('j', a.get('DOWN_ONE'));
    this.keys.bindAction('shift-j', a.get('DOWN_ONE'));
    this.keys.bindAction('k', a.get('UP_ONE'));
    this.keys.bindAction('shift-k', a.get('UP_ONE'));

    this.keys.bindAction('[End,35]', a.get('MOVE_LAST'));
    this.keys.bindAction('[Home,36]', a.get('MOVE_FIRST'));

    this.keys.bindAction('[/,191]', a.get('FOCUS_SEARCH'));
    this.keys.bindAction('ctrl-f', a.get('FOCUS_SEARCH'));
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

  onStoreLoad: function() {
    // Used to indicate complete loading during startup
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

  myBeforeRender: function(ct) {},

  afterRender: function(ct) {
    var me = this;
    me.callParent(arguments);
    me.focusEl = me.el.createChild({
      tag: 'a',
      cls: 'pp-grid-focus',
      href: '#',
      html: '&#160;'
    });

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
    this.authorTip = new Ext.tip.ToolTip({
      maxWidth: 600,
      showDelay: 0,
      hideDelay: 0,
      target: this.getEl(),
      delegate: '.pp-authortip',
      renderTo: document.body,
      listeners: {
        beforeshow: {
          fn: function(tip) {
            var node = this.getView().findItemByChild(tip.triggerElement);
            var pub = this.getView().getRecord(node);
            tip.body.dom.innerHTML = pub.data._authortip;
          },
          scope: this
        }
      }
    });
  },

  getStore: function() {
    if (this._store !== undefined) {
      return this._store;
    }
    var me = this;
    this._store = new Ext.data.Store({
      autoLoad: false,
      remoteFilter: true,
      autoDestroy: false,
      model: 'Publication',
      proxy: new Ext.data.AjaxProxy({
        url: Paperpile.Url('/ajax/plugins/resultsgrid'),
        // We don't set timeout here but handle timeout separately in
        // specific plugins.
        timeout: 1000000,
        method: 'GET',
        extraParams: {
          grid_id: me.id,
          plugin_file: me.plugin_file,
          plugin_name: me.plugin_name,
          plugin_query: me.plugin_query,
          plugin_mode: me.plugin_mode,
          plugin_order: Paperpile.Settings.get('sort_field')
        },
      }),
    });

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
    if (!this.getStore()) {
      return;
    }
    // The refresh button does not get reset and keeps
    // spinning. It is resetted if an error occurs in the
    // proxy. Therefore I call the exception explicitly as a
    // workaround
    this.getStore().proxy.fireEvent('exception');

    this.getStore().proxy.getConnection().abort();

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

  gridTemplates: {},

  setTemplate: function(key) {
    var tpl = Paperpile.grid.GridTemplates[key].call(Paperpile.grid.GridTemplates);
    this.view.tpl = tpl;
    this.view.refresh();
  },

  getPubTemplate: function() {
    return Paperpile.grid.GridTemplates.list();
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
      'EDIT', ]);
  },

  // Same as above, but for the context menu.
  initContextMenuItemIds: function() {
    this.contextMenuItemIds = new Ext.util.MixedCollection();
    this.contextMenuItemIds.addAll([
      'OPEN_PDF',
      'OPEN_PDF_FOLDER',
      this.createContextSep('CONTEXT_SEP1'),
      'EDIT',
      'AUTO_COMPLETE',
      'SELECT_ALL',
      'TRASH',
      this.createContextSep('CONTEXT_SEP2'),
      'EXPORT_SELECTION',
      this.createContextSep('CONTEXT_SEP3'),
      'COPY_FORMATTED',
      'COPY_BIBTEX_CITATION',
      'COPY_BIBTEX_KEY']);
  },

  createContextSep: function(itemId) {
    this.extraActions[itemId] = new Ext.menu.Separator({
      itemId: itemId
    });
    return itemId;
  },

  createTbSep: function(itemId) {
    this.extraActions[itemId] = new Ext.toolbar.Separator({
      itemId: itemId
    });
    return itemId;
  },

  getToolbar: function() {
    return this.toolbar;
  },

  createToolbar: function() {
    var toolbar = new Ext.toolbar.Toolbar({
      enableOverflow: false
    });

    Ext.apply(this.extraActions, {
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
      'EXPORT_MENU': new Ext.button.Split({
        text: 'Export to File',
        itemId: 'EXPORT_MENU',
        handler: this.handleExportView,
        //iconCls: 'pp-icon-save',
        scope: this,
        menu: {
          items: [
            Paperpile.app.Actions.get('EXPORT_VIEW'),
            Paperpile.app.Actions.get('EXPORT_SELECTION')]
        }
      })
    });

    this.initToolbarMenuItemIds();
    var itemIds = this.toolbarMenuItemIds;
    for (var i = 0; i < itemIds.length; i++) {
      var id = itemIds.getAt(i);
      var action = this.getAction(id);
      var cmp;
      if (action) {
        cmp = toolbar.add(action);
        var index = toolbar.items.indexOf(cmp);
        toolbar.move(index, toolbar.items.getCount());
      } else {
        Paperpile.log("No action found for " + id);
      }
    }
    return toolbar;
  },

  getContextMenu: function() {
    return this.context;
  },

  createContextMenu: function() {

    this.context = new Ext.menu.Menu({
      plugins: [new Ext.ux.TDGi.MenuKeyTrigger()],
      hideTooltips: true,
      // Custom flag which hides tooltips in menu items.
      listeners: {
        contextmenu: {
          fn: function(event) {
            event.preventDefault();
          },
          element: 'el'
        }
      }
    });
    var context = this.context;
    this.initContextMenuItemIds();
    var itemIds = this.contextMenuItemIds; // This is an Ext.util.MixedCollection.
    for (var i = 0; i < itemIds.length; i++) {
      var id = itemIds.getAt(i);
      var action = this.getAction(id);
      var cmp;
      if (action) {
        cmp = context.add(action);
        var index = context.items.indexOf(cmp);
        context.move(index, context.items.getCount());
      } else {
        Paperpile.log("No action found for " + id);
      }
    }
  },

  onContextClick: function(view, index, node, event) {
    if (!this.getSelectionModel().isSelected(index)) {
      this.getSelectionModel().selectRow(index);
    } else {
      this.getSelectionModel().setCursor(index);
    }

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

  getAction: function(id) {
    var action = Paperpile.app.Actions.get(id);
    if (!action) {
      action = this.extraActions[id];
    }
    if (!action) {
      Paperpile.log("Grid couldn't find any action for " + id);
    }
    return action;
  },

  // Private. Don't override.
  updateButtons: function() {
    return;
    var docked = this.getDockedItems();

    Ext.Array.forEach(docked, function(item, index, length) {
      item.enable();
    },
    this);

    this.getContextMenu().items.each(function(item, index, length) {
      item.enable();
    });
    for (var key in this.extraActions) {
      var action = this.extraActions[key];
      if (action['setDisabled']) {
        action.setDisabled(false);
      }
    }

    var selection = this.getSingleSelection();

    this.getAction('SELECT_ALL').setText('Select All');
    if (this.isAllSelected() || this.getTotalCount() == 0) {
      this.getAction('SELECT_ALL').disable();
    }

    if (!selection || selection.data.pdf == '') {
      this.getAction('VIEW_PDF').disable();
      this.getAction('OPEN_PDF_FOLDER').disable();
    }

    if (!selection) {
      this.getAction('AUTO_COMPLETE').disable();
      this.getAction('EDIT').disable();
      this.getAction('DELETE').disable();
      this.getAction('COPY_FORMATTED').disable();
    }

    //    var tbar = this.getTopToolbar();
    var context = this.getContextMenu();

    context.getComponent('EXPORT_SELECTION').setText("Export Selection...");

    var settings = Paperpile.Settings.get('bibtex');
    if (settings.bibtex_mode == 1) {
      this.getContextByItemId('COPY_BIBTEX_CITATION').show();
      this.getContextByItemId('COPY_BIBTEX_KEY').show();
    } else {
      this.getContextByItemId('COPY_BIBTEX_CITATION').hide();
      this.getContextByItemId('COPY_BIBTEX_KEY').hide();
    }

    if (this.getStore().getCount() == 0) {
      this.getAction('EXPORT_MENU').disable();
      this.getAction('EXPORT_SELECTION').disable();
      this.getAction('EXPORT_VIEW').disable();
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

  getSelectedCollections: function(collectionType) {
    var selection = this.getSelection();
    var newSel = [];
    Ext.each(selection, function(pub) {
      newSel.push(pub.data);
    });
    selection = newSel;

    var list = new Ext.util.MixedCollection();
    var store = Ext.getStore(collectionType);
    store.each(function(record) {
      delete record.data.multiCount;
      delete record.data.multiName;
    });

    if (this.isAllSelected()) {
      // If all are selected, we collect all of this collectionType
      store.each(function(record) {
        record.data.multiCount = record.data.count;
        list.add(record.get('guid'), record.data);
      });
    } else {
      Ext.each(selection, function(data) {
        var guids = data[collectionType].split(',');
        for (var i = 0; i < guids.length; i++) {
          var guid = guids[i];
          if (guid == '') {
            continue;
          }
          if (!list.containsKey(guid)) {
            var record = store.getById(guid);
            if (record) {
              record.data.multiCount = 1;
              list.add(guid, record.data);
            }
          } else {
            list.get(guid).multiCount++;
          }
        }
      });
    }

    list.each(function(item) {
      if (item.multiCount > 1) {
        item.multiName = item.name + " (" + item.multiCount + ")";
      } else {
        item.multiName = item.name;
      }
    });

    // Sort descending by count.
    list.sort([new Ext.util.Sorter({
      property: 'multiCount',
      direction: 'DESC'
    }),
    new Ext.util.Sorter({
      property: 'count',
      direction: 'DESC'
    })]);
    return list;
  },

  getSelectionForAjax: function() {
    if (this.isAllSelected()) {
      return 'ALL';
    } else {
      return this.getSelectedIds();
    }
  },

  getSelectedIds: function() {
    var ids = [];
    var records = this.getSelectionModel().getSelection();
    Ext.each(records, function(item) {
      ids.push(item.getId());
    });
    return ids;
  },

  getSelection: function() {
    if (this.isAllSelected()) {
      return 'ALL';
    } else {
      return this.getSelectionModel().getSelection();
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

  handleExportView: function() {
    Paperpile.main.handleExport(this.id, 'all');
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

  handleEdit: function(isNew, autoComplete) {
    var selection = this.getSingleSelection();

    if (selection) {
      var rowid = selection.get('_rowid');
      var guid = selection.data.guid;
    }

    win = new Paperpile.pub.EditWindow({});
    win.on('close', function() {
      Paperpile.main.focusCurrentPanel();
    });
    win.show(this);
  },

  locateInLibrary: function() {
    var record = this.getSingleSelection();
    Paperpile.main.showReferenceInLibrary(record);
  },

  // Update specific fields of specific entries to avoid complete
  // reload of everything.
  updateFromServer: function(data) {

    if (data.pub_delta && data.pub_delta_ignore != this.id) {
      // Reload the whole store if we get a pub_delta flag.
      Paperpile.log("  Pub delta - reloading grid store for " + this.id);
      this.getStore().load();
      return;
    } else {
      // Go through each record and apply updates if needed.
      var pubs = data.pubs;
      if (!pubs) {
        pubs = [];
      }

      var store = this.getStore();
      for (var guid in pubs) {
        Paperpile.log(guid);
        var pubDataFromServer = pubs[guid];
        var pub = store.getById(guid);
        if (!pub) {
          Paperpile.log("  pub not found for guid " + guid);
          continue;
        }
        //        pub.editing = true;
        pub.dirty = false;
        pub.set(pubDataFromServer);
        if (pub.dirty) {
          store.fireEvent('update', store, pub, Ext.data.Model.EDIT);
        }
      }
    }
  },

  selectAll: function() {
    this.getSelectionModel().selectAll();
  },

  isAllSelected: function() {
    return this.getSelectionModel().isAllSelected();
  },

  setSearchQuery: function() {
    // To be implemented by subclasses.
  },

  getPub: function(guid) {
    return this.getStore().getById(guid);
  },

  getSingleSelection: function() {
    var selections = this.getSelectionModel().getSelections();
    if (selections.length > 0) {
      return selections[0];
    } else {
      Paperpile.log("Nothing selected -- make sure the call to getSingleSelection handles undefined!");
      return undefined;
    }
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