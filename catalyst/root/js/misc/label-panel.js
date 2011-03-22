Ext.define('Paperpile.CollectionPopup', {
  extend: 'Ext.Panel',
  alias: 'widget.labelpanel',

  // Configurable options start here.	    
  addCheckBoxes: true,
  filterBar: true,
  width: 175,
  height: 200,
  maxViewHeight: 200,
  layoutPadding: 4,
  sortBy: 'count',
  sortDirection: 'DESC',
  // End configurable options.
  constructor: function(cfg) {
    cfg = cfg || {};
    Ext.apply(this, cfg);

    this.addEvents(
      'itemcheck',
      'itemtrigger');

    this.callParent(arguments);
  },
  initComponent: function() {
    this.store = Ext.getStore(this.collectionType);

    if (this.filterBar === true) {
      this.filterField = new Ext.form.TextField({
        cls: 'pp-collection-panel-filter',
        width: '100%',
        emptyText: 'Search Labels',
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
    this.view = new Ext.DataView({
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

    this.manageLabels = new Ext.Component({
      height: 20,
      flex: 0,
      html: Paperpile.pub.PubPanel.actionTextLink('MANAGE_' + Ext.util.Format.uppercase(this.collectionType))
    });
    this.applyLabels = new Ext.Component({
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
    this.newLabel = new Ext.Component({
      height: 20,
      flex: 0,
      hidden: true,
      html: '<a class="pp-textlink">Create new</a>',
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

    var items;
    if (this.filterField) {
      items = [this.filterField, this.viewport];
    } else {
      items = [this.viewport, this.menu];
    }
    items.push(this.applyLabels, this.manageLabels, this.newLabel);

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
      handler: this.fireTrigger,
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
        getItemNode: function(values) {
          if (values.type == 'LABEL') {
            return['<div class="pp-collection-item-count">',
            values.count,
            '</div>',
            '<div class="pp-ellipsis pp-collection-item-name">',
            this.highlightSearchSubset(values.name),
            '</div>', ].join('');
            /*
	      return['<div class="pp-grid-label pp-label-style-' + values.style + '">',
            values.name,
            '</div>'].join('');
	      */
          } else if (values.type == 'FOLDER') {
            return[
            '<div class="pp-grid-folder">',
            values.name,
            '</div>'].join('');
          }
        }
      });
    return template;
  },

  getSingleSel: function() {
    return this.view.getSelectionModel().getSingleSelection();
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
    var records = new Ext.util.MixedCollection();
    records.addAll(this.getCheckedRecords());

    if (records.getCount() == 0 && this.filterField.getValue() != '') {
      this.fireEvent('itemtrigger', this, this.filterField.getValue());
      return;
    }

    if (this.getSingleSel()) {
      records.add(this.getSingleSel());
    }
    this.fireEvent('itemtrigger', this, records.getRange());

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
    var checkedItems = this.getCheckedRecords();
    var filter = this.filterField.getValue();

    this.viewport.show();

    this.applyLabels.hide();
    this.newLabel.hide();
    this.manageLabels.hide();

    if (this.store.getCount() == 0) {
      this.viewport.hide();
    }

    if (checkedItems.length > 0) {
      this.applyLabels.show();
    } else if (filter != '') {
      this.newLabel.update(['<a class="pp-textlink">',
        '<span style="float:right;">(Create new)</span>',
        '<div class="pp-ellipsis"><b>' + filter + '</b></div>',
        '</a>'].join(''));
      this.newLabel.show();
    } else {
      this.manageLabels.show();
    }
  },

  // Aligns this labelpanel to show up below an element.
  alignTo: function(el) {
    this.getEl().alignTo(el, 'tl-bl', [-1, 0]);
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
    this.mon(Ext.getDoc(), "mousedown", this.onMouseDown, this);
    if (this.filterField) {
      this.filterField.setValue('');
      Ext.defer(this.filterField.focus, 20);
      this.updateFilterAndView();
    } else {
      Ext.defer(this.getEl().focus, 20);
    }
  },

  hide: function() {
    this.callParent(arguments);
    this.mun(Ext.getDoc(), "mousedown", this.onMouseDown, this);
  },

  dontHideOnClickNodes: function() {
    return[];
  },

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