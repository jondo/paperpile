Paperpile.PluginGrid = Ext.extend(Ext.grid.GridPanel, {

    plugin_query:'',
    closable:true,
    region:'center',
    limit: 25,
    allSelected:false,
    itemId:'grid',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: '/ajax/plugins/resultsgrid', 
                method: 'GET'
            }),
               baseParams:{grid_id: this.id,
                           plugin_file: this.plugin_file,
                           plugin_name: this.plugin_name,
                           plugin_query: this.plugin_query,
                           plugin_mode: this.plugin_mode,
                           plugin_order: "created DESC",
                           limit:this.limit
                          },
               reader: new Ext.data.JsonReader(),
            }); 
        
        var _pager=new Ext.PagingToolbar({
            pageSize: this.limit,
            store: _store,
            displayInfo: true,
            displayMsg: 'Displaying papers {0} - {1} of {2}',
            emptyMsg: "No papers to display",
        });

        this.actions={
            'NEW': new Ext.Action({
                text: 'New',
                handler: this.newEntry,
                scope: this,
                cls: 'x-btn-text-icon add',
                disabled:true,
                itemId:'new_button'
                
            }),
            
            'EDIT': new Ext.Action({
                text: 'Edit',
                handler: this.editEntry,
                scope: this,
                cls: 'x-btn-text-icon edit',
                disabled:true,
                itemId:'edit_button'
            }),

            'DELETE': new Ext.Action({
                text: 'Delete',
                handler: this.deleteEntry,
                scope: this,
                cls: 'x-btn-text-icon delete',
                disabled:true,
                itemId:'delete_button'
            }),

            'IMPORT': new Ext.Action({
                text: 'Import',
                handler: this.insertEntry,
                scope: this,
                cls: 'x-btn-text-icon add',
                disabled:true,
                itemId:'import_button'
            }),
            
            'EXPORT': new Ext.Action({
                text: 'Export',
                handler: this.exportEntry,
                scope: this,
                disabled:true,
                itemId:'export_button'
            }),

            'SELECT_ALL': new Ext.Action({
                text: 'Select all',
                handler: this.selectAll,
                scope: this,
                disabled:true,
                itemId:'select_all_button'
            }),


        };


        var tbar=[{xtype:'tbfill'},
                  this.actions['NEW'],
                  this.actions['IMPORT'],
                  this.actions['DELETE'],
                  this.actions['EDIT'],
                  { xtype:'button',
                    itemId: 'more_menu',
                    menu:new Ext.menu.Menu({
                        items:[
                            this.actions['EXPORT'],
                            this.actions['SELECT_ALL'],
                        ]
                    })
                  }


                  /*

 {   xtype:'button',
                      itemId: 'new_button',
                      text: 'New',
                      cls: 'x-btn-text-icon add',
                      //disabled: true,
                      listeners: {
                          click:  {fn: this.newEntry, scope: this}
                      },
                  },

                  { xtype:'button',
                    itemId: 'add_button',
                    text: 'Import',
                    hidden:true,
                    cls: 'x-btn-text-icon add',
                    listeners: {
                        click:  {
                            fn: function(){
                                this.insertEntry();
                            },
                            scope: this
                        },
                    },
                    //disabled: true,
                  },
                  {   xtype:'button',
                      text: 'Delete',
                      itemId: 'delete_button',
                      cls: 'x-btn-text-icon delete',
                      listeners: {
                          click:  {fn: this.deleteEntry, scope: this}
                      },
                      //disabled: true,
                  },
                  {   xtype:'button',
                      itemId: 'edit_button',
                      text: 'Edit',
                      cls: 'x-btn-text-icon edit',
                      listeners: {
                          click:  {fn: this.editEntry, scope: this}
                      },
                      //disabled: true,
                  }, 
                  {  xtype:'button',
                     text: 'More',
                     itemId: 'more_menu',
                     menu:new Ext.menu.Menu({
                         //itemId: 'more_menu',
                         items:[
                             {  text: 'Select all',
                                listeners: {
                                    click: {fn: function(){
                                        this.allSelected=true;
                                        this.getSelectionModel().selectAll();
                                        this.getSelectionModel().on('selectionchange',
                                                                    function(sm){
                                                                        this.allSelected=false;
                                                                    }, this, {single:true});
                                        this.getSelectionModel().on('rowdeselect',
                                                                    function(sm){
                                                                        sm.clearSelections();
                                                                    }, this, {single:true});
                                        
                                    }, scope: this}
                                },
                             },
                             {  text: 'Export selected',
                                listeners: {
                                    click:  {fn: function(){this.exportEntry('selection')}, scope: this}
                                },
                             },
                             {  text: 'Export all',
                                listeners: {
                                    click:  {fn: function(){this.exportEntry('all')}, scope: this}
                                },
                             }
                         ]
                     }),
                     //disabled: true,
                  }*/
                 ];
        
        this.contextMenu=new Ext.menu.Menu({
            items:[
                this.actions['IMPORT'],
                this.actions['DELETE'],
                this.actions['EDIT'],
                this.actions['EXPORT'],
                this.actions['SELECT_ALL'],
            ]
        });
        
        this.on('rowcontextmenu', 
                function(grid, row, e){
                    this.getSelectionModel().selectRow(row);
                    this.contextMenu.showAt(e.getXY());
                }, this, {stopEvent:true});

        var renderPub=function(value, p, record){

            // Can possibly be speeded up with compiling the template.

            record.data._notes_tip=Ext.util.Format.stripTags(record.data.notes);
            record.data._citekey=Ext.util.Format.ellipsis(record.data.citekey,18);

            var t = new Ext.XTemplate(
                '<div class="pp-grid-info">',
                '<tpl if="_imported">',
                '<div class="pp-grid-key" ext:qtip="Imported {created}" >{_citekey}&nbsp;</div',
                '</tpl>',
                '<tpl if="!_imported">',
                '<div>&nbsp;</div',
                '</tpl>',
                '<div>',
                '<tpl if="pdf">',
                '<div class="pp-grid-status pp-grid-status-pdf" ext:qtip="{pdf}"></div>',
                '</tpl>',
                '<tpl if="attachments">',
                '<div class="pp-grid-status pp-grid-status-attachments" ext:qtip="{attachments} attached file(s)"></div>',
                '</tpl>',
                '<tpl if="notes">',
                '<div class="pp-grid-status pp-grid-status-notes" ext:qtip="{_notes_tip}"></div>',
                '</tpl>',
                '</div>',
                '</div>',
                '<div class="pp-grid-data">',
                '<p class="pp-grid-title">{title}</p>',
                '<p class="pp-grid-authors">{_authors_display}</p>',
                '<p class="pp-grid-citation">{_citation_display}</p>',
                '<tpl if="_snippets_text">',
                '<p class="pp-grid-snippets"><span class="heading">PDF:</span> {_snippets_text}</p>',
                '</tpl>',
                '<tpl if="_snippets_abstract">',
                '<p class="pp-grid-snippets"><span class="heading">Abstract:</span> {_snippets_abstract}</p>',
                '</tpl>',
                '<tpl if="_snippets_notes">',
                '<p class="pp-grid-snippets"><span class="heading">Notes:</span> {_snippets_notes}</p>',
                '</tpl>',
                '</div>'
            );

            return t.apply(record.data);

        }
    
        Ext.apply(this, {
            ddGroup  : 'gridDD',
            enableDragDrop   : true,
            itemId:'grid',
            store: _store,
            bbar: _pager,
            tbar: tbar,
            enableHdMenu : false,
            autoExpandColumn:'publication',

            columns:[{header: "Papers",
                      id: 'publication',
                      dataIndex: 'title',
                      renderer:renderPub,
                     }
                    ],
        });
        
        Paperpile.PluginGrid.superclass.initComponent.apply(this, arguments);

        
        this.on('beforedestroy', this.onClose,this);


        // A bug in ExtJS 2.2 does not allow clearing a multiple selection when an item is clicked
        // This hack should become unnecessary in future versions of ExtJS
        this.on('rowclick', 
                function( grid, rowIndex, e ){
                    if (e.hasModifier()){
                        return;
                    }
                    var sm=this.getSelectionModel();
                    if (sm.getCount()>1 && sm.isSelected(rowIndex)){
                        sm.clearSelections();
                    }
                }, this);

        this.store.on('loadexception', this.onError);

        this.store.on('load', 
                      function(){
                          this.getSelectionModel().selectRow(0);
                      }, this);
        
    },


    afterRender: function(){

        this.getSelectionModel().on('rowselect',
                                    function(sm, rowIdx, r){
                                        var container= this.findParentByType(Paperpile.PubView);
                                        this.updateButtons();
                                        container.onRowSelect(sm, rowIdx, r);
                                        this.completeEntry();
                                    },this);

        this.getSelectionModel().on('rowdeselect',
                                    function(sm, rowIdx, r){
                                        var container= this.findParentByType(Paperpile.PubView);
                                        container.onRowSelect(sm, rowIdx, r);
                                    },this);


        this.el.on({
			contextmenu:{fn:function(){return false;},stopEvent:true}
		});
        
        Paperpile.PluginGrid.superclass.afterRender.apply(this, arguments);
   
    },

    onError: function(exception, options, response, error){
        Paperpile.main.error(response);
    },

    updateButtons: function(){
        
        var imported=this.getSelection('IMPORTED').length;
        var notImported=this.getSelection('NOT_IMPORTED').length;
        var selected=imported+notImported;
        
        console.log(imported, notImported, selected);

        console.log(this.getTopToolbar().items);

        this.actions['NEW'].enable();
        this.actions['EXPORT'].enable();

        if (selected == 1){
            this.actions['EDIT'].setDisabled(imported==0);
            this.actions['IMPORT'].setDisabled(imported);
            this.actions['DELETE'].setDisabled(imported==0);
        }

        if (selected > 1 ){
            this.actions['EDIT'].disable();
            this.actions['DELETE'].setDisabled(imported==0);
            this.actions['IMPORT'].setDisabled(imported==0);
        }

        this.actions['SELECT_ALL'].setDisabled(this.allSelected);

        /*
        var tbar = this.getTopToolbar();
        var sm = this.getSelectionModel();
        var record = sm.getSelected();
        
        return;
        
        if (tbar.items.get('new_button')){
            tbar.items.get('new_button').enable();
        }

        tbar.items.get('more_menu').enable();

        if (tbar.items.get('edit_button')){
            if (record){
                if (record.data._imported && (sm.getCount() == 1 )){
                    tbar.items.get('edit_button').enable();
                } else {
                    tbar.items.get('edit_button').disable();
                }
            }
        }

        if (tbar.items.get('add_button')){
            tbar.items.get('add_button').setDisabled( record.data._imported );
        }

        if (tbar.items.get('delete_button')){
            tbar.items.get('delete_button').setDisabled( ! record.data._imported );
        }
*/

                
    },

   // Small helper functions to get the index of a given item in the toolbar configuration array
   // We have to use the text instead of itemId. Actions do not seem to support itemIds. 
   // A better solution should be possible with ExtJS 3

    getButtonIndex: function(itemId){
        var tbar=this.getTopToolbar();
        for (var i=0; i<tbar.length;i++){
            if (tbar[i].getText){
                if (tbar[i].getText() == itemId) return i;
            }
        }
    },
    
    // Returns list of sha1s for the selected entries, either ALL, IMPORTED, NOT_IMPORTED

    getSelection: function(what){

        if (!what) what='ALL';

        if (this.allSelected){
            return 'ALL';
        }
        
        var selection=[];

        this.getSelectionModel().each(
            function(record){
                if ((what == 'ALL') ||
                    (what == 'IMPORTED' && record.get('_imported')) ||
                    (what == 'NOT_IMPORTED' && !record.get('_imported'))){
                    selection.push(record.get('sha1'));
                }
            });

        return selection;

    },

    // Some plugins use a two-stage process for showing entries: First
    // only minimal info is scraped from site to build list quickly
    // without harassing the site too much. Then the details are
    // fetched only when user clicks the entry.
       
    completeEntry: function(){

        // _details_link indicates if an entry still needs to be completed or not
        if (this.getSelectionModel().getSelected().data._details_link){

            var sha1=this.getSelectionModel().getSelected().data.sha1;
        
            Ext.getCmp('statusbar').setText('Downloading details');
            Ext.getCmp('statusbar').showBusy();
        
            Ext.Ajax.request({
                url: '/ajax/crud/complete_entry',
                params: { sha1: sha1,
                          grid_id: this.id,
                        },
                method: 'GET',
                success: function(response){
                    var json = Ext.util.JSON.decode(response.responseText);
                    var record=this.store.getAt(this.store.find('sha1',sha1));
                    record.beginEdit();
                    for ( var i in json.data){
                        record.set(i,json.data[i]);
                    }
                    record.endEdit();
                    Ext.getCmp('statusbar').clearStatus();
                },
                scope:this
            });
        }
    },


    //
    // Inserts the entry into local database. Optionally a callback function+scope can be given;
    // If no callback function is needed make sure function is called with insertEntry()
    //

    insertEntry: function(callback,scope){
        
        var selection=this.getSelection('NOT_IMPORTED');

        //var selection=this.getSelection();

        if (selection.length==0) return;
        
        Ext.Ajax.request({
            url: '/ajax/crud/insert_entry',
            params: { selection: selection,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry Inserted.');

                this.store.suspendEvents();
                for (var sha1 in json.data){
                    var record=this.store.getAt(this.store.find('sha1',sha1));
                    if (!record) continue;
                    record.beginEdit();
                    record.set('_imported',1);
                    record.set('citekey',json.data[sha1].citekey);
                    record.set('_rowid', json.data[sha1]._rowid);
                    record.endEdit();
                }
                this.store.resumeEvents();
                this.store.fireEvent('datachanged',this.store);

                this.updateButtons();
                    
                if (callback){
                    callback.createDelegate(scope,[json.data])();
                }

            },
            scope:this
        });

    },

    deleteEntry: function(){
        
        selection=this.getSelection();

        var index=this.store.indexOf(this.getSelectionModel().getSelected());

        Ext.Ajax.request({
            url: '/ajax/crud/delete_entry',
            params: { selection: selection,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(){
                this.updateButtons();
                if (selection == 'ALL'){
                    this.store.removeAll();
                } else {
                    for (var i=0;i<selection.length;i++){
                        this.store.remove(this.store.getAt(this.store.find('sha1',selection[i])));
                    }
                    this.getSelectionModel().selectRow(index);
                }
                
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
            scope: this
        });

    },

    exportEntry: function(what){

        var selection=[];
        
        if (what == 'selection'){
            selection=this.getSelection();
        }
        
        var window=new Paperpile.ExportWindow({source_grid:this.id, 
                                               selection:selection,
                                              });

        window.show();

    },

    editEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().data.sha1;

        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');

        var form=new Paperpile.Forms.PubEdit({data:this.getSelectionModel().getSelected().data,
                                              grid_id: this.id,
                                              spotlight: true,
                                              callback: function(status){
                                                  east_panel.remove('pub_edit');
                                                  east_panel.doLayout();
                                                  east_panel.getLayout().setActiveItem('pdf_manager');
                                                  east_panel.showBbar();
                                              },
                                              scope:this
                                             });

        
        east_panel.hideBbar();
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');
    },

    newEntry: function(){
        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');

        var form=new Paperpile.Forms.PubEdit({data:{pubtype:'ARTICLE'}, 
                                              grid_id: null,
                                              spotlight: true,
                                              callback: function(status,data){
                                                  east_panel.remove('pub_edit');
                                                  east_panel.doLayout();
                                                  east_panel.getLayout().setActiveItem('pdf_manager');
                                                  east_panel.showBbar();
                                              },
                                              scope:this

                                             });

       
        east_panel.hideBbar();
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');

    },

    // Update specific fields of specific entries to avoid complete
    // reload of everything data is a hash of a hash with sha1 as the
    // first key and the other fields that need to be udpated as the
    // other keys

    updateData: function(data){
        this.store.suspendEvents();
        for (var sha1 in data){
            var record=this.store.getAt(this.store.find('sha1',sha1));
            if (!record) continue;
            var update=data[sha1];
            record.beginEdit();
            for (var field in update){
                record.set(field,update[field]);
            }
            record.endEdit();
        }
        this.store.resumeEvents();
        this.store.fireEvent('datachanged',this.store);
    },


    selectAll: function(){
        this.allSelected=true;
        this.getSelectionModel().selectAll();
        this.getSelectionModel().on('selectionchange',
                                    function(sm){
                                        this.allSelected=false;
                                    }, this, {single:true});
        this.getSelectionModel().on('rowdeselect',
                                    function(sm){
                                        sm.clearSelections();
                                    }, this, {single:true});
        
    },
    

    onClose: function(cont, comp){
        Ext.Ajax.request({
            url: '/ajax/plugins/delete_grid',
            params: { grid_id: this.id,
                    },
            method: 'GET'
        });
    },
});








