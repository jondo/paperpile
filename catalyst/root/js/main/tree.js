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
      load: {
        scope: this,
        fn: function(node) {
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
        fn: function(node) {
          if (node.id == 'TAGS_ROOT') {
            this.updateScrollSize();
          }
        }
      },
      insert: {
        scope: this,
        fn: function(tree, parent, node, refNode) {}
      },
      resize: {
        scope: this,
        // Set scroll size the first time, when the node is rendered
        fn: function(node) {
          this.updateScrollSize();
        }
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

  updateScrollSize: function() {
    var node = this.getNodeById('TAGS_ROOT');

    // Make sure everything is rendered; this allows to call the function via the 'resize' event;
    if (node) {
      if (node.rendered) {
        var el = Ext.Element.get(node.ui.getEl());
        var curHeight = el.getHeight();

        var maxHeight = Paperpile.main.globalSettings['tags_list_height'];
        if (!maxHeight) {
          //maxHeight=Math.round(this.getInnerHeight()/3);
          //Paperpile.main.storeSettings({tags_list_height:maxHeight});
        }

        var wrap = Ext.get('pp-labels-wrap');
        if (!wrap) {
          wrap = el.wrap({
            tag: 'div',
            id: 'pp-labels-wrap'
          });
        }

        el.setStyle('overflow', 'auto');

        if (maxHeight) {
          wrap.setStyle('height', maxHeight + "px");
          el.setStyle('height', maxHeight + "px");
        }

        this.tagResizer = new Ext.Resizable(wrap.id, {
          handles: 's',
          minHeight: 30,
          pinned: true
        });
        this.tagResizer.on('resize', function(resizer, w, h, e) {
          wrap.setStyle('height', h + "px");
          el.setStyle('height', h + "px");
          Paperpile.main.storeSettings.defer(20, this, [{
            tags_list_height: h
          }]);
        },
        this);

        wrap.on('mouseover', function() {
          this.tagResizer.south.el.show();
        },
        this);
        wrap.on('mouseout', function() {
          this.tagResizer.south.el.hide();
        },
        this);

        this.tagResizer.south.el.set({
          'ext:qtip': "Resize the Labels area"
        });
        this.tagResizer.south.el.hide();
      }
    }
  },

  myOnClick: function(node, e) {
    // Only count clicks that occur right within the node text area.
    var targetEl = e.getTarget("span", 10, true);
    if (!targetEl) {
      return;
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
      if (window.UserVoice) {
        UserVoice.Popin.show()
      };
      break;
    case 'DUPLICATES':
      Paperpile.main.tabs.newPluginTab('Duplicates', {},
        "Duplicates", "pp-icon-duplicates", "duplicates")
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
        iconCls = 'pp-tag-style-tab ' + 'pp-tag-style-' + Paperpile.main.getStyleForTag(node.id);
        title = node.text;
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
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/move_in_collection'),
      params: {
        grid_id: grid.id,
        selection: sel,
        guid: node.id,
        type: 'FOLDER'
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  addTag: function(grid, sel, node) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/move_in_collection'),
      params: {
        grid_id: grid.id,
        selection: sel,
        guid: node.id,
        type: 'LABEL'
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: Paperpile.main.onError,
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

        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/crud/move_collection'),
          params: {
            target_node: e.target.id,
            drop_node: e.dropNode.id,
            point: e.point,
            type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL'
          },
          success: function() {
            // Should we do something here?
          },
          failure: Paperpile.main.onError
        });

      } else {

        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/tree/move_node'),
          params: {
            target_node: e.target.id,
            drop_node: e.dropNode.id,
            point: e.point
          },
          success: function() {
            // Should we do something here?
          },
          failure: Paperpile.main.onError
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
  },

  onContextMenu: function(node, e) {
    // Note: this doesn't actually get called when the tree context triangle plugin is loaded.
    var menu = this.getContextMenu(node);
    if (menu != null) {
      if (menu.getShownItems(node).length > 0) {
        this.allowSelect = true;
        node.select();
        this.allowSelect = false;
        menu.setNode(node);
        menu.render();
        menu.hideItems();
        menu.showAt(e.getXY());

        if (node.type == 'FOLDER') {
          this.createAutoExportTip(menu);
        }
      }
    }
  },

  createAutoExportTip: function(contextMenu) {
    this.autoExportTip = new Ext.ToolTip({
      trackMouse: false,
      anchor: 'left',
      showDelay: 300,
      hideDelay: 100,
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

    if (item.textDisabled) {
      return "Auto-export disabled";
    } else {
      var exportFile = this.getAutoExportLocation(node);
      var displayText = [
        '<b>',
        exportFile,
        '</b>',
        '<br/>Click to change'].join("");
      return displayText;
    }
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
	Paperpile.log(childNode.id);
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
      Paperpile.log(nodes.length);
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
      parent_id: node.parentNode.id,
    });

    // Send to backend
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/new_active'),
      params: pars,
      success: function() {
        //Ext.getCmp('statusbar').clearStatus();
        //Ext.getCmp('statusbar').setText('Added new active folder');
      },
      failure: Paperpile.main.onError,
    });

  },

  newRSS: function() {
    var window = new Paperpile.NewFeedWindow({});
    window.show();
  },

  createNewFeedNode: function(feedUrl) {

    var n = this.getNodeById('ACTIVE_ROOT');
    var newNode = n.appendChild(this.loader.createNode({
      text: 'Loading feed',
      iconCls: 'pp-icon-loading',
      qtip: feedUrl,
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

    Paperpile.status.showBusy("Loading new RSS feed");
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/new_rss'),
      params: pars,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        if (json.error) {
          Paperpile.main.onError(response);
          newNode.remove();
        } else {
          newNode.setText(json.title);
          newNode.plugin_title = json.title;
          Ext.get(newNode.getUI().getIconEl()).replaceClass('pp-icon-loading', 'pp-icon-feed');
        }
        Paperpile.status.clearMsg();
      },
      failure: function(response) {
        Paperpile.main.onError(response),
        newNode.remove();
      }
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

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/new_collection'),
      params: {
        type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL',
        text: node.text,
        node_id: node.id,
        parent_id: node.type === 'FOLDER' ? node.parentNode.id : 'ROOT'
      },
      success: function(response) {
        if (node.type === 'TAGS') {
          var json = Ext.util.JSON.decode(response.responseText);
          this.reloadTags(json);
        }
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  //
  // Deletes RSS feed
  //
  deleteRss: function() {
    var node = this.getSelectionModel().getSelectedNode();

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/delete_rss'),
      params: {
        node_id: node.id
      },
      success: function() {},
      failure: Paperpile.main.onError,
    });

    node.remove();
  },

  //
  // Deletes active folder
  //
  deleteActive: function() {
    var node = this.getSelectionModel().getSelectedNode();

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/delete_active'),
      params: {
        node_id: node.id
      },
      success: function() {},
      failure: Paperpile.main.onError,
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

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/save_node_params'),
      params: pars,
      success: function() {},
      failure: Paperpile.main.onError
    });

  },

  //
  // Rename node
  //
  onRenameComplete: function(editor, newText, oldText) {

    editor.editNode.plugin_title = newText;
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/rename_node'),
      params: {
        node_id: editor.editNode.id,
        new_text: newText
      },
      success: function() {
        editor.un("complete", this.onRenameComplete);
      },
      failure: Paperpile.main.onError
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

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_collection'),
      params: {
        guid: node.id,
        type: node.type === 'FOLDER' ? 'FOLDER' : 'LABEL'
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        if (node.type === 'TAGS') {
          // Close the tab using the label's GUID, which is the node's id and the tab's itemId.
          Paperpile.main.tabs.closeTabById(node.id);
          this.reloadTags(json);
        } else {
          Paperpile.main.onUpdate(json.data);
        }
      },
      scope: this,
      failure: Paperpile.main.onError
    });
    node.remove();
  },

  deleteFolder: function() {
    var node = this.lastSelectedNode;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_collection'),
      params: {
        guid: node.id,
        type: 'FOLDER'
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: Paperpile.main.onError,
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

    var hidden = 1;
    if (checked) {
      hidden = 0;
    }

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/set_visibility'),
      params: {
        node_id: node.id,
        hidden: hidden
      },
      success: function() {
        //Ext.getCmp('statusbar').clearStatus();
        //Ext.getCmp('statusbar').setText('Hide/Show node');
      },
      failure: Paperpile.main.onError,

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
      newNode = n.appendChild(
        this.loader.createNode({
          text: tag,
          iconCls: 'pp-icon-empty',
          tagStyle: 'default',
          cls: 'pp-tag-tree-node pp-tag-tree-style-0',
          draggable: true,
          leaf: true,
          expanded: true,
          children: [],
          id: Paperpile.utils.generateUUID()
        }));
      var pars = {
        type: 'TAGS',
        plugin_name: 'DB',
        plugin_title: tag,
        plugin_iconCls: 'pp-icon-tag',
        plugin_mode: 'FULLTEXT',
        plugin_query: 'labelid:' + Paperpile.utils.encodeTag(tag),
        plugin_base_query: 'labelid:' + Paperpile.utils.encodeTag(tag)
      };
      newNode.init(pars);
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

  sortTagsByCount: function() {
    // The counts of articles for each label aren't stored in the frontend,
    // so we call the backend to give us a sorted list of GUIDs.
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/list_labels_sorted'),
      params: {},
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        var data = json.data;

        var ids = [];
        for (var i = 0; i < data.length; i++) {
          var id = data[i].id;
          var node = this.getNodeById(id);
          ids.push(node.id);
        }

        this.setCollectionSort(ids);
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  sortTagsByName: function() {
    var root = this.getNodeById('TAGS_ROOT');

    var tagCollection = new Ext.util.MixedCollection();
    root.eachChild(function(node) {
      tagCollection.add(node.id, node);
    });

    tagCollection.sort('ASC', function(a, b) {
      return a.text.localeCompare(b.text);
    });

    var sortedIds = [];
    tagCollection.each(function(obj) {
      sortedIds.push(obj.id);
    });

    this.setCollectionSort(sortedIds);
  },

  setCollectionSort: function(idList) {
    var firstNodeId = idList[0];
    var firstNode = this.getNodeById(firstNodeId);
    var parentNode = firstNode.parentNode;
    var parentId = parentNode.id;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/sort_collection'),
      params: {
        parent_id: parentId,
        node_id_order: idList
      },
      success: function() {
        this.reloadTags();
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  },

  // Data is the JSON returned by a previous ajax call. Optional.
  reloadTags: function(json) {
    Ext.StoreMgr.lookup('tag_store').reload({
      callback: function() {
        if (json) {
          Paperpile.main.onUpdate(json.data);
        }
      }
    });
    var tagsRoot = this.getNodeById('TAGS_ROOT');
    tagsRoot.silentLoad = true;
    delete tagsRoot.attributes.children;
    tagsRoot.reload();
    tagsRoot.eachChild(function(node) {
      node.render(true);
    });
  },

  //
  // Is called after a new tag has been created. Writes tag
  // information to database and updates and saves tree
  // representation to database.
  //
  // [greg] nuke me -- I think we can get rid of this method...
  onNewTag: function(node) {
    node.setText(this.getUniqueTag(node.text));

    var index = node.parentNode.indexOf(node);

    var tag = node.text;
    var pars = {
      tag: tag,
      style: 'default',
      sort_order: index
    };

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/new_tag'),
      params: pars,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        this.reloadTags(json);
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  // [greg] nuke me.
  deleteTag: function(node) {
    var tag = node.text;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_tag'),
      params: {
        tag: tag
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        node.remove();
        this.reloadTags(json);
        Paperpile.main.tabs.closeTabByTitle(tag);
      },
      scope: this
    });
  },

  styleCollection: function(number) {
    var node = this.lastSelectedNode;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/style_collection'),
      params: {
        guid: node.id,
        style: number,
        type: 'LABEL'
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.reloadTagStyles();
      },
      failure: Paperpile.main.onError,
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

    node.setText(newText);
    node.plugin_title = newText;

    var tag = oldText;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/rename_collection'),
      params: {
        guid: node.id,
        new_name: newText,
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        // Things we need to rename / update when a collection changes:
        // (1) use the onUpdate handlers to take care of the grid and sidepanel.
        Paperpile.main.onUpdate(json);
        this.reloadTags(json);

        // (2) If this tab has an open grid, rename it.
        var openTab = Paperpile.main.tabs.find("itemId", node.id); // Find by GUID.
        if (openTab.length > 0) {
          openTab[0].setTitle(newText);
        }

      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  //
  // Rename the tag given by node globally
  //
  // [greg] nuke me.
  triggerRenameTag: function() {
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

  // [greg] nuke me.
  commitRenameTag: function(editor, newText, oldText) {
    var node = editor.editNode;

    if (newText == oldText) {
      return;
    }
    newText = this.getUniqueTag(newText);

    node.setText(newText);
    node.plugin_title = newText;
    node.plugin_query = 'labelid:' + Paperpile.utils.encodeTag(newText);
    node.plugin_base_query = 'labelid:' + Paperpile.utils.encodeTag(newText);
    var tag = oldText;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/rename_tag'),
      params: {
        old_tag: tag,
        new_tag: newText
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        // If this tab has an open grid, rename it.
        var tagTab = Paperpile.main.tabs.find("title", oldText);
        if (tagTab.length > 0) {
          tagTab[0].setTitle(newText);
        }

        Paperpile.main.onUpdate(json);
        this.reloadTags(json);
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  exportNode: function() {
    var node = this.lastSelectedNode;

    var window = new Paperpile.SimpleExportWindow({
      source_node: node.id
    });
    window.show();
  },

  autoExportCheck: function(item, state) {
    var parentMenu = item.parentMenu;
    var node = parentMenu.node;
    if (state === true) {
      node['plugin_auto_export_enable'] = true;
      var exportFile = this.getAutoExportLocation(node);
      this.autoExportMessage(node.text, exportFile);
      //this.saveNode(node);
      Ext.Ajax.request({
        url: Paperpile.Url('/ajax/misc/set_file_sync'),
        params: {
          guid: node.id,
          file: exportFile,
          active: 1
        },
        success: function() {
          //update Paperpile.main.globalSettings here (is faster than
          //reload everything from the backend)
        },
        failure: Paperpile.main.onError
      });
    } else {
      //node['plugin_auto_export_enable'] = false;
      //this.saveNode(node);
    }
  },

  getAutoExportLocation: function(node) {
    // Gets either (a) the defined auto-export location from the node's plugin parameters, or (b) a location defined based on the folder name and ID.
    var export_file = node['plugin_auto_export_file'] || '';

    var export_filetype = Paperpile.main.globalSettings['auto_export_filetype'] || '.bib';

    if (export_file === '') {
      var unique_folder_label = this.getUniqueFolderBreadcrumb(node);
      var file_name = unique_folder_label + export_filetype;
      export_file = Paperpile.main.globalSettings.user_home + '/' + file_name;
    }
    return export_file;
  },

  autoExportClick: function(item, event) {
    var parentMenu = item.parentMenu;
    var node = parentMenu.node;

    var initialFile = this.getAutoExportLocation(node);
    var parts = Paperpile.utils.splitPath(initialFile);

    var stopMenuHide = function(menu) {
      return false;
    };
    parentMenu.on('beforehide', stopMenuHide);

    win = new Paperpile.FileChooser({
      saveMode: true,
      saveDefault: parts.file,
      currentRoot: parts.dir,
      warnOnExisting: true,
      callback: function(button, path) {
        parentMenu.un('beforehide', stopMenuHide);
        if (button == 'OK') {
          node['plugin_auto_export_file'] = path;
          this.saveNode(node);
          parentMenu.hide();

          this.autoExportMessage(node.text, path);
        }
      },
      scope: this
    });
    win.show();
    return false;
  },

  autoExportMessage: function(folder, file) {
    Paperpile.status.updateMsg({
      type: 'info',
      msg: 'References in folder \'' + folder + '\' will now auto-export to ' + file,
      hideOnClick: true,
      duration: 5
    });
  }

});

Paperpile.Tree.EXPORT_MENU_STRING = "Export contents...";
Paperpile.Tree.AUTO_EXPORT_MENU_STRING = "Auto export...";

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
    this.doLayout();
  },

  showAt: function(el, pos) {
    Paperpile.Tree.ContextMenu.superclass.showAt.call(this, el, pos);
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
    if (this.node['plugin_auto_export_enable']) {
      item.setChecked(true, true);
      item.enableText();
    } else {
      item.setChecked(false, true); // Second param is true to suppress event.
      item.disableText();
    }
  },

  getShownItems: function(node) {
    if (node.id == 'FOLDER_ROOT') {
      return[
      'folder_menu_new',
      'folder_menu_export'];
    } else {
      return[
      'folder_menu_new',
      'folder_menu_delete',
      'folder_menu_rename',
      'folder_menu_export',
      'folder_menu_auto_export'];
    }
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
        text: 'Subscribe to RSS feed',
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
      return[
      'active_menu_rss', ];
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
        text: 'More Resources & Tools',
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
        id: 'sort_tags_by_count',
        text: 'Paper Count',
        handler: tree.sortTagsByCount,
        scope: tree
      },
      {
        id: 'sort_tags_by_name',
        text: 'Name',
        handler: tree.sortTagsByName,
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
        id: 'tags_menu_delete',
        text: 'Delete',
        handler: tree.deleteCollection,
        scope: tree
      },
      {
        id: 'tags_menu_rename',
        text: 'Rename',
        handler: tree.triggerRenameTag,
        scope: tree
      },
      {
        id: 'tags_menu_style',
        text: 'Style',
        menu: tree.stylePickerMenu
      },
      {
        id: 'tags_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        scope: tree
      },
      {
        id: 'sort_by_menu',
        text: 'Sort Labels By',
        menu: tree.sortByMenu
      },
      ]
    });
    Paperpile.Tree.TagsMenu.superclass.initComponent.call(this);
  },

  getShownItems: function(node) {
    if (node.id == 'TAGS_ROOT') {
      return['tags_menu_new',
      'sort_by_menu'];
    } else {
      return['tags_menu_new',
      'tags_menu_delete',
      'tags_menu_rename',
      'tags_menu_style',
      'tags_menu_export'];
    }
  }
});

Paperpile.Tree.TrashMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    var tree = this.tree;

    Ext.apply(this, {
      items: [{
        id: 'trash_menu_empty',
        text: 'Empty Trash',
        handler: tree.emptyTrash,
        scope: tree
      },
      {
        id: 'trash_menu_restore',
        text: 'Restore All Items',
        handler: tree.restoreTrash,
        scope: tree
      }]
    });
    Paperpile.Tree.TrashMenu.superclass.initComponent.call(this);
  },

  getShownItems: function(node) {
    return[];
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