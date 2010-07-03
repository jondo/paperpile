Ext.ux.ButtonPlus = function(config) {
  config = config || {};
  if (config.initialConfig) {
    if (config.isAction) { // actions
      this.baseAction = config;
    }
    config = config.initialConfig; // component cloning / action set up
  } else if (config.tagName || config.dom || Ext.isString(config)) { // element object
    config = {
      applyTo: config,
      id: config.id || config
    };
  }
};

Ext.ux.ButtonPlus = Ext.extend(Ext.Panel, {
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

Ext.reg('buttonplus', Ext.ux.ButtonPlus);

Ext.ux.UnstyledButton = Ext.extend(Ext.Button, {
  cls: 'x-btn-plain'
});
Ext.reg('unstyledbutton', Ext.ux.UnstyledButton);
Ext.ux.SubtleButton = Ext.extend(Ext.Button, {
  cls: 'x-btn-subtle'
});
Ext.reg('subtlebutton', Ext.ux.SubtleButton);