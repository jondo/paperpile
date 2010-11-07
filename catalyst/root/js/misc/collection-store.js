Paperpile.CollectionStore = Ext.extend(Ext.data.Store, {
  constructor: function(config) {
    Ext.apply(this, config);
    Ext.apply(this, {
      proxy: new Ext.data.HttpProxy({
        url: Paperpile.Url('/ajax/crud/list_collections'),
        method: 'GET'
      }),
      baseParams: {
        type: this.collectionType
      },
      reader: new Ext.data.JsonReader(),
      pruneModifiedRecords: true
    });
    Paperpile.CollectionStore.superclass.constructor.call(this);
  },
  initComponent: function() {

    Paperpile.CollectionStore.superclass.initComponent.call(this);
  },

  findByGUID: function(guid) {
    var labelIndex = this.findExact('guid', guid);
    if (labelIndex !== -1) {
      return this.getAt(labelIndex);
    } else {
      return null;
    }
  },

  updateCollection: function(record) {
    var params = {};
    Ext.apply(params, record.data);
    Paperpile.Ajax({
      url: '/ajax/crud/update_collection',
      params: params,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        this.reload();
      },
      scope: this
    });

  }

});