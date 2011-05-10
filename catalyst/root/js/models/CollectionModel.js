Ext.define('Collection', {
	extend: "Ext.data.Model",
	    fields: ['guid', 'name', 'type', 'parent', 'expanded', 'sort_order', 'hidden', 'style', {
    name: 'count',
    type: 'int',
    defaultValue: 0
  },
    'data'],
  idProperty: 'guid'
});