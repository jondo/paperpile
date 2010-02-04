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
      plugins: [Paperpile.ContextTrianglePlugin]
    });

    this.treeEditor.on({
      complete: {
        scope: this,
        fn: this.commitRenameTag
      }
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
        // This is necessary because we load the tree as a whole
        // during startup but want to re-load single nodes
        // afterwards. We achieve this by removing the children
        // array which gets stored in node.attributes
        fn: function(node) {
          delete node.attributes.children;
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
      function() {
        return this.allowSelect;
      },
      this);
  },

  initEvents: function() {
    Paperpile.Tree.superclass.initEvents.call(this);

    // Extend the TreeDropZone to customize the "getDropPoint" functionality:
    //   -> if dragging from the grid over the Tags, it should always be in "append" mode.
    Paperpile.Tree.TreeDropZone = Ext.extend(Ext.tree.TreeDropZone, {
      getDropPoint: function(e, n, dd) {
        var node = n.node;
        if (dd.dragData.grid != null) { // This is a bit hacky... there should be a better way to determine where the drag data is coming from.
          return "append";
        }

        return Paperpile.Tree.TreeDropZone.superclass.getDropPoint.call(this, e, n, dd);
      }
    });

    this.dropZone = new Paperpile.Tree.TreeDropZone(this, {
      ddGroup: this.ddGroup,
      appendOnly: false
    });

    this.dragZone = new Ext.tree.TreeDragZone(this, {
      containerScroll: true,
      ddGroup: this.ddGroup,
      proxy: new Paperpile.StatusTipProxy(),

      // This is slightly modified to remove the context triangle before loading the ghost proxy.
      onInitDrag: function(e) {
        this.tree.contextTriangle.hide();
        var data = this.dragData;
        this.tree.getSelectionModel().select(data.node);
        this.tree.eventModel.disable();
        this.proxy.update("");
        data.node.ui.appendDDGhost(this.proxy.ghost.dom);
        this.tree.fireEvent("startdrag", this.tree, data.node, e);
      },

      afterDragOver: function(target, e, id) {
        var myType = this.dragData.node.type;
        if (target.grid) {
          if (myType == 'TAGS') {
            this.proxy.updateTip('Apply label to reference');
          } else if (myType == 'FOLDER') {
            this.proxy.updateTip('Place reference in folder');
          }
        } else if (target.tree) {
          var data = target.dragOverData;
          var dt = data.target;
          if (myType == 'TAGS' && dt && dt.type == 'TAGS') {
            this.proxy.updateTip('Move label');
          } else if (myType == 'FOLDER' && dt && dt.type == 'FOLDER') {
            this.proxy.updateTip('Move folder');
          }
        } else {
          this.proxy.updateTip('');
        }
      }
    });

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
    //      Paperpile.log(e);
    //      Paperpile.log(e.browserEvent);
    //      Paperpile.log("Tree on Click!");
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

      // all other nodes are handled via the generic plugin mechanism
    default:
      // Skip "header" nodes indicated by XXX_ROOT
      if (node.id.search('ROOT') == -1) {
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
          var store = Ext.StoreMgr.lookup('tag_store');
          var style = '0';
          if (store.getAt(store.find('tag', node.text))) {
            style = store.getAt(store.find('tag', node.text)).get('style');
          }
          iconCls = 'pp-tag-style-tab pp-tag-style-' + style;
          title = node.text;
        }

        // Call appropriate frontend, tags, active folders, and folders are opened only once
        // and we pass the node.id as item-id for the tab
        if (node.type == 'TAGS' || node.type == 'ACTIVE' || node.type == 'FOLDER') {
          Paperpile.main.tabs.newPluginTab(node.plugin_name, pars, title, iconCls, node.id);
        } else if (node.type == 'TRASH') {
          Paperpile.main.tabs.newTrashTab();
          //Paperpile.main.tabs.showQueueTab();
        } else {
          Paperpile.main.tabs.newPluginTab(node.plugin_name, pars, title, iconCls);
        }
      } else {
        var main = Paperpile.main.tabs.getItem("MAIN");
        Paperpile.main.tabs.activate(main);
      }
      break;
    }

  },

  getDropPoint: function(e, n, dd) {
    return Paperpile.Tree.superclass.getDropPoint(e, n, dd);
  },

  onNodeDrag: function(e) {
    // We are dragging from the data grid
    if (e.source.dragData.grid) {
      // only allow drop on Folders, Tags and Trash
      if ((e.target.type == 'TAGS' || e.target.type == 'FOLDER' || e.target.type == 'TRASH') && e.target.id != 'TAGS_ROOT') {

        e.cancel = false;

        if (e.target.type == 'TRASH') {
          var imported = e.source.dragData.grid.getSelection('IMPORTED');
          if (imported.length == 0) {
            e.cancel = true;
          }
        }

      } else {
        // Cancel if not on a folder, tag or trash.
        e.cancel = true;
      }
    } else {

      // We are dragging internal nodes from the tree
      // Only allow operations within the same subtree,
      // i.e. nodes are of the same type
      if (e.source.dragData.node.type != e.target.type) {
        e.cancel = true;
      } else if (e.target.type == 'TAGS' && e.point == 'append') {
        e.cancel = true;
      } else {
        // Allow only re-ordering in active folder and import plugins,
        // because we only support one level
        if ((e.target.type == 'ACTIVE' || e.target.type == 'IMPORT_PLUGIN') && e.point == 'append') {
          e.cancel = true;
        } else {
          // Can't move node above root
          if (e.target.id.search('ROOT') != -1 && e.point == 'above') {
            e.cancel = true;
          }
        }
      }
    }
  },

  addFolder: function(grid, sel, node) {
    var el = Ext.get(node.getUI().getTextEl());
    el.highlight("ffff9c", {
      easing: 'bounceBoth',
      duration: 1
    });
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/move_in_folder'),
      params: {
        grid_id: grid.id,
        selection: sel,
        node_id: node.id
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
    Paperpile.log(grid);
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/add_tag'),
      params: {
        grid_id: grid.id,
        selection: sel,
        tag: node.text
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
    // We're dragging from the data grid
    if (e.source.dragData.grid) {
      var grid = e.source.dragData.grid;
      var sel = grid.getSelection();
      var node = e.target;

      if (node.type == 'FOLDER') {
        this.addFolder(grid, sel, node);
      } else if (e.target.type == 'TAGS') {
        this.addTag(grid, sel, node);
      } else if (node.type == 'TRASH') {
        grid.deleteEntry('TRASH');
      }
    } else {
      // We're dragging nodes internally
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
    var menu = this.getContextMenu(node);
    if (menu != null) {
      if (menu.getShownItems(node).length > 0) {
        this.allowSelect = true;
        node.select();
        this.lastSelectedNode = node;
        menu.node = node;
        menu.hideItems();
        menu.showAt(e.getXY());
      }
    }
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
        id: this.generateUID()
      }));

      // apply the parameters
      //	    newNode.add(new Paperpile.TreeMenu());
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

    var n = this.getNodeById('ACTIVE_ROOT');

    Ext.Msg.prompt('Subscribe to RSS feed', 'Location:', function(btn, text) {
      if (btn == 'ok') {

        var newNode = n.appendChild(this.loader.createNode({
          text: 'Loading feed',
          iconCls: 'pp-icon-loading',
          qtip: text,
          draggable: true,
          expanded: true,
          children: [],
          id: this.generateUID()
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
          plugin_url: text,
          plugin_id: newNode.id
        };

        newNode.init(pars);

        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/tree/new_rss'),
          params: pars,
          success: function(response) {
            var json = Ext.util.JSON.decode(response.responseText);

            if (json.error) {
              Paperpile.main.onError(response);
              newNode.remove();
            }

            newNode.setText(json.title);

            newNode.plugin_title = json.title;

            Ext.get(newNode.getUI().getIconEl()).replaceClass('pp-icon-loading', 'pp-icon-feed');

          },
          failure: function(response) {
            Paperpile.main.onError(response),
            newNode.remove();
          }
        });
      }
    },
    this);
  },

  //
  // Creates new folder
  //
  newFolder: function() {

    var node = this.getSelectionModel().getSelectedNode();

    var treeEditor = this.treeEditor;
    var newNode;

    node.expand(false, false, function(n) {

      newNode = n.appendChild(this.loader.createNode({
        text: 'New Folder',
        iconCls: 'pp-icon-folder',
        draggable: true,
        expanded: true,
        children: [],
        leaf: true,
        id: this.generateUID()
      }));

      newNode.init({
        type: 'FOLDER',
        plugin_name: 'DB',
        plugin_title: node.text,
        plugin_iconCls: 'pp-icon-folder',
        plugin_mode: 'FULLTEXT'
      });

      newNode.select();

      treeEditor.on({
        complete: {
          scope: this,
          single: true,
          fn: function() {
            var path = this.relativeFolderPath(newNode);
            newNode.plugin_title = newNode.text;
            newNode.plugin_query = 'folder:' + newNode.id
            newNode.plugin_base_query = 'folder:' + newNode.id
            this.onNewFolder(newNode);
          }
        }
      });

      (function() {
        treeEditor.triggerEdit(newNode);
      }.defer(10));
    }.createDelegate(this));

  },

  //
  // Is called after a new folder has been created. Writes folder
  // information to database and updates and saves tree
  // representation to database.
  //
  onNewFolder: function(node) {

    this.getSelectionModel().clearSelections();
    this.allowSelect = false;

    // Again get all plugin_* parameters to send to server
    var pars = {};
    for (var key in node) {
      if (key.match('plugin_')) {
        pars[key] = node[key];
      }
    }

    // Set other relevant node parameters which need to be stored
    Ext.apply(pars, {
      type: 'FOLDER',
      text: node.text,
      iconCls: 'pp-icon-folder',
      node_id: node.id,
      plugin_title: node.text,
      path: this.relativeFolderPath(node),
      parent_id: node.parentNode.id
    });

    // Send to backend
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/tree/new_folder'),
      params: pars,
      success: function() {
        //Ext.getCmp('statusbar').clearStatus();
        //Ext.getCmp('statusbar').setText('Added new folder');
      },
      failure: Paperpile.main.onError
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
    var node = this.getSelectionModel().getSelectedNode();
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

  deleteFolder: function() {
    var node = this.getSelectionModel().getSelectedNode();

    Ext.Ajax.request({

      url: Paperpile.Url('/ajax/tree/delete_folder'),
      params: {
        node_id: node.id,
        parent_id: node.parentNode.id,
        name: node.text,
        path: this.relativeFolderPath(node),
      },
      success: function() {
        //Ext.getCmp('statusbar').clearStatus();
        //Ext.getCmp('statusbar').setText('Deleted folder');
      },
      failure: Paperpile.main.onError,
    });

    node.remove();

  },

  /* Debugging only */
  reloadFolder: function() {
    var node = this.getSelectionModel().getSelectedNode();
    node.reload();
  },

  generateUID: function() {
    return ((new Date()).getTime() + "" + Math.floor(Math.random() * 1000000)).substr(0, 18);
  },

  configureSubtree: function(node) {
    this.configureNode = node;
    var oldLoader = node.loader;
    var tmpLoader = new Paperpile.TreeLoader({
      url: Paperpile.Url('/ajax/tree/get_node'),
      baseParams: {
        checked: true
      },
      requestMethod: 'GET'
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
    node.expand(false, false, function(n) {
      newNode = n.appendChild(
        this.loader.createNode({
          text: 'New Label',
          iconCls: 'pp-icon-empty',
          tagStyle: 0,
          cls: 'pp-tag-tree-node pp-tag-tree-style-0',
          draggable: true,
          leaf: true,
          expanded: true,
          children: [],
          id: this.generateUID()
        }));
      var pars = {
        type: 'TAGS',
        plugin_name: 'DB',
        plugin_title: node.text,
        plugin_iconCls: 'pp-icon-tag',
        plugin_mode: 'FULLTEXT'
      };
      this.onNewTag(newNode);
      newNode.init(pars);
      newNode.select();

      (function() {
        treeEditor.on('canceledit', this.removeOnCancel, this);
        treeEditor.triggerEdit(newNode);
      }.defer(10, this));
    }.createDelegate(this));
  },

  removeOnCancel: function(editor, newText, oldText) {
    var node = editor.editNode;
    this.deleteTag(node);
    editor.un('canceledit', this.removeOnCancel);
  },

  //
  // Is called after a new tag has been created. Writes tag
  // information to database and updates and saves tree
  // representation to database.
  //
  onNewTag: function(node) {
    var pars = {
      tag: node.text,
      style: 'default'
    };

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/new_tag'),
      params: pars,
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
        Ext.StoreMgr.lookup('tag_store').reload();
      },
      failure: Paperpile.main.onError
    });
  },

  deleteTag: function(node) {
    var tag = node.text;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_tag'),
      params: {
        tag: tag
      },
      success: function() {

        // Remove the entry of the tag in the tree
        node.remove();

        // Update store with tags from the server
        Ext.StoreMgr.lookup('tag_store').reload({
          callback: function() {

            // Afterwards update entries on all open tabs
            Paperpile.main.tabs.items.each(
              function(item, index, length) {
                var grid = item.items.get('center_panel').items.get('grid');
                grid.store.suspendEvents();
                var records = grid.getStore().data.items;
                for (i = 0; i < records.length; i++) {
                  var oldTags = records[i].get('tags');
                  var newTags = oldTags;

                  newTags = newTags.replace(new RegExp("^" + tag + "$"), ""); //  XXX
                  newTags = newTags.replace(new RegExp("^" + tag + ","), ""); //  XXX,
                  newTags = newTags.replace(new RegExp("," + tag + "$"), ""); // ,XXX
                  newTags = newTags.replace(new RegExp("," + tag + ","), ","); // ,XXX,
                  records[i].set('tags', newTags);
                }

                grid.store.resumeEvents();
                grid.store.fireEvent('datachanged', this.store);

                // If a entry is selected in a tab, also update the display
                var sidepanel = item.items.get('east_panel').items.get('overview');
                var selected = grid.getSelectionModel().getSelected();
                if (selected) {
                  sidepanel.updateDetail();
                }
              });
          }
        });
      },
      failure: Paperpile.main.onError
    });
  },

  styleTag: function(number) {
    var node = this.lastSelectedNode;

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/style_tag'),
      params: {
        tag: node.text,
        style: number,
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Ext.StoreMgr.lookup('tag_store').reload({
          callback: function() {
            // Force a reload of the sidebar.
            json.data.updateSidePanel = true;

            Paperpile.main.onUpdate(json.data);
            node.ui.removeClass('pp-tag-tree-style-' + node.tagStyle);
            node.ui.addClass('pp-tag-tree-style-' + number);
            node.tagStyle = number;

          }
        });
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  },

  //
  // Rename the tag given by node globally
  //
  triggerRenameTag: function() {
    (function() {
      var node = this.getSelectionModel().getSelectedNode();
      this.treeEditor.triggerEdit(node);
    }.defer(10, this));
  },

  commitRenameTag: function(editor, newText, oldText) {
    var node = editor.editNode;
    if (node.type != 'TAGS') return;

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
        Ext.StoreMgr.lookup('tag_store').reload({
          callback: function() {
            Paperpile.main.onUpdate(json.data);
          }
        });
      },
      failure: Paperpile.main.onError
    });

  },

  exportNode: function() {

    var node = this.getSelectionModel().getSelectedNode();

    var window = new Paperpile.ExportWindow({
      source_node: node.id
    });
    window.show();

  },

});

Paperpile.Tree.EXPORT_MENU_STRING = "Export contents...";

Paperpile.Tree.ContextMenu = Ext.extend(Ext.menu.Menu, {
  node: null,
  tree: null,
  initComponent: function() {
    Paperpile.Tree.ContextMenu.superclass.initComponent.call(this);

    this.on('beforeshow', this.hideItems);
    this.on('beforehide',
      function() {
        this.getSelectionModel().clearSelections();
        this.allowSelect = false;
      },
      Paperpile.main.tree);
  },
  setNode: function(node) {
    this.node = node;
  },

  getShownItems: function(node) {
    return[];
  },

  hideItems: function() {
    this.items.each(function(item) {
      item.hide();
    });
    var shownIds = this.getShownItems(this.node);
    for (var i = 0; i < shownIds.length; i++) {
      this.items.get(shownIds[i]).show();
    }
    this.doLayout();
  },

  showAt: function(el, pos) {
    //    this.hideItems();
    Paperpile.Tree.ContextMenu.superclass.showAt.call(this, el, pos);
  }

});

Paperpile.Tree.FolderMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    this.tree = Paperpile.main.tree;
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
        handler: tree.deleteFolder,
        scope: tree
      },
      {
        id: 'folder_menu_rename',
        text: 'Rename',
        handler: tree.renameNode,
        scope: tree
      },
      {
        id: 'folder_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        scope: tree
      }]
    });
    Paperpile.Tree.FolderMenu.superclass.initComponent.call(this);
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
      'folder_menu_export'];
    }
  }

});

Paperpile.Tree.ActiveMenu = Ext.extend(Paperpile.Tree.ContextMenu, {
  initComponent: function() {
    this.tree = Paperpile.main.tree;
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
    this.tree = Paperpile.main.tree;
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
    this.tree = Paperpile.main.tree;
    var tree = this.tree;

    Ext.apply(this, {
      items: [{
        id: 'tags_menu_new',
        text: 'New Label',
        handler: tree.newTag,
        scope: tree
      },
      {
        id: 'tags_menu_delete',
        text: 'Delete',
        handler: function() {
          this.tree.deleteTag(this.node);
        },
        scope: this
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
        menu: new Paperpile.StylePickerMenu({
          handler: function(cm, number) {
            this.styleTag(number);
          },
          scope: tree
        })
      },
      {
        id: 'tags_menu_export',
        text: Paperpile.Tree.EXPORT_MENU_STRING,
        handler: tree.exportNode,
        scope: tree
      }]
    });

    Paperpile.Tree.TagsMenu.superclass.initComponent.call(this);
  },

  getShownItems: function(node) {
    if (node.id == 'TAGS_ROOT') {
      return['tags_menu_new'];
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
    this.tree = Paperpile.main.tree;
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