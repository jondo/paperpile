Paperpile.HoverButtonPlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.HoverButtonPlugin, Ext.util.Observable, {
  baseCls: 'pp-hoverbutton',
  baseOverCls: 'pp-hoverbutton-over',
  cls: 'pp-hoverbutton-default',
  overCls: '',
  fn: null,
  scope: null,
  showButtonIf: null,

  init: function(treePanel) {
    Ext.apply(treePanel.loader, {
      baseAttrs: {
        uiProvider: Paperpile.HoverButtonTreeNodeUI
      }
    });
    treePanel.initEvents = treePanel.initEvents.createSequence(this.myInitEvents);
    treePanel.onRender = treePanel.onRender.createSequence(this.myOnRender);
    treePanel.hoverButtonPlugin = this;
  },

  // Called from the plugin scope.
  callFunction: function(node) {
    if (this.fn != null) {
      this.fn.defer(20, this.scope, [node]);      
    }
  },

  getClass: function() {
      return this.cls+" "+this.baseCls;
  },

  getOverClass: function() {
      return this.overCls+" "+this.baseOverCls;
  },

  // Called from the treePanel scope.
  myInitEvents: function() {
    var el = this.getTreeEl();
    //      el.on('mousedown', this.delegateClick, this);
    this.on('startdrag', function(panel, node, event) {
      // Once the drag has started, we hack into the Dom and hide the context triangle.
      var ghostDom = this.dragZone.proxy.ghost.dom;
      var ghostEl = Ext.fly(ghostDom);
      ghostEl.select('.' + this.hoverButtonPlugin.baseCls).remove();
    },
    this);

    this.dropZone.onNodeOver = this.dropZone.onNodeOver.createSequence(function() {
      this.tree.hoverButton.hide();
    });
    this.dropZone.onNodeOut = this.dropZone.onNodeOut.createSequence(function() {});

  },

  // Called from the treePanel scope.
  myOnRender: function() {
    this.hoverButton = Ext.DomHelper.append(this.getEl(), {
      id: this.id + "_hover_button",
      tag: "div",
      cls: this.hoverButtonPlugin.getClass()
    },
    true);
    this.hoverButton.addClassOnOver(this.hoverButtonPlugin.getOverClass());
  }
});

Paperpile.HoverButtonTreeNodeUI = Ext.extend(Ext.tree.TreeNodeUI, {
  onClick: function(e) {
    if (e.browserEvent.type == 'click') {
      if (!Ext.fly(e.getTarget()).hasClass(this.node.ownerTree.hoverButtonPlugin.baseCls)) {
        Paperpile.HoverButtonTreeNodeUI.superclass.onClick.call(this, e);
        return;
      }
    }

    if (e.button != 0) return;
    var el = Ext.fly(e.getTarget());
    // Intercept clicks on the button.
    if (el.hasClass(this.node.ownerTree.hoverButtonPlugin.baseCls)) {
      e.stopEvent();
      this.node.ownerTree.hoverButtonPlugin.callFunction(this.node);
      return;
    } else {
      this.node.ownerTree.hoverButton.removeClass(plugin.baseOverCls);
      this.node.ownerTree.hoverButton.hide();
    }
  },

  onOver: function(e) {
    var nodeEl = Ext.fly(this.getEl());
    var alignEl = nodeEl.child(".x-tree-node-el");
    if (this.node.ownerTree === null) return;

    var plugin = this.node.ownerTree.hoverButtonPlugin;

    // Call the showButtonIf function and exit if it returns false.
    if (plugin.showButtonIf !== null) {
      var result = plugin.showButtonIf.call(this.node, this.node);
      if (result === false) return;
    }

    var btn = this.node.ownerTree.hoverButton;
    alignEl.appendChild(btn);
    btn.alignTo(alignEl, 'r-r?', [-3, 0]);
    this.hideDelay.cancel();
    btn.show();
    Paperpile.HoverButtonTreeNodeUI.superclass.onOver.call(this, e);
  },

  onOut: function(e) {
    var nodeEl = this.getEl();
    if (this.node != null && this.node.ownerTree != null) {
      var btn = this.node.ownerTree.hoverButton;
      if (btn != null) {
        this.hideDelay.delay(20, this.hideButton, this, [btn]);
      }
    }
    Paperpile.HoverButtonTreeNodeUI.superclass.onOut.call(this, e);
  },

  hideDelay: new Ext.util.DelayedTask(),
  hideButton: function(btn) {
    btn.removeClass(this.node.ownerTree.hoverButtonPlugin.getOverClass());
    btn.hide();
  }

});