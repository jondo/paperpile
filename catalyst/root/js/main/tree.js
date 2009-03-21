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
                id:'root'
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

            default:

                var pars={}
                for (var key in node){
                    if (key.match('plugin_')){
                        pars[key]=node[key];
                    }
                }

                Paperpile.main.tabs.newPluginTab(node.plugin_name, pars);
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
                      path: d.target.getPath('text')
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
            var alignEl =menu.node.getUI().getEl();
            menu.showAt(menu.getEl().getAlignToXY(alignEl, 'tl-tl?', [0, 18]));
        }

	},


    newActive: function() {

        var node = this.getSelectionModel().getSelectedNode();
        var grid=Paperpile.main.tabs.getActiveTab().items.get('center_panel').items.get('grid');
        var treeEditor = this.treeEditor;

        // Get all plugin_* parameters from search plugin grid
        // including the lates query parameters form the data store
        var pars={};

        for (var key in grid){
            if (key.match('plugin_')){
                console.log(key);
                pars[key]=grid[key];
            }
        }
        
        for (var key in grid.store.baseParams){
            if (key.match('plugin_')){
                pars[key]=grid.store.baseParams[key];
            }
        }

        var newNode;
        var title;

        if (pars.plugin_query !=''){
            title=pars.plugin_query;
        } else {
            title=pars.plugin_name;
        }
                
        Ext.apply(pars,{plugin_title: title,
                        plugin_base_query: pars.plugin_query,
                        plugin_iconCls: pars.plugin_iconCls, 
                        type: 'ACTIVE', 
                       });

        node.expand(false, false, function(n) {

            console.log(pars);
		    
		    newNode = n.appendChild(new Paperpile.AsyncTreeNode({
                text: title, 
                iconCls:pars.plugin_iconCls, 
                leaf:true,
            }));
        
            newNode.init(pars);
            newNode.select();

		    treeEditor.on({
			    complete:{
				    scope:this,
				    single:true,
				    fn:this.onNewActive,
			    }
            });
                                    
		    (function(){treeEditor.triggerEdit(newNode);}.defer(10));
		}.createDelegate(this));

    },

    newFolder: function() {
        var node = this.getSelectionModel().getSelectedNode();
		
	    var treeEditor = this.treeEditor;
		var newNode;

		var appendNode = node.isLeaf() ? node.parentNode : node;
        
		appendNode.expand(false, false, function(n) {
		    
			newNode = n.appendChild(new Paperpile.AsyncTreeNode({text:'New Folder', 
                                                                 iconCls:'pp-icon-folder', 
                                                                 type: 'FOLDER', 
                                                                })
                                   );
            newNode.select();

			treeEditor.on({
				complete:{
					scope:this,
					single:true,
					fn:this.onNewDir,
				}
            });
                                    
			treeEditor.creatingNewDir = true;
			(function(){treeEditor.triggerEdit(newNode);}.defer(10));
		}.createDelegate(this));

    },

    onNewDir: function(){

        var node = this.getSelectionModel().getSelectedNode();
        this.getSelectionModel().clearSelections();
        this.allowSelect=false;
       
        Ext.Ajax.request({

            url: '/ajax/tree/new_folder',
            params: { node_id: node.id,
                      parent_id: node.parentNode.id,
                      name: node.text,
                      path:node.getPath('text'),
                    },
            success: function(){
                
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Added new folder');
            },
        });

    },

    onNewActive: function(){

        var node = this.getSelectionModel().getSelectedNode();

        this.getSelectionModel().clearSelections();
        this.allowSelect=false;

        var pars={}
        for (var key in node){
            if (key.match('plugin_')){
                pars[key]=node[key];
            }
        }

        Ext.apply(pars,{
            type: 'ACTIVE',
            text: node.text,
            plugin_title: node.text,
            iconCls: pars.plugin_iconCls,
            node_id: node.id,
            parent_id: node.parentNode.id,
        });

        Ext.Ajax.request({

            url: '/ajax/tree/new_active',
            params: pars,
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Added new folder');
            },
        });


        Ext.getCmp('statusbar').clearStatus();
        Ext.getCmp('statusbar').setText('New Active');

    },





    deleteFolder: function(){
        var node = this.getSelectionModel().getSelectedNode();

        Ext.Ajax.request({

            url: '/ajax/tree/delete_folder',
            params: { node_id: node.id,
                      parent_id: node.parentNode.id,
                      name: node.text,
                      path:node.getPath('text'),
                    },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Deleted folder');
            },
        });

        node.remove();
       
    },

    deleteActive: function(){
        var node = this.getSelectionModel().getSelectedNode();

        Ext.Ajax.request({

            url: '/ajax/tree/delete_active',
            params: { node_id: node.id,
                    },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Deleted active folder');
            },
        });
        
        node.remove();
       
    },

    /* Debugging only */
    reloadFolder: function(){
        var node = this.getSelectionModel().getSelectedNode();
        node.reload();
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

Paperpile.Tree.ActiveMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        var tree=Paperpile.main.tree;

        Ext.apply(config,{items:[
            { itemId: 'active_menu_new',
              text:'New from current tab',
              handler: tree.newActive,
              scope: tree
            },
            { id: 'context_menu_delete',
              text:'Delete',
              handler: tree.deleteActive,
              scope: tree
            },
            { id: 'context_menu_reload',
              text:'Reload',
              //handler: tree.reloadFolder,
              scope: tree
            }
        ]});
        
        Paperpile.Tree.ActiveMenu.superclass.constructor.call(this, config);
        
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
