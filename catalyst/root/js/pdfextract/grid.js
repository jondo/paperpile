Paperpile.PdfExtractGrid = Ext.extend(Ext.grid.GridPanel, {

    region:'center',
    path: '',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: Paperpile.Url('/ajax/pdfextract/grid'), 
                method: 'GET'
            }),
               reader: new Ext.data.JsonReader(),
            }); 
        
        var pluginsStore=[['PubMed','PubMed'],
                          //['GoogleScholar','Google Scholar']
                         ];
        
        var combo= new Ext.form.ComboBox(
            { editable:false,
              forceSelection:true,
              triggerAction: 'all',
              disableKeyFilter: true,
              fieldLabel:'Type',
              mode: 'local',
              width: 120,
              store: pluginsStore,
              value: 'PubMed',
              listeners: {
                  select: {
                      fn: function(combo,record,index){
                          this.matchPlugin=record.data.value;
                      },
                      scope:this,
                  }
              }
            });


        var tbar=[ { xtype: 'tbtext', text: 'Match PDF files against: '} ,
                   { xtype: 'combo',
                     editable:false,
                     forceSelection:true,
                     triggerAction: 'all',
                     disableKeyFilter: true,
                     fieldLabel:'Type',
                     mode: 'local',
                     width: 120,
                     store: pluginsStore,
                     value: 'PubMed',
                     listeners: {
                         select: {
                             fn: function(combo,record,index){
                                 this.controlPanel.matchPlugin=record.data.value;
                             },
                             scope:this,
                         }
                     }
                   },
                   { xtype:'tbfill'},
                   { xtype:'button',
                      itemId: 'import_button',
                      text: 'Import',
                      cls: 'x-btn-text-icon add',
                      disabled: true,
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
                   {  xtype:'button',
                      itemId: 'delete_button',
                      text: "Remove from list",
                      cls: 'x-btn-text-icon delete',
                      disabled: true,
                      listeners: {
                          click:  {fn: this.deleteEntry, scope: this}
                      },
                  }, 

                  {   xtype:'button',
                      itemId: 'edit_button',
                      text: 'Edit manually',
                      cls: 'x-btn-text-icon edit',
                      disabled: true,
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
            sm: new Ext.grid.RowSelectionModel({singleSelect:true}),
            columns:[{header: "File",
                      id: 'file_basename',
                      dataIndex: 'file_basename',
                      sortable: true,
                      renderer: function(value, p, record){
                          return '<div class="pp-pdfextract-file" ext:qtip="'+record.get('file_name')+'">'+value+'</div>';
                      }
                     },
                     {header: "Title",
                      id: 'title',
                      dataIndex: 'title',
                      width: 150,
                      sortable: true,
                      renderer: function(value, p, record){
                          if (value){
                              // _citation_display not available here, would have been nice for tooltip. Fix later.
                              //return '<div ext:qtip="'+record.get('_citation_display')+'">'+value+'</div>';
                              return value;
                          } else {
                              return '';
                          }
                      }

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
            params: { path: this.path },
            callback: function(){
                this.controlPanel=this.ownerCt.ownerCt.items.get('east_panel').items.get('control_panel');
                this.controlPanel.initControls();
            },
            scope: this
        });

        this.getSelectionModel().on('rowselect',
                                    function(sm, rowIdx, r){
                                        this.updateButtons();
                                    },this);
        
    },

    updateButtons: function(){
        
        var tbar = this.getTopToolbar();
        var sm = this.getSelectionModel();
        var record = sm.getSelected();
        
        if (sm.getCount() == 1){
            if (record){
                if (record.data.status != 'IMPORTED'){
                    tbar.items.get('import_button').enable();
                    tbar.items.get('edit_button').enable();
                    tbar.items.get('delete_button').enable();
                }
            }
        }
    },


    editEntry: function(){
        var east_panel=this.findParentByType(Ext.PdfExtractView).items.get('east_panel');

        var data=this.getSelectionModel().getSelected().data;
        var file_name=data.file_name;

        data.attach_pdf=data.file_name;
                
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

    deleteEntry: function(){

        var record=this.getSelectionModel().getSelected();
      
        // The next record should be selected but does not work. Fix later.
        //this.getSelectionModel().selectNext();
        
        this.store.remove(record);

        this.controlPanel.updateView();
        
    }
    

});





