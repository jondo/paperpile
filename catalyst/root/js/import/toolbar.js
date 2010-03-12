Paperpile.ToolbarLayout = Ext.extend(Ext.layout.ToolbarLayout, {

  fitToSize: function(t) {
    // Mostly yoinked from the Ext source, Toolbar.js.
    // Changes are noted.

    if(this.container.enableOverflow === false){
      return;
    }

    var tb = this.container;
    var items = this.container.items.items;
    var len = items.length;

    // Figure out if and where the menuBreak is set.
    var menuBreakIndex = len;
    for (i=0; i < len; i++) {
      var item = items[i];
      if (item.itemId == tb.menuBreakItemId) {
	menuBreakIndex = i;
      }
    }

    var w = t.dom.clientWidth,
    lw = this.lastWidth || 0,
    iw = t.dom.firstChild.offsetWidth,
    clipWidth = w - this.triggerWidth,
    hideIndex = -1;
    
    this.lastWidth = w;
    
    if(iw > w || (this.hiddens && w >= lw) || menuBreakIndex < len-1) {
      var i, c, loopWidth = 0;

      for(i = 0; i < len; i++) {
	c = items[i];
	if(!c.isFill){
	  loopWidth += this.getItemWidth(c);
	  // Start hiding items at whichever comes first: the menuBreak item, or the natural overflow.
          if(loopWidth > clipWidth || i > menuBreakIndex){
            if(!(c.hidden || c.xtbHidden)){
	      this.hideItem(c);
	    }
          }
        }else if(c.xtbHidden){
	  this.unhideItem(c);
        }
      }
    }
    if(this.hiddens){
      this.initMore();
      if(!this.lastOverflow){
	this.container.fireEvent('overflowchange', this.container, true);
	this.lastOverflow = true;
      }
    }else if(this.more){
      this.clearMenu();
      this.more.destroy();
      delete this.more;
      if(this.lastOverflow){
	this.container.fireEvent('overflowchange', this.container, false);
	this.lastOverflow = false;
      }
    }
  }
});

Paperpile.Toolbar = function(config) {
  Ext.apply(this,config);
  Paperpile.Toolbar.superclass.constructor.call(this);
};
Ext.extend(Paperpile.Toolbar,Ext.Toolbar, {
  menuBreakItemId: 'asdf',
  initComponent: function() {
    Ext.apply(this, {
      layout: new Paperpile.ToolbarLayout()
    });
    Paperpile.Toolbar.superclass.initComponent.call(this);
  }
});
