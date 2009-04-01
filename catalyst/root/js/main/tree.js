Paperpile.Tree = Ext.extend(Ext.tree.TreePanel, {

    initComponent: function() {
		Ext.apply(this, {
            title: 'Paperpile Pre 2',
            enableDrop:true,
            ddGroup: 'gridDD',
            animate: false,
            lines:false,
            autoScroll: true,
            loader: new Paperpile.TreeLoader(
                {  url: '/ajax/tree/node',
                   requestMethod: 'GET'
                }
            ),
            root: {
                nodeType: 'async',
                text: 'Root',
                leaf:false,
                id:'ROOT'
            },
            treeEditor:new Ext.tree.TreeEditor(this, {
				allowBlank:false,
				cancelOnEsc:true,
				completeOnEnter:true,
				ignoreNoChange:true,
				//selectOnFocus:this.selectOnEdit,
			}) 
		});

		Paperpile.Tree.superclass.initComponent.call(this);

        this.on({
			contextmenu:{scope:this, fn:this.onContextMenu, stopEvent:true},
            beforenodedrop:{scope:this, fn:this.onNodeDrop},
            checkchange:{scope:this,fn:this.onCheckChange}
		});


        // Avoid selecting nodes; only allow under certain
        // circumstances where it makes sense (e.g context menu selection)
        
        this.allowSelect=false;
        this.getSelectionModel().on("beforeselect",
                                    function(){
                                        return this.allowSelect;
                                    }, this);
        

        this.on("click", function(node,e){

            switch(node.type){

            case 'RESET_DB':
                Paperpile.main.resetDB();
                break;

            case 'SETTINGS':
                Paperpile.main.settings();
                break;

            // all other nodes are handled via the generic plugin mechanism
            default:

                // Skip "header" nodes 
                if (node.id != 'ACTIVE_ROOT'){

                    // Collect plugin paramters
                    var pars={}
                    for (var key in node){
                        if (key.match('plugin_')){
                            pars[key]=node[key];
                        }
                    }

                    // Call appropriate frontend
                    Paperpile.main.tabs.newPluginTab(node.plugin_name, pars);
                }
                break;
            }
        });
	},
    
    onNodeDrop: function(d){

        Ext.Ajax.request({

            url: '/ajax/tree/move_in_folder',
            params: { node_id: d.target.id,
                      sha1: d.data.selections[0].data.sha1,
                      rowid: d.data.selections[0].data._rowid,
                      grid_id: d.source.grid.id,
                      path: this.relativeFolderPath(d.target)
                    },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Moved to folder');
            },

        });


    },


    onRender:function() {
		Paperpile.Tree.superclass.onRender.apply(this, arguments);

        // Do not show browser-context menu
        this.el.on({
			contextmenu:{fn:function(){return false;},stopEvent:true}
		});

    },

    //
    // Shows context menu specific for node type
    //

    onContextMenu:function(node, e) {

        var menu=null;
        
        switch (node.type){
        
        case 'FOLDER':
            this.allowSelect=true;
            node.select();
            menu=new Paperpile.Tree.FolderMenu({node:node});
            break;

        case 'ACTIVE':
            this.allowSelect=true;
            node.select();
            menu=new Paperpile.Tree.ActiveMenu({node:node});
            break;
        }

        if (menu != null){
            menu.node=node;
            menu.showAt(e.getXY());
        }

	},

    //
    // Creates a new active folder based on the currently active tab
    //

    newActive: function(node) {

        var grid=Paperpile.main.tabs.getActiveTab().items.get('center_panel').items.get('grid');
        var treeEditor = this.treeEditor;

        // Get all plugin_* parameters from search plugin grid
        var pars={};

        for (var key in grid){
            if (key.match('plugin_')){
                pars[key]=grid[key];
            }
        }

        // include the latest query parameters form the data store that
        // define the search
        for (var key in grid.store.baseParams){
            if (key.match('plugin_')){
                pars[key]=grid.store.baseParams[key];
            }
        }

        // Use query as default title, or plugin name if query is
        // empty
        var title;
        if (pars.plugin_query !=''){
            title=pars.plugin_query;
        } else {
            title=pars.plugin_name;
        }
                
        Ext.apply(pars, { type: 'ACTIVE', 
                          plugin_title: title,
                          // current query becomes base query for further filtering
                          plugin_base_query: pars.plugin_query, 
                        });

        // Now create new child
        var newNode;
        node.expand(false, false, function(n) {
    
		    newNode = n.appendChild(new Paperpile.AsyncTreeNode({
                text: title, 
                iconCls:pars.plugin_iconCls, 
                leaf:true,
                id: this.generateUID()
            }));
        
            // apply the parameters
            newNode.init(pars);
            newNode.select();

            // Allow the user to edit the name of the active folder
		    treeEditor.on({
			    complete:{
				    scope:this,
				    single:true,
				    fn: function(){
                        newNode.plugin_title=newNode.text;
                        // if everything is done call onNewActive
                        this.onNewActive(newNode);
                    }
			    }
            });
           	(function(){treeEditor.triggerEdit(newNode);}.defer(10));

		}.createDelegate(this));
    },

    //
    // Is called after a new active folder was created. Adds node to
    // tree representation in backend and saves it to database.
    //

    onNewActive: function(node){

        // Selection of node during creation is no longer needed
        this.getSelectionModel().clearSelections();
        this.allowSelect=false;

        // Again get all plugin_* parameters to send to server
        var pars={}
        for (var key in node){
            if (key.match('plugin_')){
                pars[key]=node[key];
            }
        }

        // Set other relevant node parameters which need to be stored
        Ext.apply(pars,{
            type: 'ACTIVE',
            text: node.text,
            plugin_title: node.text,
            iconCls: pars.plugin_iconCls,
            node_id: node.id,
            parent_id: node.parentNode.id,
        });

        // Send to backend
        Ext.Ajax.request({
            url: '/ajax/tree/new_active',
            params: pars,
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Added new active folder');
            },
        });
        
    },


    //
    // Creates new folder
    //

    newFolder: function() {
    
        var node = this.getSelectionModel().getSelectedNode();
		
	    var treeEditor = this.treeEditor;
	    var newNode;
        
		node.expand(false, false, function(n) {
		    
			newNode = n.appendChild(new Paperpile.AsyncTreeNode({text:'New Folder', 
                                                                 iconCls:'pp-icon-folder', 
                                                                 draggable:true,
                                                                 expanded:true,
                                                                 children:[],
                                                                 id: this.generateUID()
                                                                })
                                   );

            newNode.init(
                { type: 'FOLDER', 
                  plugin_name: 'DB',
                  plugin_title: node.text,
                  plugin_iconCls: 'pp-icon-folder',
                  plugin_mode: 'FULLTEXT',
                });

            newNode.select();

			treeEditor.on({
				complete:{
					scope:this,
					single:true,
					fn: function(){
                        var path=this.relativeFolderPath(newNode);
                        newNode.plugin_title=newNode.text;
                        newNode.plugin_query='folders:'+ path;
                        newNode.plugin_base_query='folders:'+ path,
                        this.onNewFolder(newNode);
                    }
				}
            });
                                    
			treeEditor.creatingNewDir = true;
			(function(){treeEditor.triggerEdit(newNode);}.defer(10));
		}.createDelegate(this));

    },


    //
    // Is called after a new folder has been created. Writes folder
    // information to database and updates and saves tree
    // representation to database.
    //

    onNewFolder: function(node){

        this.getSelectionModel().clearSelections();
        this.allowSelect=false;

        // Again get all plugin_* parameters to send to server
        var pars={}
        for (var key in node){
            if (key.match('plugin_')){
                pars[key]=node[key];
            }
        }

        // Set other relevant node parameters which need to be stored
        Ext.apply(pars,{
            type: 'FOLDER',
            text: node.text,
            iconCls: 'pp-icon-folder',
            node_id: node.id,
            plugin_title: node.text,
            path: this.relativeFolderPath(node),
            parent_id: node.parentNode.id,
        });

        // Send to backend
        Ext.Ajax.request({
            url: '/ajax/tree/new_folder',
            params: pars,
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Added new active folder');
            },
        });
    },

    //
    // Deletes active folder 
    //

    deleteActive: function(){
        var node = this.getSelectionModel().getSelectedNode();

        Ext.Ajax.request({
            url: '/ajax/tree/delete_active',
            params: { node_id: node.id },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Deleted active folder');
            },
        });

        node.remove();

    },


    //
    // Rename active folder 
    //

    renameActive: function(){
        var node = this.getSelectionModel().getSelectedNode();

        console.log(this);
        
        var treeEditor=this.treeEditor;

        treeEditor.on({
			complete:{
				scope:this,
				single:true,
				fn:function(editor, newText, oldText){
                    editor.editNode.plugin_title=newText;
                    Ext.Ajax.request({
                        url: '/ajax/tree/rename_active',
                        params: { node_id: node.id,
                                  new_text: newText
                                },
                        success: function(){
                            Ext.getCmp('statusbar').clearStatus();
                            Ext.getCmp('statusbar').setText('Renamed active folder');
                        },
                    });
                },
			}
        });
                                    
		(function(){treeEditor.triggerEdit(node);}.defer(10));
    },

    deleteFolder: function(){
        var node = this.getSelectionModel().getSelectedNode();

        Ext.Ajax.request({

            url: '/ajax/tree/delete_folder',
            params: { node_id: node.id,
                      parent_id: node.parentNode.id,
                      name: node.text,
                      path: this.relativeFolderPath(node),
                    },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Deleted folder');
            },
        });

        node.remove();
       
    },


    /* Debugging only */
    reloadFolder: function(){
        var node = this.getSelectionModel().getSelectedNode();
        node.reload();
    },

    generateUID: function(){
        return ((new Date()).getTime() + "" + Math.floor(Math.random() * 1000000)).substr(0, 18);
    },

    configureSubtree: function(node){
        this.configureNode=node;
        var oldLoader=node.loader;
        var tmpLoader=new Paperpile.TreeLoader(
            {  url: '/ajax/tree/node',
               baseParams: {checked:true},
               requestMethod: 'GET'
            });
        node.loader=tmpLoader;
        node.reload();
        node.loader=oldLoader;
        
        var div=Ext.Element.get(node.ui.getAnchor()).up('div');

        var ok=Ext.DomHelper.append(div, 
              '<a href="#" id="configure-node"><span class="pp-ok-text">&nbsp;Done</span></a>', true);

        

        ok.on({
			click:{ 
                fn:function(){
                    this.configureNode.reload();
                    Ext.Element.get(this.configureNode.ui.getAnchor()).up('div').select('#configure-node').remove();

                },
                stopEvent:true,
                scope:this
            }
		});
    },

    onCheckChange: function(node, checked){

        var hidden=1;
        if (checked){
            hidden=0;
        }

        Ext.Ajax.request({
            url: '/ajax/tree/set_visibility',
            params: { node_id: node.id,
                      hidden: hidden
                    },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Hide/Show node');
            },

        });
    },

    //
    // Returns the path for a folder relative the folder root
    //

    relativeFolderPath: function(node){

        // Simple remove the first 3 levels
        var path=node.getPath('text');
        var parts=path.split('/');
        path=parts.slice(3,parts.length).join('/');
        return(path);
    }



});








Paperpile.Tree.FolderMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        var tree=Paperpile.main.tree;

        Ext.apply(config,{items:[
            { itemId: 'folder_menu_new',
              text:'New Folder',
              handler: tree.newFolder,
              scope: tree
            },
            { itemId: 'folder_menu_delete',
              text:'Delete',
              handler: tree.deleteFolder,
              scope: tree
            },
            { itemId: 'folder_menu_reload',
              text:'Reload',
              handler: tree.reloadFolder,
              scope: tree
            }
        ]});
        
        Paperpile.Tree.FolderMenu.superclass.constructor.call(this, config);
        
    },

});

//
// Context menu for "active folders"
// is called with the selected node as "node" config parameter
//

Paperpile.Tree.ActiveMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        var tree=Paperpile.main.tree;

        Ext.apply(config,{items:[
            { id: 'active_menu_new', //itemId does not work here
              text:'Save current search as active folder',
              handler: function(){
                  Paperpile.main.tree.newActive(this.node);
              },
              scope: this
            },
            { id: 'active_menu_delete',
              text:'Delete',
              handler: tree.deleteActive,
              scope: tree
            },
            { id: 'active_menu_rename',
              text:'Rename',
              handler: tree.renameActive,
              scope: tree
            },

            { id: 'active_menu_configure',
              text:'Configure',
              handler: function(){
                  Paperpile.main.tree.configureSubtree(this.node);
              },
              scope: this
            }

        ]});
        
        Paperpile.Tree.ActiveMenu.superclass.constructor.call(this, config);
        

        this.on('beforeshow',
                function(){
                    if (this.node.id == 'ACTIVE_ROOT'){
                        this.items.get('active_menu_delete').hide();
                        this.items.get('active_menu_rename').hide();
                    } else {
                        this.items.get('active_menu_new').hide();
                        this.items.get('active_menu_configure').hide();
                    }
                },
                this
               );

        this.on('beforehide',
                function(){
                    this.getSelectionModel().clearSelections();
                    this.allowSelect=false;
                },
                tree
               );
    },

});






// Extend TreeNode to allow to pass additional parameters from the server,
// Note that TreeNode is not a 'component' but only an observable, so we 
// can't override as usual but have do define (and call) an init function 
// for ourselves. 

Paperpile.AsyncTreeNode = Ext.extend(Ext.tree.AsyncTreeNode, {

    init: function(attr) {
		    Ext.apply(this, attr);
	},

});

Paperpile.TreeNode = Ext.extend(Ext.tree.TreeNode, {

    init: function(attr) {
		Ext.apply(this, attr);
	},

});

// To use our custom TreeNode we also have to override TreeLoader
Paperpile.TreeLoader = Ext.extend(Ext.tree.TreeLoader, {
	  
    initComponent: function() {
		    Paperpile.TreeLoader.superclass.initComponent.call(this);
	  },


    // This function is taken from extjs-debug.js and modified
    createNode : function(attr){

        if(this.baseAttrs){
            Ext.applyIf(attr, this.baseAttrs);
        }
  
        if(this.applyLoader !== false){
            attr.loader = this;
        }

        if(typeof attr.uiProvider == 'string'){
            attr.uiProvider = this.uiProviders[attr.uiProvider] || eval(attr.uiProvider);
        }


        // Return our custom TreeNode here

        if (attr.leaf){
            var node=new Paperpile.TreeNode(attr);
            node.init(attr);
            return node;
        } else {
            var node=new Paperpile.AsyncTreeNode(attr);
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
