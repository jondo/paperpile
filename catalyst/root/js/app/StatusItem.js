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
	    tpl: this.getTemplate(),
		cls: 'pp-status-item'
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
    var me = this;
    return new Ext.XTemplate(
      '<div class="pp-status-item">',
      '  <tpl if="icon">',
      '    <img src="{icon}"/>',
      '  </tpl>',
      '  {text}',
      '  <tpl for="actions">',
      '    {[this.formatAction(values)]}',
      '  </tpl>',
      '</div>', {
        formatAction: function(values) {
	      return Paperpile.pub.PubPanel.link(values.action_id, me.id, values.text);
        }

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
      me.updateStatus(cfg, false);
    },
    delay);
    this.delayTimeouts.push(timeout);
  },

  updateStatus: function(cfg, clearTimeouts) {
    if (!this.active) {
      this.active = true;
      this.ownerCt.updateLayout();
    }

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