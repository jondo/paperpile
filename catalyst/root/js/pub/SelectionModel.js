Ext.define('Paperpile.grid.SelectionModel', {
  extend: 'Ext.util.Observable',
  singleSelect: false,
  selectPageBeforeAll: false,
  maintainSelectionBetweenReloads: true,

  // The cursor and the anchor represent the controller of this 
  // row selection. Only change these values in response to a
  // user interaction!!
  anchor: null,
  getAnchor: function() {
    return this.anchor;
  },
  setAnchor: function(anchor) {
    this.anchor = anchor;
    //      Paperpile.log("Anchor to "+this.anchor);
  },
  cursor: null,
  getCursor: function() {
    return this.cursor;
  },
  setCursor: function(cursor) {
    this.cursor = cursor;
    //      Paperpile.log("Cursor to "+this.cursor);
  },

  constructor: function(cfg) {
    var me = this;

    cfg = cfg || {};
    Ext.apply(me, cfg);

    this.selected = new Ext.util.MixedCollection();
    this.selected.getKey = function(o) {
      return o.getId();
    };

    this.last = false;
    this.lastActive = false;

    this.addEvents(
      'afterselectionchange',
      'allselected');

    me.callParent(arguments);
  },

  bind: function(store, initial) {
    var me = this;

    if (!initial && me.store) {
      if (store !== me.store && me.store.autoDestroy) {
        me.store.destroy();
      } else {
        me.store.un("add", me.onStoreAdd, me);
        me.store.un("clear", me.onStoreClear, me);
        me.store.un("remove", me.onStoreRemove, me);
        me.store.un("update", me.onStoreUpdate, me);
      }
    }
    if (store) {
      store = Ext.data.StoreMgr.lookup(store);
      store.on({
        add: me.onStoreAdd,
        clear: me.onStoreClear,
        remove: me.onStoreRemove,
        update: me.onStoreUpdate,
        scope: me
      });
    }
    me.store = store;
    if (store && !initial) {
      me.refresh();
    }
  },

  bindComponent: function(view) {
    var me = this,
    eventListeners = {
      refresh: me.refresh,
      render: me.onViewRender,
      scope: me,
      el: {
        scope: me
      }
    };

    if (!view['focusRow']) {
      Paperpile.log("Binding PP selection model to a Component without 'focusRow'");
    }
    if (!view['focus']) {
      Paperpile.log("Binding PP selection model to a Component without 'focus'");
    }

    me.view = view;
    me.bind(view.getStore());
    eventListeners.el['mousedown'] = me.handleMouseEvent;
    view.on(eventListeners);
  },

  onViewRender: function() {
    var me = this;
  },

  // when a record is added to a store
  onStoreAdd: function() {

  },

  // when a store is cleared remove all selections
  // (if there were any)
  onStoreClear: function() {
    var me = this,
    selected = this.selected;

    if (selected.getCount > 0) {
      this.clearSelections();
      this.fireEvent('afterselectionchange', this, this.getSelections());
    }
  },

  // prune records from the SelectionModel if
  // they were selected at the time they were
  // removed.
  onStoreRemove: function(store, record) {
    var me = this,
    selected = me.selected;

    if (me.locked || !me.pruneRemoved) {
      return;
    }

    if (selected.remove(record)) {
      if (me.lastSelected == record) {
        me.lastSelected = null;
      }
      if (me.getLastFocused() == record) {
        me.setLastFocused(null);
      }
      me.maybeFireSelectionChange(true);
    }
  },

  // if records are updated
  onStoreUpdate: function() {

  },

  onRemove: function(v, index, r) {
    if (this.selected.remove(r) !== false) {
      this.fireEvent('selectionchange', this, this.getSelection());
    }
  },

  onRowUpdated: function(v, index, r) {
    if (this.isSelected(r)) {
      v.onItemSelect(r);
    }
  },

  selectRecords: function(records, keepExisting) {
    if (this.isLocked()) {
      return;
    }
    if (!keepExisting) {
      this.clearSelections();
    }
    var ds = this.store;
    for (var i = 0, len = records.length; i < len; i++) {
      this.selectRow(ds.indexOf(records[i]), true);
    }
  },

  selectNext: function(keepExisting) {
    if (this.isLocked()) {
      return;
    }

    if (this.hasNext()) {
      this.selectRow(this.getCursor() + 1, keepExisting);
      this.focusToCursor();
      return true;
    }
    return false;
  },

  focusToCursor: function() {
    if (this.getCursor() !== null) {
      if (this.view['focusRow']) {
        this.view.focusRow(this.getCursor());
        Ext.defer(this.view.focus, 10);
      }
    }
  },

  /**
     * Selects the row that precedes the last selected row.
     * @param {Boolean} keepExisting (optional) <tt>true</tt> to keep existing selections
     * @return {Boolean} <tt>true</tt> if there is a previous row, else <tt>false</tt>
     */
  selectPrevious: function(keepExisting) {
    if (this.isLocked()) {
      return;
    }

    if (this.hasPrevious()) {
      this.selectRow(this.getCursor() - 1, keepExisting);
      this.focusToCursor();
      return true;
    }
    return false;
  },

  hasNext: function() {
    return this.getCursor() !== null && (this.cursor() + 1) < this.store.getCount();
  },

  hasPrevious: function() {
    return !! this.getCursor();
  },

  getSelection: function() {
    return this.getSelections();
  },

  getSelections: function() {
    if (this.selected.getCount() > 0) {
      return this.selected.getRange();
    } else {
      return[];
    }
  },

  getSingleSelection: function() {
    var cur = this.getCursor();
    if (cur !== null) {
      var record = this.selected.getAt(cur);
      if (record !== undefined) {
        return record;
      }
    }

    // If there is no cursor, just give back the first selected item.
    return this.selected.getAt(0);
  },

  getFirstSelected: function() {
    return this.selected.getAt(0);
  },

  getLowestSelected: function() {
    var s = this.getSelections();
    var lowestRecord = undefined;
    var lowestIndex = undefined;
    for (var i = 0, len = s.length; i < len; i++) {
      var record = s[i];
      var myIndex = this.store.indexOfId(record.id);
      if (lowestRecord !== undefined) {
        if (myIndex < lowestIndex) {
          lowestRecord = record;
          lowestIndex = myIndex;
        }
      } else {
        lowestRecord = record;
        lowestIndex = myIndex;
      }
    }
    return lowestRecord;
  },
  getHighestSelected: function() {
    var s = this.getSelections();
    var highestRecord = undefined;
    var highestIndex = undefined;
    for (var i = 0, len = s.length; i < len; i++) {
      var record = s[i];
      var myIndex = this.store.indexOfId(record.id);
      if (highestRecord !== undefined) {
        if (myIndex > highestIndex) {
          highestRecord = record;
          highestIndex = myIndex;
        }
      } else {
        highestRecord = record;
        highestIndex = myIndex;
      }
    }
    return highestRecord;
  },

  isLocked: function() {
    return this.locked;
  },

  clearSelections: function(fast) {
    if (this.isLocked()) {
      return;
    }
    if (fast !== true) {
      var ds = this.store;
      var s = this.selected;
      s.each(function(r) {
        this.deselectRow(ds.indexOfId(r.id));
      },
      this);
      s.clear();
    } else {
      this.selected.clear();
    }
    this.setCursor(null);
  },

  hasSelection: function() {
    return this.selected.getCount() > 0;
  },

  isSelected: function(index) {
    var r = Ext.isNumber(index) ? this.store.getAt(index) : index;
    return (r && this.selected.indexOf(r) > -1 ? true : false);
  },

  select: function(records, keepExisting, suppressEvents) {
    var me = this;

    if (me.isLocked()) {
      return;
    }
    if (typeof records === "number") {
      records = [me.store.getAt(records)];
    }

    var indices = [];
    for (var i = 0; i < records.length; i++) {
      var record = records[i];
      var index = me.store.indexOf(record);
      indices.push(index);
    }
    me.selectRows(indices, keepExisting);
  },

  selectRows: function(rows, keepExisting, preventViewNotify) {
    if (this.isLocked()) {
      return;
    }
    if (!keepExisting) {
      this.clearSelections();
    }
    for (var i = 0, len = rows.length; i < len; i++) {
      this.selectRow(rows[i], true, preventViewNotify);
    }
  },

  selectRange: function(startRow, endRow, keepExisting) {
    var i;
    if (this.isLocked()) {
      return;
    }
    if (!keepExisting) {
      this.clearSelections();
    }
    if (startRow <= endRow) {
      for (i = startRow; i <= endRow; i++) {
        this.selectRow(i, true);
      }
    } else {
      for (i = startRow; i >= endRow; i--) {
        this.selectRow(i, true);
      }
    }
  },

  deselectRange: function(startRow, endRow, preventViewNotify) {
    if (this.isLocked()) {
      return;
    }
    for (var i = startRow; i <= endRow; i++) {
      this.deselectRow(i, preventViewNotify);
    }
  },

  selectRowAndSetCursor: function(index, keepExisting) {
    this.selectRow(index, keepExisting);
    if (this.isSelected(index)) {
      this.setCursor(index);
      this.setAnchor(index);
      this.focusToCursor();
    }
    //    Paperpile.log("Row selected and cursor set! "+index);
  },

  selectRow: function(index, keepExisting, preventViewNotify) {
    if (this.isLocked() || (index < 0 || index >= this.store.getCount()) || (keepExisting && this.isSelected(index))) {
      return;
    }

    var r = this.store.getAt(index);
    if (r) {
      if (!keepExisting) {
        this.clearSelections();
      }
      this.selected.add(r);
      this.last = this.lastActive = index;
      if (!preventViewNotify) {
        this.view.onItemSelect(r);
      }
      this.fireEvent('select', this, index, r);
      this.fireEvent('selectionchange', this, this.getSelections());
    }
  },

  deselectRow: function(index, preventViewNotify) {
    if (this.isLocked()) {
      return;
    }
    var r = this.store.getAt(index);
    if (r) {
      this.selected.remove(r);
      if (!preventViewNotify) {
        this.view.onItemDeselect(index);
      }
      this.fireEvent('rowdeselect', this, index, r);
      this.fireEvent('selectionchange', this, this.getSelections());
    }
    this.fakeAllSelected = false;
  },

  // private
  acceptsNav: function(row, col, cm) {
    return !cm.isHidden(col) && cm.isCellEditable(col, row);
  },

  destroy: function() {

    if (this.view) {
      if (this.view.getEl()) {
        this.view.getEl().un('mousedown', this.handleMouseEvent, this);
      }
      this.view.un('refresh', this.refresh, this);
      this.view.un('render', this.onViewRender, this);
      this.view.un('rowupdated', this.onRowUpdated, this);
      this.view.un('rowremoved', this.onRemove, this);
    }
    this.callParent(arguments);
  },

  keyNavMove: function(distance, e) {
    if (!e.shiftKey || this.singleSelect) {
      this.selectDistance(distance);
    } else if (this.getAnchor() !== null && this.getCursor() !== null) {
      var anchor = this.getAnchor();
      var cursor = this.constrainToGrid(this.getCursor() + distance);
      this.selectRange(this.getAnchor(), cursor);
      this.setCursor(cursor);
      this.focusToCursor();
    } else {
      this.selectFirstRow();
    }
    this.fireEvent('afterselectionchange', this, this.getSelections());
  },
  constrainToGrid: function(value) {
    if (value < 0) {
      value = 0;
    }
    if (value >= this.store.getCount()) {
      value = this.store.getCount() - 1;
    }
    return value;
  },
  selectDistance: function(dist) {
    var cursor = this.constrainToGrid(this.getCursor() + dist);
    this.selectRow(cursor, false);
    this.setCursor(cursor);
    this.setAnchor(cursor);
    this.focusToCursor();
    return true;
  },
  hasDistance: function(dist) {
    return (this.getCursor() !== null && (this.getCursor() + dist) < this.store.getCount() && (this.getCursor() + dist) >= 0);
  },

  isIgnorableClickEvent: function(a, b) {
    //    Paperpile.log(a.type + " " + b.type);
    if (a !== undefined && b !== undefined && a.type == 'mousedown' && b.type == 'click' &&
      a.target === b.target &&
      a.ctrlKey === b.ctrlKey &&
      a.shiftKey === b.shiftKey &&
      a.source === b.source) {
      //	Paperpile.log("  Ignorable!");
      return true;
    } else {
      return false;
    }
  },

  looksLikeDuplicateEvents: function(a, b) {
    if (a !== undefined && b !== undefined && a.type === b.type &&
      a.target === b.target &&
      a.ctrlKey === b.ctrlKey &&
      a.shiftKey === b.shiftKey &&
      a.source === b.source && a.browserEvent === b.browserEvent) {
      //	Paperpile.log("  Duplicate!");
      return true;
    } else {
      return false;
    }
  },
  cacheEvent: {},

  handleMouseEvent: function(e) {
    if (e.button !== 0 || this.isLocked()) {
      return;
    }

    Ext.defer(this.view.focus, 10);

    var node = this.view.findTargetByEvent(e);
    if (!node) {
      this.clearSelectionsAndUpdate(false);
      return;
    }
    var record = this.view.getRecord(node);
    var rowIndex = this.store.indexOf(record);

    var isSelected = this.isSelected(rowIndex);
    var type = e.type;
    var ctrl = e.ctrlKey;
    var shift = e.shiftKey;

    this.setCursor(rowIndex);
    if (!shift) {
      this.setAnchor(rowIndex);
    }

    if (shift) {
      if (type === 'mousedown' && this.anchor !== null) {
        this.selectRange(this.getAnchor(), rowIndex, ctrl);
        this.focusToCursor();
      }
    } else if (ctrl) {
      if (type === 'mousedown') {
        if (isSelected) {
          this.deselectRow(rowIndex);
        } else {
          this.selectRow(rowIndex, true);
          this.focusToCursor();
        }
      }
    } else {
      if (type === 'mousedown' && !isSelected) {
        this.selectRow(rowIndex, false);
        this.focusToCursor();
      } else {
        if (isSelected) {
          this.selectRow(rowIndex, false);
          this.focusToCursor();
        }
      }
    }

    this.fireEvent('afterselectionchange', this, this.getSelections());
  },

  selectFirstRow: function(keepExisting) {
    if (this.store.getCount() > 0) {
      this.selectRow(0, keepExisting);
      this.focusToCursor();
    }
  },
  selectLastRow: function(keepExisting) {
    if (this.store.getCount() > 0) {
      this.selectRow(this.store.getCount() - 1, keepExisting);
      this.focusToCursor();
    }
  },

  getSorter: function() {
    if (!this.sorter) {
      var store = this.store;
      this.sorter = new Ext.util.Sorter({
        direction: 'ASC',
        sorterFn: function(a, b) {
          var ind_a = store.indexOfId(a.id);
          var ind_b = store.indexOfId(b.id);
          // Go to the end of list if it's gone from the grid...
          if (ind_a == -1) {
            ind_a = 999;
          }
          if (ind_b == -1) {
            ind_b = 999;
          }
          return ind_a - ind_b;
        }
      });
    }
    return this.sorter;
  },

  refresh: function() {
    // For comparison, see selection/Model.js#refresh
    this.suspendEvents();
    var ds = this.store;
    var index;
    var s = this.getSelections();
    var storeCount = ds.getCount();
    if (storeCount == 0 || !this.maintainSelectionBetweenReloads) {
      this.clearSelections(true);
    }

    for (var i = 0, len = s.length; i < len; i++) {
      var r = s[i];
      if ((index = ds.indexOf(r)) != -1) {
        this.selected.add(r);
        this.view.onItemSelect(r);
      }
    }

    // Re-sort selections so they match up with the (possibly) new ordering.
    this.selected.sortBy(function(a, b) {
      var ind_a = ds.indexOfId(a.id);
      var ind_b = ds.indexOfId(b.id);
      // Go to the end of list if it's gone from the grid...
      if (ind_a == -1) {
        ind_a = 999;
      }
      if (ind_b == -1) {
        ind_b = 999;
      }
      return ind_a - ind_b;
    });

    this.resumeEvents();
    if (s.length != this.selected.getCount()) {
      this.fireEvent('selectionchange', this, this.getSelections());
      this.fireEvent('afterselectionchange', this, this.getSelections());
    }
  },

  isAllSelected: function() {
    if (this.fakeAllSelected) {
      return true;
    } else {
      return false;
    }
  },

  isPageSelected: function() {
    return (this.getCount() == this.store.getCount() && this.getCount() < this.store.getTotalCount());
  },

  selectPage: function() {
    this.clearSelections(true);
    this.selectRange(0, this.store.getCount() - 1);
    this.fakeAllSelected = false;
    this.fireEvent('afterselectionchange', this, this.getSelections());
    this.fireEvent('pageselected', this, this.getSelections());
  },

  selectAll: function(forceAll) {
    if (this.isLocked()) {
      return;
    }

    // If we're using the 'pageSelection' param, first select
    // this page's worth of counts. Then, if called when we're
    // already selecting the full pag
    if (this.selectPageBeforeAll) {
      if (forceAll === true || this.fakeAllSelected || this.isPageSelected()) {
        // The whole page is already selected,so now
        // od the fake select all flag.
        this.selectRange(0, this.store.getCount() - 1);
        this.fakeAllSelected = true;
        this.fireEvent('afterselectionchange', this, this.getSelections());
        this.fireEvent('allselected', this, this.getSelections());
      } else {
        // Do the standard thing to select all on page.
        this.clearSelections(true);
        this.selectRange(0, this.store.getCount() - 1);
        this.fakeAllSelected = false;
        this.fireEvent('afterselectionchange', this, this.getSelections());
        this.fireEvent('pageselected', this, this.getSelections());
      }
    } else {
      // If 'selectPageBeforeAll' isn't set to true, immediately select all.
      this.clearSelections(true);
      this.selectRange(0, this.store.getCount() - 1);
      this.fakeAllSelected = true;
      this.fireEvent('afterselectionchange', this, this.getSelections());
      this.fireEvent('allselected', this, this.getSelections());
    }
  },

  getCount: function() {
    if (this.fakeAllSelected) {
      return this.store.getTotalCount();
    } else {
      return this.selected.getCount();
    }
  },

  clearSelectionsAndUpdate: function(fast) {
    this.clearSelections(fast);
    this.fireEvent('afterselectionchange', this, this.getSelections());
  },

  clearSelections: function(fast) {
    if (this.isLocked()) {
      return;
    }
    if (fast !== true) {
      var ds = this.store;
      var s = this.selected;
      s.each(function(r) {
        this.deselectRow(ds.indexOf(r));
      },
      this);
      s.clear();
    } else {
      this.selected.clear();
    }
    this.last = false;
    // DO NOT fire an 'afterselectionchange' event here!
  }

});