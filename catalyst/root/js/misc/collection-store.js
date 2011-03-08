Ext.define('Paperpile.net.CollectionProxy', {
  extend: 'Ext.data.AjaxProxy',
  alias: 'proxy.pp.collectionproxy',
  buildUrl: function(request) {
    if (request.action == 'read') {
      return Paperpile.Url('/ajax/crud/list_collections');
    } else {
      return 'asdfasdfasdf';
    }
  }
});

Ext.regModel('CollectionModel', {
  fields: ['guid', 'name', 'type', 'parent', 'sort_order', 'hidden', 'style', 'data'],
  idProperty: 'guid',
  proxy: {
    type: 'pp.collectionproxy'
  }
});

Ext.define('Paperpile.net.CollectionStore', {
  extend: 'Ext.data.Store',
  config: {
    collectionType: 'LABEL'
  },
  constructor: function(config) {
    Ext.apply(config, {
      model: 'CollectionModel'
    });
    Paperpile.net.CollectionStore.superclass.constructor.call(this, config);
  },
  findByGUID: function(guid) {
    var labelIndex = this.findExact('guid', guid);
    if (labelIndex !== -1) {
      return this.getAt(labelIndex);
    } else {
      return null;
    }
  }
});