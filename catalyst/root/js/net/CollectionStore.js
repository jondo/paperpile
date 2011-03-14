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
  }
});