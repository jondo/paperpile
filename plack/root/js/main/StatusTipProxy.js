/* Copyright 2009-2011 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU Affero General Public License as
   published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Affero General Public License for more details.  You should have
   received a copy of the GNU Affero General Public License along with
   Paperpile.  If not, see http://www.gnu.org/licenses. */



// A drag'n'drop proxy with a status icon AND an information 'tip'.
Paperpile.StatusTipProxy = Ext.extend(Ext.dd.StatusProxy, {
  defaultTip: '',

  constructor: function(config) {
    Ext.apply(this, config);

    Paperpile.StatusTipProxy.superclass.constructor.call(this, config);

    this.el.appendChild(Ext.DomHelper.createDom({
      tag: 'div',
      cls: 'x-dd-drag-tip'
    }));
    this.tip = Ext.get(this.el.dom.childNodes[2]);
  },

  reset: function(clearGhost) {
    Paperpile.StatusTipProxy.superclass.reset.call(this, clearGhost);
    this.updateTip(this.defaultTip);
  },

  updateTip: function(tip) {
    if (!this.updateDT) {
      this.updateDT = new Ext.util.DelayedTask(this.updateTipDelay);
    }
    this.updateDT.delay(20, this.updateTipDelay, this, [tip]);
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