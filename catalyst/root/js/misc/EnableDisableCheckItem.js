Ext.ux.EnableDisableCheckItem = Ext.extend(Ext.menu.CheckItem, {

  textDisabled: false,
    onRender : function(c){
        Ext.ux.EnableDisableCheckItem.superclass.onRender.apply(this, arguments);

	if (this.textDisabled) {
	    this.textEl.addClass('x-item-disabled');
	}

	this.setHandler(this.cancelClickHandler,this);
    },

    cancelClickHandler: function(item,e) {
	var returnValue = this.myHandleClick(e);
	return returnValue;
    },

    myHandleClick: function(e) {
	var el = Ext.fly(e.target);
	
    if (el.hasClass('x-menu-item-text')) {
      if (this.textDisabled) {
        return false;
      } else {
        // Text clicked -- call actions as normal.
	  return true;
      }
    } else {
      if (this.textDisabled) {
        this.textEl.removeClass('x-item-disabled');
        this.textDisabled = false;
        this.setChecked(false);
      } else {
        this.textEl.addClass('x-item-disabled');
        this.textDisabled = true;
        this.setChecked(false);
      }
	return false;
    }
  }
});

Ext.reg('enabledisablecheckitem', Ext.ux.EnableDisableCheckItem);