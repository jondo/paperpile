Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

Paperpile.Viewport = Ext.extend(Ext.Viewport, {

    canvasWidth:null,
    canvasHeight:null,
    globalSettings:null,

    initComponent: function() {
        Ext.apply(this, 
                  {layout: 'border',
                   renderTo: Ext.getBody(),
                   items:[{xtype:'panel',
                           layout:'border',
                           region:'center',
                           tbar: [{xtype:'button', text:"Test"}],
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
                              height:600,
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
                url: '/ajax/misc/tag_list', 
                method: 'GET'
            }),
              storeId: 'tag_store',
              baseParams:{},
              reader: new Ext.data.JsonReader(),
              pruneModifiedRecords:true,
            }
        ); 
        this.tagStore.reload();

        

        
        this.on('afterlayout',this.onAfterLayout,this);
                 
	},

    loadSettings: function(callback,scope){

        Ext.Ajax.request({
            url: '/ajax/misc/get_settings',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                this.globalSettings=json.data;
                //Ext.getCmp('statusbar').clearStatus();
                //Ext.getCmp('statusbar').setText('Loaded settings.');
                if (callback){
                    callback.createDelegate(scope)();
                }
            },
            scope:this,
        });
    },


    onAfterLayout: function(){

        //this.canvasWidth=Ext.getCmp('canvas_panel').getInnerWidth();
        //this.canvasHeight=Ext.getCmp('canvas_panel').getInnerHeight();

    },

    onPDFtabToggle: function(button, pressed){

        if (button.id == 'pdf_manager_tab_button' && pressed){
            this.canvas_panel.getLayout().setActiveItem('pdf_manager');
        }

        if (button.id == 'pdf_view_tab_button' && pressed){
            this.canvas_panel.getLayout().setActiveItem('pdf_viewer');
        }
    },


    importJournals: function(){
        //statusBar = Ext.getCmp('statusbar');
        //statusBar.showBusy();
        //statusBar.setText('Importing journals titles');
        Ext.Ajax.request({
            url: '/ajax/misc/import_journals',
            success: function(){
                //statusBar.clearStatus();
                //statusBar.setText('Import done.');
            },
            failure: this.markInvalid,
        })
    },


    resetDB: function(){
        //statusBar = Ext.getCmp('statusbar');
        //statusBar.showBusy();
        //statusBar.setText('Resetting database');
        Ext.Ajax.request({
            url: '/ajax/misc/reset_db',
            success: function(){
                //statusBar.clearStatus();
                //statusBar.setText('Reset finished.');
            },
            failure: this.markInvalid,
        })
    },


    initDB: function(){
        //statusBar = Ext.getCmp('statusbar');
        //statusBar.showBusy();
        //statusBar.setText('Initializing database');
        Ext.Ajax.request({
            url: '/ajax/misc/init_db',
            success: function(){
                //statusBar.clearStatus();
                //statusBar.setText('Initialization finished.');
            },
            failure: this.markInvalid,
        })
    },

    settings:function(){

        var panel=main.tabs.add(new Paperpile.PatternSettings({title:'Settings', 
                                                         iconCls: 'pp-icon-page',
                                                }));
        panel.show();
        
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
                                                                          iconCls: 'pp-icon-page',
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

    error: function(response){

        var data = Ext.util.JSON.decode(response.responseText);

        Ext.Msg.show({
            title:'Error',
            msg: data.errors[0],
            buttons: Ext.Msg.OK,
            animEl: 'elId',
            icon: Ext.MessageBox.ERROR
        });
    }


});

Ext.onReady(function() {
    Paperpile.initMask = new Ext.LoadMask(Ext.getBody(), {msg:"Starting Paperpile Pre 1"});
    Paperpile.initMask.show();
    Ext.Ajax.request({
        url: '/ajax/misc/init_session',
        success: Paperpile.app
    });
     
});


Paperpile.app=function(){

    Ext.QuickTips.init();
    main=new Paperpile.Viewport;
    main.show();

    Paperpile.main=main; 

    var tree=Ext.getCmp('treepanel');
    Paperpile.main.tree=tree;

    Paperpile.status=new Paperpile.Status();

    main.loadSettings();

    main.tabs.newDBtab('');
    // Global alias for main application class

    // Note: this is asynchronous, so might not be available
    // immediately (integrate this better in startup to make sure it
    // is loaded when needed)

    tree.expandAll();
    main.tabs.remove('welcome');
    Paperpile.initMask.hide();


}


