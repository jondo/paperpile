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
      '<div class="pp-box BasicInfo pp-box-style1">',
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
      '{[Paperpile.pub.PubPanel.smallTextLink("EDIT")]}',
      '{[Paperpile.pub.PubPanel.smallTextLink("TRASH")]}',
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

    var me = this;
    this.multiTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Reference Info</h2>',
      '<tpl if="this.isAllSelected(values)">',
      '  All {[this.getPubCount(values)]} references are selected.',
      '</tpl>',
      '<tpl if="this.isAllSelected(values) === false">',
      '  {[this.getPubCount(values)]} references selected.',
      '</tpl>', {
        isAllSelected: function(selection) {
          var grid = me.up('pubview').grid;
          return grid.isAllSelected();
        },
        getPubCount: function(selection) {
          var grid = me.up('pubview').grid;
          return grid.getSelectionCount();
        }
      });
  }

});