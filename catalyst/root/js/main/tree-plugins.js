Paperpile.ContextTrianglePlugin = (function() {
  return {
    init: function(treePanel) {
      Ext.apply(treePanel.loader, {
        baseAttrs: {
          uiProvider: Paperpile.ContextTreeNodeUI
        }
      });
      treePanel.initEvents = treePanel.initEvents.createSequence(this.myInitEvents);
      treePanel.onRender = treePanel.onRender.createSequence(this.myOnRender);
      
    },

    myInitEvents: function() {
      var el = this.getTreeEl();
//      el.on('mousedown', this.delegateClick, this);

      this.on('startdrag', function() {
	var ghostDom = this.dragZone.proxy.ghost.dom;
	var ghostEl = Ext.fly(ghostDom);
	ghostEl.select('.pp-tree-context-triangle').remove();
      },this);

    },

    myOnRender: function() {
      this.contextTriangle = Ext.DomHelper.append(this.getEl(), {
        id: this.itemId + "_context_triangle",
        tag: "div",
        cls: "pp-tree-context-triangle"
      },
      true);
      this.contextTriangle.addClassOnOver('pp-tree-context-triangle-over');

    }    
  };
})();

Paperpile.ContextTreeNodeUI = Ext.extend(Ext.tree.TreeNodeUI, {
  menuShowing: false,
  lastContextedNode: null,
  onClick: function(e) {
    if (e.browserEvent.type == 'click') {
      if (!Ext.fly(e.getTarget()).hasClass('pp-tree-context-triangle')) {
        Paperpile.ContextTreeNodeUI.superclass.onClick.call(this, e);
        return;
      }
    }

    if (e.button != 0) return;

    var el = Ext.fly(e.getTarget());

    // Intercept clicks on the context trigger.
    if (el.hasClass('pp-tree-context-triangle')) {
      e.stopEvent();
      var tree = this.node.ownerTree;
      var menu = tree.getContextMenu(this.node);
      if (menu != null) {
        // If the context menu is already showing, hide it and return.
        // (this gives a nice toggle-able feel to the whole thing)
        if (tree.lastContextedNode == this.node) {
          menu.hide();
          tree.lastContextedNode = null;
          return;
        }

        menu.node = this.node;
        menu.show(tree.contextTriangle, 'tl-bl');
        this.menuShowing = true;
        tree.contextTriangle.addClass('pp-tree-context-triangle-down');
        tree.allowSelect = true;
        this.node.select();
        tree.lastContextedNode = this.node;
        tree.lastSelectedNode = this.node;
        menu.on('hide',
          function() {
            this.menuShowing = false;
            tree.contextTriangle.removeClass('pp-tree-context-triangle-down');
            tree.allowSelect = false;
          },
          this);
      }
      return;
    } else {
      this.node.ownerTree.contextTriangle.hide();
    }
  },

  onOver: function(e) {
    var nodeEl = Ext.fly(this.getEl());
    var alignEl = nodeEl.child(".x-tree-node-el");
    var tri = this.node.ownerTree.contextTriangle;
    if (this.hasContextMenu()) {
      alignEl.appendChild(tri);
      tri.alignTo(alignEl, 'r-r?', [-3, 0]);
      this.hideDelay.cancel();
      tri.show();
    }
    Paperpile.ContextTreeNodeUI.superclass.onOver.call(this, e);
  },

  hasContextMenu: function() {
    var tree = this.node.ownerTree;
    var menu = tree.getContextMenu(this.node);
    var items = menu.getShownItems(this.node);
    if (items.length == 0) return false;
    return true;
  },

  onOut: function(e) {
    var nodeEl = this.getEl();
    if (this.node != null) {
      var tri = this.node.ownerTree.contextTriangle;
      if (tri != null && !this.menuShowing) {
        this.hideDelay.delay(20, this.hideTriangle, this, [tri]);
      }
    }
    Paperpile.ContextTreeNodeUI.superclass.onOut.call(this, e);
  },

  hideDelay: new Ext.util.DelayedTask(),
  hideTriangle: function(tri) {
    tri.hide();
  }

});