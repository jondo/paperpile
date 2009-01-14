Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('PaperPile');


PaperPile.Main = Ext.extend(Ext.Viewport, {

    canvasWidth:null,
    canvasHeight:null,
    id:'MAIN',
    initComponent: function() {
        Ext.apply(this, 
                  {layout: 'border',
                   renderTo: Ext.getBody(),
                   items: [ 
                       new Ext.Panel({
                           region: 'center',
                           layout: 'border',
                           bbar: new Ext.StatusBar({
                           id: 'statusbar',
                           defaultText: 'Default status text',
                           defaultIconCls: 'default-icon',
                           text: 'Ready',
                           iconCls: 'ready-icon',
                       }),
                       
                       items: [ {itemId:'navigation',
                                 region:'west',
                                 layout:'fit',
                                 margins: '2 2 2 2',
                                 cmargins: '5 5 0 5',
                                 border:0,
                                 width: 200,
                                 minSize: 100,
                                 maxSize: 300,
                                 items: [ 
                                     new PaperPile.Tree(
                                         { title: 'PaperPile',
                                           border: 0,
                                           rootVisible : false,
                                           id: 'treepanel',
                                         }
                                     ),
                                 ]
                                },{
                                    region:'east',
                                    id: 'canvas_panel',
                                    layout: 'fit',
                                    margins: '2 2 2 2',
                                    cmargins: '5 5 0 5',
                                    width: 500,
                                    minSize: 100,
                                    maxSize: 800,
                                    //items: {}
                                        //new PaperPile.PDFviewer(
                                        //    {id:'pdf_viewer',
                                        //     itemId:'pdf_viewer',
                                        //    }
                                        //),
                                        //new PaperPile.PubEdit(
                                        //    {id:'pub_edit',
                                        //     itemId:'pub_edit',
                                        //    }
                                        //)
                                                                       
                                },
                                {itemId: 'innerpanel',
                                 region:'center',
                                 border: false,
                                 layout:'border',
                                 items: [{border: false,
                                          xtype: 'datatabs',
                                          id: 'data_tabs',
                                          activeItem:0,
                                          height:200,
                                          region:'south'
                                         },
                                         {height:600,
                                          border: false,
                                          xtype: 'resultstabs',
                                          id: 'results_tabs',
                                          region: 'center',
                                          activeItem:0,
                                         }
                                        ]}]})]});
        
        PaperPile.Main.superclass.initComponent.call(this);

        this.results_tabs=Ext.getCmp('results_tabs');
        this.data_tabs=Ext.getCmp('data_tabs');
        this.canvas_panel=Ext.getCmp('canvas_panel');

        this.on('afterlayout',this.onAfterLayout,this);

                 
	  },

	  onRowSelect: function(sm, rowIdx, r) {
        this.data_tabs.getComponent('pubsummary').updateDetail(r.data);
        this.data_tabs.getComponent('pubnotes').updateDetail(r.data);
        //this.canvas_panel.getComponent('pub_edit').updateDetail(r.data);
    },

    onAfterLayout: function(){

       this.canvasWidth=Ext.getCmp('canvas_panel').getInnerWidth();
       this.canvasHeight=Ext.getCmp('canvas_panel').getInnerHeight();

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






    onNodeClick: function(node, event){
        alert(node);
    }


}

);



Ext.onReady(function() {
 
    Ext.QuickTips.init();
    Ext.Ajax.request({
        url: '/ajax/misc/reset_session',
        //success: this.validateFeed,
        //failure: this.markInvalid,
    });

    
        
    main=new PaperPile.Main;

    main.results_tabs.newDBtab();
    
    Ext.getCmp('treepanel').expandAll();

    main.show();


    //Ext.getCmp('pdf_viewer').initPDF();
    //Ext.getCmp('canvas_panel').layout.setActiveItem('pdf_viewer');
    //Ext.getCmp('canvas_panel').layout.setActiveItem('pub_edit');


     
});
