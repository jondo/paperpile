Ext.ux.KeyboardShortcuts = function(mainEl) {
  if (mainEl === undefined) {
    mainEl = document;
  }
  Ext.apply(this, {
    document: mainEl
  });
  Ext.ux.KeyboardShortcuts.constructor.call(this);
};
Ext.ux.KeyboardShortcuts = Ext.extend(Ext.util.Observable, {
  keyMap: null,
  bindings: [],
  constructor: function(config) {
    if (config === undefined) {
      config = {};
    }
    if (config.document === undefined) {
      config.document = document;
    }
    this.keyMap = new Ext.KeyMap(config.document);
    Ext.ux.KeyboardShortcuts.superclass.constructor.call(this, config);
  },
  bindAction: function(string, action) {
    var obj = this.parseKeyString(string);

    var shortcut = new Ext.ux.KeyboardShortcut({
      action: action,
      binding: obj
    });

    this.keyMap.addBinding(shortcut.binding);
    this.bindings.push(shortcut);
  },
  bindCallback: function(string, handler, scope) {
    var obj = this.parseKeyString(string);

    if (scope === undefined) {
      scope = this;
    }

    var shortcut = new Ext.ux.KeyboardShortcut({
      binding: obj,
      handler: handler,
      scope: scope
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
    return 'Ctrl';
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

    for (var i=0; i < this.bindings.length; i++) {
	var shortcut = this.bindings[i];
	shortcut.destroy();
    }
    this.bindings = null;
  }
});

Ext.ux.KeyboardShortcut = Ext.extend(Ext.util.Observable, {
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
    Ext.apply(this, config);
    Ext.ux.KeyboardShortcut.superclass.constructor.call(this, config);

    this.binding.handler = this.handleAction;
    this.binding.scope = this;
    this.binding.stopEvent = this.stopEvent;

    if (this.action) {
      this.action.addComponent(this);
      this.action.setShortcutString(this.binding.shortcutString);
      this.itemId = 'shortcut-' + this.binding.shortcutString;
    }
  },
  handleAction: function(keyCode, event) {
    if (!this.disabled) {
      if (this.action) {
        this.action.execute(keyCode, event);
      } else if (this.handler) {
        this.handler.call(this.scope);
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

});

Ext.override(Ext.Action, {
  addComponent: function(comp) {
    this.items.push(comp);
    comp.on('destroy', this.removeComponent, this);
    if (comp['setHandler']) {
      comp.setHandler(this.initialConfig.handler, this.initialConfig.scope);
    }
    if (comp['setText']) {
      comp.setText(this.initialConfig.text);
    }
    if (comp['setIconCls']) {
      comp.setIconCls(this.initialConfig.iconCls);
    }
    if (comp['setDisabled']) {
      comp.setDisabled(this.initialConfig.disabled);
    }
    if (comp['setVisible']) {
      comp.setVisible(!this.initialConfig.hidden);
    }
  },
  setShortcutString: function(string) {
    this.initialConfig.shortcutString = string;
    this.callEach('setShortcutString', [string]);
  },
  // private
  callEach: function(fnName, args) {
    var cs = this.items;
    for (var i = 0, len = cs.length; i < len; i++) {
      if (cs[i][fnName]) {
        cs[i][fnName].apply(cs[i], args);
      }
    }
  }
});


Ext.override(Ext.menu.Item, {
  onRender: function(container, position) {
    if (!this.itemTpl) {
      this.itemTpl = Ext.menu.Item.prototype.itemTpl = new Ext.XTemplate(
        '<a id="{id}" class="{cls}" hidefocus="true" unselectable="on" href="{href}"',
        '<tpl if="hrefTarget">',
        ' target="{hrefTarget}"',
        '</tpl>',
        '<img src="{icon}" class="x-menu-item-icon {iconCls}"/>',
        '<span class="x-menu-item-text">{text}</span>',
        '<div class="x-menu-item-shortcut">{shortcutString}</div>',
        '</a>');
    }
    var a = this.getTemplateArgs();
    this.el = position ? this.itemTpl.insertBefore(position, a, true) : this.itemTpl.append(container, a, true);
    this.iconEl = this.el.child('img.x-menu-item-icon');
    this.textEl = this.el.child('.x-menu-item-text');
    this.shortcutEl = this.el.child('.x-menu-item-shortcut');
    this.extraEl = this.el.child('.x-menu-item-extrabutton');
    if (!this.href) {
      this.mon(this.el, 'click', Ext.emptyFn, null, {
        preventDefault: true
      });
    }
    Ext.menu.Item.superclass.onRender.call(this, container, position);
  },
  getTemplateArgs: function() {
    return {
      id: this.id,
      cls: this.itemCls + (this.menu ? ' x-menu-item-arrow' : '') + (this.cls ? ' ' + this.cls : ''),
      href: this.href || '#',
      hrefTarget: this.hrefTarget,
      icon: this.icon || Ext.BLANK_IMAGE_URL,
      iconCls: this.iconCls || '',
      text: this.itemText || this.text || '&#160;',
      shortcutString: this.shortcutString || ''
    };
  },
  setShortcutString: function(string) {
    this.shortcutString = string;
    if (this.rendered) {
      this.shortcutEl.update(this.shortcutString);
      this.parentMenu.layout.doAutoSize();
    }
  }
});