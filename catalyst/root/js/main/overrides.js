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

// Ext overrides
/**
 *  * Clone Function
 *  * @param {Object/Array} o Object or array to clone
 *  * @return {Object/Array} Deep clone of an object or an array
 *  * @author Ing. Jozef Sakáloš
 *  */
Ext.ns('Ext.ux.util');
Ext.ux.util.clone = function(o) {
  if (!o || 'object' !== typeof o) {
    return o;
  }
  if ('function' === typeof o.clone) {
    return o.clone();
  }
  var c = '[object Array]' === Object.prototype.toString.call(o) ? [] : {};
  var p, v;
  for (p in o) {
    if (o.hasOwnProperty(p)) {
      v = o[p];
      if (v && 'object' === typeof v) {
        c[p] = Ext.ux.util.clone(v);
      }
      else {
        c[p] = v;
      }
    }
  }
  return c;
}; // eo function clone  

// Allow the autoScroll property to set the x- and y- scrollbars independently.
// http://www.brunildo.org/test/Overflowxy2.html and http://www.w3.org/TR/css3-box/#overflow-x
Ext.override(Ext.Component, {

  setAutoScroll: function(scroll) {
    if (this.rendered) {
      if (Ext.isString(scroll)) {
        if (scroll.toLowerCase().match('x')) {
          this.getContentTarget().setStyle({
            'overflow-x': 'auto'
          });
        } else {
          this.getContentTarget().setStyle({
            'overflow-x': 'hidden'
          });
        }
        if (scroll.toLowerCase().match('y')) {
          this.getContentTarget().setStyle({
            'overflow-y': 'auto'
          });
        } else {
          this.getContentTarget().setStyle({
            'overflow-y': 'hidden'
          });
        }
      } else {
        this.getContentTarget().setOverflow(scroll ? 'auto' : '');
      }
    }
    this.autoScroll = scroll;
    return this;
  }

});

Ext.override(Ext.grid.GridView, {

  // Implement a more sensible check for whether a gridview has 
  // rows at the moment. This allows us to have 'empty' content
  // within the GridView without it thinking that it has rows 
  // in view.
  hasRows: function() {
    return (this.grid.getStore().getCount() > 0);
    var fc = this.mainBody.dom.firstChild;
    return fc && fc.nodeType == 1 && fc.className != 'x-grid-empty';
  }
});


// Takes care of "this.lastOverNode.ui is null" bugs.
// See http://www.extjs.com/forum/showthread.php?t=85052
Ext.override(Ext.tree.TreeEventModel, {
  trackExit: function(e) {
    if (this.lastOverNode) {
      if (this.lastOverNode.ui && !e.within(this.lastOverNode.ui.getEl())) {
        this.onNodeOut(e, this.lastOverNode);
      }
      delete this.lastOverNode;
      Ext.getBody().un('mouseover', this.trackExit, this);
      this.trackingDoc = false;
    }
  },
  beforeEvent: function(e) {
    var node = this.getNode(e);
    if (this.disabled || !node || !node.ui) {
      e.stopEvent();
      return false;
    }
    return true;
  }
});

Ext.override(Ext.tree.TreeNode, {
  removeChild: function(node, destroy) {
    this.ownerTree.getSelectionModel().unselect(node);
    Ext.tree.TreeNode.superclass.removeChild.apply(this, arguments);
    // if it's been rendered remove dom node
    if (node.ui && node.ui.rendered) {
      node.ui.remove();
    }
    if (this.childNodes.length < 1) {
      this.collapse(false, false);
    } else {
      this.ui.updateExpandIcon();
    }
    if (!this.firstChild && !this.isHiddenRoot()) {
      this.childrenRendered = false;
    }
    return node;
  }
});

Ext.override(Ext.tree.TreeLoader, {
  clearOnLoad: false,
  processResponse: function(response, node, callback, scope) {
    var json = response.responseText;
    try {
      var o = response.responseData || Ext.decode(json);
      node.beginUpdate();
      for (var i = 0, len = o.length; i < len; i++) {
        var n = this.createNode(o[i]);
        var existingNode = node.findChild('text', n.text);
        if (existingNode) {
          node.removeChild(existingNode);
        }
        if (n) {
          node.appendChild(n);
        }
      }
      node.endUpdate();
      this.runCallback(callback, scope || node, [node]);
    } catch(e) {
      this.handleFailure(response);
    }
  }
});

Ext.override(Ext.form.Field, {
  hideItem: function() {
    this.formItem = Ext.Element(this.getEl()).findParent('.x-form-item', 4);
    this.formItem.addClass('x-hide-' + this.hideMode);
  },

  showItem: function() {
    this.formItem = Ext.Element(this.getEl()).findParent('.x-form-item', 4);
    this.formItem.removeClass('x-hide-' + this.hideMode);
  },
  setFieldLabel: function(text) {
    var ct = this.el.findParent('div.x-form-item', 4, true);
    //console.log(this.el, ct);
    var label = ct.first('label.x-form-item-label');
    label.update(text);
  }
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
  setTooltip: function(string) {
    this.initialConfig.tooltip = string;
    this.callEach('setTooltip', [string]);
  },
  setDisabledTooltip: function(string) {
    this.initialConfig.tooltip = string;
    this.callEach('setDisabledTooltip', [string]);
  },
  setDisabled: function(v) {
    this.initialConfig.disabled = v;
    this.callEach('setDisabled', [v]);
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

Ext.override(Ext.menu.BaseItem, {
  // private
  onRender: function(container, position) {
    Ext.menu.BaseItem.superclass.onRender.apply(this, arguments);
    if (this.ownerCt && this.ownerCt instanceof Ext.menu.Menu) {
      this.parentMenu = this.ownerCt;
    } else {
      this.container.addClass('x-menu-list-item');
      this.mon(this.el, {
        scope: this,
        click: this.onClick,
        mouseenter: this.activate,
        mouseleave: this.deactivate
      });
    }
    if (this.tooltip && this.parentMenu && !this.parentMenu.hideTooltips) {
      this.el.dom['qtip'] = this.tooltip;
    }
  },
  setDisabledTooltip: function(tooltip) {
    this.disabledTooltip = tooltip;
    if (this.rendered && this.disabled) {
      this.el.dom['qtip'] = tooltip;
    }
  },
  setTooltip: function(tooltip) {
    this.tooltip = tooltip;
    if (this.rendered && !this.disabled && this.parentMenu && !this.parentMenu.hideTooltips) {
      this.el.dom['qtip'] = tooltip;
    }
  },
  onDisable: function() {
    Ext.menu.BaseItem.superclass.onDisable.call(this);

    if (this.rendered) {
      this.el.dom['qtip'] = this.disabledTooltip || '';
    }
  },
  onEnable: function() {
    Ext.menu.BaseItem.superclass.onEnable.call(this);

    if (this.rendered && this.parentMenu && !this.parentMenu.hideTooltips) {
      this.el.dom['qtip'] = this.tooltip || '';
    } else {
      this.el.dom['qtip'] = '';
    }

  }
});

// Avoid scrolling to top if 'holdPosition" is given
// from: http://extjs.com/forum/showthread.php?t=13898
// GJ 2010-01-03 I changed this to always avoid scrolling to top... we can
// manually scroll to top if needed, but usually it's better to avoid the 
// visual disruption.
Ext.override(Ext.grid.GridView, {

  //    holdPosition: false,
  onLoad: function() {
    //        if (!this.holdPosition) this.scrollToTop();
    //        this.holdPosition = false;
  }
});

// The following enables the anchoring of quicktips.
// Taken from the ExtJS forums: http://www.sencha.com/forum/archive/index.php/t-100737.html
Ext.override(Ext.QuickTip, {

  onTargetOver: function(e) {
    if (this.disabled) {
      return;
    }
    this.targetXY = e.getXY();
    var t = e.getTarget();
    if (!t || t.nodeType !== 1 || t == document || t == document.body) {
      return;
    }
    if (this.activeTarget && ((t == this.activeTarget.el) || Ext.fly(this.activeTarget.el).contains(t))) {
      this.clearTimer('hide');
      this.show();
      return;
    }
    if (t && this.targets[t.id]) {
      this.activeTarget = this.targets[t.id];
      this.activeTarget.el = t;
      this.anchor = this.activeTarget.anchor || this.anchor;
      this.origAnchor = this.anchor;
      if (this.anchor) {
        this.anchorTarget = t;
      }
      this.delayShow();
      return;
    }
    var ttp, et = Ext.fly(t),
    cfg = this.tagConfig,
    ns = cfg.namespace;
    if (ttp = this.getTipCfg(e)) {
      var autoHide = et.getAttribute(cfg.hide, ns);
      this.activeTarget = {
        el: t,
        text: ttp,
        width: et.getAttribute(cfg.width, ns),
        autoHide: autoHide != "user" && autoHide !== 'false',
        title: et.getAttribute(cfg.title, ns),
        cls: et.getAttribute(cfg.cls, ns),
        align: et.getAttribute(cfg.align, ns)

      };
      this.anchor = et.getAttribute(cfg.anchor, ns);
      this.origAnchor = this.anchor;
      if (this.anchor) {
        this.anchorTarget = t;
      }
      this.delayShow();
    }
  }
});

Ext.override('Ext.form.Text', {
	showEmptyTextWithFocus: true,
    applyEmptyText : function(){
        var me = this,
            emptyText = me.emptyText;

        if (me.rendered && emptyText) {
            if (Ext.supports.Placeholder) {
                me.inputEl.dom.placeholder = emptyText;
            }
            else if (me.getRawValue().length < 1 && (!me.hasFocus || me.showEmptyTextWithFocus)) {
                me.setRawValue(emptyText);
                me.inputEl.addCls(me.emptyCls);
            }

            me.autoSize();
        }
    },

    });