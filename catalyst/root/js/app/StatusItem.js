Ext.define('Paperpile.app.StatusItem', {
  extend: 'Ext.Component',
  alias: 'widget.statusitem',
  info: {},
  active: false,
  delayTimeouts: [],
  constructor: function(cfg) {
    Ext.apply(this, cfg);

    this.callParent(arguments);
  },
  initComponent: function() {
    Ext.apply(this, {
      tpl: this.getTemplate()
    });

    this.callParent(arguments);

    if (this.info.delay > 0) {
      this.active = false;
      var timeout = Ext.Function.defer(function(info) {
        this.active = true;
        this.ownerCt.updateLayout();
        this.updateStatus(this.info, false);
      },
      this.info.delay, this, [this.info]);
      this.delayTimeouts.push(timeout);
    } else {
      this.active = true;
    }
  },

  getTemplate: function() {
    return new Ext.XTemplate(
      '<div class="pp-status-item">',
      '  <tpl if="icon">',
      '    <img src="{icon}"/>',
      '  </tpl>',
      '  {text}',
      '  <tpl for="actions">',
      '    {#}',
      '  </tpl>',
      '</div>', {

      });
  },

  delay: function(delay, text) {
    this.delayStatus(delay, {
      text: text
    });
  },

  delayStatus: function(delay, cfg) {
    var me = this;
    var timeout = Ext.Function.defer(function() {
      Paperpile.log(cfg);
      me.updateStatus(cfg, false);
    },
    delay);
    this.delayTimeouts.push(timeout);
  },

  updateStatus: function(cfg, clearTimeouts) {
    if (cfg) {
      var info = this.info;
      if (cfg.reset) {
        info = {};
      }
      Ext.apply(info, cfg);
      this.info = info;
    }
    this.update(this.info);

    if (clearTimeouts !== false) {
      this.clearTimeouts();
    }
  },

  clearTimeouts: function() {
    Paperpile.log("Clearing timeouts!");
    Ext.each(this.delayTimeouts, function(timeout) {
      clearTimeout(timeout);
    });
    this.delayTimeouts = [];
  },

  destroy: function() {
    this.clearTimeouts();
    var ownerCt = this.ownerCt;
    if (ownerCt) {
      ownerCt.remove(this);
      ownerCt.updateLayout();
    }
    this.callParent(arguments);

  }
});