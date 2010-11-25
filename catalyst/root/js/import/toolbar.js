Paperpile.ToolbarLayout = Ext.extend(Ext.layout.ToolbarLayout, {
  // private
  addComponentToMenu: function(m, c) {
    if (c instanceof Ext.Toolbar.Separator) {
      m.add('-');
    } else if (Ext.isFunction(c.isXType)) {
      if (c.isXType('splitbutton')) {
        m.add(this.createMenuConfig(c, true));
      } else if (c.isXType('button')) {
        m.add(this.createMenuConfig(c, !c.menu));
      } else if (c.isXType('buttongroup')) {
        c.items.each(function(item) {
          this.addComponentToMenu(m, item);
        },
        this);
      } else if (c.isXType('buttonplus')) {
        var bp = new Ext.ux.ButtonPlus(c);
        m.add(bp);
      }
    }
  },

  fitToSize: function(target) {
    // Mostly yoinked from the Ext source, Toolbar.js.
    // Changes are noted.
    if (this.container.enableOverflow === false) {
      return;
    }

    if (this.hiddenItems === undefined) {
      this.hiddenItems = [];
    }

    var tb = this.container;
    var items = this.container.items.items;
    var len = items.length;

    // Figure out if and where the menuBreak is set.
    var menuBreakIndex = -1;
    for (i = 0; i < len; i++) {
      var item = items[i];
      if (item.itemId == tb.menuBreakItemId) {
        menuBreakIndex = i;
      }
    }

    var width = target.dom.clientWidth,
    tableWidth = target.dom.firstChild.offsetWidth,
    clipWidth = width - this.triggerWidth,
    lastWidth = this.lastWidth || 0,

    hiddenItems = this.hiddenItems,
    hasHiddens = hiddenItems.length != 0,
    isLarger = width >= lastWidth;

    this.lastWidth = width;

    if (tableWidth > width || (hasHiddens && isLarger) || menuBreakIndex != -1 ) {
      var items = this.container.items.items,
      len = items.length,
      loopWidth = 0,
      item;

      for (var i = 0; i < len; i++) {
        item = items[i];
        if (!item.isFill) {
          loopWidth += this.getItemWidth(item);
          // Start hiding items at whichever comes first: the menuBreak item, or the natural overflow.
          if (loopWidth > clipWidth || i > menuBreakIndex) {
            if (! (item.hidden || item.xtbHidden)) {
              this.hideItem(item);
            }
          } else if (item.xtbHidden) {
            this.unhideItem(item);
          }
        }
      }
    }

    //test for number of hidden items again here because they may have changed above
    hasHiddens = hiddenItems.length != 0;

    if (hasHiddens) {
      this.initMore();

      if (!this.lastOverflow) {
        this.container.fireEvent('overflowchange', this.container, true);
        this.lastOverflow = true;
      }
    } else if (this.more) {
      this.clearMenu();
      this.more.destroy();
      delete this.more;

      if (this.lastOverflow) {
        this.container.fireEvent('overflowchange', this.container, false);
        this.lastOverflow = false;
      }
    }
  },

  /**
     * @private
     * Creates the expand trigger and menu, adding them to the <tr> at the extreme right of the
     * Toolbar table
     */
  initMore: function() {
    if (!this.more) {
      /**
             * @private
             * @property moreMenu
             * @type Ext.menu.Menu
             * The expand menu - holds items for every Toolbar item that cannot be shown
             * because the Toolbar is currently not wide enough.
             */
      this.moreMenu = new Ext.menu.Menu({
        ownerCt: this.container,
        listeners: {
          beforeshow: this.beforeMoreShow,
          scope: this
        }
      });

      /**
             * @private
             * @property more
             * @type Ext.Button
             * The expand button which triggers the overflow menu to be shown
             */
      this.more = new Ext.Button({
        iconCls: 'pp-toolbar-more-icon',
        cls: 'pp-toolbar-more',
        menu: this.moreMenu,
        ownerCt: this.container,
        tooltip: 'More tools and actions'
      });

      var td = this.insertCell(this.more, this.extrasTr, 100);
      this.more.render(td);
    }
  }
});

Paperpile.Toolbar = function(config) {
  Ext.apply(this, config);
  Paperpile.Toolbar.superclass.constructor.call(this);
};
Ext.extend(Paperpile.Toolbar, Ext.Toolbar, {
  menuBreakItemId: 'asdf',
  initComponent: function() {
    Ext.apply(this, {
      layout: new Paperpile.ToolbarLayout()
    });
    Paperpile.Toolbar.superclass.initComponent.call(this);
  }
});