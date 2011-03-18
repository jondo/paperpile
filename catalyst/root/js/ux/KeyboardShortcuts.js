Ext.define('Ext.ux.KeyboardShortcuts', {
  keyMap: null,
  bindings: [],
  constructor: function(listenerEl, config) {

    Ext.apply(this, {
      el: listenerEl
    });
    Ext.apply(this, config);

    if (this.disableOnBlur === undefined) {
      this.disableOnBlur = true;
    }

    this.keyMap = new Ext.util.KeyMap(this.el);

    if (this.disableOnBlur) {
      this.el.on('blur', this.onBlur, this);
      this.el.on('focus', this.onFocus, this);
    }

  },
  onBlur: function() {
    if (this.keyMap !== undefined) {
      this.keyMap.disable();
    }
  },
  onFocus: function() {
    if (this.keyMap !== undefined) {
      this.keyMap.enable();
    }
  },
  bindAction: function(string, action, stopEvent) {
    var obj = this.parseKeyString(string);

    if (stopEvent === undefined) {
      stopEvent = true;
    }

    var shortcut = new Ext.ux.KeyboardShortcut({
      action: action,
      binding: obj,
      stopEvent: stopEvent
    });

    var o = shortcut.binding;
    if (!o.shift) {
      delete o.shift;
    }
    if (!o.ctrl) {
      delete o.ctrl;
    }
    if (!o.alt) {
      delete o.alt;
    }

    this.keyMap.addBinding(shortcut.binding);
    this.bindings.push(shortcut);
  },
  bindCallback: function(string, handler, scope, stopEvent) {
    var obj = this.parseKeyString(string);

    if (scope === undefined) {
      scope = this;
    }

    if (stopEvent === undefined) {
      stopEvent = true;
    }

    obj.stopEvent = stopEvent;

    var shortcut = new Ext.ux.KeyboardShortcut({
      binding: obj,
      handler: handler,
      scope: scope,
      stopEvent: stopEvent
    });
    this.keyMap.addBinding(shortcut.binding);
  },
  isCtrl: function(token) {
    return Boolean(token.match(/(ctrl|control|ctl|meta)/));
  },
  isShift: function(token) {
    return Boolean(token.match(/(shift|shft)/));
  },
  isAlt: function(token) {
    return Boolean(token.match(/(alt)/));
  },
  ctrlString: function() {
    if (Paperpile.utils.isMac()) {
      return '⌘';
    } else {
      return 'Ctrl';
    }
  },
  shiftString: function() {
    return 'Shift';
  },
  altString: function() {
    return 'Alt';
  },
  shortcutAsString: function(obj) {
    var string = '';
    string += (obj.ctrl ? this.ctrlString() + '-' : '');
    string += (obj.alt ? this.altString() + '-' : '');
    string += (obj.shift ? this.shiftString() + '-' : '');

    var key = obj.keyString;
    if (key.length == 1) {
      key = key.toUpperCase();
    }
    string += (key);
    return string;
  },
  parseKeyString: function(string) {
    var key = '';
    var keyCode = -1;
    var ctrl = false;
    var shift = false;
    var alt = false;
    var tokens = string.split(/-/);
    for (var i = 0; i < tokens.length; i++) {
      if (i == tokens.length - 1) {
        // Always take the last item as the key.
        if (tokens[i].match(/\[.*\]/)) {
          // Use a custom format of [char,code] for non-canonical
          // characters and codes.
          var matches = /\[(.*),(.*)\]/.exec(tokens[i]);
          key = matches[1];
          keyCode = matches[2];
        } else {
          key = tokens[i];
        }
      } else {
        // Parse all other tokens as potential modifiers.
        var m = tokens[i];
        ctrl = ctrl || this.isCtrl(m);
        alt = alt || this.isAlt(m);
        shift = shift || this.isShift(m);
      }
    }
    if (keyCode == -1) {
      var upperKey = key.toUpperCase();
      var keyCode = Ext.EventObject[upperKey];
      if (Ext.EventObject[upperKey] === undefined) {
        Paperpile.log("Key " + upperKey + " not found! Using as keycode");
        keyCode = key;
      }
    }

    var shortcutObj = {
      key: [keyCode],
      keyString: key,
      ctrl: ctrl,
      shift: shift,
      alt: alt
    };
    shortcutObj.shortcutString = this.shortcutAsString(shortcutObj);
    return shortcutObj;
  },
  enable: function() {
    this.keyMap.enable();
  },
  disable: function() {
    this.keyMap.disable();
  },
  destroy: function() {
    this.keyMap.disable();
    this.keyMap = null;

    for (var i = 0; i < this.bindings.length; i++) {
      var shortcut = this.bindings[i];
      shortcut.destroy();
    }
    this.bindings = null;
  }
});

Ext.define('Ext.ux.KeyboardShortcut', {
  extend: 'Ext.util.Observable',
  action: null,
  binding: null,
  disabled: false,
  text: '',
  iconCls: '',
  visible: true,
  handler: null,
  scope: null,
  stopEvent: true,
  constructor: function(config) {
    Ext.ux.KeyboardShortcut.superclass.constructor.call(this, config);

    Ext.apply(this, config);

    this.binding.handler = this.handleAction;
    this.binding.scope = this;
    this.binding.stopEvent = this.stopEvent;

    if (this.action) {
      this.action.setShortcutString(this.binding.shortcutString);
      this.action.addComponent(this);
      this.itemId = 'shortcut-' + this.binding.shortcutString;
    }
  },
  handleAction: function(keyCode, event) {
    if (!this.disabled) {
      if (this.action) {
        this.action.execute(keyCode, event);
      } else if (this.handler) {
        this.handler.call(this.scope, event);
      }
    }
  },
  destroy: function() {
    this.action.removeComponent(this);
  },
  setDisabled: function(disabled) {
    this.disabled = disabled;
  },
  setText: function(text) {
    this.text = text;
  },
  setIconCls: function(cls) {
    this.iconCls = cls;
  },
  setVisible: function(vis) {
    this.visible = vis;
  },
  setHandler: function(handler, scope) {
    this.handler = handler;
    this.scope = scope;
  },

  setShortcutString: function(string) {}

});

Ext.override(Ext.Action, {
  setShortcutString: function(string) {
    var me = this;
    me.initialConfig.shortcutString = string;
    me.callEach('setShortcutString', [string]);
  }
});

Ext.override(Ext.menu.Item, {
  renderTpl: [
    '<tpl if="plain">',
    '{text}',
    '</tpl>',
    '<tpl if="!plain">',
    '<a class="' + Ext.baseCSSPrefix + 'menu-item-link" href="{href}" <tpl if="hrefTarget">target="{hrefTarget}"</tpl> hidefocus="true" unselectable="on">',
    '<img src="{icon}" class="' + Ext.baseCSSPrefix + 'menu-item-icon {iconCls}" />',
    '<span class="' + Ext.baseCSSPrefix + 'menu-item-text" <tpl if="menu">style="margin-right: 17px;"</tpl> >{text}</span>',
    '<div class="' + Ext.baseCSSPrefix + 'menu-item-shortcut">{shortcutString}</div>',
    '<tpl if="menu">',
    '<img src="' + Ext.BLANK_IMAGE_URL + '" class="' + Ext.baseCSSPrefix + 'menu-item-arrow" />',
    '</tpl>',
    '</a>',
    '</tpl>'],
  onRender: function(ct, pos) {
    var me = this,
    prefix = '.' + Ext.baseCSSPrefix;

    Ext.applyIf(me.renderData, {
      href: me.href || '#',
      hrefTarget: me.hrefTarget,
      icon: me.icon || Ext.BLANK_IMAGE_URL,
      iconCls: me.iconCls,
      menu: Ext.isDefined(me.menu),
      plain: me.plain,
      text: me.text,
      shortcutString: me.shortcutString
    });

    Ext.applyIf(me.renderSelectors, {
      itemEl: prefix + 'menu-item-link',
      iconEl: prefix + 'menu-item-icon',
      textEl: prefix + 'menu-item-text',
      arrowEl: prefix + 'menu-item-arrow',
      shortcutEl: prefix + 'menu-item-shortcut'
    });

    Ext.menu.Item.superclass.onRender.call(me, ct, pos);
  },

  setShortcutString: function(string) {
    var me = this;
    if (this.rendered) {
      if (this.shortcutEl) {
        this.shortcutEl.update(string);
      }
    }
    me.shortcutString = string;
  }
});