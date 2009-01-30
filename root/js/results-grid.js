PaperPile.ResultsGrid = Ext.extend(Ext.grid.GridPanel, {

    source_type: '',
    source_file: '',
    source_query: '',
    closable:true,

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: '/ajax/grid/resultsgrid', 
                method: 'GET'
            }),
               baseParams:{source_id: this.id,
                           source_file: this.source_file,
                           source_type: this.source_type,
                           source_query: this.source_query,
                           source_mode: this.source_mode,
                           limit:25
                          },
               reader: new Ext.data.JsonReader(),
            }); 
        
        var _pager=new Ext.PagingToolbar({
            pageSize: 25,
            store: _store,
            displayInfo: true,
            displayMsg: 'Displaying papers {0} - {1} of {2}',
            emptyMsg: "No papers to display",
        });
    
        var renderPub=function(value, p, record){

            var t = new Ext.Template(
                '<p class="pp-grid-title">{title}</p>',
                '<p class="pp-grid-authors">{authors}</p>',
                '<p class="pp-grid-citation">{citation}</p>'
            );
            return t.apply({title:record.data.title,
                            authors:record.data._authors_nice,
                            citation:record.data._citation_nice,
                           });
        }
    
        Ext.apply(this, {
            ddGroup  : 'gridDD',
            enableDragDrop   : true,
            store: _store,
            bbar: _pager,
            autoExpandColumn:'publication',
            columns:[{header: 'Citation',
                      renderer: function(value, metadata,record, rowIndex,colIndex,store){
                          if (record.data._imported){
                              return '<div class="pp-status-imported"></div>';
                          } else {
                              return '';
                          }
                      },
                      width: 60,
                     },
                     {header: 'PDF',
                      renderer: function(value, metadata,record, rowIndex,colIndex,store){
                          if (record.data.pdf){
                              return '<div class="pp-status-pdf"></div>';
                          } else {
                              return '';
                          }
                      },
                      width: 60,
                     },
                     {header: "Publication",
                      id: 'publication',
                      dataIndex: 'title',
                      renderer:renderPub,
                     }
                    ],
            
        });
        
        PaperPile.ResultsGrid.superclass.initComponent.apply(this, arguments);

        this.getSelectionModel().on('rowselect', main.onRowSelect,main);

        this.on('beforedestroy', this.onDestroy,this);

    },

    
    insertEntry: function(){
        
        var sha1=this.getSelectionModel().getSelected().id;
        Ext.Ajax.request({
            url: '/ajax/crud/insert_entry',
            params: { sha1: sha1,
                      source_id: this.id,
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry Inserted.');
                this.store.getById(sha1).set('_imported',1);
            },
            scope:this
        });

    },

    deleteEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().id;

        Ext.Ajax.request({
            url: '/ajax/crud/delete_entry',
            params: { rowid: rowid,
                      source_id: this.id,
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
        });

        this.store.remove(this.store.getById(sha1));
    },

    editEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().id;

        var form = new PaperPile.PubEdit(
            {id:'pub_edit',
             itemId:'pub_edit',
             data:this.getSelectionModel().getSelected(),
             source_id: this.id, 
             items: [{ fieldLabel: 'Type',  name: 'dummy', id:'dummy' }],
            }
        )

        Ext.getCmp('canvas_panel').add(form);
        Ext.getCmp('canvas_panel').doLayout();
        Ext.getCmp('canvas_panel').getLayout().setActiveItem('pub_edit');

    },

    onDestroy: function(cont, comp){
        Ext.Ajax.request({
            url: '/ajax/grid/delete_grid',
            params: { source_id: this.id,
                    },
            method: 'GET'
        });
    },
});

PaperPile.ResultsGridPubMed = Ext.extend(PaperPile.ResultsGrid, {

    loadMask: {msg:"Searching PubMed"},

    initComponent:function() {

        var _searchField=new Ext.app.SearchField({
            width:320,
        })

        Ext.apply(this, {
            source_type: 'PUBMED',
            title: 'PubMed',
            iconCls: 'pp-icon-pubmed',
            tbar:[_searchField,
                    {xtype:'tbfill'},
                    {   xtype:'button',
                        itemId: 'add_button',
                        text: 'Import',
                        cls: 'x-btn-text-icon add',
                        listeners: {
                            click:  {fn: this.insertEntry, scope: this}
                        },
                    },
                 ],
        });

        PaperPile.ResultsGridPubMed.superclass.initComponent.apply(this, arguments);

        _searchField.store=this.store;


    }
});


PaperPile.ResultsGridDB = Ext.extend(PaperPile.ResultsGrid, {

    base_query:'',
    
    initComponent:function() {
        
        var _filterField=new Ext.app.FilterField({
            width:320,
        });

        Ext.apply(this, {
            source_type: 'DB',
            title: 'Local library',
            iconCls: 'pp-icon-page',
            tbar:  [_filterField, 
                    {xtype:'tbfill'},
                    {   xtype:'button',
                        itemId: 'new_button',
                        text: 'New',
                        cls: 'x-btn-text-icon add',
                        listeners: {
                            click:  {fn: this.editEntry, scope: this}
                        },
                    },
                    {   xtype:'button',
                        text: 'Delete',
                        itemId: 'delete_button',
                        cls: 'x-btn-text-icon delete',
                        listeners: {
                            click:  {fn: this.deleteEntry, scope: this}
                        },
                    },
                    {   xtype:'button',
                        itemId: 'edit_button',
                        text: 'Edit',
                        cls: 'x-btn-text-icon edit',
                        listeners: {
                            click:  {fn: this.editEntry, scope: this}
                        },
                    },

                   ]
            
        });

        PaperPile.ResultsGridDB.superclass.initComponent.apply(this, arguments);
        _filterField.store=this.store;
    
        _filterField.base_query=this.base_query;


    },

    onRender: function() {
        PaperPile.ResultsGridDB.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25 }});
    }
});


PaperPile.ResultsGridFile = Ext.extend(PaperPile.ResultsGrid, {

    loadMask: true,

    initComponent:function() {
        Ext.apply(this, {
            source_type: 'FILE',
            title: 'RIS',
            iconCls: 'pp-icon-page',
        });

        PaperPile.ResultsGridFile.superclass.initComponent.apply(this, arguments);

    },

    onRender: function() {
        PaperPile.ResultsGridFile.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, 
                                 limit:25, 
                                 source_file: this.source_file,
                                }});

    }
});





