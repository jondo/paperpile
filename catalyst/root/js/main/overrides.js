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

// Ext overrides
// Add an option to not show the loading spinner for certain nodes.
Ext.override(Ext.tree.TreeNodeUI, {
  beforeLoad: function() {
    if (!this.node.silentLoad) {
      this.addClass("x-tree-node-loading");
    }
  },
  afterLoad: function() {
    if (!this.node.silentLoad) {
      this.removeClass("x-tree-node-loading");
    }
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

Ext.override(Ext.tree.AsyncTreeNode, {
  reload: function(callback, scope) {
    //Paperpile.log("Reload!");
    //this.collapse(false, false);
    //while (this.firstChild) {
    //  this.removeChild(this.firstChild).destroy();
    //}
    this.childrenRendered = false;
    this.loaded = false;
    if (this.isHiddenRoot()) {
      this.expanded = false;
    }
    this.expand(false, false, callback, scope);
  }
});

Ext.namespace("Ext.ux");
Ext.ux.clone = function(o) {
  if (!o || 'object' !== typeof o) {
    return o;
  }
  var c = '[object Array]' === Object.prototype.toString.call(o) ? [] : {};
  var p, v;
  for (p in o) {
    if (o.hasOwnProperty(p)) {
      v = o[p];
      if (v && 'object' === typeof v) {
        c[p] = Ext.ux.clone(v);
      }
      else {
        c[p] = v;
      }
    }
  }
  return c;
}; // eo function clone 
Ext.override(Ext.Component, {

  findParentByType: function(t) {
    if (!Ext.isFunction(t)) {
      return this.findParentBy(function(p) {
        return p.constructor.xtype === t;
      });
    }
    var p = this;
    do {
      p = p.ownerCt;
    } while (p != null && !(p instanceof t))
    return p;
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

Ext.override(Ext.Panel, {
  hideBbar: function() {
    this.bbar.setVisibilityMode(Ext.Element.DISPLAY);
    this.bbar.hide();
    this.syncSize();
    if (this.ownerCt) {
      this.ownerCt.doLayout();
    }
  },
  showBbar: function() {
    this.bbar.setVisibilityMode(Ext.Element.DISPLAY);
    this.bbar.show();
    this.syncSize();
    if (this.ownerCt) {
      this.ownerCt.doLayout();
    }
  }

});

Ext.override(Ext.ToolTip, {

  onShow: function() {
    Ext.ToolTip.superclass.onShow.call(this);
  },
  onHide: function() {
    Ext.ToolTip.superclass.onHide.call(this);
  }
});

Ext.override(Ext.grid.RowSelectionModel, {
  initEvents: function() {

    // Create an event which only fires after a selection is DONE changing in response
    // to a user interaction (i.e., when we shift-click to select 10 items, this only fires ONCE).
    this.addEvents('afterselectionchange');

    // Make the grid respond to click events.
    this.grid.on('rowclick', this.handleMouseDown, this);

    //    if (!this.grid.enableDragDrop && !this.grid.enableDrag) {
    this.grid.on('rowmousedown', this.handleMouseDown, this);
    //    }
    this.rowNav = new Ext.KeyNav(this.grid.getGridEl(), {
      'up': function(e) {
        this.keyNavMove(-1, e);
      },
      'down': function(e) {
        this.keyNavMove(1, e);
      },
      'pageDown': function(e) {
        var pageDistance = this.grid.getPageSize();
        this.keyNavMove(pageDistance, e);
      },
      'pageUp': function(e) {
        var pageDistance = this.grid.getPageSize();
        this.keyNavMove(-pageDistance, e);
      },
      'j': function(e) {
        this.keyNavMove(1, e);
      },
      'k': function(e) {
        this.keyNavMove(-1, e);
      },
      'n': function(e) {
        this.keyNavMove(1, e);
      },
      'p': function(e) {
        this.keyNavMove(-1, e);
      },
      scope: this
    });
    this.rowNav.keyToHandler['74'] = 'j';
    this.rowNav.keyToHandler['75'] = 'k';
    this.rowNav.keyToHandler['78'] = 'n';
    this.rowNav.keyToHandler['80'] = 'p';
    this.grid.getView().on({
      scope: this,
      refresh: this.onRefresh,
      rowupdated: this.onRowUpdated,
      rowremoved: this.onRemove
    });
  },
  keyNavMove: function(distance, e) {
    if (!e.shiftKey || this.singleSelect) {
      this.selectDistance(distance);
    } else if (this.last !== false && this.lastActive !== false) {
      var anchor = this.lastActive;
      var cursor = this.constraintToGrid(this.last + distance);
      this.selectRange(anchor, cursor);
      this.grid.getView().focusRow(cursor);
      this.last = cursor;
      this.lastActive = anchor;
    } else {
      Paperpile.log("Dunno waht to do, selecting first row!");
      this.selectFirstRow();
    }
    this.fireEvent('afterselectionchange', this);
  },
  constraintToGrid: function(value) {
    if (value < 0) {
      value = 0;
    }
    if (value >= this.grid.store.getCount()) {
      value = this.grid.store.getCount() - 1;
    }
    return value;
  },
  selectDistance: function(dist, keepExisting) {
    var cursor = this.constraintToGrid(this.last + dist);
    this.selectRow(cursor, keepExisting);
    this.grid.getView().focusRow(this.last);
    return true;
  },
  hasDistance: function(dist) {
    return (this.last !== false && (this.last + dist) < this.grid.store.getCount() && (this.last + dist) >= 0);
  },

  looksLikeDuplicateEvents: function(a, b) {
    if (a !== undefined && b !== undefined && a.type === b.type &&
      a.target === b.target &&
      a.ctrlKey === b.ctrlKey &&
      a.shiftKey === b.shiftKey &&
      a.source === b.source && a.browserEvent === b.browserEvent) {
      return true;
    } else {
      return false;
    }
  },
  cacheEvent: {},
  // private
  handleMouseDown: function(g, rowIndex, e) {
    //      Paperpile.log("down...");
    if (e.button !== 0 || this.isLocked()) {
      return;
    }

    // We cache a shallow copy of the most recent event and compare it to the current
    // event to avoid handling duplicate events.
    if (this.looksLikeDuplicateEvents(this.cacheEvent, e)) {
      return;
    }
    Ext.apply(this.cacheEvent, e); // Store the cache by applying the event's properties to a hash.
    var view = this.grid.getView();
    var isSelected = this.isSelected(rowIndex);
    var type = e.type;
    var ctrl = e.ctrlKey;
    var shift = e.shiftKey;
    if (shift) {
      if (type === 'mousedown' && !this.singleSelect && this.last !== false) {
        var last = this.last;
        this.selectRange(last, rowIndex, ctrl);
        this.last = last; // reset the cursor point.
        view.focusRow(rowIndex);
      }
    } else if (ctrl) {
      if (type === 'mousedown') {
        if (isSelected) {
          this.deselectRow(rowIndex);
        } else {
          this.selectRow(rowIndex, true);
          view.focusRow(rowIndex);
        }
      }
    } else {
      if (type === 'mousedown' && !isSelected) {
        this.selectRow(rowIndex, false);
        view.focusRow(rowIndex);
      } else {
        if (isSelected) {
          this.selectRow(rowIndex, false);
        }
      }
    }
    this.fireEvent('afterselectionchange', this);
    //      Paperpile.log("Done!");
  },

  selectFirstRow: function() {
    this.selectRow(0);
    this.fireEvent('afterselectionchange', this);
  },

  selectRow: function(index, keepExisting, preventViewNotify) {
    if (this.isLocked() || (index < 0 || index >= this.grid.store.getCount()) || (keepExisting && this.isSelected(index))) {
      return;
    }
    var r = this.grid.store.getAt(index);
    if (r && this.fireEvent('beforerowselect', this, index, keepExisting, r) !== false) {
      if (!keepExisting || this.singleSelect) {
        this.clearSelections();
      }
      this.selections.add(r);
      this.last = this.lastActive = index;
      if (!preventViewNotify) {
        this.grid.getView().onRowSelect(index);
      }
      this.fireEvent('rowselect', this, index, r);
      this.fireEvent('selectionchange', this);
      // Adding this here to always focus the view when the next row is selected -- TODO, check if this causes any unforeseen problems.
      this.grid.getView().focusRow(index);
    }
  },

  onRefresh: function() {
    this.suspendEvents();
    var ds = this.grid.store,
    index;
    var s = this.getSelections();
    this.clearSelections(true);
    for (var i = 0, len = s.length; i < len; i++) {
      var r = s[i];
      if ((index = ds.indexOfId(r.id)) != -1) {
        this.selectRow(index, true);
      }
    }
    this.resumeEvents();
    if (s.length != this.selections.getCount()) {
      this.fireEvent('selectionchange', this);
      this.fireEvent('afterselectionchange', this);
    }
  },

  selectAll: function() {
    if (this.isLocked()) {
      return;
    }
    this.clearSelections(true);
    for (var i = 0, len = this.grid.store.getCount(); i < len; i++) {
      this.selectRow(i, true);
    }
    this.fireEvent('afterselectionchange', this);
  },

  clearSelections: function(fast) {
    if (this.isLocked()) {
      return;
    }
    if (fast !== true) {
      var ds = this.grid.store;
      var s = this.selections;
      s.each(function(r) {
        this.deselectRow(ds.indexOfId(r.id));
      },
      this);
      s.clear();
    } else {
      this.selections.clear();
    }
    this.last = false;
    // DO NOT fire an 'afterselectionchange' event here!
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

// Allow dynamically change the root, should be included by default in next version
// http://extjs.com/forum/showthread.php?p=305958
Ext.override(Ext.tree.TreePanel, {
  initComponent: function() {
    Ext.tree.TreePanel.superclass.initComponent.call(this);

    if (!this.eventModel) {
      this.eventModel = new Ext.tree.TreeEventModel(this);
    }

    // initialize the loader
    var l = this.loader;
    if (!l) {
      l = new Ext.tree.TreeLoader({
        dataUrl: this.dataUrl
      });
    } else if (typeof l == 'object' && !l.load) {
      l = new Ext.tree.TreeLoader(l);
    }
    this.loader = l;

    this.nodeHash = {};

    /**
        * The root node of this tree.
        * @type Ext.tree.TreeNode
        * @property root
        */
    // setRootNode destroys the existing root, so remove it first.
    if (this.root) {
      var r = this.root;
      delete this.root;
      this.setRootNode(r);
    }

    this.addEvents(

    /**
            * @event append
            * Fires when a new child node is appended to a node in this tree.
            * @param {Tree} tree The owner tree
            * @param {Node} parent The parent node
            * @param {Node} node The newly appended node
            * @param {Number} index The index of the newly appended node
            */
      "append",
      /**
            * @event remove
            * Fires when a child node is removed from a node in this tree.
            * @param {Tree} tree The owner tree
            * @param {Node} parent The parent node
            * @param {Node} node The child node removed
            */
      "remove",
      /**
            * @event movenode
            * Fires when a node is moved to a new location in the tree
            * @param {Tree} tree The owner tree
            * @param {Node} node The node moved
            * @param {Node} oldParent The old parent of this node
            * @param {Node} newParent The new parent of this node
            * @param {Number} index The index it was moved to
            */
      "movenode",
      /**
            * @event insert
            * Fires when a new child node is inserted in a node in this tree.
            * @param {Tree} tree The owner tree
            * @param {Node} parent The parent node
            * @param {Node} node The child node inserted
            * @param {Node} refNode The child node the node was inserted before
            */
      "insert",
      /**
            * @event beforeappend
            * Fires before a new child is appended to a node in this tree, return false to cancel the append.
            * @param {Tree} tree The owner tree
            * @param {Node} parent The parent node
            * @param {Node} node The child node to be appended
            */
      "beforeappend",
      /**
            * @event beforeremove
            * Fires before a child is removed from a node in this tree, return false to cancel the remove.
            * @param {Tree} tree The owner tree
            * @param {Node} parent The parent node
            * @param {Node} node The child node to be removed
            */
      "beforeremove",
      /**
            * @event beforemovenode
            * Fires before a node is moved to a new location in the tree. Return false to cancel the move.
            * @param {Tree} tree The owner tree
            * @param {Node} node The node being moved
            * @param {Node} oldParent The parent of the node
            * @param {Node} newParent The new parent the node is moving to
            * @param {Number} index The index it is being moved to
            */
      "beforemovenode",
      /**
            * @event beforeinsert
            * Fires before a new child is inserted in a node in this tree, return false to cancel the insert.
            * @param {Tree} tree The owner tree
            * @param {Node} parent The parent node
            * @param {Node} node The child node to be inserted
            * @param {Node} refNode The child node the node is being inserted before
            */
      "beforeinsert",

      /**
            * @event beforeload
            * Fires before a node is loaded, return false to cancel
            * @param {Node} node The node being loaded
            */
      "beforeload",
      /**
            * @event load
            * Fires when a node is loaded
            * @param {Node} node The node that was loaded
            */
      "load",
      /**
            * @event textchange
            * Fires when the text for a node is changed
            * @param {Node} node The node
            * @param {String} text The new text
            * @param {String} oldText The old text
            */
      "textchange",
      /**
            * @event beforeexpandnode
            * Fires before a node is expanded, return false to cancel.
            * @param {Node} node The node
            * @param {Boolean} deep
            * @param {Boolean} anim
            */
      "beforeexpandnode",
      /**
            * @event beforecollapsenode
            * Fires before a node is collapsed, return false to cancel.
            * @param {Node} node The node
            * @param {Boolean} deep
            * @param {Boolean} anim
            */
      "beforecollapsenode",
      /**
            * @event expandnode
            * Fires when a node is expanded
            * @param {Node} node The node
            */
      "expandnode",
      /**
            * @event disabledchange
            * Fires when the disabled status of a node changes
            * @param {Node} node The node
            * @param {Boolean} disabled
            */
      "disabledchange",
      /**
            * @event collapsenode
            * Fires when a node is collapsed
            * @param {Node} node The node
            */
      "collapsenode",
      /**
            * @event beforeclick
            * Fires before click processing on a node. Return false to cancel the default action.
            * @param {Node} node The node
            * @param {Ext.EventObject} e The event object
            */
      "beforeclick",
      /**
            * @event click
            * Fires when a node is clicked
            * @param {Node} node The node
            * @param {Ext.EventObject} e The event object
            */
      "click",
      /**
            * @event checkchange
            * Fires when a node with a checkbox's checked property changes
            * @param {Node} this This node
            * @param {Boolean} checked
            */
      "checkchange",
      /**
            * @event dblclick
            * Fires when a node is double clicked
            * @param {Node} node The node
            * @param {Ext.EventObject} e The event object
            */
      "dblclick",
      /**
            * @event contextmenu
            * Fires when a node is right clicked. To display a context menu in response to this
            * event, first create a Menu object (see {@link Ext.menu.Menu} for details), then add
            * a handler for this event:<code><pre>
new Ext.tree.TreePanel({
    title: 'My TreePanel',
    root: new Ext.tree.AsyncTreeNode({
        text: 'The Root',
        children: [
            { text: 'Child node 1', leaf: true },
            { text: 'Child node 2', leaf: true }
        ]
    }),
    contextMenu: new Ext.menu.Menu({
        items: [{
            id: 'delete-node',
            text: 'Delete Node'
        }],
        listeners: {
            itemclick: function(item) {
                switch (item.id) {
                    case 'delete-node':
                        var n = item.parentMenu.contextNode;
                        if (n.parentNode) {
                            n.remove();
                        }
                        break;
                }
            }
        }
    }),
    listeners: {
        contextmenu: function(node, e) {
//          Register the context node with the menu so that a Menu Item's handler function can access
//          it via its {@link Ext.menu.BaseItem#parentMenu parentMenu} property.
            node.select();
            var c = node.getOwnerTree().contextMenu;
            c.contextNode = node;
            c.showAt(e.getXY());
        }
    }
});
</pre></code>
            * @param {Node} node The node
            * @param {Ext.EventObject} e The event object
            */
      "contextmenu",
      /**
            * @event beforechildrenrendered
            * Fires right before the child nodes for a node are rendered
            * @param {Node} node The node
            */
      "beforechildrenrendered",
      /**
             * @event startdrag
             * Fires when a node starts being dragged
             * @param {Ext.tree.TreePanel} this
             * @param {Ext.tree.TreeNode} node
             * @param {event} e The raw browser event
             */
      "startdrag",
      /**
             * @event enddrag
             * Fires when a drag operation is complete
             * @param {Ext.tree.TreePanel} this
             * @param {Ext.tree.TreeNode} node
             * @param {event} e The raw browser event
             */
      "enddrag",
      /**
             * @event dragdrop
             * Fires when a dragged node is dropped on a valid DD target
             * @param {Ext.tree.TreePanel} this
             * @param {Ext.tree.TreeNode} node
             * @param {DD} dd The dd it was dropped on
             * @param {event} e The raw browser event
             */
      "dragdrop",
      /**
             * @event beforenodedrop
             * Fires when a DD object is dropped on a node in this tree for preprocessing. Return false to cancel the drop. The dropEvent
             * passed to handlers has the following properties:<br />
             * <ul style="padding:5px;padding-left:16px;">
             * <li>tree - The TreePanel</li>
             * <li>target - The node being targeted for the drop</li>
             * <li>data - The drag data from the drag source</li>
             * <li>point - The point of the drop - append, above or below</li>
             * <li>source - The drag source</li>
             * <li>rawEvent - Raw mouse event</li>
             * <li>dropNode - Drop node(s) provided by the source <b>OR</b> you can supply node(s)
             * to be inserted by setting them on this object.</li>
             * <li>cancel - Set this to true to cancel the drop.</li>
             * <li>dropStatus - If the default drop action is cancelled but the drop is valid, setting this to true
             * will prevent the animated "repair" from appearing.</li>
             * </ul>
             * @param {Object} dropEvent
             */
      "beforenodedrop",
      /**
             * @event nodedrop
             * Fires after a DD object is dropped on a node in this tree. The dropEvent
             * passed to handlers has the following properties:<br />
             * <ul style="padding:5px;padding-left:16px;">
             * <li>tree - The TreePanel</li>
             * <li>target - The node being targeted for the drop</li>
             * <li>data - The drag data from the drag source</li>
             * <li>point - The point of the drop - append, above or below</li>
             * <li>source - The drag source</li>
             * <li>rawEvent - Raw mouse event</li>
             * <li>dropNode - Dropped node(s).</li>
             * </ul>
             * @param {Object} dropEvent
             */
      "nodedrop",
      /**
             * @event nodedragover
             * Fires when a tree node is being targeted for a drag drop, return false to signal drop not allowed. The dragOverEvent
             * passed to handlers has the following properties:<br />
             * <ul style="padding:5px;padding-left:16px;">
             * <li>tree - The TreePanel</li>
             * <li>target - The node being targeted for the drop</li>
             * <li>data - The drag data from the drag source</li>
             * <li>point - The point of the drop - append, above or below</li>
             * <li>source - The drag source</li>
             * <li>rawEvent - Raw mouse event</li>
             * <li>dropNode - Drop node(s) provided by the source.</li>
             * <li>cancel - Set this to true to signal drop not allowed.</li>
             * </ul>
             * @param {Object} dragOverEvent
             */
      "nodedragover");
    if (this.singleExpand) {
      this.on("beforeexpandnode", this.restrictExpand, this);
    }
  },

  setRootNode: function(node) {

    //      Already had one; destroy it.
    if (this.root) {
      this.root.destroy();
    }

    if (!node.render) { // attributes passed
      node = this.loader.createNode(node);
    }
    this.root = node;
    node.ownerTree = this;
    node.isRoot = true;
    this.registerNode(node);
    if (!this.rootVisible) {
      var uiP = node.attributes.uiProvider;
      node.ui = uiP ? new uiP(node) : new Ext.tree.RootTreeNodeUI(node);
    }

    //      If we had previously rendered a tree, rerender it.
    if (this.innerCt) {
      this.innerCt.update('');
      this.afterRender();
    }
    return node;
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

Ext.override(Ext.ProgressBar, {
  updateRange: function(low, high, text, animate) {
    this.progressBar.setStyle('position', 'relative');
    this.value = high || 0;
    if (text) {
      this.updateText(text);
    }
    if (this.rendered && !this.isDestroyed) {
      var x_low = Math.floor(low * this.el.dom.firstChild.offsetWidth + 1);
      var x_high = Math.ceil(high * this.el.dom.firstChild.offsetWidth + 1);
      var w = Math.ceil(x_high - x_low);
      if (w < 2) {
        x_low -= 1;
        x_high += 1;
        w += 2;
      }
      //            this.progressBar.setWidth(w, animate === true || (animate !== false && this.animate));
      this.progressBar.setWidth(w);
      this.progressBar.setX(this.el.getX() + x_low, animate === true || (animate !== false && this.animate));
      if (this.textTopEl) {
        //textTopEl should be the same width as the bar so overflow will clip as the bar moves
        this.textTopEl.removeClass('x-hidden').setWidth(w);
      }
    }
    this.fireEvent('update', this, high, text);
    return this;
  },

});

Ext.override(Ext.grid.GridPanel, {
  getPageSize: function() {
    var numRows = this.getStore().getCount();
    var totalHeight = this.getView().mainBody.getBox().height;
    var viewportSize = this.body.getBox().height;
    var numPages = totalHeight / viewportSize;

    var meanPageSize = Math.round(numRows / numPages);
    return meanPageSize;
  },
  getVisibleRows: function() {
    var visibleRows = [];
    var tbEl = this.getTopToolbar().getEl();
    var gridBox = this.body.getBox();
    var rowCount = this.getStore().getCount();
    for (var i = 0; i < rowCount; i++) {
      // Find the row element for this item.
      var row = Ext.fly(this.getView().getRow(i));
      // Look at the offset from this row to the toolbar element.
      var xy = row.getOffsetsTo(tbEl);
      if (xy[1] < 0) {
        // If we're above the toolbar, we're too high and out of view.
        continue;
      }
      if (xy[1] < gridBox.height) {
        // If we're less than the grid's box height below the toolbar, we're probably OK.
        visibleRows.push(i);
      }
    }
    return visibleRows;
  }
});