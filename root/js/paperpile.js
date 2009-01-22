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
                       
                       items: [ {itemId:'navigation',
                                 region:'west',
                                 layout:'fit',
                                 margins: '2 2 2 2',
                                 cmargins: '5 5 0 5',
                                 border:0,
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
                                    activeItem:0,
                                    layout: 'card',
                                    items: [
                                        new PaperPile.PDFmanager(
                                            {id:'pdf_manager',
                                             itemId:'pdf_manager',
                                            }
                                        ),
                                        new PaperPile.PDFviewer(
                                            {id:'pdf_viewer',
                                             itemId:'pdf_viewer',
                                            }
                                        )

                                    ],
                                    bbar: [{ text: 'Manage PDF',
                                             id: 'pdf_manager_tab_button',
                                             enableToggle: true,
                                             toggleHandler: this.onPDFtabToggle,
                                             toggleGroup: 'pdf_tab_buttons',
                                             scope: this,
                                             allowDepress : false,
                                             pressed: true
                                           },
                                        { text: 'View PDF',
                                             id: 'pdf_view_tab_button',
                                             enableToggle: true,
                                             toggleHandler: this.onPDFtabToggle,
                                             toggleGroup: 'pdf_tab_buttons',
                                             scope: this,
                                             allowDepress : false,
                                             pressed: false
                                           }
                                          ],

                                    margins: '2 2 2 2',
                                    cmargins: '5 5 0 5',
                                    width: 500,
                                    minSize: 100,
                                    maxSize: 800,
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
        //this.data_tabs.getComponent('pubsummary').updateDetail(r.data);
        //this.data_tabs.getComponent('pubnotes').updateDetail(r.data);

        Ext.getCmp('pubsummary').updateDetail(r.data);
        Ext.getCmp('pdf_manager').updateDetail(r.data);
        Ext.getCmp('pubnotes').updateDetail(r.data);        

        if (r.data.pdf){
            Ext.getCmp('pdf_viewer').initPDF(r.data.pdf);
        }

    },

    onAfterLayout: function(){

       this.canvasWidth=Ext.getCmp('canvas_panel').getInnerWidth();
       this.canvasHeight=Ext.getCmp('canvas_panel').getInnerHeight();

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


     
});
