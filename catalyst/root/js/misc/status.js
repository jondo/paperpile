/* Copyright 2009, 2010 Paperpile

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

Paperpile.Status = Ext.extend(Ext.BoxComponent, {

  // Each status update is assigned a 'message number', which allows
  // us to uniquely identify messages. If you want to clear a specific message
  // once it's no longer useful (but avoid clearing other messages
  // that came up in the meantime), you should call the clearMessageNumber
  // method.
  messageNumber: 0,
  animConfig: {
    duration: 0.25,
    easing: 'easeOut'
  },
  scope: this,
  type: 'info',
  anchor: Ext.getBody(),
  callback: function(action) {
    //console.log(action);
  },

  initComponent: function() {
    Ext.apply(this, {
      renderTo: document.body,
      autoEl: {
        style: 'position: absolute',
        tag: 'div',
        cls: 'pp-status-line-container pp-status-' + this.type,
        children: [{
          tag: 'table',
          children: [{
            tag: 'tr',
            children: [{
              tag: 'td',
              id: 'status-msg',
              cls: 'pp-basic pp-status-msg',
            },
            {
              tag: 'td',
              children: [{
                id: 'status-action1',
                tag: 'a',
                href: '#',
                cls: 'pp-basic pp-textlink pp-status-action',
              }],
              //hidden: true,
            },
            {
              tag: 'td',
              children: [{
                id: 'status-action2',
                tag: 'a',
                href: '#',
                cls: 'pp-basic pp-textlink pp-status-action',
              }],
              //hidden: true,
            },
            {
              tag: 'td',
              id: 'status-busy',
              cls: 'pp-basic',
            },
            ]
          }]
        }]
      }
    });
    Paperpile.Status.superclass.initComponent.call(this);

  },

  afterRender: function() {
    Paperpile.Status.superclass.afterRender.apply(this, arguments);
    this.el.hide();
    //this.el.anchorTo(document.body, 't-t',[0,3]);
    this.msgEl = Ext.get('status-msg');
    this.action1el = Ext.get('status-action1');
    this.action2el = Ext.get('status-action2');
    this.busyEl = Ext.get('status-busy');

    this.msgEl.setVisibilityMode(Ext.Element.DISPLAY);
    this.action1el.setVisibilityMode(Ext.Element.DISPLAY);
    this.action2el.setVisibilityMode(Ext.Element.DISPLAY);
    this.busyEl.setVisibilityMode(Ext.Element.DISPLAY);

    this.action1el.on('click',
      function() {
        this.callback.createDelegate(this.scope, ['ACTION1'])();
      },
      this);

    this.action2el.on('click',
      function() {
        this.callback.createDelegate(this.scope, ['ACTION2'])();
      },
      this);

  },

  updateMsg: function(pars) {

    this.messageNumber++;

    var anim = false;
    if (pars.fade) {
      anim = this.animConfig;
    }
    if (pars.anim) {
      anim = pars.anim;
    }

    if (!this.el.isVisible()) {
      this.el.show(anim);
    }

    if (pars.type) {
      this.setType(pars.type);
    }

    if (pars.scope) {
      this.scope = pars.scope;
    }

    if (pars.msg) {
      Ext.DomHelper.overwrite(this.msgEl, pars.msg);
    } else {
      this.msgEl.hide();
    }

    if (pars.action1) {
      Ext.DomHelper.overwrite(this.action1el, pars.action1);
      this.action1el.show();
    } else {
      this.action1el.hide();
    }

    if (pars.action2) {
      Ext.DomHelper.overwrite(this.action2el, pars.action2);
      this.action2el.show();
    } else {
      this.action2el.hide();
    }

    if (pars.busy) {
      this.busyEl.addClass('pp-status-busy');
      this.busyEl.show();
    } else {
      this.busyEl.hide();
    }

    if (pars.duration) {
      var num = this.getMessageNumber();
      (function() {
        this.clearMessageNumber(num, anim);
      }).defer(pars.duration * 1000, this);
    }

    if (pars.hideOnClick) {
      var num = this.getMessageNumber();
      this.mon(Ext.getBody(), 'mousedown',
      function(e) {
        this.clearMessageNumber(num, anim);
      },
      this, {
        single: true
      });
      this.messageToHideOnClick = num;
    }

    if (pars.callback) {
      this.callback = pars.callback;
    }

    this.el.alignTo(Ext.getCmp('main-toolbar').getEl(), 't-t', [0, 3]);

    return this.getMessageNumber();
  },

  getMessageNumber: function() {
    return this.messageNumber;
  },

  clearMessageNumber: function(messageNumber, anim) {
    if (this.messageNumber == messageNumber) {
      this.clearMsg(anim);
    }
  },

  clearMsg: function(anim) {
    if (anim === true) {
      anim = this.animConfig;
    }
    this.el.hide(anim);
    // back to default
    this.setType('info');
    this.action1el.hide();
    this.action2el.hide();
  },

  showBusy: function(msg) {
    this.updateMsg({
      msg: msg,
      busy: true
    });
    return this.getMessageNumber();
  },

  setMsg: function(msg) {
    Ext.DomHelper.overwrite(this.msgEl, msg);
    this.el.alignTo(Ext.getCmp('main-toolbar').getEl(), 't-t', [0, 3]);
    return this.getMessageNumber();
  },

  setType: function(type) {
    this.el.replaceClass('pp-status-' + this.type, 'pp-status-' + type);
    this.type = type;
  }

});