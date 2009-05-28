Paperpile.PdfExtractGrid = Ext.extend(Ext.grid.GridPanel, {

    region:'center',
    root: '/home/wash/PDFs',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: '/ajax/pdfextract/grid', 
                method: 'GET'
            }),
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
                  {   xtype:'button',
                      itemId: 'edit_button',
                      text: 'Edit',
                      cls: 'x-btn-text-icon edit',
                      listeners: {
                          click:  {fn: this.editEntry, scope: this}
                      },
                  }, 
                 ];
   
        Ext.apply(this, {
            ddGroup  : 'gridDD',
            itemId:'grid',
            store: _store,
            tbar: tbar,
            autoExpandColumn:'title',

            columns:[{header: "File",
                      id: 'file_basename',
                      dataIndex: 'file_basename',
                      sortable: true,
                      renderer: function(value, p, record){
                          return '<div ext:qtip="'+record.get('file_name')+'">'+value+'</div>';
                      }
                     },
                     {header: "Title",
                      id: 'title',
                      dataIndex: 'title',
                      width: 150,
                      sortable: true,
                     },
                     {header: "Authors",
                      id: 'authors',
                      dataIndex: '_authors_display',
                      sortable: true,
                     },
                     {header: "DOI",
                      id: 'doi',
                      dataIndex: 'doi',
                      sortable: true,
                     },
                     {header: "Status",
                      id: 'status',
                      dataIndex: 'status',
                      sortable: true,
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
            params: { root: this.root },
            callback: function(){
                this.controlPanel=this.ownerCt.ownerCt.items.get('east_panel').items.get('control_panel');
                this.controlPanel.initControls();
            },
            scope: this
        });

    },

    editEntry: function(){
        var east_panel=this.findParentByType(Ext.PdfExtractView).items.get('east_panel');

        var data=this.getSelectionModel().getSelected().data;

        var file_name=data.file_name;

        data.attach_pdf=this.root+"/"+data.file_name;
        
        var form=new Paperpile.Forms.PubEdit({data:data,
                                              grid_id: null,
                                              spotlight: true,
                                              callback: function(status,data){
                                                  if (status == 'SAVE'){
                                                      var record=this.store.getAt(this.store.find('file_name',file_name));
                                                      record.beginEdit();
                                                      for ( var i in data){
                                                          record.set(i,data[i]);
                                                      }
                                                      record.set('status','IMPORTED');
                                                      record.set('status_msg','Data manually entered.');
                                                      
                                                      //record.set('_authors_display',data._authors_display);
                                                      //record.set('title',data.title);
                                                      record.endEdit();
                                                  }
                                                  east_panel.remove('pub_edit');
                                                  east_panel.doLayout();
                                                  east_panel.getLayout().setActiveItem('control_panel');
                                              },
                                              scope:this
                                             });
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');

    },


    
   

});





