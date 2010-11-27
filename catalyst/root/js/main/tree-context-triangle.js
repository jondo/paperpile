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

Paperpile.ContextTrianglePlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.ContextTrianglePlugin, Ext.util.Observable, {
  init: function(treePanel) {

    // Cause the treepanel to load up nodes with our extended UI subclass.
    treePanel.loader.baseAttrs = {
      uiProvider: 'Paperpile.ContextTreeNodeUI'
    };

    treePanel.positionTriangle = function(node) {
      node.ui.positionTriangle();
    };

    treePanel.eventContainsTriangle = function(e) {
      if (Ext.fly(e.getTarget('.pp-tree-context-triangle'))) {
        return true;
      } else {
        return false;
      }
    };

    treePanel.initEvents = treePanel.initEvents.createSequence(this.myInitEvents);
    treePanel.on('expandnode', this.myExpand, treePanel);
  },

  // This method is called from the TreePanel's scope, i.e. 'this' refers to the TreePanel, NOT this plugin object!
  myInitEvents: function() {
    var el = this.getTreeEl();

    // Remove the triangle from the dragged DOM when dragging starts.
    this.on('startdrag', function() {
      var ghostDom = this.dragZone.proxy.ghost.dom;
      var ghostEl = Ext.fly(ghostDom);
      ghostEl.select('.pp-tree-context-triangle').remove();
    },
    this);

    this.showMenu = function(menu, pos) {
      /*
         While a context menu is open, we store flags
         depending on where the user's mouse has gone to say whether to hide
         or show the triangle when the menu closes. Here is where those flags
         are acted upon.
        */
      var node = menu.node;
      menu.on('beforehide', function() {
        menu.node.unselect();
        var tri = this.contextTriangle;
        tri.removeClass('pp-tree-context-triangle-down');
        tri.removeClass('pp-tree-context-triangle-over');
        if (tri.shouldShowWhenMenuCloses) {
          this.positionTriangle(tri.currentHoverNode);
          tri.show();
        } else {
          tri.hide();
        }
      },
      this, {
        single: true
      });

      var tri = this.contextTriangle;
      tri.shouldShowWhenMenuCloses = true;

      if (Ext.isString(pos)) {
        // We get here when the triangle was clicked. Align the menu
        // to the triangle and show.
        menu.show(tri, pos);
      } else {
        // We get here on regular context menu events. Just move to
        // the indicated position, hide triangle and show menu.
        menu.showAt(pos);
        tri.hide();
      }
    };
  },

  myExpand: function(node) {
    // Only run this code once, when the root node loads.
    if (node.id == this.getRootNode().id) {

      // Create the context triangle object.
      this.contextTriangle = Ext.DomHelper.append(this.body, {
        id: this.itemId + "_context_triangle",
        tag: "div",
        cls: "pp-tree-context-triangle"
      },
        true);

      this.onTriangleClick = function(e, el, o) {
        e.stopPropagation();
        return;
      };

      this.onTriangleDown = function(e, el, o) {
        var node = this.eventModel.getNode(e);
        var menu = this.prepareMenu(node);
        if (menu != null) {
          var tri = this.contextTriangle;
          if (!menu.isVisible()) {
            tri.addClass('pp-tree-context-triangle-down');
            this.positionTriangle(node);
            this.showMenu(menu, 'tl-bl');
          } else {
            tri.removeClass('pp-tree-context-triangle-down');
            tri.removeClass('pp-tree-context-triangle-over');
            menu.hide();
          }
        }
        e.stopEvent();
      };

      this.onTriangleOver = function(e) {
        Ext.fly(this.contextTriangle).addClass('pp-tree-context-triangle-over');
      };
      this.onTriangleOut = function(e) {
        Ext.fly(this.contextTriangle).removeClass('pp-tree-context-triangle-over');
      };

      // Look different on hover.
      // Add a mousedown trigger (feels snappier than 'onclick').
      this.mon(this.contextTriangle, 'click', this.onTriangleClick, this);
      this.mon(this.contextTriangle, 'mousedown', this.onTriangleDown, this);
      this.mon(this.contextTriangle, 'mouseenter', this.onTriangleOver, this);
      this.mon(this.contextTriangle, 'mouseleave', this.onTriangleOut, this);
      this.contextTriangle.hide();
    }
  }
});

Paperpile.ContextTreeNodeUI = Ext.extend(Ext.tree.TreeNodeUI, {

  destroy: function() {
    var el = Ext.fly(this.elNode);
    Paperpile.ContextTreeNodeUI.superclass.destroy.call(this);
  },

  eventContainsTriangle: function(e) {
    return this.node.ownerTree.eventContainsTriangle(e);
  },

  onOver: function(e) {
    var tri = this.node.ownerTree.contextTriangle;

    tri.currentHoverNode = this.node;

    // If a menu is already showing, store this node and set a flag so the 
    // menu hide callback (defined above) knows to show the triangle over this node
    // when it closes.
    if (this.node.ownerTree.isContextMenuShowing() && this.hasContextMenu()) {
      tri.shouldShowWhenMenuCloses = true;
      return;
    }

    if (this.node.ownerTree.isContextMenuShowing() && this.node == tri.currentNode) {
      // If we're hovering over the node where the context menu is, we should
      // show the hover triangle if / when the menu closes.
      tri.shouldShowWhenMenuCloses = true;
    }

    if (this.hasContextMenu()) {
      // If this node has a context menu available, show the triangle.
      this.positionTriangle();
      tri.show();
    }

    Paperpile.ContextTreeNodeUI.superclass.onOver.call(this, e);
  },

  // Position the triangle relative to this node.
  positionTriangle: function() {
    var tri = this.node.ownerTree.contextTriangle;
    tri.currentNode = this.node;
    var nodeEl = Ext.fly(this.getEl());
    var alignEl = nodeEl.child(".x-tree-node-el");
    alignEl.appendChild(tri);
    tri.alignTo(alignEl, 'r-r?', [-3, 0]);
    tri.show();
  },

  // Does the TreePanel have a context menu for this node?
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
      var tree = this.node.ownerTree;
      var tri = tree.contextTriangle;
      if (tri != null && tri.isVisible() && !tree.isContextMenuShowing()) {
        // If a menu isn't showing, just hide the triangle.
        tri.hide();
      } else {
        // If a menu is already showing, keep the triangle visible but
        // set a flag to tell it to hide the triangle when closed.
        tri.shouldShowWhenMenuCloses = false;
      }
    }
    Paperpile.ContextTreeNodeUI.superclass.onOut.call(this, e);
  }
});