Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

IS_TITANIUM = !(window['Titanium'] == undefined);

Paperpile.Url = function(url){
    return (IS_TITANIUM) ? 'http://localhost:3000'+url : url;
}

Paperpile.Viewport = Ext.extend(Ext.Viewport, {

    globalSettings:null,

    initComponent: function() {
        Ext.apply(this, 
                  {layout: 'border',
                   renderTo: Ext.getBody(),
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
                                           html: 'Paperpile 0.4 beta',
                                       }
                                       }
                                   ),
                                   {xtype:'tbfill'},
                                   new Ext.BoxComponent(
                                       { autoEl: {
                                           tag: 'a',
                                           href:'#',
                                           html: '<div class="pp-dashboard-button"></div>'
                                           }, 
                                         id: 'dashboard-button',
                                       }
                                   ),
                                   /*
                                   {xtype:'button', 
                                    text:"Test",
                                    handler: function(){
                                        //var myIFrame = document.getElementById('iframe-testframe');  
                                        //var content = myIFrame.contentWindow.document.body.innerHTML;  
                                        //alert(content);
                                        
                                    },
                                   }
*/
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
	},

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
            currentRoot:main.globalSettings.user_home,
            showFilter: true,
            selectionMode: 'BOTH',
            filterOptions:[{text: 'PDF files',
                            suffix:['pdf']
                           }],
            callback:function(button,path){
                if (button == 'OK'){
                    var panel=main.tabs.add(new Paperpile.PdfExtractView({title:'Import PDFs', 
                                                                          iconCls: 'pp-icon-import-pdf',
                                                                          path: path
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
            currentRoot:main.globalSettings.user_home,
            filterOptions:[{text: 'All supported formats',
                            suffix:['ppl','bib','ris','enl','lib','mods','xml']
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
                    main.tabs.newPluginTab('File', {
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

                    if (grid.plugin_name == 'DB'){
                        grid.store.reload();
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

});


Ext.onReady(function() {

    Paperpile.currentStage=0;

    Paperpile.serverPID=null;

    Paperpile.stage1();


    /*

    Ext.Ajax.request({

        url: Paperpile.Url('/ajax/app/heartbeat'),

        success: function(response){
            var json = Ext.util.JSON.decode(response.responseText);
            if (json.status == 'RUNNING'){
                if (Paperpile.currentStage == 0 ){
                    Paperpile.stage1();
                }
            }
        },
                
        failure: function(response){
            
            if (IS_TITANIUM){
                var process = Titanium.Process.launch('../../catalyst/perl5/linux64/bin/perl',
                                                      ['../../catalyst/script/paperpile_server.pl', '-fork']);
                Paperpile.serverPID=process.pid;
                Paperpile.stage1();
            }

                  Ext.Msg.show({
                title:'Error',
                msg: 'Could not start Paperpile server',
                buttons: Ext.Msg.OK,
                animEl: 'elId',
                icon: Ext.MessageBox.ERROR
            });
                 
        },
        //timeout: 2000,
    });
    */
    
});

Paperpile.stage1 = function() {

    Paperpile.currentStage=1;

    Paperpile.initMask = new Ext.LoadMask(Ext.getBody(), {msg:"Starting Paperpile Pre 1"});
    Paperpile.initMask.show();
    Ext.Ajax.request({
        url: Paperpile.Url('/ajax/app/init_session'),
        success: function(response){
            var json = Ext.util.JSON.decode(response.responseText);
            if (json.error){
                
                Ext.Msg.show({
                    title:'Error',
                    msg: json.error.msg,
                    buttons: Ext.Msg.OK,
                    animEl: 'elId',
                    icon: Ext.MessageBox.ERROR
                });

                if (json.error.type == 'LibraryMissingError'){
                    Paperpile.stage2();
                } else {
                    Paperpile.initMask.hide();
                }
            } else {
                Paperpile.stage2();
            }
        }
    });
};


Paperpile.stage2=function(){

    Ext.QuickTips.init();
    main=new Paperpile.Viewport;
    main.show();

    Paperpile.main=main; 

    var tree=Ext.getCmp('treepanel');
    Paperpile.main.tree=tree;

    Paperpile.status=new Paperpile.Status();

    main.loadSettings();

    main.tabs.newDBtab('','MAIN');
    // Global alias for main application class

    // Note: this is asynchronous, so might not be available
    // immediately (integrate this better in startup to make sure it
    // is loaded when needed)

    tree.expandAll();
    main.tabs.remove('welcome');

    main.browseTest();

    Ext.get('dashboard-button').on('click', function(){ 
        Paperpile.main.tabs.newScreenTab('Dashboard','dashboard');
    });

    Paperpile.initMask.hide();
}


