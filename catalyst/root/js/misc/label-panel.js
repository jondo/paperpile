Paperpile.LabelPanel = Ext.extend(Ext.Panel, {

  initComponent: function() {

    this._store = new Paperpile.CollectionStore({
      collectionType: 'LABEL',
      storeId: 'hidden_tag_store'
    });
    this._store.on('load', this.onStoreLoad, this);
    this._store.load();

    this._template = new Ext.XTemplate(
      '<tpl for=".">',
      '    <div id="{name}-wrap" class="pp-label-panel-wrap">',
      '    <input type="checkbox" class="pp-label-panel-check" index="{#}"></input>',
      '      <div id="{name}" class="pp-label-panel-item pp-tag-style-{style}">{name}</div>',
      '    </div>',
      '</tpl>',
      '<div id="label-panel-spacing" style="height:4px;"></div>');
    this._dataView = new Ext.DataView({
      store: this._store,
      tpl: this._template,
      trackOver: true,
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
        },
        selectionchange: {
          fn: function(dv, nodes) {
            Paperpile.log(nodes);
          }
        }
      }
    });

    Ext.apply(this, {
      floating: true,
      frame: false,
      bodyStyle: 'font-size:9px,padding:5px;',
      header: false,
      renderTo: document.body,
      width: 150,
      autoScroll: true,
      id: 'label-panel',
      title: null,
      items: [this._dataView]
    });

    Paperpile.LabelPanel.superclass.initComponent.call(this);

  },

  onStoreLoad: function() {
    this._store.filter([{
      property: 'hidden',
      value: '1'
    }]);
    var viewSize = this._dataView.getSize().height;
    if (viewSize > 200) {
      viewSize = 200;
    }
    this.setHeight(viewSize + 5);
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
    }
  },

  updateCollection: function(record) {
    Ext.StoreMgr.lookup('tag_store').updateCollection(record);
  },

  myOnClick: function(view, index, el, e) {
    var record = this._store.getAt(index);
    var node = Paperpile.main.tree.recordToNode(record, 'LABEL');
    Paperpile.main.tabs.newCollectionTab(node, 'LABEL');
  },

  // Aligns this labelpanel to show up below an element.
  alignTo: function(el) {
    this.getEl().alignTo(el, 'tl-bl', [-20, 0]);
  },

  refresh: function() {
    this._store.reload();
  }

});