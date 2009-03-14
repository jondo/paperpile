Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('PaperPile');

PaperPile.Viewport = Ext.extend(Ext.Viewport, {

    canvasWidth:null,
    canvasHeight:null,
    globalSettings:null,

    initComponent: function() {
        Ext.apply(this, 
                  {layout: 'border',
                   renderTo: Ext.getBody(),
                   items: [ { border: 0,
                              xtype:'tree',
                              rootVisible : false,
                              id: 'treepanel',
                              itemId:'navigation',
                              region:'west',
                              margins: '2 2 2 2',
                              cmargins: '5 5 0 5',
                              width: 200,
                              minSize: 100,
                              maxSize: 300,
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
                          ]});
        
        PaperPile.Viewport.superclass.initComponent.call(this);

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

    loadSettings: function(){

        Ext.Ajax.request({
            url: '/ajax/misc/get_settings',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                this.globalSettings=json.data;
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Loaded settings.');
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
        statusBar = Ext.getCmp('statusbar');
        statusBar.showBusy();
        statusBar.setText('Importing journals titles');
        Ext.Ajax.request({
            url: '/ajax/misc/import_journals',
            success: function(){
                statusBar.clearStatus();
                statusBar.setText('Import done.');
            },
            failure: this.markInvalid,
        })
    },


    resetDB: function(){
        statusBar = Ext.getCmp('statusbar');
        statusBar.showBusy();
        statusBar.setText('Resetting database');
        Ext.Ajax.request({
            url: '/ajax/misc/reset_db',
            success: function(){
                statusBar.clearStatus();
                statusBar.setText('Reset finished.');
            },
            failure: this.markInvalid,
        })
    },


    initDB: function(){
        statusBar = Ext.getCmp('statusbar');
        statusBar.showBusy();
        statusBar.setText('Initializing database');
        Ext.Ajax.request({
            url: '/ajax/misc/init_db',
            success: function(){
                statusBar.clearStatus();
                statusBar.setText('Initialization finished.');
            },
            failure: this.markInvalid,
        })
    },

    settings:function(){
        var win=new PaperPile.Settings();
        win.show();
    }
}

);

Ext.onReady(function() {
    PaperPile.initMask = new Ext.LoadMask(Ext.getBody(), {msg:"Starting Paperpile Pre 1"});
    PaperPile.initMask.show();
    Ext.Ajax.request({
        url: '/ajax/misc/init_session',
        success: PaperPile.app
    });
     
});


PaperPile.app=function(){

    Ext.QuickTips.init();
    main=new PaperPile.Viewport;
    main.show();

    main.tabs.newDBtab('');
    // Global alias for main application class
    PaperPile.main=main; 

    // Note: this is asynchronous, so might not be available
    // immediately (integrate this better in startup to make sure it
    // is loaded when needed)
    main.loadSettings();
    
    var tree=Ext.getCmp('treepanel');
    PaperPile.main.tree=tree;
    tree.expandAll();
    main.tabs.remove('welcome');
    
    PaperPile.initMask.hide();
    
 

    //Ext.StoreMgr.lookup('tag_store').each(function(rec){console.log(rec)});

}
