Paperpile.Tree = Ext.extend(Ext.tree.TreePanel, {

    initComponent: function() {
		Ext.apply(this, {
            enableDD:true,
            ddGroup: 'gridDD',
            animate: false,
            lines:false,
            autoScroll: true,
            loader: new Paperpile.TreeLoader(
                {  url: '/ajax/tree/get_node',
                   requestMethod: 'GET',
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
			}) 
		});

		Paperpile.Tree.superclass.initComponent.call(this);

        this.on({
			contextmenu:{scope:this, fn:this.onContextMenu, stopEvent:true},
            beforenodedrop:{scope:this, fn:this.onNodeDrop},
            checkchange:{scope:this,fn:this.onCheckChange},
            // This is necessary because we load the tree as a whole
            // during startup but want to re-load single nodes
            // afterwards. We achieve this by removing the children
            // array which gets stored in node.attributes 
            load:{scope:this, 
                  fn:function(node){
                      delete node.attributes.children
                  }
                 }
		});

        this.on('nodedragover', function(e){

            // We are dragging from the data grid
            if (e.source.dragData.grid){

                // only 'appends' make sense
                if (e.point != 'append'){
                    e.cancel=true;
                } else {
                    // only allow drop on Folders and Tags
                    if ((e.target.type == 'TAGS' || e.target.type == 'FOLDER') &&
                        e.target.id != 'TAGS_ROOT'){

                        //if (e.target.id = 'FOLDER_ROOT'){
                        //    console.log(e.source.dragData);
                        //}

                        // drop on tags only if not already tagged with the same tag
                        if (e.target.type=='TAGS'){
                            var tags=e.source.grid.getSelectionModel().getSelected().data.tags.split(',');

                            var alreadyTagged=false;

                            for(var i = 0; i < tags.length; i++) {
                                if(tags[i] == e.target.text){
                                    alreadyTagged=true;
                                }
                            }
                            e.cancel= alreadyTagged;
                        } else {
                            e.cancel=false;
                        }
                    } else {
                        e.cancel=true;
                    }
                }
               
            } 
            // We are dragging internal nodes from the tree
            else {
                
                // Only allow operations within the same subtree,
                // i.e. nodes are of the same type
                if (e.source.dragData.node.type != e.target.type){
                    e.cancel=true;
                } else {

                    // Allow only re-ordering in active folder and import plugins,
                    // because we only support one level
                    if ((e.target.type == 'ACTIVE' || e.target.type == 'IMPORT_PLUGIN') && e.point =='append'){
                        e.cancel=true;
                    } else {
                        // Can't move node above root
                        if (e.target.id.search('ROOT')!=-1 && e.point=='above'){
                            e.cancel=true;
                        }
                    }
                }
            }
           

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

            case 'PDFEXTRACT':
                Paperpile.main.pdfExtract();
                break;

            case 'FILE_IMPORT':
                Paperpile.main.fileImport();
                break;
                

            // all other nodes are handled via the generic plugin mechanism
            default:

                // Skip "header" nodes indicated by XXX_ROOT

                if (node.id.search('ROOT')==-1){

                    // Collect plugin paramters
                    var pars={}
                    for (var key in node){
                        if (key.match('plugin_')){
                            pars[key]=node[key];
                        }
                    }
                    
                    // Use default title and css for tab 
                    var title=null;
                    var iconCls=null;

                    // For tags use specifically styled tab
                    if (node.type == 'TAGS'){
                        var store=Ext.StoreMgr.lookup('tag_store');
                        var style = '0';
                        if (store.getAt(store.find('tag',node.text))){
                            style=store.getAt(store.find('tag',node.text)).get('style');
                        }
                        iconCls='pp-tag-style-tab pp-tag-style-'+style;
                    }

                    // Call appropriate frontend
                    Paperpile.main.tabs.newPluginTab(node.plugin_name, pars, title, iconCls);
                }
                break;
            }
        });
	},

    onNodeDrop: function(e){

        // We're dragging from the data grid
        if (e.source.dragData.grid){
            if (e.target.type == 'FOLDER'){

                var params = { node_id: e.target.id,
                               sha1: e.data.selections[0].data.sha1,
                               rowid: e.data.selections[0].data._rowid,
                               grid_id: e.source.grid.id,
                               path: this.relativeFolderPath(e.target)
                             };
                
                if (e.source.grid.getSelectionModel().getSelected().data._imported){
                    if (e.target.id != 'FOLDER_ROOT'){
                        Ext.Ajax.request({
                            url: '/ajax/tree/move_in_folder',
                            params: params,
                            method: 'GET',
                            success: function(){
                                //Ext.getCmp('statusbar').clearStatus();
                                //Ext.getCmp('statusbar').setText('Moved to folder');
                            },
                        });
                    }
                } else {
                    e.source.dragData.grid.insertEntry(
                        function(data){
                            Ext.apply(params, {rowid: data._rowid});
                            if (e.target.id != 'FOLDER_ROOT'){
                                Ext.Ajax.request({
                                    url: '/ajax/tree/move_in_folder',
                                    params: params,
                                    success: function(){
                                        //Ext.getCmp('statusbar').clearStatus();
                                        //Ext.getCmp('statusbar').setText('Moved to folder');
                                    },
                                });
                            }
                        }, this);
                }
            }

            if (e.target.type == 'TAGS'){
                var newTags=e.target.text;
                var oldTags=e.data.selections[0].data.tags;
                if (oldTags != ''){
                    newTags=oldTags+','+e.target.text;
                }

                var success= function(){
                    Ext.StoreMgr.lookup('tag_store').reload();
                    e.data.selections[0].data.tags=newTags;
                    var datatabs=Paperpile.main.tabs.getActiveTab().items.get('center_panel').items.get('data_tabs');        
                    datatabs.items.get('pubsummary').updateDetail(e.data.selections[0].data);
                    //Ext.getCmp('statusbar').clearStatus();
                    //Ext.getCmp('statusbar').setText('Updated tags.');
                };

                if (e.source.grid.getSelectionModel().getSelected().data._imported){

                    Ext.Ajax.request(
                        { url: '/ajax/crud/update_tags',
                          params: { rowid: e.data.selections[0].data._rowid,
                                    tags: newTags,
                                  },
                          success: success
                        }
                    )
        
                } else {

                    e.source.dragData.grid.insertEntry(
                        function(data){
                            Ext.Ajax.request(
                                { url: '/ajax/crud/update_tags',
                                  params: { rowid: data._rowid,
                                            tags: newTags,
                                          },
                                  success: success
                                }
                            )
                        }, this);
                }
            }
        }
        // We're dragging nodes internally
        else {
            Ext.Ajax.request({
                url: '/ajax/tree/move_node',
                params: { target_node: e.target.id,
                          drop_node: e.dropNode.id,
                          point: e.point,
                        },
                success: function(){
                    //Ext.getCmp('statusbar').clearStatus();
                    //Ext.getCmp('statusbar').setText('Moved node');
                },
            });
        }
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

        case 'IMPORT_PLUGIN':
            this.allowSelect=true;
            node.select();
            menu=new Paperpile.Tree.ImportMenu({node:node});
            break;

        case 'TAGS':
            this.allowSelect=true;
            node.select();
            menu=new Paperpile.Tree.TagsMenu({node:node});
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
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Added new active folder');
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
                        newNode.plugin_query='folders:'+newNode.id
                        newNode.plugin_base_query='folders:'+newNode.id
                        this.onNewFolder(newNode);
                    }
				}
            });
                                    
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
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Added new folder');
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
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Deleted active folder');
            },
        });

        node.remove();

    },


    //
    // Rename node
    //

    renameNode: function(){
        var node = this.getSelectionModel().getSelectedNode();
        var treeEditor=this.treeEditor;

        treeEditor.on({
			complete:{
				scope:this,
				single:true,
				fn:function(editor, newText, oldText){
                    editor.editNode.plugin_title=newText;
                    Ext.Ajax.request({
                        url: '/ajax/tree/rename_node',
                        params: { node_id: node.id,
                                  new_text: newText
                                },
                        success: function(){
                            //Ext.getCmp('statusbar').clearStatus();
                            //Ext.getCmp('statusbar').setText('Renamed folder');
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
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Deleted folder');
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
            {  url: '/ajax/tree/get_node',
               baseParams: {checked:true},
               requestMethod: 'GET',
            });

        // Force reload by deleting the children which get stored in
        // attributes when we load the tree in one step in the beginning
        //delete node.attributes.children;
        
        node.loader=tmpLoader;
        node.reload();
        node.loader=oldLoader;
        
        var div=Ext.Element.get(node.ui.getAnchor()).up('div');

        var ok=Ext.DomHelper.append(div, 
              '<a href="#" id="configure-node" class="pp-textlink">Done</a>', true);

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
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Hide/Show node');
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
    },


    newTag: function() {
    
        var node = this.getNodeById('TAGS_ROOT');
		
	    var treeEditor = this.treeEditor;
	    var newNode;
        
		node.expand(false, false, function(n) {
		    
			newNode = n.appendChild(new Paperpile.AsyncTreeNode({text:'New Tag', 
                                                                 iconCls:'pp-icon-empty', 
                                                                 tagStyle:0,
                                                                 cls: 'pp-tag-tree-node pp-tag-tree-style-0',
                                                                 draggable:true,
                                                                 expanded:true,
                                                                 children:[],
                                                                 id: this.generateUID()
                                                                })
                                   );
            newNode.init(
                { type: 'TAGS', 
                  plugin_name: 'DB',
                  plugin_title: node.text,
                  plugin_iconCls: 'pp-icon-tag',
                  plugin_mode: 'FULLTEXT',
                });

            newNode.select();

			treeEditor.on({
				complete:{
					scope:this,
					single:true,
					fn: function(){
                        newNode.plugin_title=newNode.text;
                        newNode.plugin_query='tags:'+newNode.text
                        newNode.plugin_base_query='tags:'+newNode.text
                        this.onNewTag(newNode);
                    }
				}
            });
                                    
			(function(){treeEditor.triggerEdit(newNode);}.defer(10));
		}.createDelegate(this));

    },


    //
    // Is called after a new folder has been created. Writes folder
    // information to database and updates and saves tree
    // representation to database.
    //

    onNewTag: function(node){

        this.getSelectionModel().clearSelections();
        this.allowSelect=false;

        var pars={tag:node.text,
                  style: 'default'
                 };

        Ext.Ajax.request({
            url: '/ajax/crud/new_tag',
            params: pars,
            success: function(){
                Ext.StoreMgr.lookup('tag_store').reload();
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Added new Tag');
            },
        });
    },

    //
    // Delete the tag given by node globally
    // This code is extremely clumsy, we should consider some event-handler solution
    // but since the boxselect widget is so special this is also not straightforward.
    //
    
    deleteTag: function(node){

        var tag=node.text;

        Ext.Ajax.request({
            url: '/ajax/crud/delete_tag',
            params: { tag: tag },
            success: function(){
                
                // Remove the entry of the tag in the tree                
                node.remove();
                
                // Update store with tags from the server
                Ext.StoreMgr.lookup('tag_store').reload({
                    callback: function(){
                    
                        // Afterwards update entries on all open tabs
                        Paperpile.main.tabs.items.each(
                            function(item, index, length){
                                var grid=item.items.get('center_panel').items.get('grid');
                                var records=grid.getStore().data.items;
                                for (i=0;i<records.length;i++){
                                    var oldTags=records[i].get('tags');
                                    var newTags=oldTags;
                            
                                    newTags=newTags.replace(new RegExp("^"+tag+"$"),"");  //  XXX
                                    newTags=newTags.replace(new RegExp("^"+tag+","),"");  //  XXX,
                                    newTags=newTags.replace(new RegExp(","+tag+"$"),"");  // ,XXX
                                    newTags=newTags.replace(new RegExp(","+tag+","),","); // ,XXX,
                                    
                                    records[i].set('tags',newTags);
                                }
                                // If a entry is selected in a tab, also update the display
                                var pdf_manager=item.items.get('east_panel').items.get('pdf_manager');
                                var selected=grid.getSelectionModel().getSelected();
                                if (selected){
                                    pdf_manager.updateDetail(selected.data, true);
                                }
                            }
                        );
                    }
                });

                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Deleted tag');
            },
        });
    },


    styleTag: function(number){

        var node = this.getSelectionModel().getSelectedNode();

        Ext.Ajax.request({
            url: '/ajax/crud/style_tag',
            params: {tag: node.text, 
                     style: number,
                    },
            success: function(){
               
                
                Ext.StoreMgr.lookup('tag_store').reload({
                    callback: function(){
                        Paperpile.main.tabs.items.each(
                            function(item, index, length){
                                if (item.title == node.text){
                                    var el=Ext.get(Ext.DomQuery.selectNode('span.x-tab-strip-text',Paperpile.main.tabs.getTabEl(this)));
                                    console.log(el);
                                    el.removeClass('pp-tag-style-'+node.tagStyle);
                                    el.addClass('pp-tag-style-'+number);
                                }
                                var grid=item.items.get('center_panel').items.get('grid');
                                var pdf_manager=item.items.get('east_panel').items.get('pdf_manager');
                                var selected=grid.getSelectionModel().getSelected();
                                if (selected){
                                    pdf_manager.updateDetail(selected.data, true);
                                }
                            }
                        );
                        node.ui.removeClass('pp-tag-tree-style-'+node.tagStyle);
                        node.ui.addClass('pp-tag-tree-style-'+number);
                        node.tagStyle=number;
                    }
                });


                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Changes style of Tag');
            },
            scope: this
        });
    },

    //
    // Rename the tag given by node globally
    //
   
    renameTag: function(){

        var node = this.getSelectionModel().getSelectedNode();
        var treeEditor=this.treeEditor;
        var tag=node.text;

        treeEditor.on({
			complete:{
				scope:this,
				single:true,
				fn:function(editor, newText, oldText){
                    Ext.Ajax.request({
                        url: '/ajax/crud/rename_tag',
                        params: { old_tag: tag,
                                  new_tag: newText
                                },
                        success: function(){

                            Ext.StoreMgr.lookup('tag_store').reload({
                                callback: function(){
                      
                                    Paperpile.main.tabs.items.each(
                                        function(item, index, length){
                                            var grid=item.items.get('center_panel').items.get('grid');
                                            var records=grid.getStore().data.items;
                                            for (i=0;i<records.length;i++){
                                                var oldTags=records[i].get('tags');
                                                var newTags=oldTags;
                                                
                                                newTags=newTags.replace(new RegExp("^"+tag+"$"),newText);  //  XXX
                                                newTags=newTags.replace(new RegExp("^"+tag+","),newText+",");  //  XXX,
                                                newTags=newTags.replace(new RegExp(","+tag+"$"),","+newText);  // ,XXX
                                                newTags=newTags.replace(new RegExp(","+tag+","),","+newText+","); // ,XXX,
                                                
                                                records[i].set('tags',newTags);
                                            }
                             
                                            var pdf_manager=item.items.get('east_panel').items.get('pdf_manager');
                                            var selected=grid.getSelectionModel().getSelected();
                                            if (selected){
                                                pdf_manager.updateDetail(selected.data, true);
                                            }
                                        }
                                    );
                                }
                            });

                            //Ext.getCmp('statusbar').clearStatus();
                            //Ext.getCmp('statusbar').setText('Renamed tag');
                        },
                    });
                },
			}
        });

        (function(){treeEditor.triggerEdit(node);}.defer(10));
    },
    

    exportNode: function(){

        var node = this.getSelectionModel().getSelectedNode();

        var window=new Paperpile.ExportWindow({source_node: node.id});
        window.show();

    }

});







Paperpile.Tree.FolderMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        var tree=Paperpile.main.tree;

        Ext.apply(config,{items:[
            { id: 'folder_menu_new',
              text:'New Folder',
              handler: tree.newFolder,
              scope: tree
            },
            { id: 'folder_menu_delete',
              text:'Delete',
              handler: tree.deleteFolder,
              scope: tree
            },
            { id: 'folder_menu_rename',
              text:'Rename',
              handler: tree.renameNode,
              scope: tree
            },
            { id: 'folder_menu_export',
              text:'Export',
              handler: tree.exportNode,
              scope: tree
            },

        ]});
        
        Paperpile.Tree.FolderMenu.superclass.constructor.call(this, config);

        this.on('beforeshow',
                function(){
                    if (this.node.id == 'FOLDER_ROOT'){
                        this.items.get('folder_menu_delete').hide();
                        this.items.get('folder_menu_rename').hide();
                        this.items.get('folder_menu_export').hide();
                    } else {

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
              handler: tree.renameNode,
              scope: tree
            },
            { id: 'active_menu_export',
              text:'Export',
              handler: tree.exportNode,
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
                        this.items.get('active_menu_export').hide();
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

//
// Context menu for import plugins
// is called with the selected node as "node" config parameter
//

Paperpile.Tree.ImportMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        var tree=Paperpile.main.tree;

        Ext.apply(config,{items:[
            { id: 'import_menu_configure',
              text:'Configure',
              handler: function(){
                  Paperpile.main.tree.configureSubtree(this.node);
              },
              scope: this
            }
        ]});
        
        Paperpile.Tree.ImportMenu.superclass.constructor.call(this, config);
        

        this.on('beforeshow',
                function(){
                    if (this.node.id == 'IMPORT_PLUGIN_ROOT'){
                        // more to come later
                    } else {
                        this.items.get('import_menu_configure').disable();
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


//
// Context menu for import plugins
// is called with the selected node as "node" config parameter
//

Paperpile.Tree.TagsMenu = Ext.extend(Ext.menu.Menu, {
    
    constructor:function(config) {
        config = config || {};

        var tree=Paperpile.main.tree;

        Ext.apply(config,{items:[
            { id: 'tags_menu_new',
              text:'New Tag',
              handler: tree.newTag,
              scope: tree
            },

            { id: 'tags_menu_delete',
              text:'Delete',
              handler: function(){
                  Paperpile.main.tree.deleteTag(this.node);
              },
              scope: this
            },
            { id: 'tags_menu_rename',
              text:'Rename',
              handler: tree.renameTag,
              scope: tree
            },
            { id: 'tags_menu_style',
              text:'Style',
              menu: new Paperpile.StylePickerMenu({
                  handler : function(cm, number){
                      // For some reason this handler is called
                      // twice. First with the desired number and the
                      // second time as normal click event. We ignore
                      // the latter case and identify the event object
                      // like this:
                      if (number.A == 65) return;

                      this.styleTag(number);
                                              
                  },
                  scope:tree,
              })
            },
            { id: 'tags_menu_export',
              text:'Export',
              handler: tree.exportNode,
              scope: tree
            },
        ]});
        
        Paperpile.Tree.TagsMenu.superclass.constructor.call(this, config);
        
        this.on('beforeshow',
                function(){
                    if (this.node.id == 'TAGS_ROOT'){
                        this.items.get('tags_menu_delete').hide();
                        this.items.get('tags_menu_rename').hide();
                        this.items.get('tags_menu_export').hide();
                        this.items.get('tags_menu_style').hide();
                    } 
                }, this
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
