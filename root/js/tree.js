PaperPile.Tree = Ext.extend(Ext.tree.TreePanel, {
	  
    initComponent: function() {
		Ext.apply(this, {
            enableDrop:true,
            ddGroup: 'gridDD',
            animate: false,
            title: 'Paperpile Pre 1',
            lines:false,
            autoScroll: true,
            loader: new PaperPile.TreeLoader(
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

		PaperPile.Tree.superclass.initComponent.call(this);

        this.on({
			contextmenu:{scope:this, fn:this.onContextMenu, stopEvent:true},
			//dblclick:{scope:this, fn:this.onDblClick},
			//beforenodedrop:{scope:this, fn:this.onBeforeNodeDrop},
            beforenodedrop:{scope:this, fn:this.onNodeDrop},
			//nodedragover:{scope:this, fn:this.onNodeDragOver},
		});


        this.on("click", function(node,e){

            switch(node.type){

            case 'DB':
                Ext.getCmp('results_tabs').newDBtab(node.query);
                break;

            case 'PUBMED':
                Ext.getCmp('results_tabs').newPubMedTab(node.query);
                break;

            case 'FILE':
                Ext.getCmp('results_tabs').newFileTab(node.file);
                break;

            case 'RESET_DB':
                Ext.getCmp('MAIN').resetDB();
                break;

            case 'INIT_DB':
                Ext.getCmp('MAIN').initDB();
                break;

            case 'IMPORT_JOURNALS':
                Ext.getCmp('MAIN').importJournals();
                break;

            case 'TAG':
                Ext.getCmp('results_tabs').showDBQueryResults('FULLTEXT',
                                                              node.text,
                                                              'tags:'+node.text,
                                                              node.text,
                                                              'pp-icon-tag'
                                                             );
                
                break;

            case 'FOLDER':
                Ext.getCmp('results_tabs').showDBQueryResults('FULLTEXT',
                                                              node.text,
                                                              'folders:'+node.text,
                                                              node.text,
                                                              'pp-icon-folder'
                                                             );
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
                      source_id: d.source.grid.id,
                      path: d.target.getPath('text')
                    },
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Moved to folder');
            },

        });

        console.log(d.source);

    },


    onRender:function() {
		PaperPile.Tree.superclass.onRender.apply(this, arguments);

        // Do not show browser-context menu
        this.el.on({
			contextmenu:{fn:function(){return false;},stopEvent:true}
		});

    },

    onContextMenu:function(node, e) {
        node.select();
        this.contextMenu = new PaperPile.TreeMenu({node:node});
        this.contextMenu.node = node;
        this.showContextMenu();
	},

    showContextMenu:function() {
        menu=this.contextMenu;
        var alignEl =menu.node.getUI().getEl();
		menu.showAt(menu.getEl().getAlignToXY(alignEl, 'tl-tl?', [0, 18]));
	},

    newFolder: function(node) {
        var node = this.getSelectionModel().getSelectedNode();
		
	    var treeEditor = this.treeEditor;
		var newNode;

		var appendNode = node.isLeaf() ? node.parentNode : node;
        
		appendNode.expand(false, false, function(n) {
		    
			newNode = n.appendChild(new PaperPile.AsyncTreeNode({text:'New Folder', 
                                                                 iconCls:'folder', 
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

    /* Debugging only */
    reloadFolder: function(){
        var node = this.getSelectionModel().getSelectedNode();
        node.reload();
    }

});


PaperPile.TreeMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        console.log(config.node);

        switch(config.node.attributes.type){
        case 'FOLDER':
            Ext.apply(config,{items:[
                { id: 'context_menu_new',
                  text:'New Folder',
                  handler: Ext.getCmp('treepanel').newFolder,
                  scope: Ext.getCmp('treepanel')
                },
                { id: 'context_menu_delete',
                  text:'Delete',
                  handler: Ext.getCmp('treepanel').deleteFolder,
                  scope: Ext.getCmp('treepanel')
                },
                { id: 'context_menu_reload',
                  text:'Reload',
                  handler: Ext.getCmp('treepanel').reloadFolder,
                  scope: Ext.getCmp('treepanel')
                }

            ]});
            break;
        }
        
        PaperPile.TreeMenu.superclass.constructor.call(this, config);

    },

});



// Extend TreeNode to allow to pass additional parameters from the server,
// Note that TreeNode is not a 'component' but only an observable, so we 
// can't override as usual but have do define (and call) an init function 
// for ourselves. 

PaperPile.AsyncTreeNode = Ext.extend(Ext.tree.AsyncTreeNode, {

    init: function(attr) {
		    Ext.apply(this, attr);
	},

});

PaperPile.TreeNode = Ext.extend(Ext.tree.TreeNode, {

    init: function(attr) {
		Ext.apply(this, attr);
	},

});

// To use our custom TreeNode we also have to override TreeLoader
PaperPile.TreeLoader = Ext.extend(Ext.tree.TreeLoader, {
	  
    initComponent: function() {
		    PaperPile.TreeLoader.superclass.initComponent.call(this);
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
            var node=new PaperPile.TreeNode(attr);
            node.init(attr);
            return node;
        } else {
            var node=new PaperPile.AsyncTreeNode(attr);
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





Ext.reg('tree', PaperPile.Tree);
