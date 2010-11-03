Paperpile.LabelPanel = Ext.extend(Ext.Panel, {

  initComponent: function() {

    this._store = new Paperpile.CollectionStore({
      collectionType: 'LABEL',
      storeId: 'hidden_tag_store'
    });
    this._store.on('load', this.onStoreLoad, this);
    this._store.load();

    if (this.filterBar === true) {
      this._filter = new Ext.form.TextField({
        cls: 'pp-label-panel-filter',
        width: '100%',
        itemId: 'LABEL_FILTER',
        emptyText: 'Search Labels',
        enableKeyEvents: true,
        store: this._store,
      });

      var task = new Ext.util.DelayedTask(this.onStoreLoad, this);
      this._filter.on('keydown', function(f, e) {
        task.delay(20);
      },
      this);
      var task = new Ext.util.DelayedTask(this.onStoreLoad, this);
      this._filter.on('specialkey', function(f, e) {
        if (e.getKey() == e.ENTER && this._store.getCount() == 1) {
          var record = this._store.getAt(0);
          var node = Paperpile.main.tree.recordToNode(record, 'LABEL');
          Paperpile.main.tabs.newCollectionTab(node, 'LABEL');
          this.hide();
        }
      },
      this);

    }

    this._template = new Ext.XTemplate(
      '<tpl for=".">',
      '    <div id="{name}-wrap" class="pp-label-panel-wrap">',
      '    <input type="checkbox" class="pp-label-panel-check" index="{#}"></input>',
      '      <div id="{name}" class="pp-label-panel-item pp-tag-style-{style}">{display_name}</div>',
      '    </div>',
      '</tpl>',
      '<div id="label-panel-spacing" style="height:4px;"></div>').compile();
    this._dataView = new Ext.DataView({
      store: this._store,
      tpl: this._template,
      autoHeight: true,
      border: false,
      frame: true,
      overClass: 'pp-labelview-over',
      selectedClass: 'pp-label-panel-selected',
      itemSelector: 'div.pp-label-panel-item',
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
      width: 150,
      autoHeight: true,
      autoScroll: true,
      cls: 'pp-label-panel',
      title: null,
      items: items
    });

    Paperpile.LabelPanel.superclass.initComponent.call(this);

  },

  onStoreLoad: function() {
    this.updateFilter();
    var viewSize = this._dataView.getSize().height;
    if (viewSize > 200) {
      viewSize = 200;
    }
    this._dataViewport.setHeight(viewSize);
    this.syncSize();
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
    if (this._store.getCount() == 1) {
      this._dataView.select(0, false);
    }
  },

  myContainerClick: function(dataView, e) {
    var el = Ext.fly(e.target);
    if (el.getAttribute('index')) {
      var index = el.getAttribute('index') - 1;
      var record = this._store.getAt(index);
      record.set('hidden', 0);
      this.updateCollection(record);
      this._store.remove(record);
      this._dataView.refresh();
      this.syncSize();
    }
  },

  updateCollection: function(record) {
    Ext.StoreMgr.lookup('tag_store').updateCollection(record);
  },

  myOnClick: function(view, index, el, e) {
    var record = this._store.getAt(index);
    var node = Paperpile.main.tree.recordToNode(record, 'LABEL');
    Paperpile.main.tabs.newCollectionTab(node, 'LABEL');
    this.hide();
  },

  // Aligns this labelpanel to show up below an element.
  alignTo: function(el) {
    this.getEl().alignTo(el, 'tl-bl', [-1, 0]);
  },

  refresh: function() {
    this._store.reload();
  },

  show: function() {
    Paperpile.LabelPanel.superclass.show.call(this);
    Ext.getDoc().on("mousedown", this.onMouseDown, this);
    if (this._filter) {
      this._filter.setValue('');
      this._filter.el.focus();
    } else {
      this.getEl().focus();
    }
  },

  hide: function() {
    Paperpile.LabelPanel.superclass.hide.call(this);
    Ext.getDoc().un("mousedown", this.onMouseDown, this);
  },

  onMouseDown: function(e) {
    if (e.getTarget(".pp-label-panel")) {
      return;
    } else if (e.getTarget(".more-labels-node")) {
      return;
    } else if (e.getTarget("input")) {
      return;
    } else if (e.getTarget(".pp-tag-tree-node")) {

    } else {
      this.hide();
    }
  }

});