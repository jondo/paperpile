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
               remoteSort: true,
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
            columns:[{header: "",
                      id: 'type',
                      dataIndex: 'type',
                      sortable: true,
                      width: 30,
                      renderer: function(value, p, record){

                          var d=record.data;
                           
                          var tpl;

                          if (d.type === 'PDF_SEARCH'){
                              tpl='<div class="pp-action-search-pdf" style="height:20px">&nbsp;</div>';
                          } 

                          var t = new Ext.XTemplate(tpl); 
                          return t.apply( d );

                      }
                     },
                     { header: "Task",
                       id: 'title',
                       dataIndex: 'title',
                       sortable: true,
                       renderer: function(value, p, record){

                           var d = record.data;
                           d.task = 'Get PDF for';

                           var tpl = new Ext.XTemplate(
                               '<div class="pp-grid-data">',
                               '<div><span class="pp-grid-task">{task}</span></div>',
                               '<div>',
                               '<span class="pp-grid-title">{title}</span>',
                               '</div>',
                               '<tpl if="authors">',
                               '<p class="pp-grid-authors">{authors}</p>',
                               '</tpl>',
                               '<tpl if="citation">',
                               '<p class="pp-grid-citation">{citation}</p>',
                               '</tpl></div>');

                           return tpl.apply(d);
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
                               tpl='<div class="pp-icon-queue">{progress}</div>';
                           } 

                           if (d.status === 'PENDING'){
                               tpl='<div class="">Pending</div>';
                           }

                           if (d.status === 'DONE'){

                               if  (d.error){
                                   tpl='<div ext:qtip="{error}" class="pp-icon-cross pp-grid-error">Failed</div>';
                               } else {
                                   tpl='<div class="pp-icon-tick pp-grid-ok">Ok</div>';
                               }

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
                this.getView().holdPosition=true;
                this.store.reload();
                /*
                Ext.Ajax.request(
                    { url: Paperpile.Url('/ajax/queue/grid'),
                      params: {},
                      method: 'GET',
                      success: function(response){
                          var data = Ext.util.JSON.decode(response.responseText).data;
                          console.log(data);
                          for (var i=0; i< data.length; i++){
                              var record=this.store.getAt(this.store.find('id',data[i].id));
                              console.log(record);
                              if (record.get('progress') != data[i].progress){
                                  record.set('progress', data[i].progress);
                              }
                              if (record.get('status') != data[i].status){
                                  record.set('status', data[i].status);
                              }

                          }

                          var controlPanel=this.ownerCt.items.get('east_panel').items.get('control_panel');
                          controlPanel.updateView.createDelegate(controlPanel)();

                      },
                      failure: Paperpile.main.onError,
                      scope:this,
                    });
*/
            },
            scope: this,
            interval: 5000
        },

        this.on('beforedestroy', 
                function(){
                    Ext.TaskMgr.stop(this.pollingTask);
                    Ext.Ajax.request(
                        { url: Paperpile.Url('/ajax/queue/clear'),
                          params: {},
                          method: 'GET',
                          success: function(response){
                          
                          },
                          failure: Paperpile.main.onError,
                          scope:this,
                        });
            }, this);

        this.store.load({
            params: { foo: 'foo' },
            callback: function(){
                var controlPanel=this.ownerCt.items.get('east_panel').items.get('control_panel');
                Ext.TaskMgr.start(this.pollingTask);
            
                this.store.on('load',
                              function(){
                                  var controlPanel=this.ownerCt.items.get('east_panel').items.get('control_panel');
                                  controlPanel.updateView.createDelegate(controlPanel)();
                              }, this);

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
