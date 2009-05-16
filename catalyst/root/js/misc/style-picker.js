// Modified Ext.menu.ColorMenu 

Paperpile.StylePicker = function(config){
    Paperpile.StylePicker.superclass.constructor.call(this, config);
    this.addEvents(
        'select'
    );

    if(this.handler){
        this.on("select", this.handler, this.scope, true);
    }
};
Ext.extend(Paperpile.StylePicker, Ext.Component, {
    itemCls : "x-color-palette",
    value : null,
    clickEvent:'click',
    ctype: "Paperpile.StylePicker",
    allowReselect : false,
  
    onRender : function(container, position){

        var numbers=[];

        for (i=0; i<24; i++){
            numbers.push(i);
        }

        var t = this.tpl || new Ext.XTemplate(
            '<tpl for="."><div class="pp-tag-style-sample pp-tag-style-{.}"><span unselectable="on">a</span></div></tpl>');
        var el = document.createElement("div");
        el.className = 'pp-tag-style-picker';
        t.overwrite(el, numbers);
        container.dom.insertBefore(el, position);
        this.el = Ext.get(el);
        this.el.on(this.clickEvent, this.handleClick,  this, {delegate: "div"});
        if(this.clickEvent != 'click'){
            this.el.on('click', Ext.emptyFn,  this, {delegate: "div", preventDefault:true});
        }
    },

    afterRender : function(){
        Paperpile.StylePicker.superclass.afterRender.call(this);
        if(this.value){
            var s = this.value;
            this.value = null;
            this.select(s);
        }
    },

    handleClick : function(e, t){
        e.preventDefault();
        if(!this.disabled){
            var number = t.className.match(/pp-tag-style-(\d+)/)[1];
            this.select(number);
        }
    },
    select : function(number){
        this.value = number;
        this.fireEvent("select", this, number);
    }

});
Ext.reg('colorpalette', Paperpile.StylePicker);

Paperpile.StylePickerMenu = function(config){
    Paperpile.StylePickerMenu.superclass.constructor.call(this, config);
    this.plain = true;
    var ci = new Paperpile.StyleItem(config);
    this.add(ci);
    this.palette = ci.palette;
    this.relayEvents(ci, ["select"]);
};

Ext.extend(Paperpile.StylePickerMenu, Ext.menu.Menu);

Paperpile.StyleItem = function(config){
    Paperpile.StyleItem.superclass.constructor.call(this, new Paperpile.StylePicker(config), config);
    this.palette = this.component;
    this.relayEvents(this.palette, ["select"]);
    if(this.selectHandler){
        this.on('select', this.selectHandler, this.scope);
    }
};

Ext.extend(Paperpile.StyleItem, Ext.menu.Adapter);
