Ext.define('Paperpile.pub.panel.BasicInfo', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.BasicInfo',
  initComponent: function() {
    Ext.apply(this, {});

    this.callParent(arguments);
  },

  createTemplates: function() {
    this.callParent(arguments);

    this.singleTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Reference Info</h2>',
      '<dl class="pp-ref-info">',
      '<tpl if="pubtype">',
      '  <dt>Type: </dt>',
      '  <dd>',
      '    {pubtype:this.getPubTypeName}',
      '    <tpl if="howpublished">({howpublished})</tpl>',
      '  </dd>',
      '</tpl>',
      '  <dt>Title: </dt>',
      '  <dd>{title}</dd>',
      '<tpl if="_imported">',
      '  <tpl if="trashed==0">',
      '    <dt>Added: </dt>',
      '  </tpl>',
      '  <tpl if="trashed==1">',
      '    <dt>Deleted: </dt>',
      '  </tpl>',
      '  <dd>{created:this.prettyDate}</dd>',
      '</tpl>',
      '</dl>',
      '  <div style="clear:left;"></div>',
      '</div>', {
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

    this.multiTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Reference Info</h2>',
      '{[this.getPubCount(values)]} references selected.', {
        getPubCount: function(selection) {
          return (selection.length);
        }
      });
  }

});