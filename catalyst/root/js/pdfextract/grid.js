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
                          click:  {fn: 
                                   function(){
                                       var record=this.getSelectionModel().getSelected();
                                       this.controlPanel.importPDF.createDelegate(this.controlPanel,[record])();
                                   },
                                   scope: this
                                  }
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
                          if (record.get('status') == 'NEW') template='';
                          if (record.get('status') == 'IMPORTED') {
                              template='<div ext:qtip="{status_msg}" class="pp-icon-tick">Imported</div>';
                          }
                          if (record.get('status') == 'FAIL') {
                              template='<div ext:qtip="{status_msg}" class="pp-icon-cross">No match</div>';
                          }

                          var t = new Ext.XTemplate(template);
                          
                          return t.apply({ status_msg:record.get('status_msg'),
                                         }
                                        );
                      }
                     }
                    ],
        });
        
        Paperpile.PdfExtractGrid.superclass.initComponent.apply(this, arguments);

        this.store.load({
            callback: function(){
                this.controlPanel=this.ownerCt.ownerCt.items.get('control_panel');
                this.controlPanel.initControls();
            },
            scope: this
        });

        this.on('beforedestroy', function(cont, comp){
            Ext.Ajax.request({
                url: '/ajax/pdfextract/delete_grid',
                params: { grid_id: this.id,
                        },
                method: 'GET'
            });
        }, this );
        
    },
});





