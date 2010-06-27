/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */

Ext.ns('Paperpile');
Paperpile.Status = Ext.extend(Ext.BoxComponent, {

  anim: false,
  scope: this,
  type: 'info',
    fixedPosition: false,
  anchor: Ext.getBody(),
  callback: function(action) {
    //console.log(action);
  },

  initComponent: function() {

    var style = {
      position: 'absolute',
      padding: '0px 10px',
      'z-index': 9001,
      '-webkit-border-radius': '3px',
    };
    if (this.type == 'info') {
      style['background-color'] = '#FFF1A8';
    } else if (this.type == 'error') {
      style['background-color'] = '#FFBABA';
    }
      if (this.fixedPosition) {
	  style['position'] = 'fixed';
      }

    Ext.apply(this, {
      renderTo: document.body,
      autoEl: {
        style: style,
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
              style: {
                'font-size': '12px',
                'font-weight': 'bold',
                'padding': '0px 5px'
              }
            },
            {
              tag: 'td',
              children: [{
                id: 'status-action1',
                tag: 'span',
                cls: 'pp-basic pp-textlink pp-status-action',
                style: {
                  'font-size': '12px',
                  'font-weight': 'bold',
                  'padding': '0px 5px'
                }
              }],
              //hidden: true,
            },
            {
              tag: 'td',
              children: [{
                id: 'status-action2',
                tag: 'span',
                cls: 'pp-basic pp-textlink pp-status-action',
                style: {
                  'font-size': '12px',
                  'font-weight': 'bold',
                  'padding': '0px 5px'
                }
              }],
              //hidden: true,
            },
            {
              tag: 'td',
              id: 'status-busy',
              cls: 'pp-basic',
              style: {
                'font-size': '12px',
                background: "transparent url('" + Paperpile.Url('/images/waiting_yellow.gif') + "') no-repeat",
                width: '16px'
              },
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
      function(event) {
        this.callback.createDelegate(this.scope, ['ACTION1'])();
      },
		      this,{preventDefault:true});

    this.action2el.on('click',
      function(event) {
        this.callback.createDelegate(this.scope, ['ACTION2'])();
      },
		      this,{preventDefault:true});

  },

  updateMsg: function(pars) {

    if (!this.el.isVisible()) {
      this.el.show(this.anim);
    }

    if (pars.type) {
      this.setType(pars.type);
    }

    if (pars.scope) {
      this.scope = pars.scope;
    }

    if (pars.msg) {
      this.msgEl.update(pars.msg);
    } else {
      this.msgEl.hide();
    }

    if (pars.action1) {
      this.action1el.update(pars.action1);
      this.action1el.show();
    } else {
      this.action1el.hide();
    }

    if (pars.action2) {
      this.action2el.update(pars.action2);
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
      (function() {
        this.clearMsg()
      }).defer(pars.duration * 1000, this);
    }

    if (pars.hideOnClick) {
      Ext.getBody().on('click',
        function(e) {
          this.clearMsg();
        },
        this, {
          single: true
        });
    }

    if (pars.callback) {
      this.callback = pars.callback;
    }

    this.align();

  },

  align: function() {
    var mainToolbar = Ext.getCmp('main-toolbar');
    if (mainToolbar !== undefined) {
      this.el.alignTo(mainToolbar.getEl(), 't-t', [0, 3]);
    } else {
      this.el.alignTo(Ext.getDoc(), 't-t', [0, 10]);
    }
  },

  clearMsg: function() {
    this.el.hide(this.anim);
    // back to default
    this.setType('info');
  },

  showBusy: function(msg) {
    this.updateMsg({
      msg: msg,
      busy: true
    });
  },

  setMsg: function(msg) {
    this.msgEl.update(msg);
    //    Ext.DomHelper.overwrite(this.msgEl, msg);
    //this.el.alignTo(Ext.getCmp('main-toolbar').getEl(), 't-t', [0, 3]);
    this.align();
  },

  setType: function(type) {
    this.el.replaceClass('pp-status-' + this.type, 'pp-status-' + type);
    this.type = type;
  }

});