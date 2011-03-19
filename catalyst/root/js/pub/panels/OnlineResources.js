Ext.define('Paperpile.pub.panel.OnlineResources', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.OnlineResources',
  initComponent: function() {
    Ext.apply(this, {
      hideOnMulti: true
    });

    this.callParent(arguments);
  },

  createTemplates: function() {
    this.callParent(arguments);

    this.singleTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-bottom pp-box-style1">',
      '<h2>Online Resources</h2>',
      '  <ul>',
      '    <tpl if="this.hasOnlineLink(values)">',
      '      <li><a class="pp-textlink pp-action pp-action-go" action="VIEW_ONLINE" arg="{guid}">View Online</a></li>',
      '    </tpl>',
      '    <tpl if="this.hasOnlineLink(values) == false">',
      '      <li><a class="pp-action-inactive pp-action-go-inactive">No online link available</a></li>',
      '    </tpl>',
      '   <li><a href="#" action="EMAIL_REFERENCE" arg="{guid}" class="pp-textlink pp-action pp-action-email">E-mail Reference</a></li>',
      '  </ul>',
      '  </div>', {
        hasOnlineLink: function(values) {
          if (values.doi || values.linkout || values.url || values.eprint || values.arxivid) {
            return true;
          } else {
            return false;
          }
        }
      });
  }
});