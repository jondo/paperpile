// A drag'n'drop proxy with a status icon AND an information 'tip'.
Paperpile.StatusTipProxy = Ext.extend(Ext.dd.StatusProxy, {
  defaultTip: '',

  constructor: function(config) {
    Ext.apply(this,config);

    Paperpile.StatusTipProxy.superclass.constructor.call(this,config);

    this.el.appendChild(Ext.DomHelper.createDom({tag: 'div', cls: 'x-dd-drag-tip'}));
    this.tip = Ext.get(this.el.dom.childNodes[2]);
  },

  reset: function(clearGhost) {
    Paperpile.StatusTipProxy.superclass.reset.call(this,clearGhost);
    this.updateTip(this.defaultTip);
  },

  updateTip: function(tip) {
    if (!this.updateDT) {
      this.updateDT = new Ext.util.DelayedTask(this.updateTipDelay);
    }
    this.updateDT.delay(20,this.updateTipDelay,this,[tip]);
  },

  updateTipDelay: function(tip) {
    if (tip && tip != '') {
      this.tip.show();
      this.tip.update(tip);
    } else {
      this.tip.hide();
    }
    this.sync();
  },

  getTip: function() {
    return this.tip;
  }

});