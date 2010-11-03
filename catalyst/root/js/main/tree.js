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
      loader: new Paperpile.TreeLoader({
        url: Paperpile.Url('/ajax/tree/get_node'),
        requestMethod: 'GET'
      }),
      root: {
        nodeType: 'async',
        text: 'Root',
        leaf: false,
        id: 'ROOT'
      },
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
        stopEvent: false
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
      load: {
        scope: this,
        fn: function(node) {

          if (node.id == "TAGS_ROOT") {

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
              this.on({
                beforeappend: {
                  fn: function(tree, parent, node, index) {
                    if (node.id == 'MORE_LABELS') {
                      if (this.labelPanel && this.labelPanel.isVisible()) {
                        this.labelPanel.alignTo.defer(1, this.labelPanel, [this.moreLabelsNode.ui.getTextEl()]);
                      }
                    }
                  },
                  scope: this
                }
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
                  this.reloadTags();
                }

              },
              this);
              this.labelPanel.on('beforeshow', function() {
                this.hideShowMode = true;
                this.reloadTags();
                var el = Ext.fly(this.moreLabelsNode.getUI().getEl());
                if (el) {
                  el.addClass('more-labels-node-down');
                }
              },
              this);
              this.labelPanel.setVisible(false);
            }

            this.reloadTags();
          }

          // This is necessary because we load the tree as a whole
          // during startup but want to re-load single nodes
          // afterwards. We achieve this by removing the children
          // array which gets stored in node.attributes
          delete node.attributes.children;

          // Here's where we ensure that only "rename-able" nodes are set as editable.
          if (this.isNodeDraggable(node) && (node.type == "TAGS" || node.type == "FOLDER" || node.type == "ACTIVE")) {
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

  isNodeDraggable: function(node) {
    var id = node.id;
    // Root nodes not allowed.
    if (id === 'ROOT' || id === 'FOLDER_ROOT' || id === 'LOCAL_ROOT' || id === 'TAGS_ROOT' || id === 'TRASH' || id === 'ACTIVE_ROOT' || id === 'IMPORT_PLUGIN_ROOT') {
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
        //   -> if dragging from the grid over the Tags, it should always be in "append" mode.
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

  myOnClick: function(node, e) {
    if (e != null) {
      // Only take clicks that occur right within the node text area.
      var targetEl = e.getTarget("span", 10, true);
      if (!targetEl) {
        return;
      }
    }
    switch (node.id) {
    case 'FOLDER_ROOT':
      var main = Paperpile.main.tabs.getItem("MAIN");
      Paperpile.main.tabs.activate(main);
      return;
    case 'TAGS_ROOT':
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
    case 'IMPORT_PLUGIN':
    case 'TAGS':
    case 'FOLDER':
    case 'ACTIVE':
      // Collect plugin paramters
      var pars = {};
      for (var key in node) {
        if (key.match('plugin_')) {
          pars[key] = node[key];
        }
      }

      // Use default title and css for tab
      var title = pars.plugin_title;
      var iconCls = null;

      // For tags use specifically styled tab
      if (node.type == 'TAGS') {
        pars.collection_type = 'label';
        iconCls = 'pp-tag-style-tab ' + 'pp-tag-style-' + node.style;
        title = node.text;
      }

      if (node.type == 'FOLDER') {
        pars.collection_type = 'folder';
      }

      // For now we reload feeds whenever they are opened 
      if (pars.plugin_name == 'Feed') {
        pars.plugin_reload = 1;
      }

      // Call appropriate frontend, tags, active folders, and folders are opened only once
      // and we pass the node.id as item-id for the tab
      Paperpile.main.tabs.newPluginTab(node.plugin_name, pars, title, iconCls, node.id);
      break;

    default:
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
      if (myType == 'TAGS') {
        proxy.updateTip('Apply label to reference');
      } else if (myType == 'FOLDER') {
        proxy.updateTip('Place reference in folder');
      } else {
        proxy.updateTip('');
      }
    } else if (e.data.node) {
      var myType = e.data.node.attributes.type;
      var targetType = target.attributes.type;
      if (myType == 'TAGS' && targetType == 'TAGS') {
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
      // only allow drop on Folders, Tags and Trash
      if ((e.target.type == 'TAGS' || e.target.type == 'FOLDER' || e.target.type == 'TRASH') && e.target.id != 'TAGS_ROOT') {
        if (e.target.type == 'TRASH') {
          var imported = e.source.dragData.grid.getSelection('IMPORTED');
          if (imported.length == 0) {
            e.cancel = true;
          }
        } else if (e.target.type == 'TAGS') {
          // Be genreally permissive for trash and tags.
          e.cancel = false;
        } else if (e.target.type == 'FOLDER') {
          e.cancel = false;
        }
      } else {
        // Cancel if not on a folder, tag or trash.
        e.cancel = true;
      }
    } else {
      // We are dragging internal nodes from the tree
      // Only allow operations within the same subtree,
      // i.e. nodes are of the same type
      if (!this.areNodeTypesCompatible(e.source.dragData.node.type, e.target.type)) {
        e.cancel = true;
      } else if (e.target.type == 'TAGS' && e.point == 'append') {
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

  addTag: function(grid, sel, node) {
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
      } else if (e.target.type == 'TAGS') {
        this.addTag(grid, sel, node);
      } else if (node.type == 'TRASH') {
        grid.deleteEntry('TRASH');
      }
    } else {
      // We're dragging nodes internally
      if (node.type === 'FOLDER' || node.type === 'TAGS') {

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
          enableToggle: true,
          style: {
            'position': 'relative',
            'float': 'right'
          },
          scale: 'tiny',
          tooltip: 'Add a new journal or RSS feed',
          icon: Paperpile.Url('/images/icons/plus.png')
        });
        this.rssButton.render(ui.elNode);
        this.rssButton.getEl().alignTo(ui.elNode, 'r-r', [-2, 0]);
        this.rssButton.on('toggle', this.rssButtonToggle,
          this);
      }
    },
    this);

    this.mon(this.el, 'mousedown', this.myMouseDown, this);

  },

  myMouseDown: function(e) {
    var target = e.target;
    var el = Ext.fly(target);
    if (el.findParent(".more-labels-node", 5)) {
      e.stopEvent();
      this.moreLabelsDown();
      return;
    }
  },

  moreLabelsDown: function() {
    var textEl = this.moreLabelsNode.getUI().getTextEl();
    if (!this.labelPanel.isVisible()) {
      this.labelPanel.alignTo(textEl);
      this.labelPanel.refresh();
      this.labelPanel.show();
    } else {
      this.labelPanel.hide();
    }
  },

  onContextMenu: function(node, e) {
    // Save the position before preparing the menu -- if we don't do this,
    // the event becomes a 'blur' event and we lose the position info!
    var pos = e.getXY();
    var menu = this.prepareMenu(node, e);
    if (menu !== null) {
      this.showMenu(menu, pos, e);
    }
  },

  prepareMenu: function(node, e) {
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

  showMenu: function(menu, position, e) {
    menu.showAt(position);
  },

  prepareMenuBeforeShowing: function(node, menu) {
    if (node.type == 'FOLDER' || node.type == 'TAGS') {
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
    var menus = [this.folderMenu, this.activeMenu, this.importMenu, this.tagsMenu, this.trashMenu, this.defaultMenu];
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

    case 'TAGS':
      if (this.tagsMenu == null) {
        this.tagsMenu = new Paperpile.Tree.TagsMenu();
      }
      menu = this.tagsMenu;
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
      //      Paperpile.log(childNode.id);
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
    //    Paperpile.log(nodes.length);
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
        this.newFeedPanel.hide();
        this.rssButton.toggle(false, true);
      };
      this.newFeedPanel = new Paperpile.NewFeedPanel({
        callback: callback.createDelegate(this)
      });
    }
    var panel = this.newFeedPanel;
    if (buttonState === true) {
      panel.show();
      Ext.QuickTips.getQuickTip().hide();
      panel.getEl().alignTo(button.getEl(), 'tl-bl');
    } else {
      panel.hide();
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
      newNode = n.appendChild(this.loader.createNode({
        text: 'New Folder',
        iconCls: 'pp-icon-folder',
        draggable: true,
        expanded: true,
        children: [],
        // Important: Folders must not be created as leaf nodes, because they need to be able to hold other folders.
        leaf: false,
        // Also important: use the loaded:true parameter to signal the UI that there aren't children waiting to be loaded. Things mess up without this!!!
        loaded: true,
        id: Paperpile.utils.generateUUID()
      }));

      var pars = {
        type: 'FOLDER',
        plugin_query: 'folderid:' + newNode.id,
        plugin_base_query: 'folderid:' + newNode.id,
        plugin_name: 'DB',
        plugin_title: newNode.text,
        plugin_iconCls: 'pp-icon-folder',
        plugin_mode: 'FULLTEXT'
      };
      newNode.init(pars);

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
        if (node.type === 'TAGS') {
          var json = Ext.util.JSON.decode(response.responseText);
          Paperpile.main.triggerTagStoreReload();
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
        Paperpile.main.triggerTagStoreReload();
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

    Paperpile.Ajax({
      url: '/ajax/crud/delete_collection',
      params: {
        guid: node.id,
        type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL'
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        if (node.type === 'TAGS') {
          // Close the tab using the label's GUID, which is the node's id and the tab's itemId.
          Paperpile.main.tabs.closeTabById.defer(100, Paperpile.main.tabs, [node.id]);
          Paperpile.main.triggerTagStoreReload();
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

    if (node.type == 'TAGS') {
      var store = Ext.StoreMgr.lookup('tag_store');
      var tagIndex = store.findExact('guid', node.id);
      if (tagIndex !== -1) {
        var record = store.getAt(tagIndex);
        var hidden = 1;
        if (checked) {
          hidden = 0;
        }
        record.set('hidden', hidden);
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

  newTag: function() {
    var node = this.getNodeById('TAGS_ROOT');
    var treeEditor = this.treeEditor;
    var newNode;
    var tag = 'New Label';
    node.expand(false, false, function(n) {

      newNode = this.loader.createNode({
        text: tag,
        iconCls: 'pp-icon-empty',
        tagStyle: 'default',
        cls: 'pp-tag-tree-node pp-tag-tree-style-0',
        draggable: true,
        leaf: true,
        expanded: true,
        children: [],
        id: Paperpile.utils.generateUUID(),
        type: 'TAGS',
        plugin_name: 'DB',
        plugin_title: tag,
        plugin_iconCls: 'pp-icon-tag',
        plugin_mode: 'FULLTEXT',
        plugin_query: 'labelid:' + Paperpile.utils.encodeTag(tag),
        plugin_base_query: 'labelid:' + Paperpile.utils.encodeTag(tag)
      });
      if (this.moreLabelsNode) {
        node.insertBefore(newNode, this.moreLabelsNode);
      } else {
        Paperpile.log("Wazza");
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

  containsTagWithText: function(text) {
    var tagIndex = Ext.StoreMgr.lookup('tag_store').findExact('tag', text);
    if (tagIndex > -1) {
      return true;
    }
    return false;
  },

  getNodeBreadcrumb: function(node, separator, limit_id) {
    var string = node.text;
    node = node.parentNode;
    while (node) {
      if (node.id == limit_id) {
        return string;
      }
      string = node.text + separator + string;
      node = node.parentNode;
    }
    return string;
  },

  getUniqueFolderBreadcrumb: function(node) {
    var folderRoot = this.getNodeById('FOLDER_ROOT');
    var leaves = this.getAllLeafNodes(folderRoot);
    var name_hash;
    for (var i = 0; i < leaves.length; i++) {
      var leaf = leaves[i];
      var bc = this.getNodeBreadcrumb(leaf, "_", 'FOLDER_ROOT');
      if (leaves[bc] === undefined) {
        leaves[bc] = 0;
      } else {
        leaves[bc]++;
      }
      if (leaf === node) {
        var uniqueName = bc;
        var suffix = "";
        if (leaves[bc] > 0) {
          suffix = "_" + leaves[bc];
        }
        return uniqueName + suffix;
      }
    }
  },

  getUniqueTag: function(text) {
    var base = text;
    var i = 2;
    while (this.containsTagWithText(text)) {
      text = base + " (" + i + ")";
      i++;
    }
    return text;
  },

  sortAndHideTags: function() {
    Paperpile.Ajax({
      url: '/ajax/crud/sort_and_hide_labels',
      params: {},
      success: function() {
        var store = Ext.StoreMgr.lookup('tag_store');
        var hidden_store = Ext.StoreMgr.lookup('hidden_tag_store');
        store.reload({
          callback: function() {
            var totalCount = store.getTotalCount();
            var hidden_total = hidden_store.getCount();
            Paperpile.status.updateMsg({
              type: 'info',
              msg: totalCount + " labels were auto-arranged (" + hidden_total + " now hidden from view)",
              fade: true,
              duration: 3.5
            });

          }
        });
      },
      scope: this
    });
  },

  sortTagsByCount: function() {
    Paperpile.Ajax({
      url: '/ajax/crud/sort_labels_by_count',
      params: {},
      success: function() {
        Ext.StoreMgr.lookup('tag_store').reload();
        Paperpile.status.updateMsg({
          type: 'info',
          msg: totalCount + " labels were sorted by paper count.",
          fade: true,
          duration: 1.5
        });
      },
      scope: this
    });
  },

  sortTagsByName: function() {
    Paperpile.Ajax({
      url: '/ajax/crud/sort_labels_by_name',
      params: {},
      success: function() {
        Ext.StoreMgr.lookup('tag_store').reload();
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
        Ext.StoreMgr.lookup('tag_store').reload();
      },
      scope: this
    });
  },

  hideCollection: function() {
    var store = Ext.StoreMgr.lookup('tag_store');
    var node = this.lastSelectedNode;
    var index = store.findExact('guid', node.id);
    if (index !== -1) {
      record = store.getAt(index);
      record.set('hidden', 1);
      store.updateCollection(record);
    }
  },

  // Data is the JSON returned by a previous ajax call. Optional.
  reloadTags: function(json) {
    if (json && json.data) {
      json.data.collection_delta = 0;
      Paperpile.main.onUpdate(json.data);
    }

    var tagsRoot = this.getNodeById('TAGS_ROOT');
    if (!tagsRoot) {
      return;
    }
    tagsRoot.silentLoad = true;
    tagsRoot.removeAll();

    var hiddenNodeCount = 0;

    var store = Ext.StoreMgr.lookup('tag_store');
    for (var i = 0; i < store.getCount(); i++) {
      var record = store.getAt(i);
      if (record.get('hidden') !== 1) {
        var node = this.recordToNode(record, 'TAGS');
        tagsRoot.appendChild(node);
      } else {
        hiddenNodeCount++;
      }
    }

    if (hiddenNodeCount > 0) {
      this.moreLabelsNode.setText(hiddenNodeCount + " more...");
      tagsRoot.appendChild(this.moreLabelsNode);
    } else {
      if (this.labelPanel.isVisible()) {
        this.labelPanel.hide();
      }
    }

    tagsRoot.expand();
  },

  recordToNode: function(record, type) {
    var pars = {
      id: record.get('guid'),
      text: record.get('name'),
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
      plugin_title: record.get('name')
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
      pars.cls = "pp-tag-node pp-tag-tree-node pp-tag-tree-style-" + record.get('style');
      pars.iconCls = "pp-icon-empty";
      pars.type = 'TAGS';
      pars.plugin_query = "labelid:" + record.get('guid');
      pars.plugin_base_query = "labelid:" + record.get('guid');
      pars.plugin_iconCls = "pp-icon-tag";
      pars.tagStyle = record.get('style');
    }
    var node = this.loader.createNode(pars);
    //    Paperpile.log(node);
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
        Paperpile.main.triggerTagStoreReload();
      },
      scope: this
    });
  },

  //
  // Rename the tag given by node globally
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
    var tag = oldText;
    Paperpile.Ajax({
      url: '/ajax/crud/update_collection',
      params: {
        guid: node.id,
        name: newText
      },
      success: function(response) {
        Paperpile.main.triggerTagStoreReload();
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
      tree: Paperpile.main.tree
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
        scope: tree
      },
      {
        id: 'folder_menu_delete',
        text: 'Delete',
        handler: tree.deleteCollection,
        scope: tree
      },
      {
        id: 'folder_menu_rename',
        text: 'Rename',
        handler: tree.triggerRenameCollection,
        scope: tree
      },
      {
        id: 'folder_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
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
        scope: tree
      },
      {
        id: 'active_menu_rename',
        text: 'Rename',
        handler: tree.renameNode,
        scope: tree
      },
      {
        id: 'active_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
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

Paperpile.Tree.TagsMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;

    tree.sortByMenu = {
      items: [{
        id: 'sort_tags_by_name',
        text: 'Alphabetically',
        handler: tree.sortTagsByName,
        scope: tree
      },
      {
        id: 'sort_tags_by_count',
        text: 'Paper Count',
        handler: tree.sortTagsByCount,
        scope: tree
      }]
    };

    Ext.apply(this, {
      items: [{
        id: 'tags_menu_new',
        text: 'New Label',
        iconCls: 'pp-icon-tag-new',
        handler: tree.newTag,
        scope: tree
      },
      {
        id: 'tags_menu_arrange',
        iconCls: 'pp-icon-clean',
        text: 'Auto-arrange Labels',
        handler: tree.sortAndHideTags,
        scope: tree
      },
      {
        id: 'tags_menu_style',
        text: 'Style',
        menu: tree.stylePickerMenu
      },
      {
        id: 'tags_menu_delete',
        text: 'Delete',
        handler: tree.deleteCollection,
        scope: tree
      },
      {
        id: 'tags_menu_rename',
        text: 'Rename',
        handler: tree.triggerRenameCollection,
        scope: tree
      },
      {
        id: 'tags_menu_hide',
        text: 'Hide from List',
        handler: tree.hideCollection,
        scope: tree
      },
      {
        id: 'tags_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        scope: tree
      },
      {
        id: 'sort_by_menu',
        text: 'Sort Labels',
        menu: tree.sortByMenu
      },
      {
        xtype: 'enabledisablecheckitem',
        id: 'tags_menu_auto_export',
        text: Paperpile.Tree.AUTO_EXPORT_MENU_STRING,
        hideOnClick: true,
        textDisabled: true,
        cls: 'pp-auto-export-menu-item',
        handler: tree.autoExportClick,
        checkHandler: tree.autoExportCheck,
        scope: tree
      }]
    });
    Paperpile.Tree.TagsMenu.superclass.initComponent.call(this);
  },

  initShownItems: function() {
    var item = this.items.get('tags_menu_auto_export');
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
    if (node.id == 'TAGS_ROOT') {
      items = ['tags_menu_new',
        'tags_menu_arrange',
        'sort_by_menu'];
    } else {
      items = [
        'tags_menu_style',
        'tags_menu_delete',
        'tags_menu_hide',
        'tags_menu_rename',
        'tags_menu_export'];
      if (Paperpile.main.getSetting('bibtex').bibtex_mode == 1) {
        items.push('tags_menu_auto_export');
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

// Extend TreeNode to allow to pass additional parameters from the server,
// Note that TreeNode is not a 'component' but only an observable, so we
// can't override as usual but have do define (and call) an init function
// for ourselves.
Paperpile.AsyncTreeNode = Ext.extend(Ext.tree.AsyncTreeNode, {
  init: function(attr) {
    Ext.apply(this, attr);
  }

});

Paperpile.TreeNode = Ext.extend(Ext.tree.TreeNode, {
  init: function(attr) {
    Ext.apply(this, attr);
  }

});

// To use our custom TreeNode we also have to override TreeLoader
Paperpile.TreeLoader = Ext.extend(Ext.tree.TreeLoader, {

  // This function is taken from extjs-debug.js and modified
  createNode: function(attr) {
    if (this.baseAttrs) {
      Ext.applyIf(attr, this.baseAttrs);
    }
    if (this.applyLoader !== false) {
      attr.loader = this;
    }
    if (typeof attr.uiProvider == 'string') {
      attr.uiProvider = this.uiProviders[attr.uiProvider] || eval(attr.uiProvider);
    }

    // Return our custom TreeNode here
    if (attr.leaf) {
      var node = new Paperpile.TreeNode(attr);
      node.init(attr);
      return node;
    } else {
      var node = new Paperpile.AsyncTreeNode(attr);
      node.init(attr);
      return node;
    }

    // code in the original implementation
    //if(attr.nodeType){
    //    return new Ext.tree.TreePanel.nodeTypes[attr.nodeType](attr);
    //}else{
    //    return attr.leaf ?
    //        new Ext.tree.TreeNode(attr) :
    //        new Ext.tree.AsyncTreeNode(attr);
    //}
  }

});

Ext.reg('tree', Paperpile.Tree);