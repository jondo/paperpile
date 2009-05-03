Paperpile.PdfExtractGrid = Ext.extend(Ext.grid.GridPanel, {

    region:'center',
    root: '/home/wash/PDFs',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: '/ajax/pdfextract/grid', 
                method: 'GET'
            }),
               baseParams:{grid_id: this.id,
                           root: this.root,
                          },
               reader: new Ext.data.JsonReader(),
            }); 
        
        var tbar=[{xtype:'tbfill'},
                  {   xtype:'button',
                      itemId: 'new_button',
                      text: 'New',
                      cls: 'x-btn-text-icon add',
                      disabled: true,
                      //listeners: {
                      //    click:  {fn: this.newEntry, scope: this}
                      //},
                  },
                 ];
   
        Ext.apply(this, {
            ddGroup  : 'gridDD',
            itemId:'grid',
            store: _store,
            tbar: tbar,
            autoExpandColumn:'file_name',

            columns:[{header: "File",
                      id: 'file_name',
                      dataIndex: 'file_name',
                     },
                     {header: "Title",
                      id: 'title',
                      dataIndex: 'title',
                     },
                     {header: "Authors",
                      id: 'authors',
                      dataIndex: '_authors_display',
                     },
                     {header: "DOI",
                      id: 'doi',
                      dataIndex: 'doi',
                     }
                    ],
        });
        
        Paperpile.PdfExtractGrid.superclass.initComponent.apply(this, arguments);

        this.store.load({callback: this.extract,
                         scope: this,
                        } 
                       );

      
    },

    extract: function(record){

         Ext.Ajax.request({
            url: '/ajax/pdfextract/extract',
             params: { root: this.root,
                       grid_id: this.id,
                     },
             method: 'GET',
             success: function(response){
                 this.store.reload();
             },
             scope:this,
             timeout: 600000,
         });
    }
    

});
