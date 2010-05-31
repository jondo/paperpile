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

Paperpile.ContextTrianglePlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.ContextTrianglePlugin, Ext.util.Observable, {
  init: function(treePanel) {
    Ext.apply(treePanel.loader, {
      baseAttrs: {
        uiProvider: Paperpile.ContextTreeNodeUI
      }
    });

    treePanel.positionTriangle = function() {
      var tri = this.contextTriangle;
      var node = tri.lastOverNode;
      node.ui.positionTriangle();
    };

    treePanel.eventContainsTriangle = function(e) {
      if (Ext.fly(e.getTarget()).hasClass('pp-tree-context-triangle')) {
        return true;
      }
      return false;
    };

    treePanel.toggleContext = function(e, el, o) {
      var node = this.eventModel.getNode(e);
      var menu = this.getContextMenu(node);
      if (menu != null) {
        var tri = this.contextTriangle;
        if (!menu.isVisible()) {
          tri.addClass('pp-tree-context-triangle-down');
          this.onContextMenu(node, e);
        } else {
          menu.hide();
        }
      }
    };

    treePanel.initEvents = treePanel.initEvents.createSequence(this.myInitEvents);
    treePanel.onRender = treePanel.onRender.createSequence(this.myOnRender);
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

    // Unload the TreePanel's context menu callback:
    this.un('contextmenu', this.onContextMenu);
    // Create this plugin's version of the function:
    this.onContextMenu = function(node, e) {
      var menu = this.getContextMenu(node);

      if (menu != null && menu.getShownItems(node).length > 0) {

        /*
         While a context menu is open, we store flags
         depending on where the user's mouse has gone to say whether to hide
         or show the triangle when the menu closes. Here is where those flags
         are acted upon.
        */
        menu.on('beforehide', function() {
          menu.node.unselect();
          var tri = this.contextTriangle;
          tri.removeClass('pp-tree-context-triangle-down');
          if (tri.shouldHideWhenMenuCloses) {
            tri.hide();
          }
          if (tri.shouldShowWhenMenuCloses) {
            this.positionTriangle();
            tri.show();
          }
          tri.shouldHideWhenMenuCloses = false;
          tri.shouldShowWhenMenuCloses = false;
        },
        this, {
          single: true
        });

        // Cause this TreeNode to be selected.
        this.allowSelect = true;
        node.select();
        this.allowSelect = false;

        // Initialize and show the context menu.
        menu.setNode(node);
        menu.render();
        menu.hideItems();

        var tri = this.contextTriangle;
        if (this.eventContainsTriangle(e)) {
          menu.show(tri, 'tl-bl');
          tri.shouldShowWhenMenuCloses = true;
          tri.lastOverNode = node;
        } else {
          menu.showAt(e.getXY());
          tri.hide();
        }

        if (node.type == 'FOLDER') {
          this.createAutoExportTip(menu);
        }
      }
    };
    // Add a callback for our new version of the onContextMenu function:
    this.on({
      contextmenu: {
        scope: this,
        fn: this.onContextMenu,
        stopEvent: true
      }
    });

  },

  // This method is also called from the TreePanel's scope.
  myOnRender: function() {
    // Create the context triangle object.
    this.contextTriangle = Ext.DomHelper.append(this.body, {
      id: this.itemId + "_context_triangle",
      tag: "div",
      cls: "pp-tree-context-triangle"
    },
      true);

    // Look different on hover.
    this.contextTriangle.addClassOnOver('pp-tree-context-triangle-over');
    // Add a mousedown trigger (feels snappier than 'onclick').
    this.contextTriangle.on('mousedown', this.toggleContext, this);
    this.contextTriangle.hide();
  }
});

Paperpile.ContextTreeNodeUI = Ext.extend(Ext.tree.TreeNodeUI, {

  eventContainsTriangle: function(e) {
    return this.node.ownerTree.eventContainsTriangle(e);
  },

  // Capture any click events that fall on the triangle.
  onDblClick: function(e) {
    if (!this.eventContainsTriangle(e)) {
      Paperpile.ContextTreeNodeUI.superclass.onClick.call(this, e);
    } else {
      e.stopEvent();
    }
  },
  onClick: function(e) {
    if (!this.eventContainsTriangle(e)) {
      Paperpile.ContextTreeNodeUI.superclass.onClick.call(this, e);
    } else {
      e.stopEvent();
    }
  },

  onOver: function(e) {
    var tri = this.node.ownerTree.contextTriangle;

    // If a menu is already showing, store this node and set a flag so the 
    // menu hide callback (defined above) knows to show the triangle over this node
    // when it closes.
    if (this.node.ownerTree.isContextMenuShowing() && this.hasContextMenu()) {
      tri.shouldShowWhenMenuCloses = true;
      tri.shouldHideWhenMenuCloses = false;
      tri.lastOverNode = this.node;
      return;
    }

    // Everything looks OK, just show the triangle.
    if (this.hasContextMenu()) {
      this.positionTriangle();
      tri.show();
    }

    Paperpile.ContextTreeNodeUI.superclass.onOver.call(this, e);
  },

  // Position the triangle relative to this node.
  positionTriangle: function() {
    var tri = this.node.ownerTree.contextTriangle;
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
        tri.hide();
      } else {
        // If a menu is already showing, set a flag to tell it to hide the triangle
        // when closed.
        tri.shouldHideWhenMenuCloses = true;
        tri.shouldShowWhenMenuCloses = false;
      }
    }
    Paperpile.ContextTreeNodeUI.superclass.onOut.call(this, e);
  },
});