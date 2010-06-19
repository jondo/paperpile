Ext.ux.ButtonPlus = Ext.extend(Ext.Panel, {
  defaults: {},
  layout: 'table',
  defaultType: 'menuitem',
  frame: true,
  shadow: false,
  border: false,
  baseCls: 'x-plain',
  cls: 'x-button-plus',
  internalDefaults: {},
  actionMode: 'container',
    hideOnClick:true,
  initComponent: function() {

    if (this.items.length > 1) {
      this.items[1].xtype = 'unstyledbutton';
    }

    Ext.ux.ButtonPlus.superclass.initComponent.call(this);

    this.on('afterlayout', this.onAfterLayout, this);
  },
  onRender: function(container, position) {
    Ext.ux.ButtonPlus.superclass.onRender.apply(this, arguments);
    if (this.ownerCt && this.ownerCt instanceof Ext.menu.Menu) {
      this.parentMenu = this.ownerCt;
    }

      this.items.each(function(item,index,length) {
	  item.on('click',this.onClick,this,[item]);
      },this);

  },
  onClick: function(item) {
      if (this.hideOnClick && this.parentMenu) {
	  this.parentMenu.hide.defer(10,this.parentMenu);
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
    Paperpile.log("Menu: " + this.parentMenu);

    var first = this.items.get(0);
    if (this.items.getCount() > 1) {
      var second = this.items.get(1);
      //second.doAutoWidth();
	//second.el.setWidth(16);
      var secondWidth = second.el.getWidth();
      var containerWidth = this.container.getWidth();
      var remainder = containerWidth - secondWidth;
      first.el.setWidth(remainder);
    }
  },

  enable: function() {
    Ext.ux.ButtonPlus.superclass.enable.call(this);

    this.items.each(function(item, index, length) {
      item.enable();
    });
  }

});

Ext.reg('buttonplus',Ext.ux.ButtonPlus);

Ext.ux.UnstyledButton = Ext.extend(Ext.Button, {
    cls: 'x-btn-plain'

});
Ext.reg('unstyledbutton',Ext.ux.UnstyledButton);