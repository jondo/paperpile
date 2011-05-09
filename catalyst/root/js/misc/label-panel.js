Ext.define('Paperpile.Collectionpicker', {
  extend: 'Ext.Panel',
  alias: 'widget.collectionpicker',

  // Configurable options start here.	    
  addCheckBoxes: true,
  filterBar: true,
	    alignString: 'tr-br',
  width: 175,
  height: 200,
  maxViewHeight: 200,
  layoutPadding: 4,
  sortBy: 'sort_order',
  sortDirection: 'DESC',
  // End configurable options.
  constructor: function(cfg) {
    cfg = cfg || {};
    Ext.apply(this, cfg);

    this.addEvents(
      'itemcheck',
      'applychanges');

    this.callParent(arguments);
  },
  initComponent: function() {
    this.store = Ext.getStore(this.collectionType);

    if (this.filterBar === true) {
      this.filterField = new Ext.form.TextField({
        cls: 'pp-collection-panel-filter',
        width: '100%',
        emptyText: 'Search ' + this.collectionType,
        hideLabel: true,
        enableKeyEvents: true,
        flex: 0
      });

      this.filterTask = new Ext.util.DelayedTask(this.updateFilterAndView, this);
      this.mon(this.filterField, 'keyup', function(f, e) {
        var k = e.getKey();
        if (k == e.DOWN || k == e.UP || k == e.ENTER || k == e.TAB) {
          return;
        } else {
          this.filterTask.delay(20);
        }
      },
      this);
    }

    var viewWidth = this.width - this.padding * 2 - 20;
    if (this.addCheckBoxes) {
      viewWidth -= 10;
    }
    this.view = new Ext.view.View({
      border: false,
      frame: true,
      store: this.store,
      tpl: this.createTemplate(),
      autoHeight: true,
      multiSelect: false,
      singleSelect: true,
      trackOver: true,
      loadingText: null,
      overItemCls: 'pp-grid-over',
      selectedItemCls: 'pp-grid-selected',
      itemSelector: 'div.pp-collection-item',
      getSelectionModel: function() {
        if (!this.selModel) {
          var me = this;
          this.selModel = new Paperpile.grid.SelectionModel();
        }
        return this.selModel;
      },
      onMouseOver: function(e) {
        var me = this;
        var item = e.getTarget(me.itemSelector, me.getTargetEl());
        if (!item) {
          return;
        }
        var record = me.getRecord(item);
        var index = me.store.indexOf(record);
        me.getSelectionModel().select(index);
      },
      onMouseOut: function(e) {
        var me = this;
        var item = e.getTarget(me.itemSelector, me.getTargetEl());
        if (!item) {
          return;
        }
        var record = me.getRecord(item);
        var index = me.store.indexOf(record);
        me.getSelectionModel().deselectRow(index);
      },
      listeners: {
        mousedown: {
          fn: this.handleMouseEvent,
          scope: this
        }
      }
    });

    this.viewport = new Ext.Panel({
      itemId: 'viewport',
      bodyCls: 'pp-collection-panel-vp',
      autoScroll: true,
      flex: 1,
      items: [this.view]
    });

    this.manageCollection = new Ext.Component({
      height: 20,
      flex: 0,
      html: '<a class="pp-textlink">Manage ' + this.collectionType + '</a>',
      listeners: {
        click: {
          element: 'el',
          fn: function() {
            Paperpile.app.Actions.execute('MANAGE_' + Ext.util.Format.uppercase(this.collectionType));
            this.hide();
          },
          scope: this
        }
      }
    });
    this.apply = new Ext.Component({
      height: 20,
      flex: 0,
      hidden: true,
      html: '<a class="pp-textlink">Apply</a>',
      listeners: {
        click: {
          element: 'el',
          fn: function() {
            this.fireTrigger();
          },
          scope: this
        }
      }
    });
    this.newCollection = new Ext.Component({
      height: 20,
      flex: 0,
      hidden: true,
      html: '<a class="pp-textlink">Create new</a>',
      listeners: {
        click: {
          element: 'el',
          fn: function() {
            this.view.getSelectionModel().clearSelections();
            this.fireTrigger();
          },
          scope: this
        }
      }
    });

    var items;
    if (this.filterField) {
      items = [this.filterField, this.viewport];
    } else {
      items = [this.viewport, this.menu];
    }
    items.push(this.apply, this.manageCollection, this.newCollection);

    Ext.apply(this, {
      hidden: true,
      autoRender: true,
      floating: true,
      frame: false,
      header: false,
      renderTo: document.body,
      cls: 'pp-collection-panel',
      layout: {
        type: 'vbox',
        align: 'stretch',
        pack: 'start',
        padding: this.layoutPadding
      },
      height: 200,
      title: null,
      items: items
    });

    this.callParent(arguments);

    this.actions = [];
    this.actions['SELECT_FIRST'] = new Ext.Action({
      handler: this.selectFirst,
      scope: this
    });
    this.actions['DOWN_ONE'] = new Ext.Action({
      handler: this.selectNext,
      scope: this
    });
    this.actions['UP_ONE'] = new Ext.Action({
      handler: this.selectPrev,
      scope: this
    });
    this.actions['FIRE_EVENT'] = new Ext.Action({
      handler: function(keyCode, event) {
        this.fireTrigger();
        event.stopEvent();
      },
      scope: this
    });

    this.on('render', function() {
      this.keys = new Ext.ux.KeyboardShortcuts(this.body);
      this.keys.bindCallback('tab', function(keyCode, event) {
        event.stopEvent();
        this.actions['DOWN_ONE'].execute();
      },
      this);
      this.keys.bindCallback('shift-tab', function(keyCode, event) {
        event.stopEvent();
        this.actions['UP_ONE'].execute();
      },
      this);
      this.keys.bindAction('down', this.actions['DOWN_ONE'], true);
      this.keys.bindAction('up', this.actions['UP_ONE'], true);
      this.keys.bindAction('enter', this.actions['FIRE_EVENT'], true);
    },
    this);

  },

  createTemplate: function() {
    var me = this;
    var template = new Ext.XTemplate(
      '  <tpl for=".">',
      '    <div class="pp-collection-item">',
      this.addCheckBoxes ? '<input type="checkbox" class="pp-collection-panel-check" <tpl if="checked">checked="true"</tpl>></input>' : '',
      '        <div>{[this.getItemNode(values)]}</div>',
      '    </div>',
      '  </tpl>', {
        highlightSearchSubset: function(value) {
          var search = me.filterField.getValue();
          if (search) {
            var regexp = "(" + search + ")";
            value = value.replace(new RegExp(regexp, "i"), "<b>$1</b>");
          }
          return value;
        },
	getDepthSpacing: function(values) {
	      var depth = values.treeDepth || 0;
	      var str = '<span style="margin-left:'+depth*5+'px;"></span>';
	      return str;
	  },
        getItemNode: function(values) {
          if (values.type == 'LABEL' || values.type == 'FOLDER') {
            return[
		   '<div class="pp-collection-item-count">',
            values.count,
            '</div>',
            '<div class="pp-ellipsis pp-collection-item-name">',
		   this.getDepthSpacing(values),
            this.highlightSearchSubset(values.name),
            '</div>', ].join('');
            /*
	      return['<div class="pp-grid-label pp-label-style-' + values.style + '">',
            values.name,
            '</div>'].join('');
	      */
          }
        }
      });
    return template;
  },

  getSingleSel: function() {
    return this.view.getSelectionModel().getSingleSelection();
  },

  setCheckedIds: function(ids) {
    var store = this.store;
    Ext.each(ids, function(id) {
      var rec = store.getById(id);
      rec.data.initialChecked = 1;
      rec.data.checked = 1;
    });
  },

  getCheckedRecords: function() {
    var records = [];
    this.store.each(function(item) {
      if (item.data.checked) {
        records.push(item);
      }
    });
    return records;
  },

  selectFirst: function(keyCode, event) {
    this.view.getSelectionModel().select(0, false);
    this.scrollTo(0);
  },

  selectNext: function(keyCode, event) {
    var item = this.getSingleSel();
    var index = this.store.indexOf(item);

    if (index == -1) {
      this.view.getSelectionModel().select(0, false);
      this.scrollTo(0);
      return;
    }

    if (index < this.store.getCount() - 1) {
      index++;
    }

    this.view.getSelectionModel().select(index, false);
    this.scrollTo(index);
  },

  selectPrev: function(keyCode, event) {
    var item = this.getSingleSel();
    var index = this.store.indexOf(item);
    index--;
    if (index < 0) {
      index = 0;
    }
    this.view.getSelectionModel().select(index, false);
    this.scrollTo(index);
  },

  fireTrigger: function() {
    var checked = new Ext.util.MixedCollection();
    var unchecked = new Ext.util.MixedCollection();

    if (this.getSingleSel()) {
      var record = this.getSingleSel();
      if (record.data.checked) {
        unchecked.add(this.getSingleSel());
      } else {
        checked.add(this.getSingleSel());
      }
    }

    this.store.each(function(record) {
      if (record.data.initialChecked && !record.data.checked) {
        unchecked.add(record);
      }
      if (!record.data.initialChecked && record.data.checked) {
        checked.add(record);
      }
      delete record.data.initialChecked;
      delete record.data.checked;
    });

    // Reset the original sort and filter states.
    this.store.clearFilter();
    this.store.filters = this.origFilter;
    this.store.sort(this.origSort);

    if (checked.getCount() > 0 || unchecked.getCount() > 0) {
      this.fireEvent('applychanges', this, checked, unchecked);
    } else if (this.filterField.getValue() != '') {
      // We have a search term and no checked or selected records.
      // Return the bare string to create a new label.
      this.fireEvent('newitem', this, this.filterField.getValue());
      return;
    } else {}
  },

  scrollTo: function(index) {
    var dom = this.view.getNode(index);
    Ext.get(dom).scrollIntoView(this.viewport.body);
  },

  getBaseFilters: function() {
    // To be overridden as needed for special cases.
  },

  updateFilter: function() {
    this.store.clearFilter();
    var text = this.filterField.getValue();
    var filters = [];
    var defaultFilters = this.getBaseFilters();
    if (defaultFilters) {
      filters.push(defaultFilters);
    }
    if (text != '') {
      filters.push({
        property: 'name',
        value: text,
        anyMatch: true,
        caseSensitive: false
      });
    }
    this.store.filter(filters);
    this.store.sort(this.sortBy, this.sortDirection);
    if (this.store.getCount() > 0 && this.filterField.getValue() != '') {
      this.view.getSelectionModel().select(0, false);
    } else {
      this.view.getSelectionModel().clearSelections();
    }
  },

  handleMouseEvent: function(dv, index, target, event) {
    var item = event.getTarget(this.view.getItemSelector(), this.view.getTargetEl());
    var record = this.view.getRecord(item);

    var checkbox = event.getTarget('input[type=checkbox]');
    if (checkbox) {
      // If it's not currently checked, that means it will be.
      // Set the record's 'checked' property to TRUE.
      if (!checkbox.checked) {
        record.data.checked = true;
      } else {
        record.data.checked = false;
      }
      this.updateButtons();
      this.fireEvent('itemcheck', this, record);
    } else {
      // Click occurred on an item.
      this.fireTrigger();
    }
  },

  updateButtons: function(record) {
    var filter = this.filterField.getValue();

    this.viewport.show();

    this.apply.hide();
    this.newCollection.hide();
    this.manageCollection.hide();

    if (this.store.getCount() == 0) {
      this.viewport.hide();
    }

    var hasChanges = false;
    this.store.each(function(record) {
      if ((record.data.checked && !record.data.initialChecked) || (record.data.initialChecked && !record.data.checked)) {
        hasChanges = true;
      }
    });
    if (hasChanges) {
      this.apply.show();
    } else if (filter != '') {
      this.newCollection.update(['<a class="pp-textlink">',
        '<span style="float:right;">(Create new)</span>',
        '<div class="pp-ellipsis"><b>' + filter + '</b></div>',
        '</a>'].join(''));
      this.newCollection.show();
    } else {
      this.manageCollection.show();
    }
  },

  // Aligns this labelpanel to show up below an element.
  alignTo: function(el) {
    this.getEl().alignTo(el, this.alignString, [-1, 0]);
  },

  updateFilterAndView: function() {
    this.updateFilter();

    var viewSize = this.view.getSize().height;
    if (viewSize > this.maxViewHeight) {
      viewSize = this.maxViewHeight;
    }

    var totalHeight = this.layoutPadding;
    this.items.each(function(item) {
      if (item.itemId == 'viewport') {
        totalHeight += viewSize;
      } else {
        totalHeight += item.getHeight();
      }
      totalHeight += this.layoutPadding;
    },
    this);
    this.setHeight(totalHeight + 2);
    this.updateButtons();
  },

  show: function() {
    this.callParent(arguments);

    this.origSort = this.store.getSortState();
    this.origFilter = this.store.filters;

    this.updateButtons();
    this.mon(Ext.getDoc(), "mousedown", this.onMouseDown, this);
    if (this.filterField) {
      this.filterField.setValue('');
      this.updateFilterAndView();
      this.filterField.focus();
    } else {
      Ext.defer(this.getEl().focus, 20);
    }
  },

  hide: function() {
    this.store.each(function(record) {
      record.data.checked = false;
    });

    this.mun(Ext.getDoc(), "mousedown", this.onMouseDown, this);
    this.callParent(arguments);
  },

  dontHideOnClickNodes: Ext.emptyFn,

  onMouseDown: function(e) {
    var dontHideOnClickNodes = ['.pp-collection-panel',
      'input[type=checkbox]'];

    var extras = this.dontHideOnClickNodes();
    for (var i = 0; i < extras.length; i++) {
      dontHideOnClickNodes.push(extras[i]);
    }

    for (var i = 0; i < dontHideOnClickNodes.length; i++) {
      if (e.getTarget(dontHideOnClickNodes[i])) {
        return;
      }
    }
    this.hide();
  }

});