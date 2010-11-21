Paperpile.LabelPanel = Ext.extend(Ext.Panel, {

  initComponent: function() {

    this._store = new Paperpile.CollectionStore({
      collectionType: 'LABEL',
      storeId: 'hidden_label_store'
    });
    this._store.load();

    if (this.filterBar === true) {
      this._filter = new Ext.form.TextField({
        cls: 'pp-label-panel-filter',
        width: '100%',
        itemId: 'LABEL_FILTER',
        emptyText: 'Search Labels',
        enableKeyEvents: true
      });

      this._filterTask = new Ext.util.DelayedTask(this.updateFilterAndView, this);
      this.mon(this._filter,'keyup',function(f, e) {
        var k = e.getKey();
        if (k == e.DOWN || k == e.UP || k == e.ENTER || k == e.TAB) {
          return;
        } else {
          this._filterTask.delay(20);
        }
      },
      this);
    }

    this._template = new Ext.XTemplate(
      '<tpl for=".">',
      '    <div id="{name}-wrap" class="pp-label-panel-wrap">',
      '    <input type="checkbox" class="pp-label-panel-check" index="{#}"></input>',
      '      <div id="{name}" class="pp-label-panel-item pp-label-style-{style}">{display_name}</div>',
      '    </div>',
      '</tpl>',
      '<div id="label-panel-spacing" style="height:4px;"></div>').compile();
    this._dataView = new Ext.DataView({
      store: this._store,
      tpl: this._template,
      autoHeight: true,
      border: false,
      frame: true,
      trackOver: true,
      overClass: 'pp-label-panel-over',
      selectedClass: 'pp-label-panel-selected',
      singleSelect: true,
      itemSelector: 'div.pp-label-panel-wrap',
      boxMaxHeight: 250,
      boxMinHeight: 50,
      emptyText: '',
      listeners: {
        click: {
          fn: this.myOnClick,
          scope: this
        },
        containerclick: {
          fn: this.myContainerClick,
          scope: this
        }
      }
    });

    this._dataViewport = new Ext.Container({
      cls: 'pp-label-panel-vp',
      autoEl: 'div',
      autoScroll: true,
      items: [this._dataView]
    });

    var items;
    if (this._filter) {
      items = [this._filter, this._dataViewport];
    } else {
      items = [this._dataViewport];
    }

    Ext.apply(this, {
      floating: true,
      frame: false,
      bodyStyle: 'font-size:9px,padding:5px;',
      header: false,
      renderTo: document.body,
      width: 175,
      autoHeight: true,
      autoScroll: true,
      cls: 'pp-label-panel',
      title: null,
      items: items
    });

    Paperpile.LabelPanel.superclass.initComponent.call(this);

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
    this.actions['OPEN_SELECTED'] = new Ext.Action({
      handler: this.openSelected,
      scope: this
    });

    this.on('render', function() {
      this.keys = new Ext.ux.KeyboardShortcuts(this.body);
      this.keys.bindAction('tab', this.actions['DOWN_ONE']);
      this.keys.bindAction('down', this.actions['DOWN_ONE']);
      this.keys.bindAction('up', this.actions['UP_ONE']);
      this.keys.bindAction('enter', this.actions['OPEN_SELECTED']);
    },
    this);
  },

  getSingleSel: function() {
    var selectedIndices = this._dataView.getSelectedIndexes();
    if (selectedIndices.length > 0) {
      return selectedIndices[selectedIndices.length - 1];
    } else {
      return -1;
    }
  },

  selectFirst: function(keyCode, event) {
    this._dataView.select(0, false);
    this.scrollTo(0);
  },

  selectNext: function(keyCode, event) {
    var ind = this.getSingleSel();

    if (ind == -1) {
      this._dataView.select(0, false);
      this.scrollTo(0);
      return;
    }

    if (ind < this._store.getCount() - 1) {
      ind++;
    }

    this._dataView.select(ind, false);
    this.scrollTo(ind);
  },

  selectPrev: function(keyCode, event) {
    var ind = this.getSingleSel();
    ind--;
    if (ind < 0) {
      ind = 0;
    }
    this._dataView.select(ind, false);
    this.scrollTo(ind);
  },

  openSelected: function(keyCode, event) {
    var ind = this.getSingleSel();
    var record = this._store.getAt(ind);
    var node = Paperpile.main.tree.recordToNode(record, 'LABEL');
    Paperpile.main.tabs.newCollectionTab(node, 'LABEL');
    this.hide();
  },

  scrollTo: function(index) {
    var dom = this._dataView.getNode(index);
    Ext.get(dom).scrollIntoView(this._dataViewport.getEl());
  },

  updateFilter: function() {
    var text = this._filter.getValue();
    var filters = [{
      property: 'hidden',
      value: 1,
      exactMatch: true
    }];
    if (text != '') {
      filters.push({
        property: 'name',
        value: text,
        anyMatch: true,
        caseSensitive: false
      });
    }
    this._store.filter(filters);
    //    if (this._store.getCount() == 1) {
    //      this._dataView.select(0, false);
    //    }
  },

  myContainerClick: function(dataView, e) {
    var el = Ext.fly(e.target);
    if (el.getAttribute('index')) {
      var index = el.getAttribute('index') - 1;
      var record = this._store.getAt(index);
      record.set('hidden', 0);
      Paperpile.main.tree.refreshLabels();
      this.updateCollection(record);
    }
  },

  updateCollection: function(record) {
    Ext.StoreMgr.lookup('label_store').updateCollection(record);
  },

  myOnClick: function(view, index, el, e) {
    if (e.getTarget(".pp-label-panel-item", 1)) {
      var record = this._store.getAt(index);
      var node = Paperpile.main.tree.recordToNode(record, 'LABEL');
      Paperpile.main.tabs.newCollectionTab(node, 'LABEL');
      this.hide();
    } else {
      this.myContainerClick(view, e);
    }
  },

  // Aligns this labelpanel to show up below an element.
  alignTo: function(el) {
    this.getEl().alignTo(el, 'tl-bl', [-1, 0]);
  },

  loadRecordsFromStore: function() {
    var labels = Ext.StoreMgr.lookup('label_store');

    // Take all of our Records and add them to the hidden label store.
    this._store.removeAll();
    var allRecords = labels.getRange();
    this._store.add(allRecords);
  },

  updateFilterAndView: function() {
    this.updateFilter();
    var viewSize = this._dataView.getSize().height;
    if (viewSize > 200) {
      viewSize = 200;
    }
    this._dataViewport.setHeight(viewSize);
    this.syncSize();
  },

  refreshView: function() {
    this.loadRecordsFromStore();
    this.updateFilterAndView();
  },

  show: function() {
    Paperpile.LabelPanel.superclass.show.call(this);
    this.mon(Ext.getDoc(),"mousedown", this.onMouseDown, this);
    if (this._filter) {
      this._filter.setValue('');
      this._filter.el.focus();
      this.updateFilterAndView();
    } else {
      this.getEl().focus();
    }
  },

  hide: function() {
    Paperpile.LabelPanel.superclass.hide.call(this);
    this.mun(Ext.getDoc(),"mousedown", this.onMouseDown, this);
  },

  onMouseDown: function(e) {
    if (e.getTarget(".pp-label-panel")) {
      return;
    } else if (e.getTarget(".more-labels-node")) {
      return;
    } else if (e.getTarget("input")) {
      return;
    } else if (e.getTarget(".pp-label-tree-node")) {

    } else {
      this.hide();
    }
  }

});