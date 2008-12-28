PaperPile.ResultsGrid = Ext.extend(Ext.grid.GridPanel, {

    source_type: '',
    source_file: '',
    source_query: '',

    closable:true,
    
    initComponent:function() {

        var _store=new Ext.data.Store(
            {id: 'data',
             proxy: new Ext.data.HttpProxy({
                 url: '/ajax/resultsgrid', 
                 method: 'GET'
             }),
             baseParams:{source_id: this.id,
                         source_file: this.source_file,
                         source_type: this.source_type,
                         source_query: this.source_query,
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
            items:[ 
                new Ext.Button({
                    id: 'buttonx',
                    text: 'Add',
                    cls: 'x-btn-text-icon add',
                    listeners: {
                        click:  {fn: this.insertEntry, scope: this}
                    },
                }),
                new Ext.Button({
                    id: 'buttonx',
                    text: 'Delete',
                    cls: 'x-btn-text-icon delete',
                    listeners: {
                        click:  {fn: this.deleteEntry, scope: this}
                    },
                })
            ]
        });
    
        var renderPub=function(value, p, record){
            return String.format('<p><b>{0}</b></p>{1}',record.data.title,record.data.authors_flat);
        }
    
        Ext.apply(this, {
            store: _store,
            bbar: _pager,
            border:true,
            iconCls: 'tabs',
            columns:[{header: 'Imported',
                      dataIndex: 'imported',
                     },
                     {header: "Publication",
                      width: 400,
                      renderer:renderPub
                     }],
        });
        
        PaperPile.ResultsGrid.superclass.initComponent.apply(this, arguments);

        this.getSelectionModel().on('rowselect', main.onRowSelect,main);

        this.on('beforedestroy', this.onDestroy,this);

    }, // eo function initComponent

    
    insertEntry: function(){
        
        var sha1=this.getSelectionModel().getSelected().id;
        Ext.Ajax.request({
            url: '/ajax/insert_entry',
            params: { sha1: sha1,
                      source_id: this.id,
                    },
            method: 'GET'
            //success: this.validateFeed,
            //failure: this.markInvalid,
        });

        this.store.getById(sha1).set('imported',1);
    },

    deleteEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('rowid');
        var sha1=this.getSelectionModel().getSelected().id;

        Ext.Ajax.request({
            url: '/ajax/delete_entry',
            params: { rowid: rowid,
                      source_id: this.id,
                    },
            method: 'GET'
            //success: this.validateFeed,
            //failure: this.markInvalid,
        });

        this.store.remove(this.store.getById(sha1));
        //this.store.remove(this.store.reload());
    },


    onDestroy: function(cont, comp){
        Ext.Ajax.request({
            url: '/ajax/delete_grid',
            params: { source_id: this.id,
                    },
            method: 'GET'
            //success: this.validateFeed,
            //failure: this.markInvalid,
        });
    },
});

PaperPile.ResultsGridPubMed = Ext.extend(PaperPile.ResultsGrid, {

    initComponent:function() {

        var _searchField=new Ext.app.SearchField({
            width:320,
        })

        Ext.apply(this, {
            source_type: 'PUBMED',
            title: 'PubMed',
            tbar:[_searchField],
        });

        PaperPile.ResultsGridPubMed.superclass.initComponent.apply(this, arguments);

        _searchField.store=this.store;


    }, // eo function initComponent
});


PaperPile.ResultsGridDB = Ext.extend(PaperPile.ResultsGrid, {

    initComponent:function() {
        
        var _filterField=new Ext.app.FilterField({
            width:320,
        })

        Ext.apply(this, {
            source_type: 'DB',
            title: 'Local library',
            iconCls: 'tabs',
            tbar:[_filterField],
        });

        PaperPile.ResultsGridDB.superclass.initComponent.apply(this, arguments);
        _filterField.store=this.store;

    }, // eo function initComponent

    onRender: function() {
        PaperPile.ResultsGrid.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25}});
    }
});


PaperPile.ResultsGridFile = Ext.extend(PaperPile.ResultsGrid, {

    loadMask: true,

    initComponent:function() {
        Ext.apply(this, {
            source_type: 'FILE',
            title: 'RIS',
            iconCls: 'tabs',
        });

        PaperPile.ResultsGridPubMed.superclass.initComponent.apply(this, arguments);

    }, // eo function initComponent

    onRender: function() {
        PaperPile.ResultsGrid.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25}});
    }
});


Ext.reg('resultsgrid', PaperPile.ResultsGrid);
Ext.reg('resultsgridpubmed', PaperPile.ResultsGridPubMed);
Ext.reg('resultsgriddb', PaperPile.ResultsGridDB);
 







