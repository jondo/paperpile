Ext.ux.EnableDisableCheckItem = Ext.extend(Ext.menu.CheckItem, {

  textDisabled: false,

  onRender: function(c) {
    Ext.ux.EnableDisableCheckItem.superclass.onRender.apply(this, arguments);

    if (this.textDisabled) {
      this.disableText();
    } else {
      this.enableText();
    }

    //this.on('click',this.myClickHandler, this);
  },

  handleClick: function(e) {
    var pm = this.parentMenu;
    if (this.hideOnClick) {
      if (pm.floating) {
        pm.hide.defer(this.clickHideDelay, pm, [true]);
      } else {
        pm.deactivateActive();
      }
    }
  },

  onClick: function(e) {
    var shouldContinue = this.myClickHandler(e);
    if (shouldContinue && !this.disabled && this.fireEvent("click", this, e) !== false && (this.parentMenu && this.parentMenu.fireEvent("itemclick", this, e) !== false)) {
      this.handleClick(e);
    } else {
      e.stopEvent();
    }
    //       Ext.menu.CheckItem.superclass.handleClick.apply(this, arguments);
  },

  myClickHandler: function(e) {
    var el = Ext.get(e.target);

    if (el.hasClass('x-menu-item-text') || el.hasClass('x-menu-item')) {
      if (this.textDisabled) {
        e.stopEvent();
        return false;
      } else {
        return true;
      }
    } else if (el.hasClass('x-menu-item-icon')) {
      if (this.textDisabled) {
        // Check button pressed, textDisabled -- turn me on, baby!
        this.enableText();
        this.setChecked(true);
        var shouldActivate = !this.shouldDeactivate(e);
        if (shouldActivate) {
          this.activate();
        }
      } else {
        // Deactivate, un-highlight, disable, etc.
        this.disableText();
        this.setChecked(false);
      }
      e.stopEvent();
      return false;
    }
  },

  disableText: function() {
    this.deactivate();
    this.textEl.addClass('x-item-disabled');
    this.el.addClass('x-item-text-disabled');
    this.textDisabled = true;
    this.activeClass = '';
  },

  enableText: function() {
    this.textEl.removeClass('x-item-disabled');
    this.el.removeClass('x-item-text-disabled');
    this.textDisabled = false;
    this.activeClass = 'x-menu-item-active';
  }
});

Ext.reg('enabledisablecheckitem', Ext.ux.EnableDisableCheckItem);