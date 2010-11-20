
Ext.ns('Ext.ux.TDGi');

Ext.ux.TDGi.MenuKeyTrigger = Ext.extend(Object, {
  /**
   * @constructor
   * @param c
   */
  constructor: function(c) {
    c = c || {};
    this.initialConfig = c;
    Ext.apply(this, c);
  },
  init: function(p) {
    this.menu = p;
    p.on({
      scope: this,
      buffer: 110,
      destroy: this.onDestroy,
      show: {
        single: true,
        fn: this.onMenuRenderAttachKeyMap // attach the handler
      }
    });

    //focus the element
    //runs within the scope of the parent (menu);
    p.on('show', function(menu) {
      menu.el.focus();
    });
  },
  /**
   *  @private onDestroy clear data and detach listeners upon parent's destroy.
   */
  onDestroy: function() {
    this.keyMapkeys = null;
    this.menu = null;
    p.un({
      scope: this,
      keydown: this.onKeyMapKeyFire
    });
  },
  /**
   * @private onMenurenderAttachKeyMap Attaches the key listeners to the parent menu upon its render.
   * @param menu
   */
  onMenuRenderAttachKeyMap: function(menu) {
    this.keyMapKeys = this.compileKeys(menu);

    var keys = [];

    for (var key in this.keyMapKeys) {
      keys.push(key);
    }

    menu.mon(menu.el, {
      scope: this,
      keydown: this.onKeyMapKeyFire
    });

    menu.el.focus();
  },
  /**
   * @private compileKeys go through the list of items and create a map of menu items that contain
   * @param menu
   */
  compileKeys: function(menu) {
    var keys = {};

    var items = menu.items;
    items.each(function(item) {
      if (item.triggerKey) {
        keys[item.triggerKey.substr(0, 1).toUpperCase()] = item;

        item.setText(item.text);

      }

      if (item.menu && this.selfPropegate) {
        var plugin = new this.constructor(this.initialConfig);
        plugin.init(item.menu);

        // Activate the first item
        item.menu.on('show', this.activateFirstMenuItem);

      }
    },
    this);

    return keys;
  },

  /**
   * @param menu
   */
  activateFirstMenuItem: function(menu) {
    var menuItems = menu.items;

    if (menuItems.items.length > 0) {

      if (menuItems.items[0].activate) {
        menuItems.items[0].activate(true);
      }
    }

  },
  /**
   * @private onKeyMapKeyFire called when mapped keys are struck
   * @param e Ext.EventObject
   */
  onKeyMapKeyFire: function(e) {

    var charCode = e.getCharCode(),
    key = String.fromCharCode(charCode),
    item;

    if (this.activeItem && charCode == Ext.EventObject.ENTER) {
      if (this.activeItem.handler) {
        this.activeItem.onClick(e);
      }
      return;
    }

    if (item = this.keyMapKeys[key]) {
      /**
       * Deactivate all menu items.
       */
      this.menu.items.each(function(i) {
        if (i.deactivate) {
          i.deactivate();
        }
      });

      this.menu.activeItem = this.activeItem = item;
      /**
       * Key is pressed, activate item only if ENTER key is required
       */
      //            console.info(this.requireEnter)
      if (this.requireEnter) {
        item.activate(true);
        return;
      }
      /**
       * Key is pressed, automatically call onClick
       */
      else {
        if (item.handler) {
          item.onClick(e);
        }
        else if (item.menu) {
          item.activate(true);
        }
      }

      item.activate(true);
    }
    else {
      delete this.activeItem;
    }

  }
});

Ext.preg('ux.MenuKeyTrigger', Ext.ux.TDGi.MenuKeyTrigger);

// Ugly override to Ext.menu.Item to auto-underline hotkey when setText is called.
Ext.override(Ext.menu.Item, {
  setText: function(text) {
    this.text = text || '&#160;';
    if (this.rendered) {
      if (this.triggerKey) {
        if (this.text.match(new RegExp(this.triggerKey, 'i'))) {
          this.text = this.text.replace(new RegExp('(' + this.triggerKey + ')', 'i'), '<u>$1</u>');
        }
      }
      this.textEl.update(this.text);
      this.parentMenu.layout.doAutoSize();
    }
  }
});