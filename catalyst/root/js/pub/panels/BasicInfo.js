Ext.define('Paperpile.pub.panel.BasicInfo', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.BasicInfo',

  detailsMode: false,
  initComponent: function() {
    Ext.apply(this, {});

    this.callParent(arguments);
  },

  createTemplates: function() {
    this.callParent(arguments);

    var me = this;
    this.singleTpl = new Ext.XTemplate(
      '<div class="pp-box BasicInfo pp-box-style1">',
      '<div style="float:right;">',
      '  {[Paperpile.pub.PubPanel.miniLink("OVERVIEW_DETAILS_TOGGLE", undefined, this.getDetailsToggleText(values))]}',
      '  {[Paperpile.pub.PubPanel.iconButton("EDIT")]}',
      '  {[Paperpile.pub.PubPanel.iconButton("TRASH")]}',
      '<br/>',
      '</div>',
      '<h2>Reference Info</h2>',
      '<tpl if="this.isDetailsMode()">',
      '  <dl class="pp-basicinfo-details">',
      '  <tpl for="this.getDetailsFields(values)">',
      '    <dt>{label}:</dt>',
      '    <dd class="pp-details pp-copyable <tpl if="url">pp-linkable pp-ellipsis</tpl>"',
      '    <tpl if="url">url="{url}"</tpl>',
      '    >',
      '      {value}',
      '    </dd>',
      '  </tpl>',
      '  </dl>',
      '</tpl>',
      '<tpl if="!this.isDetailsMode()">',
      '  <dl class="pp-basicinfo-summary">',
      '  <tpl if="pubtype">',
      '    <dt>Type: </dt>',
      '    <dd>',
      '      {[this.getPubTypeName(values.pubtype)]}',
      '      <tpl if="howpublished">({howpublished})</tpl>',
      '    </dd>',
      '  </tpl>',
      '    <dt>Title: </dt>',
      '    <dd class="pp-copyable">{title}</dd>',
      '  <tpl if="_imported">',
      '    <tpl if="trashed==0">',
      '      <dt>Added: </dt>',
      '    </tpl>',
      '    <tpl if="trashed==1">',
      '      <dt>Deleted: </dt>',
      '    </tpl>',
      '    <dd>{created:this.prettyDate}</dd>',
      '  </tpl>',
      '  <tpl for="this.getLinkOuts(values)">',
      '    <dt>{label}: </dt>',
      '    <dd class="pp-copyable pp-linkable" url="{url}">{value}</dd>',
      '  </tpl>',
      '  </dl>',
      '    <div style="clear:left;"></div>',
      '  </div>',
      '</tpl>', {
        getDetailsToggleText: function() {
          if (me.isDetailsMode()) {
            return "Less...";
          } else {
            return "More...";
          }
        },
        isDetailsMode: function() {
          return me.isDetailsMode();
        },
        getDetailsFields: function(values) {
          var currType = Paperpile.main.globalSettings.pub_types[values.pubtype];
          var fieldNames = Paperpile.main.globalSettings.pub_fields;

          var allFields = ['sortkey', 'title', 'booktitle', 'series',
            'authors', 'editors', 'journal', 'chapter',
            'volume', 'number', 'issue', 'edition', 'pages',
            'howpublished', 'publisher', 'organization',
            'school', 'address', 'year', 'month', 'day',
            'issn', 'isbn', 'lccn',
            'keywords', 'note'];

          var list = [];
          for (var i = 0; i < allFields.length; i++) {
            var field = allFields[i];
            var value = values[field];
            var label = fieldNames[field];
            // Check if we have type-specific names
            if (currType.labels) {
              if (currType.labels[field]) {
                label = currType.labels[field];
              }
            }
            // Breaks layout, needs proper fix
            if (label === 'How published') {
              label = 'How publ.';
            }
            if (!value) continue;
            list.push({
              field: field,
              label: label,
              value: value
            });
          }

	  var linkOuts = this.getLinkOuts(values);
	  for (var i=0; i < linkOuts.length; i++) {
	      list.push(linkOuts[i]);
	  }
          return list;
        },
        getLinkOuts: function(values) {
          var fields = [{
            field: 'doi',
            label: 'DOI',
            pattern: 'http://dx.doi.org/{0}'
          },
          {
            field: 'pmid',
            label: 'PubMed ID',
            pattern: 'http://www.ncbi.nlm.nih.gov/pubmed/{0}'
          },
          {
            field: 'url',
            label: 'URL',
            pattern: '{0}'
          },
          {
            field: 'eprint',
            label: 'eprint',
            pattern: '{0}'
          },
          {
            field: 'arxivid',
            label: 'arXiv ID',
            pattern: 'http://arxiv.org/abs/{0}'
          },
          ];
          var linkOuts = [];
          Ext.each(fields, function(field) {
            if (values[field.field]) {
              field.value = values[field.field];
              field.url = Ext.String.format(field.pattern, field.value);
              linkOuts.push(field);
            }
          });
          return linkOuts;
        },
        getPubTypeName: function(pubType, all) {
          var pt = Paperpile.main.globalSettings.pub_types[pubType];
          if (pt) {
            return pt.name;
          } else {
            return 'Publication';
          }
        },
        prettyDate: function(date, all) {
          return Paperpile.utils.prettyDate(date);
        }

      });

      var me = this;
      this.multiTpl = new Ext.XTemplate(
        '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
        '<h2>Reference Info</h2>',
        '<tpl if="this.isAllSelected(values)">',
        '  All {[this.getPubCount(values)]} references are selected.',
        '</tpl>',
        '<tpl if="this.isAllSelected(values) === false">',
        '  {[this.getPubCount(values)]} references selected.',
        '</tpl>',
        '{[Paperpile.pub.PubPanel.link("TRASH")]}',
        '{[Paperpile.pub.PubPanel.link("COPY_FORMATTED")]}',
        '{[Paperpile.pub.PubPanel.link("EXPORT_SELECTION")]}', {
          isAllSelected: function(selection) {
            var grid = me.up('pubview').grid;
            return grid.isAllSelected();
          },
          getPubCount: function(selection) {
            var grid = me.up('pubview').grid;
            return grid.getSelectionCount();
          }
        });

      this.emptyTpl = new Ext.XTemplate(
        '<div class="pp-box pp-box-style2">',
        '  <p class="pp-inactive">No references selected.</p>',
        '</div>');
    },
    isDetailsMode: function() {
      return this.detailsMode;
    },
    toggleDetailsMode: function() {
      this.detailsMode = !this.detailsMode;
      this.setSelection(this.selection);
    }

  });