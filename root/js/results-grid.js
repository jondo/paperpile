PaperPile.ResultsGrid = Ext.extend(Ext.grid.GridPanel, {

    source_type: '',
    source_file: '',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {id: 'data',
             proxy: new Ext.data.HttpProxy({
                 url: '/ajax/resultsgrid', 
                 method: 'GET'
             }),
             baseParams:{task: "LISTING", 
                         source_id: this.id,
                         source_file: this.source_file,
                         source_type: this.source_type
                        },
             reader: new Ext.data.JsonReader(),
            }); // eof _store

        var _pager=new Ext.PagingToolbar({
            pageSize: 25,
            store: _store,
            displayInfo: true,
            displayMsg: 'Displaying papers {0} - {1} of {2}',
            emptyMsg: "No papers to display",
            items:[ 
                new Ext.Button({
                    id: 'buttonx',
                    text: 'Add to database',
                    cls: 'x-btn-text-icon add',
                    listeners: {
                        click:  {fn: this.insertEntry, scope: this}
                    }
                })
            ]
        }); // eof _pager
    

        var renderPub=function(value, p, record){
            return String.format('<b>{0}</b><br>{1}',record.data.title,record.data.authors_flat);
        }
    
        Ext.apply(this, {
            store: _store,
            bbar: _pager,
            border:true,
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

    }, // eo function initComponent

    
    insertEntry: function(){
        
        var pubid=this.getSelectionModel().getSelected().id;
        Ext.Ajax.request({
            url: '/ajax/insert_entry',
            params: { pub_id: pubid,
                      source_id: this.id,
                    },
            method: 'GET'
            //success: this.validateFeed,
            //failure: this.markInvalid,
        });

      this.store.getById(pubid).set('imported',1);

        
    },

    onRender: function() {
        this.store.load({params:{start:0, limit:25}});
        PaperPile.ResultsGrid.superclass.onRender.apply(this, arguments);
        
    }
   
}
                                
 
);
 
Ext.reg('resultsgrid', PaperPile.ResultsGrid);
