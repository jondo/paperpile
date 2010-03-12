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


Ext.namespace('Ext.ux');

Ext.ux.Menubar = Ext.extend(Ext.menu.Menu, {
  plain: true,
  cls: "",
  minWidth: 120,
  shadow: false,
  orientation: "vertical",
  activatedClass: "x-menu-activated",

  constructor: function(config) {
    Ext.ux.Menubar.superclass.constructor.call(this, config);
    this.cls += " x-menubar";
    if (this.orientation == "vertical") {
      this.subMenuAlign = "tl-tr?";
      this.cls += " x-vertical-menubar";
    } else {
      this.subMenuAlign = "tl-bl?";
      this.cls += " x-horizontal-menubar";
    }
  },

  // private
  render: function(container) {
    if (this.el) {
      return;
    }
    if (container) {
      var el = this.el = Ext.get(container);
      el.addClass("x-menu");
    } else {
      var el = this.el = new Ext.Layer({
        cls: "x-menu",
        shadow: this.shadow,
        constrain: false,
        parentEl: this.parentEl || document.body,
        zindex: 15000
      });
    }

    this.keyNav = new Ext.menu.MenuNav(this);

    if (this.plain) {
      el.addClass("x-menu-plain");
    }
    if (this.cls) {
      el.addClass(this.cls);
    }
    // generic focus element
    this.focusEl = el.createChild({
      tag: "a",
      cls: "x-menu-focus",
      href: "#",
      onclick: "return false;",
      tabIndex: "-1"
    });
    var ul = el.createChild({
      tag: "ul",
      cls: "x-menu-list"
    });
    ul.on({
      click: this.onClick,
      mouseover: this.onMouseOver,
      mouseout: this.onMouseOut,
      scope: this
    });
    this.items.each(function(item) {
      var li = ul.createChild({
        tag: 'li',
        cls: 'x-menu-list-item',
        style: {
          'float': (item.align == 'right') ? 'right' : 'left',
          padding: "0 2px"
        }
      },
      null, true);
      if (item instanceof Ext.menu.TextItem) {
        item.addClass("menubar-textitem");
        item.render(li, this);
      } else {
        item.render(li, this);
      }

    },
    this);
    this.ul = ul;
    // this.autoWidth(); // not for menu bars.
  },

  show: function(container) {
    this.fireEvent("beforeshow", this);
    if (!this.el) {
      this.render();
    }
    this.fireEvent("show", this);
  },

  forceHide: function() {
    if (this.activeItem) {
      this.activeItem.deactivate();
      delete this.activeItem;
    }

    this.deactivate();
    this.el.hide();
    this.hidden = true;
  },

  hide: function() {
    // Stop auto-hiding of this menu. -GJ
    //        this.fireEvent("beforehide", this);
    if (this.activeItem) {
      this.activeItem.deactivate();
      delete this.activeItem;
    }
    /*
        this.deactivate();
        this.el.hide();
        this.hidden=true;
        this.fireEvent("hide", this);       
*/
  },

  onClick: function(e) {
    var t = this.findTargetItem(e);

    if (t && t.menu === undefined) {
      t.onClick(e);
      this.fireEvent("click", this, t, e);
    } else {
      if (this.activated) {
        this.deactivate();
        this.activeItem.hideMenu();
      } else if (t) {
        this.activate();
        if (t.canActivate && !t.disabled) {
          this.setActiveItem(t, true);
        }
        this.fireEvent("click", this, e, t);
      }
      e.stopEvent();
    }
  },

  onMouseOver: function(e) {
    var t;
    if (t = this.findTargetItem(e)) {
      if (t.canActivate && !t.disabled) {
        this.setActiveItem(t, this.activated);
      }
    }
    this.fireEvent("mouseover", this, e, t);
  },

  onMouseOut: function(e) {
    var t;
    if (!this.activated) {
      if (t = this.findTargetItem(e)) {
        if (t == this.activeItem && t.shouldDeactivate(e)) {
          //this.activeItem.deactivate();
          delete this.activeItem;
        }
      }
      this.fireEvent("mouseout", this, e, t);
    }
  },

  activate: function() {
    // Sort of a hack to deactivate the menu when clicked somewere else or when an other menu opens.
    this.fireEvent("beforeshow", this);
    this.fireEvent("show", this);

    this.activated = true;
    this.ul.addClass("x-menu-activated");
  },

  deactivate: function() {
    this.activated = false;
    this.ul.removeClass("x-menu-activated");
  }
});