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

Paperpile.PluginButton = Ext.extend(Ext.Button, {
  height: 20,
  width: 20
});

Paperpile.PluginOrderPanel = Ext.extend(Ext.Container, {

  settingsPanel: null,
  settingName: 'search_seq',
  tempSettingValue: null,
  origValue: null,

  initComponent: function() {
    this.origValue = Paperpile.main.getSetting(this.settingName);
    this.tempSettingValue = Paperpile.main.getSetting(this.settingName);

    var usedConfig = {
      cls: 'pp-pluginlist pp-pluginlist-used'
    };
    this.usedPlugins = this.createPluginOrderTreePanel(usedConfig);
    this.usedPlugins.initEvents = this.usedPlugins.initEvents.createSequence(function() {
      this.usedPlugins.dragZone.onBeforeDrag = this.usedPlugins.dragZone.onBeforeDrag.createInterceptor(function(data, e) {
        if (this.usedPlugins.getRootNode().childNodes.length == 1) {
          if (data.node) {
            data.node.draggable = false;
          }
        }
      },
      this);
    },
    this);

    var availableConfig = {
      cls: 'pp-pluginlist',
      listeners: {
        'dblclick': {
          // Move plugins to the 'used' column if double-clicked.
          fn: function(node, event) {},
          scope: this
        }
      }
    };
    this.availablePlugins = this.createPluginOrderTreePanel(availableConfig);

    this.actions = {};
    this.actions['BUTTON_UP'] = new Paperpile.PluginButton({
      itemId: 'BUTTON_UP',
      icon: '/images/icons/up.png',
      handler: this.moveUp,
      scope: this
    });
    this.actions['BUTTON_DOWN'] = new Paperpile.PluginButton({
      itemId: 'BUTTON_DOWN',
      icon: '/images/icons/down-small.png',
      handler: this.moveDown,
      scope: this
    });
    this.actions['BUTTON_LEFT'] = new Paperpile.PluginButton({
      itemId: 'BUTTON_LEFT',
      icon: '/images/icons/back.png',
      handler: this.switchSelected,
      scope: this
    });
    this.actions['BUTTON_RIGHT'] = new Paperpile.PluginButton({
      itemId: 'BUTTON_RIGHT',
      icon: '/images/icons/next.png',
      handler: this.switchSelected,
      scope: this
    });

    Ext.apply(this, {
      width: 330,
      height: 150,
      cls: 'pp-pluginlist-base',
      bodyCssClass: 'pp-pluginlist-wrap',
      layout: {
        type: 'vbox',
        align: 'stretch',
      },
      defaults: {
	  border: false,
        flex: 4
      },
      items: [{
        flex: 1,
        layout: 'hbox',
        defaults: {
	  border: false,
          flex: 4,
	  align:'stretch'
        },
        items: [{
	  tag:'div',
	  cls: 'label',
          html:'Current search order <span id="current-tooltip" class="pp-tooltip-link">?</span>'
        },
	{
	    xtype:'spacer',
	    flex: 1
	},
        {
	  tag:'div',
	  cls: 'label',
          html:'Available Resources <span id="available-tooltip" class="pp-tooltip-link">?</span>'
        }]
      },
      {
        layout: {
          type: 'hbox',
          align: 'stretch'
        },
        defaults: {
	  border: false,
          flex: 3
        },
        items: [{
		    border: false,
          items: [this.usedPlugins]
        },
        {
          layout: 'vbox',
          flex: 1,
          layoutConfig: {
            align: 'center',
            pack: 'center'
          },
          defaults: {
	  border: false,
            flex: 1
          },
          items: [this.actions['BUTTON_LEFT'],
          this.actions['BUTTON_RIGHT']]
        },
        {
	    border: false,
          items: [this.availablePlugins]
        }]
      },
      {
	flex: 1,
        layout: {
          type: 'hbox',
          align: 'stretch'
        },
        defaults: {
	  border: false,
          flex: 1
        },
        items: [{
          layout: {
	      type: 'hbox',
	      align: 'middle',
	      pack: 'center'
	  },
          defaults: {flex:1},
          items: [this.actions['BUTTON_UP'], this.actions['BUTTON_DOWN']]
        },
        {
          type: 'spacer',
          flex: 1
        }]
      }]
    });

    Paperpile.PluginOrderPanel.superclass.initComponent.call(this);

    this.usedPlugins.on('nodedrop', this.saveAndLoad, this);
    this.usedPlugins.getSelectionModel().on('selectionchange', function() {
      this.clearSelections(this.availablePlugins);
      this.updateButtons();
    },
    this);
    this.availablePlugins.on('nodedrop', this.saveAndLoad, this);
    this.availablePlugins.getSelectionModel().on('selectionchange', function() {
      this.clearSelections(this.usedPlugins);
      this.updateButtons();
    },
    this);

    this.on('afterrender', function() {

      new Ext.ToolTip({
        target: 'current-tooltip',
        minWidth: 50,
        maxWidth: 300,
        html: 'These resources are searched in the given order to find the full bibliographic data for a partial reference or a PDF. List those resources first which your PDFs/references are most likely to be found in.',
        anchor: 'left',
        showDelay: 0,
        hideDelay: 0
      });

      new Ext.ToolTip({
        target: 'available-tooltip',
        minWidth: 50,
        maxWidth: 300,
        html: 'All available online resources that can be used to find the full bibliographic data for a partial reference or PDF.',
        anchor: 'left',
        showDelay: 0,
        hideDelay: 0
      });

      this.reloadView();

    },
    this);
  },

  initEvents: function() {
    Paperpile.PluginOrderPanel.superclass.initEvents.call(this);
  },

  moveUp: function() {
    var node = this.getSelected();
    if (node.isFirst()) return;
    var parent = node.parentNode;
    var index = parent.indexOf(node);
    var prevChild = parent.childNodes[index - 1];
    parent.removeChild(node, false);
    parent.insertBefore(node, prevChild);
    this.saveAndLoad();
    this.selectById(node.id);
  },

  moveDown: function() {
    var node = this.getSelected();
    if (node.isLast()) return;
    var parent = node.parentNode;
    var index = parent.indexOf(node);
    var nextChild = parent.childNodes[index + 1];

    parent.removeChild(node, false);
    if (nextChild.isLast()) parent.appendChild(node);
    else {
      var nextNextChild = parent.childNodes[index + 1];
      parent.insertBefore(node, nextNextChild);
    }
    this.saveAndLoad();
    this.selectById(node.id);
  },

  clearSelections: function(treePanel) {
    treePanel.getSelectionModel().clearSelections(true);
  },

  getSelected: function() {
    var selectedNode = this.usedPlugins.getSelectionModel().getSelectedNode();
    if (selectedNode == null) selectedNode = this.availablePlugins.getSelectionModel().getSelectedNode();
    return selectedNode;
  },

  selectById: function(id) {
    if (this.selectByTreeId(id, this.usedPlugins)) return;
    this.selectByTreeId(id, this.availablePlugins);
  },
  selectByTreeId: function(id, tree) {
    var node = tree.getNodeById(id);
    if (node) {
      tree.getSelectionModel().select(node);
      return true;
    }
    return false;
  },

  switchSelected: function() {
    this.switchNode(this.getSelected());
  },

  switchNode: function(node) {
    var ownerTree = node.getOwnerTree();
    var otherTree = this.usedPlugins;
    if (ownerTree == this.usedPlugins) {
      otherTree = this.availablePlugins;
    }
    node.remove(false);
    var otherRoot = otherTree.getRootNode();
    otherRoot.appendChild(node);
    this.saveAndLoad();
    this.selectById(node.id);
  },

  updateButtons: function() {
    // Disable all buttons.
    for (var key in this.actions) {
      this.actions[key].disable();
    }

    var selectedNode = this.usedPlugins.getSelectionModel().getSelectedNode();
    if (selectedNode != null) {
      // The usedPlugins tree is selected. Update buttons accordingly.
      if (!selectedNode.isLast()) this.actions['BUTTON_DOWN'].enable();
      if (!selectedNode.isFirst()) this.actions['BUTTON_UP'].enable();

      var root = selectedNode.getOwnerTree().getRootNode();
      if (root.childNodes.length > 1) {
        // Only allow moving to the right if we're not the only child.
        this.actions['BUTTON_RIGHT'].enable();
      }
    }

    selectedNode = this.availablePlugins.getSelectionModel().getSelectedNode();
    if (selectedNode != null) {
      this.actions['BUTTON_DOWN'].disable();
      this.actions['BUTTON_UP'].disable();
      this.actions['BUTTON_LEFT'].enable();
    }

  },

  createPluginOrderTreePanel: function(config) {
    config = Ext.apply(config, {
      enableDD: true,
      ddGroup: 'plugin-list',
      dragConfig: {},
      dropConfig: {},
      animate: false,
      rootVisible: false,
      lines: false,
      border: true,
      height: 100
    });
    var newPanel = new Ext.tree.TreePanel(config);

    newPanel.initEvents = newPanel.initEvents.createInterceptor(function() {
      Paperpile.PluginOrderDropZone = Ext.extend(Ext.tree.TreeDropZone, {
        initComponent: function() {
          Ext.apply(this, {
            allowContainerDrop: true
          });
          Paperpile.PluginOrderDropZone.superclass.initComponent.call(this);
        },
        onContainerOver: function(dd, e, data) {
          var lastNode = this.tree.getRootNode().lastChild;
          if (lastNode == null) {
            return this.dropAllowed;
          }
          var dragObject = {
            ddel: lastNode.ui.elNode,
            node: lastNode
          };
          this.lastOverNode = dragObject;
          if (this.onNodeOver(dragObject, "below", dd, e, data)) {
            this.lastOverNode = dragObject;
            return "x-tree-drop-ok-below";
          }
          return this.dropNotAllowed;
        },
        onContainerDrop: function(dd, e, data) {
          var lastNode = this.tree.getRootNode().lastChild;
          if (lastNode == null) {
            return this.processDrop(this.tree.getRootNode(), data, 'append', dd, e, data.node);
          }
          lastNode.ui.startDrop();
          var dropNode = data.node;
          return this.processDrop(lastNode, data, 'below', dd, e, dropNode);
        }
      });
      this.dropZone = new Paperpile.PluginOrderDropZone(this, {});
    },
    newPanel);

    var root = new Ext.tree.TreeNode({
      text: 'Plugin Order',
      draggable: false,
      id: 'root',
      children: []
    });
    newPanel.setRootNode(root);
    return newPanel;
  },

  saveAndLoad: function() {
    this.saveToModel();
    this.reloadView();
  },

  saveToModel: function() {
    var list = '';

    var root = this.usedPlugins.getRootNode();
    var children = root.childNodes;
    var classNames = [];
    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      classNames.push(child.attributes.className);
    }
    list = classNames.join(',');
    this.tempSettingValue = list;

    if (this.tempSettingValue != Paperpile.main.getSetting(this.settingName)) {
      this.settingsPanel.setSaveDisabled(false);
    }
  },

  // Implement an isDirty function so we can play along with the other fields
  // in the settings.js panel
  isDirty: function() {
    return (this.tempSettingValue != this.origValue);
  },

  getValue: function() {
    return this.tempSettingValue;
  },

  reloadView: function() {
    var root = Paperpile.main.tree.getNodeById('IMPORT_PLUGIN_ROOT');

    var allPluginHash = {};
    var usedPluginHash = {};
    var availablePluginHash = {};

    var children = root.childNodes;
    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      if (child.type != 'IMPORT_PLUGIN') {
        continue;
      }
      var pluginName = child.text;
      var pluginClassName = child.plugin_name;
      var obj = {
        id: 'root/' + child.plugin_name,
        iconCls: child.iconCls,
        text: child.text,
        className: child.plugin_name,
        draggable: true,
        leaf: true
      };
      allPluginHash[pluginClassName] = obj;
    }

    var currentListString = this.tempSettingValue || "PubMed";
    var currentList = currentListString.split(",");
    for (var i = 0; i < currentList.length; i++) {
      var item = currentList[i];
      var record = allPluginHash[item];
      usedPluginHash[item] = record;
    }

    var allKeys = [];
    for (var key in allPluginHash) {
      allKeys.push(key);
    }
    allKeys.sort();

    for (var i = 0; i < allKeys.length; i++) {
      var key = allKeys[i];
      if (!usedPluginHash[key]) {
        availablePluginHash[key] = allPluginHash[key];
      }
    }

    this.replaceNodes(this.usedPlugins, usedPluginHash);
    this.replaceNodes(this.availablePlugins, availablePluginHash);
    //this.numberNodes(this.usedPlugins);
    this.updateButtons();
  },

  numberNodes: function(tree) {
    var root = tree.getRootNode();
    var rootEl = Ext.fly(root.getUI().getEl());
    rootEl.select('.pp-pluginlist-number').remove();
    root.eachChild(function(node) {
      var el = Ext.fly(node.getUI().getEl());
      var index = root.indexOf(node) + 1;
      Ext.DomHelper.insertBefore(el, {
        tag: 'div',
        cls: 'pp-pluginlist-number',
        html: index + ') '
      });
    });
  },

  clearRoots: function() {
    this.replaceNodes(this.availablePlugins, {});
  },

  replaceNodes: function(tree, nodeHash) {
    var root = tree.getRootNode();
    var children = root.childNodes;
    while (root.childNodes.length > 0) {
      root.removeChild(root.childNodes[0], true);
    }
    for (var key in nodeHash) {
      var obj = nodeHash[key];
      root.appendChild(tree.getLoader().createNode(obj));
    }
    root.collapse();
    root.expand();
  }

});