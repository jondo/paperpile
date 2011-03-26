Ext.define('Paperpile.pub.panel.OnlineResources', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.OnlineResources',
  initComponent: function() {
    Ext.apply(this, {
      hideOnMulti: false
    });

    this.callParent(arguments);
  },

  createTemplates: function() {
    this.callParent(arguments);

    this.singleTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-bottom pp-box-style1">',
      '<h2>Online Resources</h2>',
      '    <tpl if="this.hasOnlineLink(values)">',
      '      {[Paperpile.pub.PubPanel.button("VIEW_ONLINE")]}<br/>',
      '    </tpl>',
      '    <tpl if="!this.hasOnlineLink(values)">',
      '      <a class="pp-action-inactive pp-action-go-inactive">No online link available</a>',
      '    </tpl>',
      '   {[Paperpile.pub.PubPanel.link("AUTO_COMPLETE")]}<br/>',
      '   {[Paperpile.pub.PubPanel.link("EMAIL")]}',
      '  </div>', {
        hasOnlineLink: function(values) {
          if (values.doi || values.linkout || values.url || values.eprint || values.arxivid) {
            return true;
          } else {
            return false;
          }
        }
      });

    this.multiTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-style1">',
      '  <h2>Online Resources</h2>',
      '  {[Paperpile.pub.PubPanel.link("AUTO_COMPLETE")]}<br/>',
      '  {[Paperpile.pub.PubPanel.link("EMAIL")]}<br/>',
      '</div>');
  }
});