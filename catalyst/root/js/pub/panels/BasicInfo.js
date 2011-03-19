Ext.define('Paperpile.pub.panel.BasicInfo', {
  extend: 'Ext.Component',
  alias: 'widget.BasicInfo',
  initComponent: function() {
    Ext.apply(this, {
      tpl: this.createTemplate()
    });
  },

  setPublication: function(pub) {
    this.pub = pub;
    this.update(pub.data);
  },

  createTemplate: function() {
    return new Ext.XTemplate(
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
  }

});