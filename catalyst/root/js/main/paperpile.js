Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

IS_TITANIUM = !(window['Titanium'] == undefined);

Paperpile.Url = function(url){
    return (IS_TITANIUM) ? 'http://127.0.0.1:3000'+url : url;
}

Paperpile.Viewport = Ext.extend(Ext.Viewport, {

    globalSettings:null,

    initComponent: function() {
        Ext.apply(this,
                  {layout: 'border',
                   renderTo: Ext.getBody(),
		   enableKeyEvents:true,
		   keys:{},
                   items:[{xtype:'panel',
                           layout:'border',
                           region:'center',
                           tbar: new Ext.Toolbar({
                               id: 'main-toolbar',
                               cls: 'pp-main-toolbar',
                               items:[
                                   new Ext.BoxComponent(
                                       { autoEl: {
                                           cls: 'pp-main-toolbar-label',
                                           tag: 'div',
                                           html: 'Paperpile 0.4 preview',
                                       }
                                       }
                                   ),
                                   {xtype:'tbfill'},
                                   //new Paperpile.QueueWidget(),
                                   new Ext.BoxComponent(
                                       { autoEl: {
                                           tag: 'a',
                                           href:'#',
                                           html: '<div class="pp-dashboard-button"></div>'
                                           },
                                         id: 'dashboard-button',
                                       }
                                   ),
                               ]}),
                           items: [ { border: 0,
                              xtype:'tree',
                              rootVisible : false,
                              id: 'treepanel',
                              itemId:'navigation',
                              region:'west',
                              margins: '2 2 2 2',
                              cmargins: '5 5 0 5',
                              width: 200,
                              bbar: new Ext.StatusBar({
                                  border:0,
                                  id: 'statusbar',
                                  defaultText: 'Default status text',
                                  defaultIconCls: 'default-icon',
                                  text: 'Ready',
                                  iconCls: 'ready-icon',
                              }),
                            },
                            { region:'center',
                              border: false,
                              //height:600,
                              border: false,
                              xtype: 'tabs',
                              id: 'tabs',
                              activeItem:0,
                            }
                                 ]}
                         ],

                  }
                 );

        Paperpile.Viewport.superclass.initComponent.call(this);

        this.tabs=Ext.getCmp('tabs');

        this.tagStore=new Ext.data.Store(
            { proxy: new Ext.data.HttpProxy({
                url: Paperpile.Url('/ajax/misc/tag_list'),
                method: 'GET'
            }),
              storeId: 'tag_store',
              baseParams:{},
              reader: new Ext.data.JsonReader(),
              pruneModifiedRecords:true,
            }
        );
        this.tagStore.reload();

//	this.loadKeys();
	},

/*
    keyMap:null,
    loadKeys:function() {
      this.keyMap = new Ext.KeyMap(document,[
        {
	  key: [Ext.EventObject.TAB,Ext.EventObject.W,Ext.EventObject.A],
//	  ctrl:true,
	  stopEvent:true,
	  handler: this.controlPlus,
	  scope:this
	}
      ]);
    },

    controlPlus:function(e,t) {
      var key = e.getKey();
      log("Key!" + key);
      switch (key) {
      case Ext.EventManager.TAB:
	e.stopEvent();
	break;
      case Ext.EventObject.W:
	log("W!");
	var curTab = Paperpile.main.tabs.getActiveTab();
	console.log(curTab);
	Paperpile.main.tabs.remove(curTab);
	e.stopEvent();
	console.log("Stopped ctrl-W!");
	break;
      }
    },
*/
    loadSettings: function(callback,scope){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/misc/get_settings'),
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                this.globalSettings=json.data;
                if (callback){
                    callback.createDelegate(scope)();
                }
            },
            failure: Paperpile.main.onError,
            scope:this,
        });
    },

    onPDFtabToggle: function(button, pressed){

        if (button.id == 'pdf_manager_tab_button' && pressed){
            this.canvas_panel.getLayout().setActiveItem('pdf_manager');
        }

        if (button.id == 'pdf_view_tab_button' && pressed){
            this.canvas_panel.getLayout().setActiveItem('pdf_viewer');
        }
    },


    pdfExtract: function(){

        win=new Paperpile.FileChooser({
            title: "Select single PDF file or directory to search for PDF files",
            currentRoot:Paperpile.main.globalSettings.user_home,
            showFilter: true,
            selectionMode: 'BOTH',
            filterOptions:[{text: 'PDF files',
                            suffix:['pdf']
                           }],
            callback:function(button,path){
                if (button == 'OK'){
                    var panel=Paperpile.main.tabs.add(new Paperpile.PdfExtractView({title:'Import PDFs',
                                                                                    iconCls: 'pp-icon-import-pdf',                                                                                    path: path
                                                                         }));
                    panel.show();
                }
            }
        });

        win.show();



    },

    fileImport: function(){

        win=new Paperpile.FileChooser({
            showFilter: true,
            currentRoot:Paperpile.main.globalSettings.user_home,
            filterOptions:[{text: 'All supported formats',
                            suffix:['ppl','bib','ris','enl','lib','mods','xml','rss']
                           },
                           {text: 'BibTeX (.bib)',
                            suffix: ['bib']
                           },
                           {text: 'RIS file (.ris)',
                            suffix: ['ris']
                           },
                           {text: 'Endnote (.enl, .lib )',
                            suffix: ['enl','lib']
                           },
                           {text: 'Endnote XML (.xml)',
                            suffix: ['xml']
                           },
                           {text: 'Word 2007 XML (.xml)',
                            suffix: ['xml']
                           },
                           {text: 'MODS (.mods, .xml)',
                            suffix: ['mods','xml']
                           },
                           {text: 'RSS (.rss, .xml)',
                            suffix: ['rss','xml']
                           },
                           {text: 'Paperpile (.ppl)',
                            suffix: ['ppl']
                           },
                           {text: 'All files',
                            suffix:['ALL']
                           },
                          ],

            callback:function(button,path){
                if (button == 'OK'){
                    var parts=Paperpile.utils.splitPath(path);
                    Paperpile.main.tabs.newPluginTab('File', {
                        plugin_file: path,
                        plugin_name: 'File',
                        plugin_mode: 'FULLTEXT',
                        plugin_query: '',
                        plugin_base_query:'',
                    }, parts.file, 'pp-icon-file');
                }
            }
        });

        win.show();

    },

    browseTest: function(){

        /*
        Ext.ux.IFrameComponent = Ext.extend(Ext.BoxComponent, {
            onRender : function(ct, position){
                this.el = ct.createChild({tag: 'iframe', id: 'iframe-'+ this.id, frameBorder: 0, src: this.url});
            }

        });

        var tab = new Ext.Panel({
            //id: id,
            title: 'Google',
            closable:true,
            // layout to fit child component
            layout:'fit',
            // add iframe as the child component
            items: [ new Ext.ux.IFrameComponent({ id:'testframe', url: 'http://google.com' }) ]
        });
*/

        //Paperpile.main.tabs.add(new Paperpile.Browser());

    },

    // Reloads DB grids upon insert/entries; it is possible to avoid
    // reload of a grid by passing the id via ignore

    onUpdateDB: function(ignore){

        Paperpile.main.tabs.items.each(
            function(item, index, length){

                if (item.tabType=='PLUGIN'){

                    var grid=item.items.get('center_panel').items.get('grid');

                    if (ignore){
                        if (grid.id == ignore){
                            return;
                        }
                    }

                    if (grid.plugin_name == 'DB' || grid.plugin_name == 'Trash'){
                        grid.getView().holdPosition = true;
                        grid.getStore().reload();
                        //grid.store.reload();
                    }

                }
            }
        );
    },

    onError: function(response){

        var error={ type:"Unknown",
                    msg: "Empty response or timeout.",
                  };

        //Timed out errors come back empty otherwise fill in error
        //data from backend

        if (response.responseText){
            error= Ext.util.JSON.decode(response.responseText).error;
        }

        if (error.type == 'Unknown'){
            Paperpile.status.updateMsg(
                { type:'error',
                  msg: 'An unexpected error has occured.',
                  action1: 'Details',
                  callback: function(action){
                      Ext.Msg.show({
                          title:'Error',
                          msg: error.msg,
                          buttons: Ext.Msg.OK,
                          animEl: 'elId',
                          icon: Ext.MessageBox.ERROR
                      });
                  },
                  hideOnClick: true,
                }
            );
        } else {
            Paperpile.status.updateMsg(
                { type:'error',
                  msg: error.msg,
                  hideOnClick: true,
                }
            );
        }
    },

    startHeartbeat: function(){

        this.heartbeatTask = {
            run: this.pollServer,
            scope: this,
            interval: 5000
        }

        //Ext.TaskMgr.start(this.heartbeatTask);

    },

    
    pollServer: function(){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/app/heartbeat'),
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);

                for (var jobID in json.queue){
                    
                    var callback = json.queue[jobID].callback;

                    if (callback){
                        if (callback.notify){
                            Paperpile.status.clearMsg(); 
                            Paperpile.status.updateMsg(
                                { msg: callback.notify,
                                  hideOnClick: true,
                                }
                            );
                        }
                        if (callback.updatedb){
                            this.onUpdateDB();
                        }
                    }
                    

                }
            },
                
            failure: function(response){
                // do something reasonable here when server contact breaks down.
            }
        })
    },

    inc_read_counter: function(rowid){

        if (rowid){
            Ext.Ajax.request({
                url: Paperpile.Url('/ajax/misc/inc_read_counter'),
                params: { rowid: rowid,
                        },
                success: function(response){
                },
                failure: Paperpile.main.onError,
                scope:this,
            });
        }
    }
    

});


