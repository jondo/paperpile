Ext.regModel('PublicationModel', {
  fields: ['guid', 'title', '_imported', 'trashed', 'labels', 'folders', 'pdf', 'pdf_name', 'annote', 'citekey', 'created', 'doi', 'authors', 'last_read'],
  idProperty: 'guid'
});