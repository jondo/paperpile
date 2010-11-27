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

Paperpile.Tree = function(config) {
  Ext.apply(this, config);
  Paperpile.Tree.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.Tree, Ext.tree.TreePanel, {
  initComponent: function() {
    Ext.apply(this, {
      enableDD: true,
      ddGroup: 'gridDD',
      animate: false,
      lines: false,
      autoScroll: true,
      root: {
        id: 'NO_LOAD'
      },
      rootVisible: false,
      loader: new Paperpile.TreeLoader({
        url: Paperpile.Url('/ajax/tree/get_node'),
        requestMethod: 'GET'
      }),
      treeEditor: new Ext.tree.TreeEditor(this, {
        allowBlank: false,
        cancelOnEsc: true,
        completeOnEnter: true,
        ignoreNoChange: true
      }),
      plugins: [new Paperpile.ContextTrianglePlugin()]
    });

    this.stylePickerMenu = new Paperpile.StylePickerMenu({
      handler: function(cm, number) {
        this.styleCollection(number);
      },
      scope: this
    });

    Paperpile.Tree.superclass.initComponent.call(this);

    this.on({
      contextmenu: {
        scope: this,
        fn: this.onContextMenu,
        stopEvent: true
      },
      beforenodedrop: {
        scope: this,
        fn: this.onNodeDrop
      },
      nodedragover: {
        scope: this,
        fn: this.onNodeDrag
      },
      checkchange: {
        scope: this,
        fn: this.onCheckChange
      },
      click: {
        scope: this,
        fn: this.myOnClick
      },
      containerClick: {
        scope: this,
        fn: this.myContainerClick
      },
      beforeLoad: {
        scope: this,
        fn: function(node) {
          if (node.id === 'NO_LOAD' || node.id === 'MORE_LABELS') {
            return false;
          } else {
            return true;
          }
        }
      },
      load: {
        scope: this,
        fn: function(node) {
          if (node.id == "LOCAL_ROOT" || node.id == "ACTIVE_ROOT" || node.id == "IMPORT_PLUGIN_ROOT") {
            node.getUI().addClass('pp-root-node');
          }

          if (node.id == "LABEL_ROOT") {

            // Create the 'more...' node.
            if (!this.moreLabelsNode) {
              this.moreLabelsNode = this.loader.createNode({
                text: "0 more...",
                leaf: true,
                draggable: false,
                type: 'MORE_LABELS',
                id: 'MORE_LABELS',
                cls: 'more-labels-node'
              });

              node.on({
                expand: {
                  fn: function(node) {
                    if (this.labelPanel && this.labelPanel.isVisible()) {
                      this.labelPanel.alignTo(this.moreLabelsNode.getUI().getTextEl());
                    }
                  }
                },
                scope: this
              });
            }

            // Create the panel that's hidden / shown when the "more..." node is clicked.
            if (!this.labelPanel) {
              this.labelPanel = new Paperpile.LabelPanel({
                filterBar: true
              });
              this.labelPanel.on('beforehide', function() {
                var el = Ext.fly(this.moreLabelsNode.getUI().getEl());
                if (el) {
                  el.removeClass('more-labels-node-down');
                  this.hideShowMode = false;
                  this.refreshLabels();
                }

              },
              this);
              this.labelPanel.on('beforeshow', function() {
                this.hideShowMode = true;
                this.refreshLabels();
                var el = Ext.fly(this.moreLabelsNode.getUI().getEl());
                if (el) {
                  el.addClass('more-labels-node-down');
                }
              },
              this);
              this.labelPanel.setVisible(false);
            }

            this.refreshLabels();
            this.refreshFolders();
          }

          // This is necessary because we load the tree as a whole
          // during startup but want to re-load single nodes
          // afterwards. We achieve this by removing the children
          // array which gets stored in node.attributes
          delete node.attributes.children;

          // Here's where we ensure that only "rename-able" nodes are set as editable.
          if (this.isNodeDraggable(node) && (node.type == "LABEL" || node.type == "FOLDER" || node.type == "ACTIVE")) {
            node.editable = true;
          } else {
            node.editable = false;
          }

        }
      },
      expandnode: {
        scope: this,
        fn: function(node) {}
      },
      beforeappend: {
        scope: this,
        fn: function(tree, parent, node) {
          return true;
        }
      },
      resize: {
        scope: this,
        fn: function(node) {}
      }
    });

    this.treeEditor.on({
      startedit: {
        scope: this,
        fn: function() {
          /*
	     * TreeEditor takes the node.text by default, but we 
	     * want to edit the full node name which is stored
	     * in node.name (b/c we may shorten node.text if the
	     * node.name is too long)
	     */
          var fullName = this.treeEditor.editNode.name;
          if (!fullName && this.treeEditor.editNode.text) {
            fullName = this.treeEditor.editNode.text;
          }
          this.treeEditor.field.setValue(fullName);
          this.treeEditor.field.selectText();
        }
      }
    });

    // Avoid selecting nodes; only allow under certain
    // circumstances where it makes sense (e.g context menu selection)
    this.allowSelect = false;
    this.getSelectionModel().on("beforeselect",
      function(sm, node) {
        return this.allowSelect;
      },
      this);
    this.getSelectionModel().on('selectionchange', function(sm, node) {
      if (node) {
        this.lastSelectedNode = node;
      }
    },
    this);
  },

  loadTree: function() {
    var root = this.getRootNode();
    // To keep the tree from immediately loading we only set the right
    // ID when this method is called. 
    root.setId('ROOT');
    this.reloadNode(root);
  },

  reloadNode: function(node, expandAll) {
    if (expandAll === undefined) {
      expandAll = true;
    }
    node.loaded = false;
    node.loading = false;
    node.expand(expandAll);
  },

  isNodeDraggable: function(node) {
    var id = node.id;
    // Root nodes not allowed.
    if (id === 'ROOT' || id === 'FOLDER_ROOT' || id === 'LOCAL_ROOT' || id === 'LABEL_ROOT' || id === 'TRASH' || id === 'ACTIVE_ROOT' || id === 'IMPORT_PLUGIN_ROOT') {
      return false;
    } else {
      // Everything else is OK.
      return true;
    }

    /*
    if (node.type == 'IMPORT_PLUGIN' && node.id != 'IMPORT_PLUGIN_ROOT') return false;
    if (node.parentNode) {
      var parent = node.parentNode;
      if (parent.id == 'ROOT') return true;
      if (parent.parentNode) {
        var grandparent = parent.parentNode;
        if (grandparent.id == 'ROOT') return true;
      }
    }
    return false;
*/
  },

  initEvents: function() {
    Paperpile.Tree.TreeDropZone = Ext.extend(Ext.tree.TreeDropZone, {
      ddGroup: this.ddGroup,
      appendOnly: false,
      getDropPoint: function(e, n, dd) {
        var node = n.node;
        //   -> if dragging from the grid over the Labels, it should always be in "append" mode.
        // This is a bit hacky... there should be a better way to determine where the drag data is coming from.
        if (dd.dragData.grid != null) {
          return "append";
        }
        return Paperpile.Tree.TreeDropZone.superclass.getDropPoint.call(this, e, n, dd);
      }
    });
    this.dropZone = new Paperpile.Tree.TreeDropZone(this, {});

    Paperpile.Tree.TreeDragZone = Ext.extend(Ext.tree.TreeDragZone, {
      containerScroll: true,
      ddGroup: this.ddGroup,
      proxy: new Paperpile.StatusTipProxy(),
      onBeforeDrag: function(data, e) {
        if (data.node) {
          var type = data.node.attributes.type;
          if (!Paperpile.main.tree.isNodeDraggable(data.node)) {
            data.node.draggable = false;
          }
        }
        return Paperpile.Tree.TreeDragZone.superclass.onBeforeDrag.call(this, data, e);
      }

    });
    this.dragZone = new Paperpile.Tree.TreeDragZone(this, {});

    Paperpile.Tree.superclass.initEvents.call(this);
  },

  myContainerClick: function(tree, e) {
    var targetEl = e.getTarget("span", 10, true);
    if (!targetEl) {
      Paperpile.main.grabFocus();
      return;
    }
  },

  myOnClick: function(node, e) {
    if (e != null) {
      // Only take clicks that occur right within the node text area.
      var targetEl = e.getTarget("span", 10, true);
      if (!targetEl) {
        Paperpile.main.grabFocus();
        return;
      }
    }
    switch (node.id) {
    case 'FOLDER_ROOT':
      var main = Paperpile.main.tabs.getItem("MAIN");
      Paperpile.main.tabs.activate(main);
      return;
    case 'LABEL_ROOT':
    case 'ACTIVE_ROOT':
    case 'IMPORT_PLUGIN_ROOT':
    case 'LOCAL_ROOT':
    case 'ROOT':
      return;
    }

    switch (node.type) {
    case 'MORE_LABELS':
      break;
    case 'PDFEXTRACT':
      Paperpile.main.pdfExtract();
      break;
    case 'FILE_IMPORT':
      Paperpile.main.fileImport();
      break;
    case 'CLOUDS':
      Paperpile.main.tabs.newScreenTab('Clouds', 'clouds');
      break;
    case 'FEEDBACK':
      Paperpile.main.userVoice();
      break;
    case 'DUPLICATES':
      Paperpile.main.tabs.newPluginTab('Duplicates', {},
        "Duplicates", "pp-icon-duplicates", "duplicates");
      break;
    case 'TRASH':
      Paperpile.main.tabs.newTrashTab();
      break;
    case 'LABEL':
      Paperpile.main.tabs.newCollectionTab(node, 'LABEL');
      break;
    case 'FOLDER':
      Paperpile.main.tabs.newCollectionTab(node, 'FOLDER');
      break;
    case 'IMPORT_PLUGIN':
    case 'ACTIVE':
      // Collect plugin paramters
      var pars = {};
      for (var key in node) {
        if (key.match('plugin_')) {
          pars[key] = node[key];
        }
      }

      // For now we reload feeds whenever they are opened 
      if (pars.plugin_name == 'Feed') {
        pars.plugin_reload = 1;
      }

      // Use default title and css for tab
      var title = pars.plugin_title;

      var iconCls = null;

      // Call appropriate frontend, labels, active folders, and folders are opened only once
      // and we pass the node.id as item-id for the tab
      Paperpile.main.tabs.newPluginTab(node.plugin_name, pars, title, iconCls, node.id);
      break;

    default:
      Paperpile.main.grabFocus();
      break;
    }
  },

  updateDragStatus: function(e) {
    var target = e.target;
    var proxy = e.source.proxy;
    if (!proxy.updateTip) {
      return;
    }
    if (e.source.dragData.grid) {
      var myType = e.target.type;
      if (myType == 'LABEL') {
        proxy.updateTip('Apply label to reference');
      } else if (myType == 'FOLDER') {
        proxy.updateTip('Place reference in folder');
      } else {
        proxy.updateTip('');
      }
    } else if (e.data.node) {
      var myType = e.data.node.attributes.type;
      var targetType = target.attributes.type;
      if (myType == 'LABEL' && targetType == 'LABEL') {
        proxy.updateTip('Move label');
      } else if (myType == 'FOLDER' && targetType == 'FOLDER') {
        proxy.updateTip('Move folder');
      } else {
        proxy.updateTip('');
      }
    } else {
      proxy.updateTip('');
    }
  },

  onNodeDrag: function(e) {
    // We are dragging from the data grid
    if (e.source.dragData.grid) {
      var grid = e.source.dragData.grid;
      var t = e.target.type;
      // only allow drop on Folders, Labels and Trash
      if ((t == 'FOLDER_ROOT' || t == 'LABEL' || t == 'FOLDER' || t == 'TRASH') && e.target.id != 'LABEL_ROOT') {
        if (t == 'TRASH') {
          var imported = grid.getSelection('IMPORTED');
          var trashed = grid.getSelection('TRASHED');
          if (imported.length == 0 || trashed.length == imported.length) {
            e.cancel = true;
          }
        } else if (t == 'LABEl') {
          // Be genreally permissive for trash and labels.
          e.cancel = false;
        } else if (t == 'FOLDER') {
          e.cancel = false;
        }
      } else {
        // Cancel if not on a folder, label or trash.
        e.cancel = true;
      }
    } else {
      // We are dragging internal nodes from the tree
      // Only allow operations within the same subtree,
      // i.e. nodes are of the same type
      if (!this.areNodeTypesCompatible(e.source.dragData.node.type, e.target.type)) {
        e.cancel = true;
      } else if (e.target.type == 'LABEL' && e.point == 'append') {
        e.cancel = true;
      } else {
        // Allow only re-ordering for these types.
        if ((e.target.type == 'ACTIVE' || this.toolNodeTypes[e.target.type]) && e.point == 'append') {
          e.cancel = true;
        } else {
          // Can't move node above root
          if (e.target.id.search('ROOT') != -1 && e.point == 'above') {
            e.cancel = true;
          }
        }
      }
    }
    //this.updateDragStatus(e);
  },

  toolNodeTypes: {
    IMPORT_PLUGIN: 1,
    PDFEXTRACT: 1,
    FILE_IMPORT: 1,
    CLOUDS: 1,
    DUPLICATES: 1,
    FEEDBACK: 1
  },

  areNodeTypesCompatible: function(a, b) {
    if (a == b) {
      return true;
    }
    if (this.toolNodeTypes[a] && this.toolNodeTypes[b]) {
      return true;
    }
    return false;
  },

  addFolder: function(grid, sel, node) {
    var el = Ext.get(node.getUI().getTextEl());
    el.highlight("ffff9c", {
      easing: 'bounceBoth',
      duration: 1
    });
    Paperpile.Ajax({
      url: '/ajax/crud/move_in_collection',
      params: {
        grid_id: grid.id,
        selection: sel,
        guid: node.id,
        type: 'FOLDER'
      },
      scope: this
    });
  },

  addLabel: function(grid, sel, node) {
    Paperpile.Ajax({
      url: '/ajax/crud/move_in_collection',
      params: {
        grid_id: grid.id,
        selection: sel,
        guid: node.id,
        type: 'LABEL'
      },
      scope: this
    });
  },

  onNodeDrop: function(e) {

    var node = e.target;

    // We're dragging from the data grid
    if (e.source.dragData.grid) {
      var grid = e.source.dragData.grid;
      var sel = grid.getSelection();
      if (node.type == 'FOLDER') {
        this.addFolder(grid, sel, node);
      } else if (e.target.type == 'LABEL') {
        this.addLabel(grid, sel, node);
      } else if (node.type == 'TRASH') {
        grid.deleteEntry('TRASH');
      }
    } else {
      // We're dragging nodes internally
      if (node.type === 'FOLDER' || node.type === 'LABEL') {

        Paperpile.Ajax({
          url: '/ajax/crud/move_collection',
          params: {
            target_node: e.target.id,
            drop_node: e.dropNode.id,
            point: e.point,
            type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL'
          }
        });

      } else {

        Paperpile.Ajax({
          url: '/ajax/tree/move_node',
          params: {
            target_node: e.target.id,
            drop_node: e.dropNode.id,
            point: e.point
          }
        });
      }

    }
  },

  onRender: function() {
    Paperpile.Tree.superclass.onRender.apply(this, arguments);
    this.el.on({
      // Do not show browser-context menu
      contextmenu: {
        fn: function() {
          return false;
        },
        stopEvent: true
      }
    });

    this.on('load', function(node) {
      if (node.id == 'ACTIVE_ROOT') {
        // Add a button to the feeds root.
        var ui = node.ui;

        this.rssButton = new Ext.Button({
          cls: 'pp-rss-button',
          enableToggle: true,
          style: {
            'position': 'relative',
            'float': 'right'
          },
          scale: 'tiny',
          tooltip: 'Add a new journal or RSS feed',
          icon: Paperpile.Url('/images/icons/plus.png'),
          onClick: function() {}
        });
        this.rssButton.render(ui.elNode);
        this.rssButton.getEl().alignTo(ui.elNode, 'r-r', [-2, 0]);
      }
    },
    this);

    this.mon(this.el, 'mousedown', this.myMouseDown, this);

  },

  myMouseDown: function(e) {
    var target = e.target;
    var el = Ext.fly(target);
    if (el.findParent(".more-labels-node", 5)) {
      this.moreLabelsDown();
      return;
    }
    if (el.findParent(".pp-rss-button", 20)) {
      this.rssButtonToggle();
      return;
    }
  },

  moreLabelsDown: function() {
    var textEl = this.moreLabelsNode.getUI().getTextEl();
    if (!this.labelPanel.isVisible()) {
      this.labelPanel.alignTo(textEl);
      this.labelPanel.refreshView();
      this.labelPanel.show();
    } else {
      this.labelPanel.hide();
    }
  },

  onContextMenu: function(node, e) {
    // Save the position before preparing the menu -- if we don't do this,
    // the event becomes a 'blur' event and we lose the position info!
    var pos = e.getXY();
    var menu = this.prepareMenu(node);
    if (menu !== null) {
      this.showMenu(menu, pos);
    }
    e.stopEvent();
  },

  prepareMenu: function(node) {
    // Note: this doesn't actually get called when the tree context triangle plugin is loaded.
    var menu = this.getContextMenu(node);
    if (menu !== null) {
      if (menu.getShownItems(node).length > 0) {
        this.allowSelect = true;
        node.select();
        this.allowSelect = false;
        menu.setNode(node);
        menu.render();
        menu.hideItems();

        this.prepareMenuBeforeShowing(node, menu);
      }
    }
    return menu;
  },

  showMenu: function(menu, position) {
    menu.showAt(position);
  },

  prepareMenuBeforeShowing: function(node, menu) {
    if (node.type == 'FOLDER' || node.type == 'LABEL') {
      this.createAutoExportTip(menu);
    }
  },

  createAutoExportTip: function(contextMenu) {
    if (this.autoExportTip) {
      this.autoExportTip.destroy();
    }
    this.autoExportTip = new Ext.ToolTip({
      trackMouse: false,
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0,
      target: contextMenu.el,
      delegate: '.pp-auto-export-menu-item',
      renderTo: document.body,
      listeners: {
        beforeshow: {
          fn: function updateTipBody(tip) {
            var tipText = this.getAutoExportTipForNode(tip.triggerElement, contextMenu.node);
            if (tipText === '') {
              return false;
            } else {
              tip.body.dom.innerHTML = tipText;
            }
            return true;
          },
          scope: this
        }
      }
    });
  },

  getAutoExportTipForNode: function(triggerEl, node) {
    var menuItemEl = Ext.fly(triggerEl).findParent('.x-menu-item', 4);
    var item = Ext.getCmp(menuItemEl.id);
    if (!item) {
      return '';
    }

    var displayText = 'crap';
    if (item.textDisabled) {
      var filesync = this.getFileSyncData(node);
      var exportFile = filesync.file;
      if (!exportFile || exportFile == '') {
        displayText = 'Click to choose a file.';
      } else {
        displayText = [
          'File: <b>',
          exportFile,
          '</b>',
          '<br/>Auto-export is disabled.'].join("");
      }
    } else {
      var filesync = this.getFileSyncData(node);
      var exportFile = filesync.file;
      displayText = [
        'File: <b>',
        exportFile,
        '</b>',
        '<br/>Click to change'].join("");
    }
    return displayText;
  },

  isContextMenuShowing: function() {
    var menus = [this.folderMenu, this.activeMenu, this.importMenu, this.labelsMenu, this.trashMenu, this.defaultMenu];
    for (var i = 0; i < menus.length; i++) {
      var menu = menus[i];
      if (menu != null) {
        if (menu.isVisible()) return true;
      }
    }
    return false;
  },

  getContextMenu: function(node) {
    var menu = null;
    switch (node.type) {
    case 'FOLDER':
    case 'FOLDER_ROOT':
      if (this.folderMenu == null) {
        this.folderMenu = new Paperpile.Tree.FolderMenu();
      }
      menu = this.folderMenu;
      break;

    case 'ACTIVE':
      if (this.activeMenu == null) {
        this.activeMenu = new Paperpile.Tree.ActiveMenu();
      }
      menu = this.activeMenu;
      break;

    case 'IMPORT_PLUGIN':
      if (this.importMenu == null) {
        this.importMenu = new Paperpile.Tree.ImportMenu();
      }
      menu = this.importMenu;
      break;

    case 'LABEL':
    case 'LABEL_ROOT':
      if (this.labelsMenu == null) {
        this.labelsMenu = new Paperpile.Tree.LabelsMenu();
      }
      menu = this.labelsMenu;
      break;

    case 'TRASH':
      if (this.trashMenu == null) {
        this.trashMenu = new Paperpile.Tree.TrashMenu();
      }
      menu = this.trashMenu;
      break;
    default:
      if (this.defaultMenu == null) {
        this.defaultMenu = new Paperpile.Tree.ContextMenu();
      }
      menu = this.defaultMenu;
      break;
    }

    return menu;
  },

  putNodesInArray: function(node, array) {
    if (array === undefined) {
      array = [];
    }
    var children = node.childNodes;
    for (var i = 0; i < children.length; i++) {
      var childNode = children[i];
      // Recurse.
      this.putNodesInArray(childNode, array);
      // Add this child.
      array.push(childNode);
    }
  },

  putLeavesInArray: function(node, array) {
    if (array === undefined) {
      array = [];
    }
    var children = node.childNodes;
    for (var i = 0; i < children.length; i++) {
      var childNode = children[i];
      // Recurse.
      this.putLeavesInArray(childNode, array);
      // Add this child if it has no children.
      if (childNode.isLeaf) {
        array.push(childNode);
      }
    }
  },

  getAllLeafNodes: function(node) {
    if (node === undefined) {
      node = this.getRootNode();
    }
    var leaves = [];
    this.putLeavesInArray(node, leaves);
    return leaves;
  },

  getAllNodes: function(node) {
    if (node === undefined) {
      node = this.getRootNode();
    }
    var nodes = [];
    this.putNodesInArray(node, nodes);
    nodes.push(node);
    return nodes;
  },

  //
  // Creates a new active folder based on the currently active tab
  //
  newActive: function() {
    var node = this.getNodeById('ACTIVE_ROOT');

    var grid = Paperpile.main.tabs.getActiveTab().items.get('center_panel').items.get('grid');
    var treeEditor = this.treeEditor;

    // Get all plugin_* parameters from search plugin grid
    var pars = {};

    for (var key in grid) {
      if (key.match('plugin_')) {
        pars[key] = grid[key];
      }
    }

    // include the latest query parameters form the data store that
    // define the search
    for (var key in grid.store.baseParams) {
      if (key.match('plugin_')) {
        pars[key] = grid.store.baseParams[key];
      }
    }

    // Use query as default title, or plugin name if query is
    // empty
    var title;
    if (pars.plugin_query != '') {
      title = pars.plugin_query;
    } else {
      title = pars.plugin_name;
    }

    Ext.apply(pars, {
      type: 'ACTIVE',
      plugin_title: title,
      // current query becomes base query for further filtering
      plugin_base_query: pars.plugin_query,
    });

    // Now create new child
    var newNode;
    node.expand(false, false, function(n) {

      newNode = n.appendChild(this.loader.createNode({
        text: title,
        display_name: title,
        name: title,
        iconCls: pars.plugin_iconCls,
        leaf: true,
        id: Paperpile.utils.generateUUID()
      }));

      // apply the parameters
      newNode.init(pars);
      newNode.select();

      // Allow the user to edit the name of the active folder
      treeEditor.on({
        complete: {
          scope: this,
          single: true,
          fn: function() {
            newNode.plugin_title = newNode.text;
            // if everything is done call onNewActive
            this.onNewActive(newNode);
          }
        }
      });
      (function() {
        treeEditor.triggerEdit(newNode);
      }.defer(10));

    }.createDelegate(this));
  },

  //
  // Is called after a new active folder was created. Adds node to
  // tree representation in backend and saves it to database.
  //
  onNewActive: function(node) {

    // Selection of node during creation is no longer needed
    this.getSelectionModel().clearSelections();
    this.allowSelect = false;

    // Again get all plugin_* parameters to send to server
    var pars = {}
    for (var key in node) {
      if (key.match('plugin_')) {
        pars[key] = node[key];
      }
    }

    // Set other relevant node parameters which need to be stored
    Ext.apply(pars, {
      type: 'ACTIVE',
      text: node.text,
      plugin_title: node.text,
      iconCls: pars.plugin_iconCls,
      node_id: node.id,
      parent_id: node.parentNode.id
    });

    // Send to backend
    Paperpile.Ajax({
      url: '/ajax/tree/new_active',
      params: pars
    });
  },

  rssButtonToggle: function(button, buttonState) {
    if (this.newFeedPanel === undefined) {
      var callback = function(url) {
        if (url != '') {
          this.createNewFeedNode(url);
        }
      };
      this.newFeedPanel = new Paperpile.NewFeedPanel({
        callback: callback.createDelegate(this)
      });
      this.newFeedPanel.on('hide', function() {
        this.rssButton.toggle(false);
      },
      this);
      this.newFeedPanel.hide();
    }

    var panel = this.newFeedPanel;
    if (panel.isVisible()) {
      panel.hide();
    } else {
      panel.show();
      Ext.QuickTips.getQuickTip().hide();
      panel.getEl().alignTo(this.rssButton.getEl(), 'tl-bl');
      this.rssButton.toggle(true);
    }
  },

  createNewFeedNode: function(feedUrl) {

    var n = this.getNodeById('ACTIVE_ROOT');
    var newNode = n.appendChild(this.loader.createNode({
      text: 'Loading feed',
      iconCls: 'pp-icon-loading',
      //      qtip: feedUrl,
      draggable: true,
      expanded: true,
      children: [],
      id: Paperpile.utils.generateUUID()
    }));

    var pars = {
      type: 'ACTIVE',
      node_id: newNode.id,
      parent_id: newNode.parentNode.id,
      iconCls: 'pp-icon-feed',
      plugin_name: 'Feed',
      plugin_title: 'New RSS feed',
      plugin_iconCls: 'pp-icon-feed',
      plugin_mode: 'FULLTEXT',
      plugin_url: feedUrl,
      plugin_id: newNode.id
    };

    newNode.init(pars);

    Paperpile.status.showBusy("Subscribing to RSS feed");
    Paperpile.Ajax({
      url: '/ajax/tree/new_rss',
      params: pars,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.status.clearMsg();
        if (json.error) {
          Paperpile.main.onError(response);
          newNode.remove();
        } else {
          newNode.setText(json.title);
          newNode.plugin_title = json.title;
          Ext.get(newNode.getUI().getIconEl()).replaceClass('pp-icon-loading', 'pp-icon-feed');
          this.myOnClick(newNode);
        }
      },
      failure: function(response) {
        Paperpile.main.onError(response),
        newNode.remove();
      },
      scope: this
    });
  },

  //
  // Creates new folder
  //
  newFolder: function() {
    var node = this.lastSelectedNode;

    var treeEditor = this.treeEditor;
    var newNode;

    node.expand(false, false, function(n) {
      var id = Paperpile.utils.generateUUID();
      var record = new Ext.data.Record({
        name: 'New Folder',
        display_name: 'New Folder',
        type: 'FOLDER',
        guid: id
      },
        id);
      var newNode = this.recordToNode(record, 'FOLDER');

      n.appendChild(newNode);

      this.lastSelectedNode = newNode;
      this.allowSelect = true;
      newNode.select();

      this.triggerNewNodeEdit(newNode);
    },
    this);
  },

  onNewCollection: function(node) {
    this.getSelectionModel().clearSelections();
    this.allowSelect = false;

    Paperpile.Ajax({
      url: '/ajax/crud/new_collection',
      params: {
        type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL',
        text: node.text,
        node_id: node.id,
        parent_id: node.type === 'FOLDER' ? node.parentNode.id : 'ROOT'
      },
      success: function(response) {
        if (node.type === 'LABEL') {
          Paperpile.main.triggerLabelStoreReload();
        } else if (node.type === 'FOLDER') {
          Paperpile.main.triggerFolderStoreReload();
        }
      },
      scope: this
    });
  },

  //
  // Deletes RSS feed
  //
  deleteRss: function() {
    var node = this.getSelectionModel().getSelectedNode();

    Paperpile.Ajax({
      url: '/ajax/tree/delete_rss',
      params: {
        node_id: node.id
      }
    });

    node.remove();
  },

  //
  // Deletes active folder
  //
  deleteActive: function() {
    var node = this.getSelectionModel().getSelectedNode();

    Paperpile.Ajax({
      url: '/ajax/tree/delete_active',
      params: {
        node_id: node.id
      }
    });

    node.remove();

  },

  // Saves a single node's 'plugin_xyz' parameter values back to the database.
  saveNode: function(node) {
    var pars = {};
    for (var key in node) {
      if (key.match('plugin_')) {
        pars[key] = node[key];
      }
    }
    pars.node_id = node.id;

    Paperpile.Ajax({
      url: '/ajax/tree/save_node_params',
      params: pars
    });

  },

  //
  // Rename node
  //
  onRenameComplete: function(editor, newText, oldText) {

    editor.editNode.plugin_title = newText;
    Paperpile.Ajax({
      url: '/ajax/tree/rename_node',
      params: {
        node_id: editor.editNode.id,
        new_text: newText
      },
      success: function() {
        editor.un("complete", this.onRenameComplete);
        Paperpile.main.triggerLabelStoreReload();
      }
    });
  },

  renameNode: function() {
    var node = this.lastSelectedNode;
    var treeEditor = this.treeEditor;

    treeEditor.on({
      complete: {
        scope: this,
        single: true,
        fn: this.onRenameComplete
      }
    });

    (function() {
      treeEditor.triggerEdit(node);
    }.defer(10));
  },

  deleteCollection: function() {
    var node = this.lastSelectedNode;

    if (node.type === 'LABEL' && (node.name === 'Incomplete') || (node.name === 'Review')) {
      Paperpile.status.updateMsg({
        type: 'info',
        msg: '"' + node.name + '"' + ' is a reserved label used by Paperpile and cannot be deleted.',
        fade: true,
        duration: 3.5
      });
      return;
    }

    Paperpile.Ajax({
      url: '/ajax/crud/delete_collection',
      params: {
        guid: node.id,
        type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL'
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        if (node.type === 'LABEL') {
          // Close the tab using the label's GUID, which is the node's id and the tab's itemId.
          Paperpile.main.tabs.closeTabById.defer(100, Paperpile.main.tabs, [node.id]);
          Paperpile.main.triggerLabelStoreReload();
        }
        if (node.type === 'FOLDER') {
          // Close the tab using the label's GUID, which is the node's id and the tab's itemId.
          Paperpile.main.tabs.closeTabById.defer(100, Paperpile.main.tabs, [node.id]);
          Paperpile.main.triggerFolderStoreReload();
        }

      },
      scope: this
    });
    if (node.el) {
      node.remove();
    }
  },

  deleteFolder: function() {
    var node = this.lastSelectedNode;

    Paperpile.Ajax({
      url: '/ajax/crud/delete_collection',
      params: {
        guid: node.id,
        type: 'FOLDER'
      }
    });

    node.remove();
  },

  /* Debugging only */
  reloadFolder: function() {
    var node = this.lastSelectedNode;
    node.reload();
  },

  configureSubtree: function(node) {
    this.configureNode = node;
    var oldLoader = node.loader;
    var tmpLoader = new Paperpile.TreeLoader({
      url: Paperpile.Url('/ajax/tree/get_node'),
      baseParams: {
        checked: true
      },
      requestMethod: 'GET',
    });

    // Force reload by deleting the children which get stored in
    // attributes when we load the tree in one step in the beginning
    //delete node.attributes.children;
    node.loader = tmpLoader;
    node.reload();
    node.loader = oldLoader;

    var div = Ext.Element.get(node.ui.getAnchor()).up('div');

    var ok = Ext.DomHelper.append(div,
      '<a href="#" id="configure-node" class="pp-textlink">Done</a>', true);

    ok.on({
      click: {
        fn: function() {
          this.configureNode.reload();
          Ext.Element.get(this.configureNode.ui.getAnchor()).up('div').select('#configure-node').remove();

        },
        stopEvent: true,
        scope: this
      }
    });
  },

  onCheckChange: function(node, checked) {

    if (node.type == 'LABEL') {
      var store = Ext.StoreMgr.lookup('label_store');
      var labelIndex = store.findExact('guid', node.id);
      if (labelIndex !== -1) {
        var record = store.getAt(labelIndex);
        var hidden = 1;
        if (checked) {
          hidden = 0;
        }
        record.set('hidden', hidden);
        this.refreshLabels();
        store.updateCollection(record);
        return;
      }

    }

    var hidden = 1;
    if (checked) {
      hidden = 0;
    }

    Paperpile.Ajax({
      url: '/ajax/tree/set_visibility',
      params: {
        node_id: node.id,
        hidden: hidden
      }
    });
  },

  //
  // Returns the path for a folder relative the folder root
  //
  relativeFolderPath: function(node) {

    // Simple remove the first 3 levels
    var path = node.getPath('text');
    var parts = path.split('/');
    path = parts.slice(3, parts.length).join('/');
    return (path);
  },

  newLabel: function() {
    var node = this.getNodeById('LABEL_ROOT');
    var treeEditor = this.treeEditor;
    var newNode;
    var label = 'New Label';
    node.expand(false, false, function(n) {

      var id = Paperpile.utils.generateUUID();
      var record = new Ext.data.Record({
        name: 'New Label',
        display_name: 'New Label',
        type: 'FOLDER',
        guid: id
      },
        id);
      var newNode = this.recordToNode(record, 'LABEL');

      if (this.moreLabelsNode) {
        node.insertBefore(newNode, this.moreLabelsNode);
      } else {

      }
      newNode.select();
      this.triggerNewNodeEdit(newNode);
    }.createDelegate(this));
  },

  triggerNewNodeEdit: function(newNode) {
    var treeEditor = this.treeEditor;
    (function() {
      this.mon(treeEditor, 'canceledit', this.removeOnCancel, this, {
        single: true
      });
      this.mon(treeEditor, 'complete', this.addOnCommit,
        this, {
          single: true
        });
      treeEditor.triggerEdit(newNode);
    }.defer(10, this));
  },

  addOnCommit: function(editor, newText, oldText) {
    var node = editor.editNode;
    this.onNewCollection(node);
  },

  removeOnCancel: function(editor, newText, oldText) {
    var node = editor.editNode;
    var treeEditor = this.treeEditor;

    // At this point, the node object exists in the front-end but wasn't added
    // to the backend yet. So just remove the node.
    node.remove();
    // Now, clear the callbacks from the treeEditor.
    this.mun(treeEditor, 'canceledit', this.removeOnCancel);
    this.mun(treeEditor, 'complete', this.addOnCommit);
  },

  sortLabelsByCount: function() {
    Paperpile.Ajax({
      url: '/ajax/crud/sort_labels_by_count',
      params: {},
      success: function() {
        var store = Ext.StoreMgr.lookup('label_store');
        store.reload({
          callback: function() {
            Paperpile.status.updateMsg({
              type: 'info',
              msg: store.getTotalCount() + " labels were sorted by paper count.",
              fade: true,
              duration: 1.5
            });
          }
        });
      },
      scope: this
    });
  },

  sortLabelsByName: function() {
    Paperpile.Ajax({
      url: '/ajax/crud/sort_labels_by_name',
      params: {},
      success: function() {
        var store = Ext.StoreMgr.lookup('label_store');
        store.reload({
          callback: function() {
            Paperpile.status.updateMsg({
              type: 'info',
              msg: store.getTotalCount() + " labels were sorted alphabetically.",
              fade: true,
              duration: 1.5
            });
          }
        });
      },
      scope: this
    });
  },

  setCollectionSort: function(idList) {
    var firstNodeId = idList[0];
    var firstNode = this.getNodeById(firstNodeId);
    var parentNode = firstNode.parentNode;
    var parentId = parentNode.id;

    Paperpile.Ajax({
      url: '/ajax/crud/sort_collection',
      params: {
        parent_id: parentId,
        node_id_order: idList
      },
      success: function() {
        Ext.StoreMgr.lookup('label_store').reload();
      },
      scope: this
    });
  },

  hideCollection: function() {
    var store = Ext.StoreMgr.lookup('label_store');
    var node = this.lastSelectedNode;
    var index = store.findExact('guid', node.id);
    if (index !== -1) {
      record = store.getAt(index);
      record.set('hidden', 1);
      store.updateCollection(record);
    }
  },

  refreshFolders: function(json) {
    if (json && json.data) {
      json.data.collection_delta = 0;
      Paperpile.main.onUpdate(json.data);
    }

    var folderRoot = this.getNodeById('FOLDER_ROOT');
    if (!folderRoot) {
      return;
    }

    var expanded = folderRoot.isExpanded();

    folderRoot.silentLoad = true;
    folderRoot.removeAll();

    // Create nodes and store in hash.
    var nodeHash = {};
    var store = Ext.StoreMgr.lookup('folder_store');
    for (var i = 0; i < store.getCount(); i++) {
      var record = store.getAt(i);
      var node = this.recordToNode(record, 'FOLDER');
      nodeHash[node.guid] = node;
    }

    for (var guid in nodeHash) {
      var node = nodeHash[guid];
      if (node.parent && node.parent != 'ROOT') {
        var parent = nodeHash[node.parent];
        parent.appendChild(node);
      } else {
        folderRoot.appendChild(node);
      }
    }

    if (expanded) {
      folderRoot.expand();
    }
  },

  // Data is the JSON returned by a previous ajax call. Optional.
  refreshLabels: function(json) {
    if (json && json.data) {
      json.data.collection_delta = 0;
      Paperpile.main.onUpdate(json.data);
    }

    var labelRoot = this.getNodeById('LABEL_ROOT');
    if (!labelRoot) {
      return;
    }

    var expanded = labelRoot.isExpanded();

    labelRoot.silentLoad = true;
    labelRoot.removeAll();

    var hiddenNodeCount = 0;

    var store = Ext.StoreMgr.lookup('label_store');
    for (var i = 0; i < store.getCount(); i++) {
      var record = store.getAt(i);
      if (record.get('hidden') !== 1) {
        var node = this.recordToNode(record, 'LABEL');
        labelRoot.appendChild(node);
      } else {
        hiddenNodeCount++;
      }
    }

    if (hiddenNodeCount > 0) {
      this.moreLabelsNode.setText(hiddenNodeCount + " more...");
      labelRoot.appendChild(this.moreLabelsNode);
    } else {
      if (this.labelPanel.isVisible()) {
        // We've got a visible panel, but no hidden nodes.
        // Suppress events to avoid endless loop, hide the panel,
        // and remove the checkboxe
        this.labelPanel.suspendEvents();
        this.labelPanel.hide();
        this.hideShowMode = false;
        Ext.fly(this.moreLabelsNode.getUI().getEl()).removeClass('more-labels-node-down');
        this.refreshLabels();
        this.labelPanel.resumeEvents();
      }
    }

    if (this.labelPanel.isVisible()) {
      this.labelPanel.refreshView();
      //      this.labelPanel.alignTo(this.moreLabelsNode.getUI().getTextEl());
    }

    if (expanded) {
      labelRoot.expand();
    }
  },

  recordToNode: function(record, type) {
    var pars = {
      id: record.get('guid'),
      text: record.get('display_name'),
      guid: record.get('guid'),
      display_name: record.get('display_name'),
      name: record.get('name'),
      type: record.get('type'),
      parent: record.get('parent'),
      sort_order: record.get('sort_order'),
      hidden: record.get('hidden'),
      style: record.get('style'),
      expanded: true,
      loaded: true,
      draggable: true,
      children: [],
      plugin_name: 'DB',
      plugin_mode: 'FULLTEXT',
      plugin_title: record.get('display_name')
    };

    if (this.hideShowMode) {
      pars.checked = true;
    }

    if (type == 'FOLDER') {
      pars.type = 'FOLDER';
      pars.collection_type = 'folder';
      pars.plugin_query = "folderid:" + record.get('guid');
      pars.plugin_base_query = "folderid:" + record.get('guid');
      pars.iconCls = "pp-icon-folder";
      pars.plugin_iconCls = "pp-icon-folder";
      pars.cls = 'pp-folder-node';
    } else {
      pars.cls = "pp-label-node pp-label-tree-node pp-label-tree-style-" + record.get('style');
      pars.iconCls = "pp-icon-empty";
      pars.type = 'LABEL';
      pars.plugin_query = "labelid:" + record.get('guid');
      pars.plugin_base_query = "labelid:" + record.get('guid');
      pars.plugin_iconCls = "pp-icon-empty";
      pars.labelStyle = record.get('style');
    }
    var node = this.loader.createNode(pars);
    return node;
  },

  handleEmptyTrash: function() {
    Paperpile.Ajax({
      url: '/ajax/crud/empty_trash',
      params: {},
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        var numDeleted = json.num_deleted;
        var msg = numDeleted + " references permanently deleted.";
        if (numDeleted == 0) {
          msg = "Nothing to delete from Trash.";
        }
        Paperpile.status.updateMsg({
          type: 'info',
          msg: msg,
          fade: true,
          duration: 1.5
        });
      },
      scope: this
    });
  },

  styleCollection: function(number) {
    var node = this.lastSelectedNode;

    Paperpile.Ajax({
      url: '/ajax/crud/update_collection',
      params: {
        guid: node.id,
        style: number,
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.triggerLabelStoreReload();
      },
      scope: this
    });
  },

  //
  // Rename the label given by node globally
  //
  triggerRenameCollection: function() {
    (function() {
      var node = this.lastSelectedNode;
      this.treeEditor.on({
        complete: {
          scope: this,
          single: true,
          fn: this.commitRenameCollection
        }
      });

      this.treeEditor.triggerEdit(node);
    }.defer(10, this));
  },

  commitRenameCollection: function(editor, newText, oldText) {
    var node = editor.editNode;

    if (newText == oldText) {
      return;
    }
    var label = oldText;
    Paperpile.Ajax({
      url: '/ajax/crud/update_collection',
      params: {
        guid: node.id,
        name: newText
      },
      success: function(response) {
        if (node.type == 'LABEL') {
          Paperpile.main.triggerLabelStoreReload();
        } else if (node.type == 'FOLDER') {
          Paperpile.main.triggerFolderStoreReload();
        }
      },
      scope: this
    });
  },

  exportNode: function() {
    var node = this.lastSelectedNode;
    Paperpile.main.handleExport(null, null, node.id);
  },

  autoExportCheck: function(item, state) {
    var parentMenu = item.parentMenu;
    var node = parentMenu.node;
    var id = node.id;

    var filesync = this.getFileSyncData(node);
    var file = filesync.file || '';

    if (state === true && file === '') {
      this.autoExportClick(item, null);
    } else if (state === true) {
      filesync.active = 1;
      this.setFileSyncData(node, filesync);
      this.autoExportMessage(node.text, file);
      Paperpile.main.triggerFileSync([node.id]);
      parentMenu.hide();
    } else {
      filesync.active = 0;
      Paperpile.status.updateMsg({
        type: 'info',
        msg: 'De-activated BibTeX file sync for \'' + node.text + '\'',
        duration: 5
      });
      parentMenu.hide();
      this.setFileSyncData(node, filesync);
    }
  },

  autoExportClick: function(item, event) {
    var parentMenu = item.parentMenu;
    var node = parentMenu.node;

    var filesync = this.getFileSyncData(node);
    var initialFile = filesync.file || '';

    var stopMenuHide = function(menu) {
      return false;
    };
    //    parentMenu.on('beforehide', stopMenuHide);
    var callback = function(filenames) {
      if (filenames.length > 0) {
        var file = filenames[0];
        filesync.file = file;
        filesync.active = 1;
        parentMenu.hide();
        this.setFileSyncData(node, filesync);
        this.autoExportMessage(node.text, file);
        Paperpile.main.triggerFileSync([node.id]);
      } else {
        if (initialFile == '') {
          // We're left with no filesync file here, so we just have to disable
          // the filesync and un-check the checkbox.
          filesync.active = 0;
          this.setFileSyncData(node, filesync);
          item.setChecked(false, false);
          item.disableText();
        }
      }
      //      parentMenu.un('beforehide', stopMenuHide);
    };
    var options = {
      title: 'Choose BibTeX file',
      selectionType: 'file',
      types: ['bib'],
      typesDescription: 'BibTeX files',
      nameFilters: ["BibTeX (*.bib)"],
      dialogType: 'save',
      multiple: false,
      path: Paperpile.utils.splitPath(initialFile).dir,
      scope: this
    };
    Paperpile.fileDialog(callback, options);
  },

  setFileSyncData: function(node, params) {
    var filesync = Paperpile.main.getSetting('file_sync') || {};
    filesync[node.id] = params;
    Paperpile.main.setSetting('file_sync', filesync);
  },

  getFileSyncData: function(node) {
    var filesync = Paperpile.main.getSetting('file_sync');

    if (!filesync) {
      filesync = {};
    }
    if (!filesync[node.id]) {
      filesync[node.id] = {};
    }
    return filesync[node.id];
  },

  autoExportMessage: function(collection_name, file) {
    Paperpile.status.updateMsg({
      type: 'info',
      msg: 'References in folder \'' + collection_name + '\' will now sync to file ' + file,
      duration: 5
    });
  }

});

Paperpile.Tree.EXPORT_MENU_STRING = "Export...";
Paperpile.Tree.AUTO_EXPORT_MENU_STRING = "BibTeX Sync...";

Paperpile.Tree.ContextMenu = Ext.extend(Ext.menu.Menu, {
  node: null,
  tree: null,
  constructor: function(config) {
    Ext.apply(this, {
      tree: Paperpile.main.tree,
      plugins: [new Ext.ux.TDGi.MenuKeyTrigger()]
    });
    Paperpile.Tree.ContextMenu.superclass.constructor.call(this, config);
  },
  initComponent: function() {
    Paperpile.Tree.ContextMenu.superclass.initComponent.call(this);
    this.on('beforeshow', this.hideItems);
    this.on('beforehide',
      function() {
        this.allowSelect = false;
        this.tree.getSelectionModel().clearSelections();
      },
      this);
  },

  setNode: function(node) {
    this.node = node;
  },

  getShownItems: function(node) {
    return[];
  },

  initShownItems: function() {
    var shownIds = this.getShownItems(this.node);
    for (var i = 0; i < shownIds.length; i++) {
      this.items.get(shownIds[i]).enable();
    }

  },

  hideItems: function() {
    this.items.each(function(item) {
      item.hide();
    });
    var shownIds = this.getShownItems(this.node);
    for (var i = 0; i < shownIds.length; i++) {
      this.items.get(shownIds[i]).show();
    }

    this.initShownItems();
    //    this.doLayout();
  },

  showAt: function(pos, parentMenu) {
    Paperpile.Tree.ContextMenu.superclass.showAt.defer(10, this, [pos, parentMenu]);
  }

});

Paperpile.Tree.FolderMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;
    Ext.apply(this, {
      items: [{
        id: 'folder_menu_new',
        text: 'New Folder',
        handler: tree.newFolder,
        triggerKey: 'n',
        scope: tree
      },
      {
        id: 'folder_menu_delete',
        text: 'Delete',
        handler: tree.deleteCollection,
        triggerKey: 'd',
        scope: tree
      },
      {
        id: 'folder_menu_rename',
        text: 'Rename',
        handler: tree.triggerRenameCollection,
        triggerKey: 'r',
        scope: tree
      },
      {
        id: 'folder_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        triggerKey: 'e',
        scope: tree
      },
      {
        xtype: 'enabledisablecheckitem',
        id: 'folder_menu_auto_export',
        text: Paperpile.Tree.AUTO_EXPORT_MENU_STRING,
        hideOnClick: true,
        textDisabled: true,
        cls: 'pp-auto-export-menu-item',
        handler: tree.autoExportClick,
        checkHandler: tree.autoExportCheck,
        scope: tree
      }]
    });
    Paperpile.Tree.FolderMenu.superclass.initComponent.call(this);
  },

  initShownItems: function() {
    Paperpile.Tree.FolderMenu.superclass.initShownItems.call(this);
    var item = this.items.get('folder_menu_auto_export');
    if (Paperpile.main.tree.getFileSyncData(this.node).active == 1) {
      item.setChecked(true, true);
      item.enableText();
    } else {
      item.setChecked(false, true); // Second param is true to suppress event.
      item.disableText();
    }
  },

  getShownItems: function(node) {
    var items;
    if (node.id == 'FOLDER_ROOT') {
      items = [
        'folder_menu_new',
        'folder_menu_export'];
      if (Paperpile.main.getSetting('bibtex').bibtex_mode == 1) {
        items.push('folder_menu_auto_export');
      }
    } else {
      items = [
        'folder_menu_new',
        'folder_menu_delete',
        'folder_menu_rename',
        'folder_menu_export'];
      if (Paperpile.main.getSetting('bibtex').bibtex_mode == 1) {
        items.push('folder_menu_auto_export');
      }
    }
    return items;
  }

});

Paperpile.Tree.ActiveMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;
    Ext.apply(this, {
      items: [{
        id: 'active_menu_rss',
        //itemId does not work here
        iconCls: 'pp-icon-feed',
        text: 'Subscribe to RSS Feed',
        handler: function() {
          tree.newRSS();
        },
        scope: tree
      },
      {
        id: 'active_menu_delete',
        text: 'Delete',
        handler: tree.deleteActive,
        triggerKey: 'd',
        scope: tree
      },
      {
        id: 'active_menu_rename',
        text: 'Rename',
        handler: tree.renameNode,
        triggerKey: 'r',
        scope: tree
      },
      {
        id: 'active_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        triggerKey: 'e',
        scope: tree
      },
      {
        id: 'active_menu_configure',
        text: 'Show/Hide Items',
        handler: function() {
          this.tree.configureSubtree(this.node);
        },
        scope: this
      }]
    });
    Paperpile.Tree.ActiveMenu.superclass.initComponent.call(this);
  },

  getShownItems: function(node) {
    if (!node) {
      return[];
    }
    if (node.id == 'ACTIVE_ROOT') {
      return[];
    } else {
      return[
      'active_menu_delete',
      'active_menu_rename',
      'active_menu_export'];
    }
  }
});

Paperpile.Tree.ImportMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;

    Ext.apply(this, {
      items: [{
        id: 'import_menu_configure',
        text: 'Hide / Show Tools',
        handler: function() {
          this.tree.configureSubtree(this.node);
        },
        scope: this
      }]
    });
    Paperpile.Tree.ImportMenu.superclass.initComponent.call(this);
  },

  getShownItems: function(node) {
    if (node.id == 'IMPORT_PLUGIN_ROOT') {
      return[
      'import_menu_configure'];
    } else {
      return[];
    }
  }
});

Paperpile.Tree.LabelsMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;

    tree.sortByMenu = {
      items: [{
        id: 'sort_labels_by_name',
        text: 'Alphabetically',
        handler: tree.sortLabelsByName,
        scope: tree
      },
      {
        id: 'sort_labels_by_count',
        text: 'Paper Count',
        handler: tree.sortLabelsByCount,
        scope: tree
      }]
    };

    Ext.apply(this, {
      items: [{
        id: 'labels_menu_new',
        text: 'New Label',
        iconCls: 'pp-icon-label-new',
        triggerKey: 'n',
        handler: tree.newLabel,
        scope: tree
      },
      {
        id: 'labels_menu_style',
        text: 'Style',
        menu: tree.stylePickerMenu
      },
      {
        id: 'labels_menu_delete',
        text: 'Delete',
        handler: tree.deleteCollection,
        triggerKey: 'd',
        scope: tree
      },
      {
        id: 'labels_menu_rename',
        text: 'Rename',
        triggerKey: 'r',
        handler: tree.triggerRenameCollection,
        scope: tree
      },
      {
        id: 'labels_menu_hide',
        text: 'Hide from List',
        triggerKey: 'h',
        handler: tree.hideCollection,
        scope: tree
      },
      {
        id: 'labels_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        triggerKey: 'e',
        scope: tree
      },
      {
        id: 'sort_by_menu',
        text: 'Sort Labels',
        menu: tree.sortByMenu
      },
      {
        xtype: 'enabledisablecheckitem',
        id: 'labels_menu_auto_export',
        text: Paperpile.Tree.AUTO_EXPORT_MENU_STRING,
        hideOnClick: true,
        textDisabled: true,
        cls: 'pp-auto-export-menu-item',
        handler: tree.autoExportClick,
        checkHandler: tree.autoExportCheck,
        scope: tree
      }]
    });
    Paperpile.Tree.LabelsMenu.superclass.initComponent.call(this);
  },

  initShownItems: function() {
    Paperpile.Tree.LabelsMenu.superclass.initShownItems.call(this);
    var item = this.items.get('labels_menu_auto_export');
    if (Paperpile.main.tree.getFileSyncData(this.node).active == 1) {
      item.setChecked(true, true);
      item.enableText();
    } else {
      item.setChecked(false, true); // Second param is true to suppress event.
      item.disableText();
    }

    if (this.node.name == 'Incomplete' || this.node.name == 'Review') {
      item = this.items.get('labels_menu_delete');
      var str = 'This is a reserved label used by Paperpile and cannot be deleted';
      item.setDisabledTooltip(str);
      item.disable();

      item = this.items.get('labels_menu_rename');
      var str = 'This is a reserved label used by Paperpile and cannot be renamed';
      item.setDisabledTooltip(str);
      item.disable();
    }
  },

  getShownItems: function(node) {
    var items;
    if (node.id == 'LABEL_ROOT') {
      items = ['labels_menu_new',
        'sort_by_menu'];
    } else {
      items = [
        'labels_menu_style',
        'labels_menu_delete',
        'labels_menu_hide',
        'labels_menu_rename',
        'labels_menu_export'];
      if (Paperpile.main.getSetting('bibtex').bibtex_mode == 1) {
        items.push('labels_menu_auto_export');
      }
    }
    return items;
  }
});

Paperpile.Tree.TrashMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;

    Ext.apply(this, {
      items: [{
        id: 'trash_menu_empty',
        text: 'Empty Trash',
        triggerKey: 'e',
        handler: tree.handleEmptyTrash,
        scope: tree
      },
      ]
    });
    Paperpile.Tree.TrashMenu.superclass.initComponent.call(this);
  },

  getShownItems: function(node) {
    return['trash_menu_empty'];
  }
});

Paperpile.TreeLoader = Ext.extend(Ext.tree.TreeLoader, {

  createNode: function(attr) {
    var node = Paperpile.TreeLoader.superclass.createNode.call(this,attr);

      // We apply the passed attributes directly to the created node, so that
      // we can easily access things like node.type, node.plugin_params, etc.
      Ext.apply(node,attr);
      return node;
  }

});