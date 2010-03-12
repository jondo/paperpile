/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */


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