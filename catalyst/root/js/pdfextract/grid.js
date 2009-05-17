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
                      itemId: 'import_button',
                      text: 'Import',
                      cls: 'x-btn-text-icon add',
                      //disabled: true,
                      listeners: {
                          click:  {fn: this.controlPanel.importPDF, scope: this.controlPanel}
                      },
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
                     },
                     {header: "Status",
                      id: 'status',
                      renderer: function(value, p, record){
                          var template='<div ext:qtip="{status_msg}">{status}</div';
                          var t = new Ext.XTemplate(template);
                          return t.apply(record.data);
                      }
                     }
                    ],
        });
        
        Paperpile.PdfExtractGrid.superclass.initComponent.apply(this, arguments);

        this.store.load({
            callback: function(){
                this.controlPanel=this.ownerCt.ownerCt.items.get('control_panel');
                this.controlPanel.showControls();
            },
            scope: this
        });
        
    },

      

});
