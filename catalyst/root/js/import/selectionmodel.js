Ext.ux.BetterRowSelectionModel = Ext.extend(Ext.grid.AbstractSelectionModel, {
  singleSelect: false,
  selectPageBeforeAll: true,
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
    Ext.apply(this, config);
    this.selections = new Ext.util.MixedCollection(false, function(o) {
      return o.id;
    });

    this.last = false;
    this.lastActive = false;

    this.addEvents(
    /**
	         * @event selectionchange
	         * Fires when the selection changes
	         * @param {SelectionModel} this
	         */
      'selectionchange',
      /**
	         * @event beforerowselect
	         * Fires before a row is selected, return false to cancel the selection.
	         * @param {SelectionModel} this
	         * @param {Number} rowIndex The index to be selected
	         * @param {Boolean} keepExisting False if other selections will be cleared
	         * @param {Record} record The record to be selected
	         */
      'beforerowselect',
      /**
	         * @event rowselect
	         * Fires when a row is selected.
	         * @param {SelectionModel} this
	         * @param {Number} rowIndex The selected index
	         * @param {Ext.data.Record} r The selected record
	         */
      'rowselect',
      /**
	         * @event rowdeselect
	         * Fires when a row is deselected.  To prevent deselection
	         * {@link Ext.grid.AbstractSelectionModel#lock lock the selections}. 
	         * @param {SelectionModel} this
	         * @param {Number} rowIndex
	         * @param {Record} record
	         */
      'rowdeselect',
      /**
	         * @event afterselectionchange
	         * Fires after the selection changes in response to a user input.
	         * @param {SelectionModel} this
	         */
      'afterselectionchange',
      'allselected',
      'pageselected');
    Ext.grid.RowSelectionModel.superclass.constructor.call(this);
  },

  initEvents: function() {
    // Collect mousedown and click events.
    this.grid.on('rowclick', this.handleMouseEvent, this);
    this.grid.on('rowmousedown', this.handleMouseEvent, this);

    this.rowNav = new Ext.KeyNav(this.grid.getGridEl(), {
      'up': function(e) {
        this.keyNavMove(-1, e);
      },
      'down': function(e) {
        this.keyNavMove(1, e);
      },
      'pageDown': function(e) {
        var pageDistance = this.grid.getPageSize();
        this.keyNavMove(pageDistance, e);
      },
      'pageUp': function(e) {
        var pageDistance = this.grid.getPageSize();
        this.keyNavMove(-pageDistance, e);
      },
      scope: this
    });
    this.grid.getView().on({
      scope: this,
      refresh: this.onRefresh,
      rowupdated: this.onRowUpdated,
      rowremoved: this.onRemove
    });
  },

  // private
  onRemove: function(v, index, r) {
    if (this.selections.remove(r) !== false) {
      this.fireEvent('selectionchange', this);
    }
  },

  // private
  onRowUpdated: function(v, index, r) {
    if (this.isSelected(r)) {
      v.onRowSelect(index);
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
    var ds = this.grid.store;
    for (var i = 0, len = records.length; i < len; i++) {
      this.selectRow(ds.indexOf(records[i]), true);
    }
  },

  /**
     * Gets the number of selected rows.
     * @return {Number}
     */
  getCount: function() {
    return this.selections.length;
  },

  /**
     * Selects the row immediately following the last selected row.
     * @param {Boolean} keepExisting (optional) <tt>true</tt> to keep existing selections
     * @return {Boolean} <tt>true</tt> if there is a next row, else <tt>false</tt>
     */
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
      this.grid.getView().focusRow(this.getCursor());
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

  /**
     * Returns true if there is a next record to select
     * @return {Boolean}
     */
  hasNext: function() {
    return this.getCursor() !== null && (this.cursor() + 1) < this.grid.store.getCount();
  },

  /**
     * Returns true if there is a previous record to select
     * @return {Boolean}
     */
  hasPrevious: function() {
    return !! this.getCursor();
  },

  /**
     * Returns the selected records
     * @return {Array} Array of selected records
     */
  getSelections: function() {
    return[].concat(this.selections.items);
  },

  /**
     * Returns the first selected record.
     * @return {Record}
     */
  getSelected: function() {
    var cur = this.getCursor();
    if (cur !== null) {
      var record = this.selections.itemAt(cur);
      if (record !== undefined) {
        return record;
      }
    }

    // If there is no cursor, just give back the first selected item.
    return this.selections.itemAt(0);
  },

  getFirstSelected: function() {
    return this.selections.itemAt(0);
  },

  getLowestSelected: function() {
    var s = this.getSelections();
    var lowestRecord = undefined;
    var lowestIndex = undefined;
    for (var i = 0, len = s.length; i < len; i++) {
      var record = s[i];
      var myIndex = this.grid.store.indexOfId(record.id);
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
      var myIndex = this.grid.store.indexOfId(record.id);
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
  /**
     * Calls the passed function with each selection. If the function returns
     * <tt>false</tt>, iteration is stopped and this function returns
     * <tt>false</tt>. Otherwise it returns <tt>true</tt>.
     * @param {Function} fn The function to call upon each iteration. It is passed the selected {@link Ext.data.Record Record}.
     * @param {Object} scope (optional) The scope (<code>this</code> reference) in which the function is executed. Defaults to this RowSelectionModel.
     * @return {Boolean} true if all selections were iterated
     */
  each: function(fn, scope) {
    var s = this.getSelections();
    for (var i = 0, len = s.length; i < len; i++) {
      if (fn.call(scope || this, s[i], i) === false) {
        return false;
      }
    }
    return true;
  },

  /**
     * Clears all selections if the selection model
     * {@link Ext.grid.AbstractSelectionModel#isLocked is not locked}.
     * @param {Boolean} fast (optional) <tt>true</tt> to bypass the
     * conditional checks and events described in {@link #deselectRow}.
     */
  clearSelections: function(fast) {
    if (this.isLocked()) {
      return;
    }
    if (fast !== true) {
      var ds = this.grid.store;
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

  /**
     * Returns <tt>true</tt> if there is a selection.
     * @return {Boolean}
     */
  hasSelection: function() {
    return this.selections.length > 0;
  },

  /**
     * Returns <tt>true</tt> if the specified row is selected.
     * @param {Number/Record} index The record or index of the record to check
     * @return {Boolean}
     */
  isSelected: function(index) {
    var r = Ext.isNumber(index) ? this.grid.store.getAt(index) : index;
    return (r && this.selections.key(r.id) ? true : false);
  },

  /**
     * Returns <tt>true</tt> if the specified record id is selected.
     * @param {String} id The id of record to check
     * @return {Boolean}
     */
  isIdSelected: function(id) {
    return (this.selections.key(id) ? true : false);
  },

  /**
     * Selects multiple rows.
     * @param {Array} rows Array of the indexes of the row to select
     * @param {Boolean} keepExisting (optional) <tt>true</tt> to keep
     * existing selections (defaults to <tt>false</tt>)
     */
  selectRows: function(rows, keepExisting) {
    if (!keepExisting) {
      this.clearSelections();
    }
    for (var i = 0, len = rows.length; i < len; i++) {
      this.selectRow(rows[i], true);
    }
  },

  /**
     * Selects a range of rows if the selection model
     * {@link Ext.grid.AbstractSelectionModel#isLocked is not locked}.
     * All rows in between startRow and endRow are also selected.
     * @param {Number} startRow The index of the first row in the range
     * @param {Number} endRow The index of the last row in the range
     * @param {Boolean} keepExisting (optional) True to retain existing selections
     */
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

  /**
     * Deselects a range of rows if the selection model
     * {@link Ext.grid.AbstractSelectionModel#isLocked is not locked}.  
     * All rows in between startRow and endRow are also deselected.
     * @param {Number} startRow The index of the first row in the range
     * @param {Number} endRow The index of the last row in the range
     */
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

  /**
     * Selects a row.  Before selecting a row, checks if the selection model
     * {@link Ext.grid.AbstractSelectionModel#isLocked is locked} and fires the
     * {@link #beforerowselect} event.  If these checks are satisfied the row
     * will be selected and followed up by  firing the {@link #rowselect} and
     * {@link #selectionchange} events.
     * @param {Number} row The index of the row to select
     * @param {Boolean} keepExisting (optional) <tt>true</tt> to keep existing selections
     * @param {Boolean} preventViewNotify (optional) Specify <tt>true</tt> to
     * prevent notifying the view (disables updating the selected appearance)
     */
  selectRow: function(index, keepExisting, preventViewNotify) {
    if (this.isLocked() || (index < 0 || index >= this.grid.store.getCount()) || (keepExisting && this.isSelected(index))) {
      return;
    }
    var r = this.grid.store.getAt(index);
    if (r && this.fireEvent('beforerowselect', this, index, keepExisting, r) !== false) {
      if (!keepExisting || this.singleSelect) {
        this.clearSelections();
      }
      this.selections.add(r);
      this.last = this.lastActive = index;
      if (!preventViewNotify) {
        this.grid.getView().onRowSelect(index);
      }
      this.fireEvent('rowselect', this, index, r);
      this.fireEvent('selectionchange', this);
    }
  },

  /**
     * Deselects a row.  Before deselecting a row, checks if the selection model
     * {@link Ext.grid.AbstractSelectionModel#isLocked is locked}.
     * If this check is satisfied the row will be deselected and followed up by
     * firing the {@link #rowdeselect} and {@link #selectionchange} events.
     * @param {Number} row The index of the row to deselect
     * @param {Boolean} preventViewNotify (optional) Specify <tt>true</tt> to
     * prevent notifying the view (disables updating the selected appearance)
     */
  deselectRow: function(index, preventViewNotify) {
    if (this.isLocked()) {
      return;
    }
    var r = this.grid.store.getAt(index);
    if (r) {
      this.selections.remove(r);
      if (!preventViewNotify) {
        this.grid.getView().onRowDeselect(index);
      }
      this.fireEvent('rowdeselect', this, index, r);
      this.fireEvent('selectionchange', this);
    }
    this.fakeAllSelected = false;
  },

  // private
  acceptsNav: function(row, col, cm) {
    return !cm.isHidden(col) && cm.isCellEditable(col, row);
  },

  // private
  onEditorKey: function(field, e) {
    var k = e.getKey(),
    newCell,
    g = this.grid,
    last = g.lastEdit,
    ed = g.activeEditor,
    ae,
    r,
    c;
    var shift = e.shiftKey;
    if (k == e.TAB) {
      e.stopEvent();
      ed.completeEdit();
      if (shift) {
        newCell = g.walkCells(ed.row, ed.col - 1, -1, this.acceptsNav, this);
      } else {
        newCell = g.walkCells(ed.row, ed.col + 1, 1, this.acceptsNav, this);
      }
    } else if (k == e.ENTER) {
      if (this.moveEditorOnEnter !== false) {
        if (shift) {
          newCell = g.walkCells(last.row - 1, last.col, -1, this.acceptsNav, this);
        } else {
          newCell = g.walkCells(last.row + 1, last.col, 1, this.acceptsNav, this);
        }
      }
    }
    if (newCell) {
      r = newCell[0];
      c = newCell[1];

      if (last.row != r) {
        this.selectRow(r); // *** highlight newly-selected cell and update selection
      }

      if (g.isEditor && g.editing) { // *** handle tabbing while editorgrid is in edit mode
        ae = g.activeEditor;
        if (ae && ae.field.triggerBlur) {
          // *** if activeEditor is a TriggerField, explicitly call its triggerBlur() method
          ae.field.triggerBlur();
        }
      }
      g.startEditing(r, c);
    }
  },

  destroy: function() {
    if (this.rowNav) {
      this.rowNav.disable();
      this.rowNav = null;
    }
    Ext.grid.RowSelectionModel.superclass.destroy.call(this);
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
    this.fireEvent('afterselectionchange', this);
  },
  constrainToGrid: function(value) {
    if (value < 0) {
      value = 0;
    }
    if (value >= this.grid.store.getCount()) {
      value = this.grid.store.getCount() - 1;
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
    return (this.getCursor() !== null && (this.getCursor() + dist) < this.grid.store.getCount() && (this.getCursor() + dist) >= 0);
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
  // private
  handleMouseDown: function(g, rowIndex, e) {
    this.handleMouseEvent(g, rowIndex, e);
  },
  handleMouseEvent: function(g, rowIndex, e) {
    if (e.button !== 0 || this.isLocked()) {
      return;
    }

    // We cache a shallow copy of the most recent event and compare it to the current
    // event to avoid handling duplicate events.
    if (this.looksLikeDuplicateEvents(this.cacheEvent, e)) {
      //	Paperpile.log("Ignoring dup mouse event!");
      return;
    }
    if (this.isIgnorableClickEvent(this.cacheEvent, e)) {
      //	Paperpile.log("Ignoring ignorable event!");
      return;
    }
    Ext.apply(this.cacheEvent, e); // Store the cache by applying the event's properties to a hash.
    var isSelected = this.isSelected(rowIndex);
    var type = e.type;
    var ctrl = e.ctrlKey;
    var shift = e.shiftKey;

    this.setCursor(rowIndex);
    if (!shift) {
      this.setAnchor(rowIndex);
    }

    if (shift) {
      if (type === 'mousedown' && !this.singleSelect && this.anchor !== null) {
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
        //	  Paperpile.log("Selecting row "+rowIndex);
        this.selectRow(rowIndex, false);
        this.focusToCursor();
      } else {
        if (isSelected) {
          //	    Paperpile.log("Already selected, but selecting again!");
          this.selectRow(rowIndex, false);
          this.focusToCursor();
        }
      }
    }
    this.fireEvent('afterselectionchange', this);
  },

  selectFirstRow: function(keepExisting) {
    if (this.grid.store.getCount() > 0) {
      this.selectRow(0, keepExisting);
      this.focusToCursor();
    }
  },
  selectLastRow: function(keepExisting) {
    if (this.grid.store.getCount() > 0) {
      this.selectRow(this.grid.store.getCount() - 1, keepExisting);
      this.focusToCursor();
    }
  },

  onRefresh: function() {
    this.suspendEvents();
    var ds = this.grid.store;
    var index;
    var s = this.getSelections();
    if (!this.maintainSelectionBetweenReloads) {
      this.clearSelections(true);
    }
    var numSelected = 0;
    for (var i = 0, len = s.length; i < len; i++) {
      var r = s[i];
      if ((index = ds.indexOfId(r.id)) != -1) {
        this.selectRow(index, true);
        numSelected++;
        this.grid.getView().onRowSelect(index);
      }
    }
    this.resumeEvents();
    if (s.length != this.selections.getCount()) {
      this.fireEvent('selectionchange', this);
      this.fireEvent('afterselectionchange', this);
    }
  },

  isAllSelected: function() {
    if (this.fakeAllSelected) {
      return true;
    }
    return false;
  },

  selectAll: function() {
    if (this.isLocked()) {
      return;
    }

    // If we're using the 'pageSelection' param, first select
    // this page's worth of counts. Then, if called when we're
    // already selecting the full pag
    if (this.selectPageBeforeAll) {
      if (this.fakeAllSelected || (this.getCount() == this.grid.store.getCount() && this.getCount() < this.grid.store.getTotalCount())) {
        // The whole page is already selected,so now
        // od the fake select all flag.
        this.fakeAllSelected = true;
        this.fireEvent('afterselectionchange', this);
        this.fireEvent('allselected', this);
      } else {
        // Do the standard thing to select all on page.
        this.clearSelections(true);
        this.selectRange(0, this.grid.store.getCount() - 1);
        this.fakeAllSelected = false;
        this.fireEvent('afterselectionchange', this);
        this.fireEvent('pageselected', this);
      }
    } else {
      // If 'selectPageBeforeAll' isn't set to true, immediately select all.
      this.clearSelections(true);
      this.selectRange(0, this.grid.store.getCount() - 1);
      this.fakeAllSelected = true;
      this.fireEvent('afterselectionchange', this);
      this.fireEvent('allselected', this);
    }
  },

  getCount: function() {
    if (this.fakeAllSelected) {
      return this.grid.store.getTotalCount();
    } else {
      return this.selections.length;
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
    this.fireEvent('afterselectionchange', this);
  },

  clearSelections: function(fast) {
    if (this.isLocked()) {
      return;
    }
    if (fast !== true) {
      var ds = this.grid.store;
      var s = this.selections;
      s.each(function(r) {
        this.deselectRow(ds.indexOfId(r.id));
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