Paperpile.GeneralSettings = Ext.extend(Ext.Panel, {

  title: 'General settings',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoLoad: {
        url: Paperpile.Url('/screens/settings'),
        callback: this.setupFields,
        scope: this
      },
      bodyStyle: 'pp-settings',
      autoScroll: true,
      iconCls: 'pp-icon-tools'
    });

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.isDirty = false;

  },

  //
  // Creates textfields, buttons and installs event handlers
  //
  setupFields: function() {

    Ext.form.VTypes["nonempty"] = /^.*$/;

    Ext.get('settings-cancel-button').on('click',
      function() {
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
      });

    this.textfields = {};
    this.combos = {};

    Ext.each(['proxy', 'proxy_user', 'proxy_passwd'],
    function(item) {
      var field = new Ext.form.TextField({
        value: Paperpile.main.globalSettings[item],
        enableKeyEvents: true,
        width: 220,
      });

      field.render(item + '_textfield', 0);

      this.textfields[item] = field;

      field.on('keypress',
        function() {
          this.isDirty = true;
          this.setSaveDisabled(false);
        },
        this);

    },
    this);

    this.combos['pager_limit'] = new Ext.form.ComboBox({
      renderTo: 'pager_limit_combo',
      editable: false,
      forceSelection: true,
      triggerAction: 'all',
      disableKeyFilter: true,
      fieldLabel: 'Type',
      mode: 'local',
      width: 60,
      store: [10, 25, 50, 75, 100],
      value: Paperpile.main.globalSettings['pager_limit'],
    });

    this.combos['pager_limit'].on('select',
      function() {
        this.isDirty = true;
        this.setSaveDisabled(false);
      },
      this);

    this.proxyCheckbox = new Ext.form.Checkbox({
      renderTo: 'proxy_checkbox'
    });

    this.proxyCheckbox.on('check',
      function(box, checked) {
        this.onToggleProxy(box, checked);
        this.isDirty = true;
        this.setSaveDisabled(false);
      },
      this);

    if (Paperpile.main.globalSettings['use_proxy'] == "1") {
      this.proxyCheckbox.setValue(true);
      this.onToggleProxy(this.proxyCheckbox, true);
    } else {
      this.proxyCheckbox.setValue(false);
      this.onToggleProxy(this.proxyCheckbox, false);
    }

    this.proxyTestButton = new Ext.Button({
      text: "Test your network connection",
      renderTo: 'proxy_test_button'
    });

    this.proxyTestButton.on('click',
      function() {

        Ext.get('proxy_test_status').removeClass(['pp-icon-tick', 'pp-icon-cross']);

        Paperpile.status.showBusy('Testing network connection.');

        var params = {
          use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
          proxy: this.textfields['proxy'].getValue(),
          proxy_user: this.textfields['proxy_user'].getValue(),
          proxy_passwd: this.textfields['proxy_passwd'].getValue(),
        };
        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/misc/test_network'),
          params: params,
          success: function(response) {

            var error;

            if (response.responseText) {
              error = Ext.util.JSON.decode(response.responseText).error;
            }

            if (error) {
              Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
              Paperpile.main.onError(response);
            } else {
              Ext.get('proxy_test_status').replaceClass('pp-icon-cross', 'pp-icon-tick');
              Paperpile.status.clearMsg();
            }

          },
          failure: function(response) {
            Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
            Paperpile.main.onError(response);
          }
        });
      },
      this);

    this.pluginOrderPanel = new Paperpile.PluginOrderPanel({
      renderTo: 'plugin_order_panel',
      settingsPanel: this
    });

    this.setSaveDisabled(true);
  },

  onToggleProxy: function(box, checked) {
    this.textfields['proxy'].setDisabled(!checked);
    this.textfields['proxy_user'].setDisabled(!checked);
    this.textfields['proxy_passwd'].setDisabled(!checked);

    if (checked) {
      Ext.select('h2,h3', true, 'proxy-container').removeClass('pp-label-inactive');
    } else {
      Ext.select('h2,h3', true, 'proxy-container').addClass('pp-label-inactive');
    }
  },

  setSaveDisabled: function(disabled) {
    var button = Ext.get('settings-save-button');
    button.un('click', this.submit, this);
    if (disabled) {
      button.replaceClass('pp-save-button', 'pp-save-button-disabled');
    } else {
      button.replaceClass('pp-save-button-disabled', 'pp-save-button');
      button.on('click', this.submit, this);
    }
  },

  submit: function() {
    Paperpile.log(this.pluginOrderPanel.getValue());
    var params = {
      use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
      proxy: this.textfields['proxy'].getValue(),
      proxy_user: this.textfields['proxy_user'].getValue(),
      proxy_passwd: this.textfields['proxy_passwd'].getValue(),
      pager_limit: this.combos['pager_limit'].getValue(),
      search_seq: this.pluginOrderPanel.getValue()
    };

    Paperpile.status.showBusy('Applying changes.');

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/settings/set_settings'),
      params: params,
      success: function(response) {

        // Update main DB tab with new pager limit. Other DB
        // plugins will use the new setting when they are newly opened.
        var new_pager_limit = this.combos['pager_limit'].getValue();
        if (new_pager_limit != Paperpile.main.globalSettings['pager_limit']) {
          var grid = Paperpile.main.tabs.items.get('MAIN').items.get('center_panel').items.get('grid');
          grid.store.baseParams['limit'] = new_pager_limit;
          grid.store.reload();
        }

        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);

        Paperpile.main.loadSettings(
          function() {
            Paperpile.status.clearMsg();
          },
          this);
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  }

});

Paperpile.PluginOrderPanel = Ext.extend(Ext.Panel, {

  // We might want to change the setting name to something else in the future.
  settingsPanel: null,
  settingName: 'search_seq',
  tempSettingValue: null,

  initComponent: function() {
    Paperpile.log(Paperpile.main.getSetting(this.settingName));
    this.tempSettingValue = Paperpile.main.getSetting(this.settingName);

    var usedConfig = {
      cls: 'pp-pluginlist pp-pluginlist-used',
      border: true,
      plugins: [
        new Paperpile.HoverButtonPlugin({
          cls: 'pp-pluginlist-hover-right',
          showButtonIf: function(node) {
            // Don't show the hover button if we're the only child node!
            var tree = node.getOwnerTree();
            var root = tree.getRootNode();
            if (root.childNodes.length == 1) {
              return false;
            }
            return true;
          },
          fn: this.switchNode,
          scope: this
        })]
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
    this.usedPlugins.setWidth("50%");

    var availableConfig = {
      cls: 'pp-pluginlist',
      border: true,
      listeners: {
        'dblclick': {
          // Move plugins to the 'used' column if double-clicked.
          fn: function(node, event) {},
          scope: this
        }
      },
      plugins: [
        new Paperpile.HoverButtonPlugin({
          cls: 'pp-pluginlist-hover-left',
          fn: this.switchNode,
          scope: this
        })]
    };
    this.availablePlugins = this.createPluginOrderTreePanel(availableConfig);
    this.availablePlugins.setWidth("50%");

    this.actions = {};
    this.actions['BUTTON_UP'] = new Ext.Button({
      itemId: 'BUTTON_UP',
      icon: '/images/icons/up.png',
      handler: this.moveUp,
      scope: this
    });
    this.actions['BUTTON_DOWN'] = new Ext.Button({
      itemId: 'BUTTON_DOWN',
      icon: '/images/icons/down-small.png',
      handler: this.moveDown,
      scope: this
    });
    this.actions['BUTTON_LEFT'] = new Ext.Button({
      itemId: 'BUTTON_LEFT',
      icon: '/images/icons/back.png',
      handler: this.switchSelected,
      scope: this
    });
    this.actions['BUTTON_RIGHT'] = new Ext.Button({
      itemId: 'BUTTON_RIGHT',
      icon: '/images/icons/next.png',
      handler: this.switchSelected,
      scope: this
    });

    this.buttonPanel = new Ext.Panel({
      layout: 'hbox',
      layoutConfig: {
        align: 'middle',
        pack: 'center',
        padding: "0 5"
      },
      items: [
        this.actions['BUTTON_LEFT'],
        this.actions['BUTTON_UP'],
        this.actions['BUTTON_DOWN'],
        this.actions['BUTTON_RIGHT']]
    });

    this.treePanel = new Ext.Panel({
      layout: 'hbox',
      layoutConfig: {
        align: 'stretch'
      },
      items: [
        this.usedPlugins,
        this.availablePlugins],
      height: 90
    });

    Ext.apply(this, {
      cls: 'pp-pluginlist-panel',
      layout: 'vbox',
      layoutConfig: {
        align: 'stretch'
      },
      items: [
        this.treePanel,
        this.buttonPanel],
      height: 120
    });

    // Create two DataViews: one for the 'unused' list, and one for the ordered list.
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
      this.reloadView();
      this.doLayout();

      // Add some guiding text here.
      var el = Ext.fly(this.usedPlugins.getTreeEl());
      el.insertFirst({
        tag: 'p',
        html: 'Current oder:',
        style: {
          margin: '0px 10px'
        }
      });
      var el = Ext.fly(this.availablePlugins.getTreeEl());
      el.insertFirst({
        tag: 'p',
        html: 'Available plugins:',
        style: {
          margin: '0px 10px'
        }
      });

    },
    this);
  },

  initEvents: function() {
    Paperpile.PluginOrderPanel.superclass.initEvents.call(this);
  },

  moveUp: function() {
    var node = this.getSelected();
    if (node.isFirst())
      return;
    var parent = node.parentNode;
    var index = parent.indexOf(node);
    var prevChild = parent.childNodes[index-1];
    parent.removeChild(node,false);
    parent.insertBefore(node,prevChild);
    this.saveAndLoad();
    this.selectById(node.id);
  },

  moveDown: function() {
    var node = this.getSelected();
    if (node.isLast())
      return;
    var parent = node.parentNode;
    var index = parent.indexOf(node);    
    var nextChild = parent.childNodes[index+1];

    parent.removeChild(node,false);
    if (nextChild.isLast())
      parent.appendChild(node);
    else {
      var nextNextChild = parent.childNodes[index+1];
      parent.insertBefore(node,nextNextChild);
    }
    this.saveAndLoad();
    this.selectById(node.id);
  },

  clearSelections: function(treePanel) {
    treePanel.getSelectionModel().clearSelections(true);
  },

  getSelected: function() {
    var selectedNode = this.usedPlugins.getSelectionModel().getSelectedNode();
    if (selectedNode == null)
      selectedNode = this.availablePlugins.getSelectionModel().getSelectedNode();
    return selectedNode;
  },

  selectById: function(id) {
    if (this.selectByTreeId(id,this.usedPlugins))
      return;
    this.selectByTreeId(id,this.availablePlugins);
  },
  selectByTreeId: function(id,tree) {
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
      if (!selectedNode.isLast())
	this.actions['BUTTON_DOWN'].enable();
      if (!selectedNode.isFirst())
	this.actions['BUTTON_UP'].enable();

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
      lines: false
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

    //    newPanel.getSelectionModel().on("beforeselect",
    //      function() {
    //        return true;
    //      });
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
    this.numberNodes(this.usedPlugins);
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