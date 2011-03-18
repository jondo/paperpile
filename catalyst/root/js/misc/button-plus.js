
Ext.define('Ext.ux.ButtonPlus', {
	extend: 'Ext.Panel',
  defaultType: 'menuitem',
  layout: 'auto',
  frame: true,
  shadow: false,
  border: false,
  baseCls: '',
  cls: 'x-button-plus',
  //  internalDefaults: {},
  actionMode: 'container',
  hideOnClick: true,
  initComponent: function() {

    if (this.items.length > 1) {
      this.items[1].xtype = 'unstyledbutton';
    }

    Ext.ux.ButtonPlus.superclass.initComponent.call(this);

    var first = this.items.get(0);
    first.on('render', function() {
      var el = first.getEl();
      var textEl = first.textEl;
      Ext.DomHelper.insertAfter(textEl, {
        tag: 'div',
        html: '&nbsp;',
        cls: 'x-menu-item-extraspace'
      });
    },
    this, {
      single: true
    });

    this.on('afterlayout', this.onAfterLayout, this);
  },
  onRender: function(container, position) {
    Ext.ux.ButtonPlus.superclass.onRender.apply(this, arguments);

    if (this.ownerCt && this.ownerCt instanceof Ext.menu.Menu) {
      this.parentMenu = this.ownerCt;
    }

    this.items.each(function(item, index, length) {
      item.on('click', this.onClick, this, [item]);
      if (index == 1) {
        item.setText('');
      }
      if (index == 0) {}
    },
    this);

  },
  afterRender: function(container, position) {
    Ext.ux.ButtonPlus.superclass.afterRender.call(this);

    var second = this.items.get(1);

    //    second.getEl().setStyle('float:right;width:24px;');
  },
  //    getWidth: function() {
  //	var w = Ext.ux.ButtonPlus.superclass.getWidth.call(this);
  //      var second = this.items.get(1);
  //		       return w + second.getEl().getWidth();
  //},
  onClick: function(item) {
    if (this.hideOnClick && this.parentMenu) {
      this.parentMenu.hide.defer(10, this.parentMenu);
    }
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
  onAfterLayout: function() {
    var first = this.items.get(0);
    var second = this.items.get(1);

    /*
    var first = this.items.get(0);
    if (this.items.getCount() > 1) {
      var second = this.items.get(1);
      second.doAutoWidth();
      Paperpile.log(first.el.getWidth());
      Paperpile.log(second.el.getWidth());
      var secondWidth = second.el.getWidth();
      var containerWidth = this.container.getWidth();
      Paperpile.log("container: " + containerWidth);
      var remainder = containerWidth - secondWidth;
      //      first.el.setWidth(remainder);
      second.el.setWidth(22);
    }
*/
  },

  enable: function() {
    Ext.ux.ButtonPlus.superclass.enable.call(this);

    this.items.each(function(item, index, length) {
      item.enable();
      // Also need to enable our base action if necessary.
      if (item.baseAction) {
        item.baseAction.enable();
      }
    });
  },
  disable: function() {
    Ext.ux.ButtonPlus.superclass.disable.call(this);

    this.items.each(function(item, index, length) {
      item.disable();
      if (item.baseAction) {
        item.baseAction.disable();
      }
    });
  }

});

Ext.define('Ext.ux.UnstyledButton', {
	extend:'Ext.button.Button',
	    alias:'widget.unstyledbutton',
  cls: 'x-btn-plain'
});


Ext.define('Ext.ux.SubtleButton', {
	extend: 'Ext.button.Button',
	    alias: 'widget.subtlebutton',
  cls: 'x-btn-subtle',
    setTooltip : function(tooltip, /* private */ initial){
        if(this.rendered){
            if(!initial){
                this.clearTip();
            }
            if(Ext.isObject(tooltip)){
                Ext.QuickTips.register(Ext.apply({
                      target: this.btnEl.parent('td').id
                }, tooltip));
                this.tooltip = tooltip;
            }else{
		this.btnEl.parent('td').dom[this.tooltipType] = tooltip;
            }
        }else{
            this.tooltip = tooltip;
        }
        return this;
    },
    // private
    clearTip : function(){
        if(Ext.isObject(this.tooltip)){
            Ext.QuickTips.unregister(this.btnEl.parent('td'));
        }
    }  
});

Ext.define('Ext.ux.TextButton', {
	extend: 'Ext.button.Button',
  cls: 'x-btn-textlink'
});
