Ext.define('Paperpile.grid.GridTemplates', {
  statics: {

    gallery: function() {
      if (this._gallery === undefined) {
        this._gallery = new Ext.XTemplate(
          '<tpl for=".">',
          '  <div class="nosel pp-grid-item pp-grid-gallery pub" guid="{guid}" id="{guid}">',
          '    <div class="pp-grid-year">{[this.formatYear(values)]}</div>',
            this.getIconSection(),
          '    <div class="pp-grid-title">{[this.formatTitle(values)]}</div>',
          '    <div class="pp-grid-authors">{[this.formatAuthors(values)]}</div>',
          '    <div class="pp-grid-journal">{[this.formatJournal(values)]}</div>',
          '  </div>',
          '</tpl>',
          '<div class="x-clear"></div>', {
            formatTitle: function(record) {
              return record.title;
	      },
            formatAuthors: function(record) {
              return record._authors_display;
	      },
	    formatJournal: function(record) {
		  return record.journal;
	      },
	    formatYear: function(record) {
		  return record.year;
	      }
          });
      }
      return this._gallery;
    },

    list: function() {
      if (this._list === undefined) {
        this._list = new Ext.XTemplate(
          '<tpl for=".">',
          '  <div class="nosel pp-grid-item pp-grid-list pub {[this.isInactive(values.labels)]}" guid="{guid}" id="{guid}">',
	            this.getIconSection(),
	  '    <div class="pp-grid-list-rightside">',
          '        <span class="pp-grid-title">{title}</span>{[this.labelStyle(values.labels, values.labels_tmp)]}',
          '      <tpl if="_authors_display">',
          '        <p class="pp-grid-authors">{_authors_display}</p>',
          '      </tpl>',
          '      <tpl if="_citation_display">',
          '        <p class="pp-grid-citation">{_citation_display}</p>',
          '      </tpl>',
          '      <tpl if="_snippets">',
          '        <p class="pp-grid-snippets">{_snippets}</p>',
          '      </tpl>',
          '    </div>',
          '  <div class="x-clear"></div>',
	  '  </div>',
          '</tpl>',
{
            labelStyle: function(labels_guid, labels_tmp) {
              var returnMe = '';
              if (labels_tmp) {
                var labels = labels_tmp.split(/\s*,\s*/);
                for (var i = 0; i < labels.length; i++) {
                  name = labels[i];
                  style = '0';
                  returnMe += '<div class="pp-label-grid-inline pp-label-style-' + style + '">' + name + '&nbsp;</div>&nbsp;';
                }
              } else {
                var labels = labels_guid.split(/\s*,\s*/);
                for (var i = 0; i < labels.length; i++) {
                  var guid = labels[i];
                  var style = Paperpile.main.labelStore.getAt(Paperpile.main.labelStore.findExact('guid', guid));
                  if (style != null) {
                    name = style.get('display_name');
                    style = style.get('style');
                    returnMe += '<div class="pp-label-grid-inline pp-label-style-' + style + '">' + name + '&nbsp;</div>&nbsp;';
                  }
                }
              }
              if (labels.length > 0) returnMe = "&nbsp;&nbsp;&nbsp;" + returnMe;
              return returnMe;
            },
            isInactive: function(label_string) {
              var labels = label_string.split(/\s*,\s*/);
              for (var i = 0; i < labels.length; i++) {
                var guid = labels[i];
                var label = Paperpile.main.labelStore.getAt(Paperpile.main.labelStore.findExact('guid', guid));
                if (label != null) {
                  name = label.get('name');
                  if (name === 'Incomplete') {
                    return ('pp-inactive');
                  }
                }
              }
              return ('');
            }
          }).compile();
      }
      return this._list;
    },
    getIconSection: function() {
      var tpl = [
        '<div class="pp-grid-icons">',
        '<tpl if="_imported">',
        this.getImportedIconSection(),
        '</tpl>',
        '<tpl if="pdf">',
        '  <div class="pp-grid-status pp-grid-status-pdf" ext:qtip="<b>{pdf_name}</b><br/>{_last_readPretty}"></div>',
        '</tpl>',
        '<tpl if="attachments">',
        '  <div class="pp-grid-status pp-grid-status-attachments" ext:qtip="{_attachments_count} attached file(s)"></div>',
        '</tpl>',
        '<tpl if="annote">',
        '  <div class="pp-grid-status pp-grid-status-notes" ext:qtip="{_notes_tip}"></div>',
        '</tpl>',
	'  <div class="x-clear"></div>',
        /*
 * Hover-buttons over the grid -- save it for the ext4 rewrite...
 * 
      '<tpl if="_needs_details_lookup == 1">',
      '  <div class="pp-grid-status pp-grid-status-lookup" ext:qtip="Lookup details" action="lookup-details"></div>',
      '</tpl>',
      '<tpl if="!_imported">',
      '  <div class="pp-grid-status pp-grid-status-import" ext:qtip="Import reference" action="import-ref"></div>',
      '</tpl>',
*/
        '</div>'];
      return tpl.join('');
    },
    getImportedIconSection: function() {
      var tpl = [
        '  <tpl if="trashed==0">',
        '    <div class="pp-grid-status pp-grid-status-imported" ext:qtip="[<b>{citekey}</b>]<br>added {_createdPretty}"></div>',
        '  </tpl>',
        '  <tpl if="trashed==1">',
        '    <div class="pp-grid-status pp-grid-status-deleted" ext:qtip="[<b>{citekey}</b>]<br>deleted {_createdPretty}"></div>',
        '  </tpl>'];
      return tpl.join('');
    }
  }
});