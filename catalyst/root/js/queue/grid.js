Paperpile.QueueGrid = Ext.extend(Ext.grid.GridPanel, {

    region:'center',
    path: '',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: Paperpile.Url('/ajax/queue/grid'), 
                method: 'GET'
            }),
               reader: new Ext.data.JsonReader(),
            }); 
        

        var tbar=[ { xtype:'tbfill'},
                   {  xtype:'button',
                      itemId: 'delete_button',
                      text: "Don't import",
                      tooltip: 'Remove PDF file from the list in case you don\'t want to import it',
                      cls: 'x-btn-text-icon delete',
                      disabled: true,
                      listeners: {
                          click:  {fn: this.deleteEntry, scope: this}
                      },
                  }, 
                 ];
   
        Ext.apply(this, {
            itemId:'grid',
            store: _store,
            tbar: tbar,
            autoExpandColumn:'title',
            sm: new Ext.grid.RowSelectionModel({singleSelect:true}),
            columns:[{header: "Type",
                      id: 'type',
                      dataIndex: 'type',
                      sortable: true,
                      renderer: function(value, p, record){
                          var tpl = new Ext.XTemplate('<div>{id} | {type} | {status} </div>');
                          return tpl.apply(record.data);
                      }
                     },
                     { header: "Task",
                       id: 'title',
                       dataIndex: 'title',
                       sortable: true,
                       renderer: function(value, p, record){
                           var tpl = new Ext.XTemplate('<div>{id} | {type} | {status} </div>');
                           return tpl.apply(record.data);
                       }
                     },
                     { header: "Status",
                       id: 'status',
                       dataIndex: 'status',
                       sortable: true,
                       renderer: function(value, p, record){

                           var d=record.data;
                           
                           var tpl;

                           //template='<div ext:qtip="{status_msg}" class="pp-icon-tick">{progress}</div>';

                           if (d.status === 'RUNNING'){
                               tpl='<div class="pp-icon-loading">{progress}</div>';
                           } 

                           if (d.status === 'PENDING'){
                               tpl='<div class="">Pending</div>';
                           }

                           if (d.status === 'DONE'){
                               tpl='<div class="pp-icon-tick">Done</div>';
                           }

                           


                           var t = new Ext.XTemplate(tpl); 

                           return t.apply( d );
                       }
                      },
                    ],
        });
        
        Paperpile.QueueGrid.superclass.initComponent.apply(this, arguments);

        this.pollingTask =  {
            run: function(){
                this.getStore().reload();
            },
            scope: this,
            interval: 5000
        },

        this.store.on('beforeload',
                      function(){
                          //Paperpile.status.showBusy('Searching PDFs');
                      }, this);
        
        this.store.on('load',
                      function(){
                          //Paperpile.status.clearMsg();
                      }, this);

        this.on('beforedestroy', 
                function(){
                    Ext.TaskMgr.stop(this.pollingTask);
                }, this);

        this.store.load({
            params: { foo: 'foo' },
            callback: function(){
                this.controlPanel=this.ownerCt.items.get('east_panel').items.get('control_panel');               //this.controlPanel.initControls();
                Ext.TaskMgr.start(this.pollingTask);
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
        
        /*
        if (sm.getCount() == 1){
            if (record){
                if (record.data.status != 'IMPORTED'){
                    tbar.items.get('import_button').enable();
                    tbar.items.get('edit_button').enable();
                    tbar.items.get('delete_button').enable();
                }
            }
        }
        */
    },


    deleteEntry: function(){

        var record=this.getSelectionModel().getSelected();
      
        // The next record should be selected but does not work. Fix later.
        //this.getSelectionModel().selectNext();
        
        this.store.remove(record);

        this.controlPanel.updateView();
        
    }

});
