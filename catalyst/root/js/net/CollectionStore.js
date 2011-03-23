Ext.define('Paperpile.net.CollectionStore', {
  extend: 'Ext.data.Store',
  config: {
    collectionType: 'LABEL'
  },
  constructor: function(config) {
    Ext.apply(config, {
      model: 'Collection',
      proxy: new Ext.data.HttpProxy({
        model: 'Collection',
        url: Paperpile.Url('/ajax/crud/list_collections'),
        timeout: 100000,
        extraParams: {
          type: config.collectionType
        },
      })
    });
    this.callParent(arguments);
  },
  sortHierarchical: function() {
    // Re-create the hierarchy of a nested collection set, and apply
    // the treeOrder and treeLevel properties to the records' data objects.
    this.sort('sort_order', 'ASC');
    var roots = this.data.filter(new Ext.util.Filter({
      root: 'data',
      property: 'parent',
      value: 'ROOT'
    }));

    this.treeOrder = 0;
    for (var i = 0; i < roots.getCount(); i++) {
      var root = roots.getAt(i);
      this.layoutChildren(root, 0);
    }
  },
  getChildren: function(record) {
    var children = this.data.filter(new Ext.util.Filter({
      root: 'data',
      property: 'parent',
      value: record.getId()
    }));
    return children;
  },
  layoutChildren: function(record, depth) {
    record.data.treeOrder = this.treeOrder++;
    record.data.treeDepth = depth;
    var children = this.getChildren(record);
    for (var i = 0; i < children.getCount(); i++) {
      var child = children.getAt(i);
      this.layoutChildren(child, depth + 1);
    }
  },

  updateFromServer: function(data) {
    //    Paperpile.log("Updating store from server");
    if (data.collection_delta) {
      this.load();
    }
  }
});