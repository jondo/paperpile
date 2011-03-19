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
      loadingText: null,
      // Remove the loading text to kill the loading mask.
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

    this.pager = new Paperpile.grid.Pager({
      dock: 'bottom',
      store: this.getStore(),
      displayInfo: true
    });
    this.pager.on('pagebutton', function(pager) {
      this.onPageButtonClick();
    },
    this);

    this.toolbar = this.createToolbar();
    var dockItems = [this.pager, this.toolbar];

    Ext.apply(this, {
      itemId: 'grid',
      autoScroll: true,
      items: [this.view],
      dockedItems: dockItems
    });

    this.callParent(arguments);

    //    this.createContextMenu();
    this.mon(this.getStore(), 'load', this.onStoreLoad, this);
    this.mon(this.getStore(), 'loadexception', function(exception, options, response, error) {
      Paperpile.main.onError(response, options);
    },
    this);

    this.on('viewready', function() {
      this.getPluginPanel().updateView();
    },
    this);

  },

  initialLoad: function() {
    if (this.isLoaded()) {
      Paperpile.log("Calling initialLoad on an already loaded store -- for shame...");
    }
    var store = this.getStore();
    var limit = Paperpile.main.globalSettings['pager_limit'] || 25;
    store.pageSize = limit;
    store.load({
      start: 0,
      limit: limit
    });
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

    a = Paperpile.app.Actions;

    this.keys.bindAction('ctrl-t', this.actions['TEST']);

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

  handleFocusSearch: function() {
    // To be implemented by subclasses or plugins.
  },

  clearSearch: function() {
    if (this.filterField) {
      this.filterField.onTrigger1Click();
      this.filterField.getEl().focus();
    } else if (this.searchField) {
      this.searchField.selectText();
      this.searchField.getEl().focus();
      this.getEmptyBeforeSearchTemplate().overwrite(this.getView().mainBody);
    }
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    switch (el.getAttribute('action')) {
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

  getStore: function() {
    if (this._store) {
      return this._store;
    }
    this._store = new Ext.data.Store({
      autoLoad: false,
      model: 'Publication',
      proxy: new Ext.data.AjaxProxy({
        model: 'Publication',
        url: Paperpile.Url('/ajax/plugins/resultsgrid'),
        startParam: 'start',
        pageParam: 'page',
        limitParam: 'limit',
        sortParam: 'sort',
        // We don't set timeout here but handle timeout separately in
        // specific plugins.
        timeout: 1000000,
        method: 'GET',
        extraParams: {
          grid_id: this.id,
          plugin_file: this.plugin_file,
          plugin_name: this.plugin_name,
          plugin_query: this.plugin_query,
          plugin_mode: this.plugin_mode,
          plugin_order: Paperpile.main.globalSettings['sort_field']
        },
      }),
    });

    // Add some callbacks to the store so we can maintain the selection between reloads.
    this.mon(this.getStore(), 'load', function(store, options) {
      this.getStore().isLoaded = true;
      for (var i = 0; i < this.doAfterNextReload.length; i++) {
        var fn = this.doAfterNextReload[i];
        Ext.defer(fn, 10, this);
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
      this.createSeparator('TB_VIEW_SEP'),
      'EDIT',
      'AUTO_COMPLETE',
      'SELECT_ALL',
      'DELETE',
      this.createSeparator('TB_DEL_SEP'),
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
      this.createContextSeparator('CONTEXT_VIEW_SEP'),
      'EDIT',
      'AUTO_COMPLETE',
      'SELECT_ALL',
      'DELETE',
      this.createContextSeparator('CONTEXT_DEL_SEP'),
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
    return this.toolbar;
  },

  createToolbar: function() {
    var toolbar = new Ext.toolbar.Toolbar({
      enableOverflow: false
    });

    this.toolbarExtras = {
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
    };

    this.initToolbarMenuItemIds();
    var itemIds = this.toolbarMenuItemIds;
    for (var i = 0; i < itemIds.length; i++) {
      var id = itemIds.getAt(i);
      Paperpile.log(id);
      var action = Paperpile.app.Actions.get(id);
      var cmp;
      if (action && action instanceof Ext.Action) {
        cmp = toolbar.add(action);
      } else if (this.toolbarExtras[id]) {
        cmp = toolbar.add(this.toolbarExtras[id]);
      }
      var index = toolbar.items.indexOf(cmp);
      toolbar.move(index, toolbar.items.getCount());
    }
    return toolbar;
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
      var action = Paperpile.app.Actions.get(id);
      if (!action) {
        continue;
      }
      context.insert(i, action);
      if (action && action instanceof Ext.Action) {
        action.addComponent(context.items.getAt(i));
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
  deleteEntry: function(mode, deleteAll) {},

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

  // Update specific fields of specific entries to avoid complete
  // reload of everything.
  updateFromServer: function(data) {

    if (data.pub_delta) {
      // Reload the whole store if we get a pub_delta flag.
      if (data.pub_delta_ignore != this.id) {
        Paperpile.log("Pub delta -- reloading grid store!");
        this.getStore().load();
        return;
      }
    } else {
      // Go through each record and apply updates if needed.
      var pubs = data.pubs;
      if (!pubs) {
        pubs = [];
      }

      var store = this.getStore();
      var pub = this.getSingleSelection();

      for (var guid in pubs) {
        var pubDataFromServer = pubs[guid];
        var pub = store.getById(guid);
        if (!pub) {
          Paperpile.log("  pub not found for guid " + guid);
          continue;
        }
        pub.editing = true;
        pub.dirty = false;
        pub.set(field, pubDataFromServer);
        if (pub.dirty) {
          Paperpile.log("Publication was modified from server!");
          Paperpile.log(pub.modified);
          store.fireEvent('update', store, record, Ext.data.Model.EDIT);
        }
      }
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