Paperpile.QueueGrid = Ext.extend(Ext.grid.GridPanel, {

    region:'center',
    path: '',
    wasRunning: false,

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: Paperpile.Url('/ajax/queue/grid'), 
                method: 'GET',
            }),
               baseParams:{limit:10},
               reader: new Ext.data.JsonReader(),
            }); 
        
        this.pager=new Ext.PagingToolbar({
            pageSize: 10,
            store: _store,
            displayInfo: true,
            displayMsg: 'Tasks {0} - {1} of {2}',
            emptyMsg: "No tasks",
        });

        this.pager.on('beforechange',
                      function(pager,params){
                          this.wasRunning=false;
                      }, this);
        
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
            bbar: this.pager,
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

                           console.log(record.get('progress'));

                           var d=record.data;
                           
                           var tpl;

                           if (d.status === 'RUNNING'){
                               tpl='<div id="job_{id}">{progress}</div><a class="pp-textlink" href="#" id=cancel_{id} onClick="Ext.getCmp(\'{thisId}\').cancelJob(\'{id}\')">Cancel</a>';
                           }

                           if (d.status === 'PENDING'){
                               tpl='<div id="job_{id}" class="">Pending</div>';
                           }
                           
                           //if (d.queue_status === 'PAUSED'){
                           //        tpl='<div class="">PAUSED</div>';
                           //    }
                           // }

                           if (d.status === 'DONE'){
                               if  (d.error){
                                   tpl='<div id="job_{id}" ext:qtip="{error}" class="pp-icon-cross pp-grid-error">Failed</div>';
                               } else {
                                   tpl='<div id="job_{id}" class="pp-icon-tick pp-grid-ok">Ok</div>';
                               }
                           }

                           d.thisId=this.id;

                           var t = new Ext.XTemplate(tpl); 
                           return t.apply( d );
                       },
                       scope:this
                     },
                    ],
        });
        
        Paperpile.QueueGrid.superclass.initComponent.apply(this, arguments);
        
        //this.reloadTask = new Ext.util.DelayedTask(function(){
        //    this.getView().holdPosition=true;
        //    this.store.reload();
        //}, this); 


        this.reloadTask = {
            run: function(){
                this.getView().holdPosition=true;
                this.store.reload();
            },
            interval: 3000,
            scope:this
        }

        this.pollingTask = {
            run: function(){
                this.updateJobs();
            },
            interval: 1000,
            scope:this
        }
        
        //this.pollingTask = new Ext.util.DelayedTask(this.updateJobs, this); 
        
        this.on('beforedestroy', 
                function(){
                    Ext.TaskMgr.stop(this.reloadTask);
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
            params: { foo: 'foo', start:0 },
            callback: function(){
                var controlPanel=this.ownerCt.items.get('east_panel').items.get('control_panel');

                Ext.TaskMgr.start(this.reloadTask);
                Ext.TaskMgr.start(this.pollingTask);

                this.store.on('load',
                              function(){
                                  var controlPanel=this.ownerCt.items.get('east_panel').items.get('control_panel');

                                  this.updateJobs();

                                  controlPanel.updateView.createDelegate(controlPanel)();

                                  if (this.store.getCount()>1){
                                  
                                      if (this.wasRunning && !this.isRunning() &&  this.store.getAt(0).get('queue_status') != 'PAUSED'){
                                      
                                          var currPage = this.getCurrPage();
                                          var maxPage = this.getTotalPage();

                                          console.log(currPage, maxPage, this.store.getTotalCount(), this.pager.pageSize);
                                      
                                          if (currPage < maxPage){
                                              this.pager.changePage(currPage+1);
                                          }
                                      
                                          this.wasRunning=false;

                                          return;
                                      }

                                      this.wasRunning= this.isRunning();
                                  }

                              }, this);

            },
            scope: this
        });

        this.getSelectionModel().on('rowselect',
                                    function(sm, rowIdx, r){
                                        this.updateButtons();
                                    },this);
        
    },



    afterRender: function(){

        // This is undocumented feature in Ext 2 and was renamed to 'refreshing' (I guess) in Ext JS 3
        //this.pager.loading.hide(); 

        
        this.pager.addButton({ text: 'Goto active task',
                               handler: function(){
                                   Ext.Ajax.request({
                                       url: Paperpile.Url('/ajax/queue/get_running'),
                                       params: {    
                                           limit: this.pager.pageSize
                                       },
                                       method: 'GET',
                                       success: function(response){
                                           var json = Ext.util.JSON.decode(response.responseText);

                                           if (json.page != -1){

                                               this.store.on('load',
                                                             function(){
                                                                 this.getView().focusRow(json.index);
                                                             }, this, {single: true});
                                               
                                               this.pager.changePage(json.page);
                                               
                                           }

                                       },
                                       failure: Paperpile.main.onError,
                                       scope:this
                                   });
                               }, 
                               scope: this
                             });

        Paperpile.QueueGrid.superclass.afterRender.apply(this, arguments);

    },

    
    getTotalPage:function(){
        var t = this.store.getTotalCount();
        return t < this.pager.pageSize ? 1 : Math.ceil(t / this.pager.pageSize);
    },

    getCurrPage:function(){
        return Math.ceil((this.pager.cursor+this.pager.pageSize)/this.pager.pageSize);
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
        
    }, 


    // Determines if the current contains a running job
    isRunning: function(){
        if (this.store.find('status','RUNNING') == -1){
            return false;
        } else {
            return true;
        }
    },


    cancelJob: function(id){

        Ext.Ajax.request(
            { url: Paperpile.Url('/ajax/queue/cancel_jobs'),
              params: {ids: id},
              method: 'GET',
              success: function(response){
              },
              failure: Paperpile.main.onError,
              scope:this,
            });
    },

    updateJobs: function(){
        var jobs=[];
        this.store.each(function(record){
            if (record.get('status') === 'RUNNING'){
                jobs.push(record.id);
            }
        }, this);
        
        if (jobs.length>0){
            Ext.Ajax.request(
                { url: Paperpile.Url('/ajax/queue/jobs'),
                  params: {ids: jobs},
                  method: 'GET',
                  success: function(response){
                      console.log(response);
                      var data = Ext.util.JSON.decode(response.responseText).data;
                      for (var id in data){
                          Ext.DomHelper.overwrite('job_'+id,data[id].info.msg);
                          if (data[id].status=='DONE'){
                              this.getView().holdPosition=true;
                              this.store.reload();
                          }
                      }
                  },
                  failure: Paperpile.main.onError,
                  scope:this,
                });
        }
    },


});
