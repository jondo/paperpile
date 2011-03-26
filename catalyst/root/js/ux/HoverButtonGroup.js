Ext.define('Ext.ux.HoverButtonGroup', {
  extend: 'Ext.container.Container',
  alias: 'widget.hoverbuttongroup',
  //  componentCls: 'hoverbuttons',
  // Configurable stuff.
  selectors: [],
  fadeDuration: 200,
  fadeDelay: 100,
  // End configurables.
  currentTarget: undefined,
  constructor: function() {
    Ext.getBody().on({
      mouseover: {
        element: 'body',
        fn: this.handleMouseEvent,
        scope: this
      },
      mouseout: {
        element: 'body',
        fn: this.handleMouseEvent,
        scope: this
      }
    });

    this.callParent(arguments);
  },

  initComponent: function() {
    Ext.apply(this, {
      style: {
        position: 'absolute'
      },
      floating: true,
      layout: {
        type: 'hbox',
        pack: 'end',
        align: 'middle',
        padding: 2
      },
      frame: false,
      border: false
    });

    this.callParent(arguments);
    this.show();
  },

  showAtTarget: function(target) {
    if (target != this.currentTarget) {
      this.currentTarget = target;
      this.show();
      this.getEl().appendTo(target);
      this.doLayout();
      this.alignTo(target, 'r-r');
      this.stopFx();
      this.getEl().setOpacity(0);
      this.animate({
        to: {
          opacity: 1
        },
        duration: this.fadeDuration,
        delay: this.fadeDelay
      });
    } else {
      this.doLayout();
      this.alignTo(target, 'r-r');
    }
  },

  hideFromTarget: function() {
    this.currentTarget = undefined;
    this.hide();
  },

  getVisibleItems: function() {
    var visibleCount = 0;
    this.items.each(function(item) {
      if (!item.isHidden()) {
        visibleCount++;
      }
    });
    return visibleCount;
  },

  doLayout: function() {
    if (this.rendered) {
      var totalWidth = 0;
      this.items.each(function(item) {
        if (item.rendered && !item.isHidden()) {
          totalWidth += item.getWidth();
          totalWidth += 2;
        }
      });
      this.setWidth(totalWidth + this.getEl().getPadding('lr'));
    }
    return this.callParent(arguments);
  },

  handleMouseEvent: function(event, target, o) {
    var be = event.browserEvent;
    var t;
    for (var i = 0; i < this.selectors.length; i++) {
      if (!t) {
        t = event.getTarget(this.selectors[i]);
      }
    }

    if (!t) {
      if (this.hideOnNextEvent) {
        this.hideFromTarget();
        event.stopEvent();
        this.hideOnNextEvent = false;
        return;
      } else {
        return;
      }
    }

    if (t && be.type == 'mouseout') {
      // Don't immediately hide ourselves on a delegate's mouseout -- instead,
      // we wait until the next mouse event to do this (see the hideFromTarget call
      // above). This avoids flicker when the mouse goes from the selector item
      // to the hover buttons.
      this.hideOnNextEvent = true;
      event.stopEvent();
      return;
    }

    if (t && be.type == 'mouseover') {
      // Mouse went over a target -- layout and show the hover buttons!
      this.hideOnNextEvent = false;
      this.showAtTarget(t);
      return;
    }

  }
});