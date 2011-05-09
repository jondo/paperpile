Ext.define('Attachment', {
	extend: "Ext.data.Model",
  fields: ['guid', 'publication', 'is_pdf', 'name', 'local_file', 'size', 'md5'],
  idProperty: 'guid',
  belongsTo: 'Publication'
});