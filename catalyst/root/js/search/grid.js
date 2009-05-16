Paperpile.PluginGrid = Ext.extend(Ext.grid.GridPanel, {

    plugin_query:'',
    closable:true,
    region:'center',
    limit: 25,

    initComponent:function() {


        console.log('PluginGrid');

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

        var tbar=[{xtype:'tbfill'},
                  {   xtype:'button',
                      itemId: 'new_button',
                      text: 'New',
                      cls: 'x-btn-text-icon add',
                      disabled: true,
                      listeners: {
                          click:  {fn: this.newEntry, scope: this}
                      },
                  },
                  {   xtype:'button',
                      text: 'Delete',
                      itemId: 'delete_button',
                      cls: 'x-btn-text-icon delete',
                      listeners: {
                          click:  {fn: this.deleteEntry, scope: this}
                      },
                      disabled: true,
                  },
                  {   xtype:'button',
                      itemId: 'edit_button',
                      text: 'Edit',
                      cls: 'x-btn-text-icon edit',
                      listeners: {
                          click:  {fn: this.editEntry, scope: this}
                      },
                      disabled: true,
                  }, 
                  {  xtype:'button',
                     text: 'More',
                     itemId: 'more_menu',
                     menu:new Ext.menu.Menu({
                         //itemId: 'more_menu',
                         items:[
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
                     disabled: true,
                  }
                 ];

        
   
        var renderPub=function(value, p, record){

            // Can possibly be speeded up with compiling the template.

            record.data._notes_tip=Ext.util.Format.stripTags(record.data.notes);
            record.data._citekey=Ext.util.Format.ellipsis(record.data.citekey,18);

            var t = new Ext.XTemplate(
                '<div class="pp-grid-status">',
                '<div class="pp-grid-key" ext:qtip="Imported {created}" >{_citekey}&nbsp;</div',
                '<div class="pp-grid-icons">',
                '<tpl if="pdf">',
                '<div class="pp-status-pdf" ext:qtip="{pdf}"></div>',
                '</tpl>',
                '<tpl if="attachments">',
                '<div class="pp-status-attachments" ext:qtip="{attachments} attached file(s)"></div>',
                '</tpl>',
                '<tpl if="notes">',
                '<div class="pp-status-notes" ext:qtip="{_notes_tip}"></div>',
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

        
        this.on('beforedestroy', this.onDestroy,this);

    },

    afterRender: function(){

        this.getSelectionModel().on('rowselect',
                                    function(sm, rowIdx, r){
                                        var container= this.findParentByType(Paperpile.PubView);
                                        this.updateButtons();
                                        container.onRowSelect(sm, rowIdx, r);
                                        this.completeEntry();
                                    },this);
        
        Paperpile.PluginGrid.superclass.afterRender.apply(this, arguments);
   
    },

    updateButtons: function(){
        
        var tbar = this.getTopToolbar();
        var sm = this.getSelectionModel();
        var record = sm.getSelected();
        
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
                
    },

   // Small helper functions to get the index of a given item in the toolbar configuration array

    getButtonIndex: function(itemId){
        
        var tbar=this.getTopToolbar();

        for (var i=0; i<tbar.length;i++){
            if (tbar[i].itemId == itemId) return i;
        }
    },
    
    // Returns list of sha1s for the selected entries

    getSelection: function(){

        var selection=[];

        this.getSelectionModel().each(
            function(record){
                selection.push(record.get('sha1'));
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
        
        var sha1=this.getSelectionModel().getSelected().data.sha1;
        Ext.Ajax.request({
            url: '/ajax/crud/insert_entry',
            params: { sha1: sha1,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry Inserted.');

                var record=this.store.getAt(this.store.find('sha1',sha1));

                // Only update relevant fields that have changed for performence reasons
                //this.store.getAt(this.store.find('sha1',sha1)).data=json.data;
                record.beginEdit();
                record.set('_imported',1);
                record.set('citekey',json.data.citekey);
                record.set('_rowid', json.data._rowid);
                record.endEdit();
                
                this.updateButtons();
                    
                if (callback){
                    callback.createDelegate(scope,[json.data])();
                }

            },
            scope:this
        });

    },

    deleteEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().data.sha1;

        this.getSelectionModel().selectNext();

        Ext.Ajax.request({
            url: '/ajax/crud/delete_entry',
            params: { rowid: rowid,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(){
                this.updateButtons();
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
            scope: this
        });

        this.store.remove(this.store.getAt(this.store.find('sha1',sha1)));

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

        var form=new Paperpile.Forms.PubEdit({data:this.getSelectionModel().getSelected().data,
                                              grid_id: this.id,
                                              spotlight: true,
                                             });

        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');
        
        east_panel.hideBbar();
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');


    },

    newEntry: function(){

        var form=new Paperpile.Forms.PubEdit({data:{pubtype:'ARTICLE'}, grid_id: null });

        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');
        
        east_panel.hideBbar();
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');

    },

    onDestroy: function(cont, comp){
        Ext.Ajax.request({
            url: '/ajax/plugins/delete_grid',
            params: { grid_id: this.id,
                    },
            method: 'GET'
        });
    },
});








