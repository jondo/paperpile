Ext.ns('Ext.ux');
Ext.ux.AutoHideMenuButton = Ext.extend(Ext.Button, {
  delay: new Ext.util.DelayedTask(),
  autoShow: true,
  autoHide: true,
  autoHideDelay: 200,

  initComponent: function() {
    Ext.ux.AutoHideMenuButton.superclass.initComponent.call(this);

    if (this.menu) {
      this.mon(this.menu, {
        scope: this,
        mouseover: function() {
          this.delay.cancel();
          //this.showMenu();
        },
        mouseout: function() {
          this.delay.delay(this.autoHideDelay, this.hideMenu, this);
        }
      });
    }

  },

  onMouseOver: function(e) {
    Ext.ux.AutoHideMenuButton.superclass.onMouseOver.call(this, e);
    this.delay.cancel();
    this.showMenu();
  },

  onMouseOut: function(e) {
    Ext.ux.AutoHideMenuButton.superclass.onMouseOut.call(this, e);
    this.delay.delay(this.autoHideDelay, this.hideMenu, this);
  }

});