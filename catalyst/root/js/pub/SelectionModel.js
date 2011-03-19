Ext.define('Paperpile.grid.SelectionModel', {
  extend: 'Ext.selection.Model',
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

  constructor: function(config) {
    this.selections = new Ext.util.MixedCollection();
    this.selections.getKey = function(o) {
      return o.getId();
    };

    this.last = false;
    this.lastActive = false;

    this.addEvents(
      'afterselectionchange',
      'allselected',
      'pageselected');
    this.callParent(arguments);
  },

  bindComponent: function(cmp) {
    cmp.on({
      scope: this,
		refresh: this.refresh,
      rowupdated: this.onRowUpdated,
      rowremoved: this.onRemove
    });

    this.view = cmp;
    this.bind(cmp.getStore());

    cmp.addListener('mousedown', this.handleMouseEvent, this, {
      element: 'el'
    });
  },

  onRemove: function(v, index, r) {
    if (this.selections.remove(r) !== false) {
      this.fireEvent('selectionchange', this, this.getSelection());
    }
  },

  onRowUpdated: function(v, index, r) {
    if (this.isSelected(r)) {
      v.onItemSelect(r);
    }
  },

  /**
     * Select records.
     * @param {Array} records The records to select
     * @param {Boolean} keepExisting (optional) <tt>true</tt> to keep existing selections
     */
  selectRecords: function(records, keepExisting) {
    if (!keepExisting) {
      this.clearSelections();
    }
    var ds = this.store;
    for (var i = 0, len = records.length; i < len; i++) {
      this.selectRow(ds.indexOf(records[i]), true);
    }
  },

  /**
     * Gets the number of selected rows.
     * @return {Number}
     */
  getCount: function() {
    return this.selections.getCount();
  },

  selectNext: function(keepExisting) {
    if (this.hasNext()) {
      this.selectRow(this.getCursor() + 1, keepExisting);
      this.focusToCursor();
      return true;
    }
    return false;
  },

  focusToCursor: function() {
    if (this.getCursor() !== null) {
      this.view.focusRow(this.getCursor());
      Ext.defer(this.view.focus, 10);
    }
  },

  /**
     * Selects the row that precedes the last selected row.
     * @param {Boolean} keepExisting (optional) <tt>true</tt> to keep existing selections
     * @return {Boolean} <tt>true</tt> if there is a previous row, else <tt>false</tt>
     */
  selectPrevious: function(keepExisting) {
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
    if (this.selections.getCount() > 0) {
      return this.selections.getRange();
    } else {
      return[];
    }
  },

  getSelected: function() {
    var cur = this.getCursor();
    if (cur !== null) {
      var record = this.selections.getAt(cur);
      if (record !== undefined) {
        return record;
      }
    }

    // If there is no cursor, just give back the first selected item.
    return this.selections.getAt(0);
  },

  getFirstSelected: function() {
    return this.selections.getAt(0);
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

  clearSelections: function(fast) {
    if (this.isLocked()) {
      return;
    }
    if (fast !== true) {
      var ds = this.store;
      var s = this.selections;
      s.each(function(r) {
        this.deselectRow(ds.indexOfId(r.id));
      },
      this);
      s.clear();
    } else {
      this.selections.clear();
    }
    this.setCursor(null);
  },

  hasSelection: function() {
    return this.selections.getCount() > 0;
  },

  isSelected: function(index) {
    var r = Ext.isNumber(index) ? this.store.getAt(index) : index;
    return (r && this.selections.indexOf(r) > -1 ? true : false);
  },

  selectRows: function(rows, keepExisting) {
    if (!keepExisting) {
      this.clearSelections();
    }
    for (var i = 0, len = rows.length; i < len; i++) {
      this.selectRow(rows[i], true);
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
      this.selections.add(r);
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
      this.selections.remove(r);
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
        this.selections.add(r);
        this.view.onItemSelect(r);
      }
    }

    // Re-sort selections so they match up with the (possibly) new ordering.
    this.selections.sortBy(function(a, b) {
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
    if (s.length != this.selections.getCount()) {
      this.fireEvent('selectionchange', this, this.getSelections());
      this.fireEvent('afterselectionchange', this, this.getSelections());
    }
  },

  isAllSelected: function() {
    if (this.fakeAllSelected) {
      return true;
    }
    return false;
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
      return this.selections.getCount();
    }
  },

  selectRows: function(rows, keepExisting) {
    if (!keepExisting) {
      this.clearSelections();
    }
    for (var i = 0, len = rows.length; i < len; i++) {
      this.selectRow(rows[i], true);
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
      var s = this.selections;
      s.each(function(r) {
        this.deselectRow(ds.indexOf(r));
      },
      this);
      s.clear();
    } else {
      this.selections.clear();
    }
    this.last = false;
    // DO NOT fire an 'afterselectionchange' event here!
  }

});