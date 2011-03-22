Ext.define('Paperpile.screens.CatalystLog', {
  extend: 'Ext.panel.Panel',
  alias: 'widget.catalystlog',
  title: 'Catalyst log',
  iconCls: 'pp-icon-console',
  id: 'log-panel',

  markup: [
    '<div class="pp-catalyst-log">',
    '<pre id="catalyst-log">{content}</pre>',
    '<div id="log-last-line"></div>',
    '</div>'],

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoScroll: true,
		tpl : new Ext.XTemplate(this.markup)
    });

    this.callParent(arguments);
  },

  afterRender: function() {
    this.callParent(arguments);

    this.on('activate',
      function() {
        Ext.get('log-last-line').dom.scrollIntoView();
      },
      this);

    this.update();

  },

  update: function() {

    this.tpl.overwrite(this.body, {
      content: Paperpile.serverLog
    },
      true);

  },

  addLine: function(line) {
    Ext.get('catalyst-log').insertHtml('beforeEnd', line);
  }

});