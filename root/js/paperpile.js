Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('PaperPile');

PaperPile.Main = Ext.extend(Ext.Viewport, {
    initComponent: function() {
        Ext.apply(this, 
                  {layout: 'border',
                   renderTo: Ext.getBody(),
                   items: [ new Ext.Panel({
                       region: 'center',
                       layout: 'border',
                       bbar: new Ext.StatusBar({
                           id: 'statusbar',
                           defaultText: 'Default status text',
                           defaultIconCls: 'default-icon',
                           text: 'Ready',
                           iconCls: 'ready-icon',
                       }),
                       
                       items: [ {title: 'PaperPile',
                                 itemId:'navigation',
                                 region:'west',
                                 margins: '2 2 2 2',
                                 cmargins: '5 5 0 5',
                                 width: 200,
                                 minSize: 100,
                                 maxSize: 300,
                                 items: [{ xtype: 'button',
                                           itemId: 'new_file_button',
                                           id: 'new_file_button',
                                           text: 'New file tab',
                                         },
                                         { xtype: 'button',
                                           itemId: 'new_db_button',
                                           id: 'new_db_button',
                                           text: 'New DB tab',
                                         },{ xtype: 'button',
                                             itemId: 'new_pubmed_button',
                                             id: 'new_pubmed_button',
                                             text: 'New PubMed tab',
                                           },{ xtype: 'button',
                                               itemId: 'import_journals_button',
                                               id: 'import_journals_button',
                                               text: 'Import Journals',
                                             }
                                        ]
                                },
                                {region:'east',
                                 margins: '2 2 2 2',
                                 cmargins: '5 5 0 5',
                                 width: 400,
                                 minSize: 100,
                                 maxSize: 800
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
                 
	  },

	  onRowSelect: function(sm, rowIdx, r) {
        this.data_tabs.getComponent('pubsummary').updateDetail(r.data);
        this.data_tabs.getComponent('pubnotes').updateDetail(r.data);
        this.data_tabs.getComponent('pubedit').updateDetail(r.data);
    },

    importJournals: function(){
        statusBar = Ext.getCmp('statusbar');
        statusBar.showBusy();
        statusBar.setText('Importing journals titles');
        Ext.Ajax.request({
            url: '/ajax/import_journals',
            success: function(){
                statusBar.clearStatus();
                statusBar.setText('Import done.');
            },
            failure: this.markInvalid,
        })
    }


}

);



Ext.onReady(function() {
 
    Ext.QuickTips.init();
    Ext.enableListenerCollection=true;
    Ext.Ajax.request({
        url: '/ajax/reset_session',
        //success: this.validateFeed,
        //failure: this.markInvalid,
    });
        
    main=new PaperPile.Main;

    main.results_tabs.newDBtab();
    
    main.show();

    var button=Ext.getCmp('new_file_button');
    button.on('click', main.results_tabs.newFileTab,main.results_tabs);

    var button=Ext.getCmp('new_db_button');
    button.on('click', main.results_tabs.newDBtab,main.results_tabs);

    var button=Ext.getCmp('new_pubmed_button');
    button.on('click', main.results_tabs.newPubMedTab,main.results_tabs);

    var button=Ext.getCmp('import_journals_button');
    button.on('click', main.importJournals,main);

     
});
