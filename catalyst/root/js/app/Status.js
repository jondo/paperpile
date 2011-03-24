Ext.define('Paperpile.app.Status', {
  extend: 'Ext.panel.Panel',
  alias: 'widget.status',

  // Configuration options
  // Expanded: when true, shows all status items instead of just the most recent.
  expanded: false,
  // End config options.
  initComponent: function() {
    Ext.apply(this, {
      autoRender: true,
      floating: true,
      /*
      layout: {
        type: 'vbox',
        pack: 'start',
        align: 'stretch'
      },
      width: 200,
      height: 30,
*/
      cls: 'pp-status',
    });
    this.callParent(arguments);
    this.show();
    this.setPosition(50, 50);
  },

  createNotification: function(cfg) {
    var params = {
      info: Ext.apply(cfg, {
        created: Ext.util.Format.date(new Date(), 'U')
      })
    };
    var item = Ext.createByAlias('widget.statusitem', params);
    this.insert(0, item);
    this.updateLayout();
    return item;
  },

  updateLayout: function() {
    this.items.sort({
      property: 'priority',
      direction: 'DESC'
    },
    {
      property: 'created',
      direction: 'DESC'
    });

    this.items.each(function(item) {
      if (!item.active) {
        item.hide();
      }
    });
    var activeItems = this.items.filterBy(function(item) {
      return item.active == true
    });

    if (this.expanded) {

    } else {
      if (activeItems.getCount() > 1) {
        activeItems.getAt(0).show();
        for (var i = 1; i < activeItems.getCount(); i++) {
          var item = activeItems.getAt(i);
          item.hide();
        }
      } else if (activeItems.getCount() > 0) {
        activeItems.getAt(0).show();
      }
    }

  },

  statics: {
    busyIcon: '/images/waiting_yellow.gif'
  }
});