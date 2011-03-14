Ext.regModel('Collection', {
  fields: ['guid', 'name', 'type', 'parent', 'sort_order', 'hidden', 'style', {
    name: 'count',
    type: 'int',
    defaultValue: 0
  },
    'data'],
  idProperty: 'guid'
});