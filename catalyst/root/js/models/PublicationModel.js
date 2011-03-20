var libraryFields = [
  'pubtype', 'citekey', 'sortkey', 'title', 'booktitle', 'series', 'authors', 'editors', 'afilliation', 'journal', 'chapter', 'volume', 'number', 'issue', 'edition', 'pages', 'url', 'howpublished', 'publisher', 'organization', 'school', 'address', 'year', 'month', 'day', 'eprint', 'issn', 'isbn', 'pmid', 'lccn', 'arxivid', 'doi', 'abstract', 'keywords', 'linkout', 'note'];
var sqlFields = [
  'guid', 'sha1', 'pdf', 'pdf_name', 'attachments', 'trashed', 'created', 'last_read', 'times_read', 'annote', 'labels', 'labels_tmp', 'folders'];

var displayFields = [
		     '_attachments_list', '_authors_display', '_citation_display', '_snippets', '_pubtype_name', 'howpublished', '_imported', '_createdPretty', '_search_job'];

var allFields = [].concat(libraryFields, sqlFields, displayFields);
Ext.regModel('Publication', {
  fields: allFields,
  idProperty: 'guid'
});