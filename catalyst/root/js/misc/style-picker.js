// Modified Ext.menu.ColorMenu 
Paperpile.StylePicker = function(config) {
  Paperpile.StylePicker.superclass.constructor.call(this, config);
  this.addEvents(
    'select');

  if (this.handler) {
    this.on("select", this.handler, this.scope, true);
  }
};

Ext.extend(Paperpile.StylePicker, Ext.Component, {
  itemCls: "x-color-palette",
  value: null,
  clickEvent: 'click',
  ctype: "Paperpile.StylePicker",
  allowReselect: false,

  onRender: function(container, position) {

    var numbers = [];

    for (i = 0; i < 24; i++) {
      numbers.push(i);
    }

    var t = this.tpl || new Ext.XTemplate(
      '<tpl for="."><div class="pp-tag-style-sample pp-tag-style-{.}"><span unselectable="on">Label</span></div></tpl>');
    var el = document.createElement("div");
    el.id = this.getId();
    el.className = 'pp-tag-style-picker';
    t.overwrite(el, numbers);
    container.dom.insertBefore(el, position);
    this.el = Ext.get(el);
    this.mon(this.el, this.clickEvent, this.handleClick, this, {
      delegate: "div"
    });
    if (this.clickEvent != 'click') {
      this.mon(this.el, 'click', Ext.emptyFn, this, {
        delegate: "div",
        preventDefault: true
      });
    }
  },

  afterRender: function() {
    Paperpile.StylePicker.superclass.afterRender.call(this);
    if (this.value) {
      var s = this.value;
      this.value = null;
      this.select(s);
    }
  },

  handleClick: function(e, t) {
    e.preventDefault();
    if (!this.disabled) {
      var number = t.className.match(/pp-tag-style-(\d+)/)[1];
      this.select(number);
    }
  },
  select: function(number) {
    this.value = number;
    this.fireEvent("select", this, number);
  }

});

Ext.reg('colorpalette', Paperpile.StylePicker);

Paperpile.StylePickerMenu = Ext.extend(Ext.menu.Menu, {
  hideOnClick: true,
  enableScrolling: false,

  initComponent: function() {
    Ext.apply(this, {
      plain: true,
      showSeparator: false,
      items: this.palette = new Paperpile.StylePicker(this.initialConfig)
    });
    this.palette.purgeListeners();
    Paperpile.StylePickerMenu.superclass.initComponent.call(this);
    this.relayEvents(this.palette, ["select"]);
    this.on('select', this.menuHide, this);
    if (this.handler) {
      this.on('select', this.handler, this.scope || this);
    }
  },

  menuHide: function() {
    if (this.hideOnClick) {
      this.hide(true);
    }
  }
});