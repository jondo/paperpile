Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('PaperPile');

PaperPile.Main = Ext.extend(Ext.Viewport, {
    initComponent: function() {
        Ext.apply(this, 
                  {layout: 'border',
                   renderTo: Ext.getBody(),
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
                                       text: 'New file tab',
                                     }]
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
                             items: [{height:600,
                                      border: false,
                                      xtype: 'resultstabs',
                                      region: 'center',
                                      activeItem:0,
                                     },
                                     {border: false,
                                      xtype: 'datatabs',
                                      activeItem:0,
                                      height:200,
                                      region:'south'
                                     }]}]});
                               
        PaperPile.Main.superclass.initComponent.call(this);

        this.results_tabs=this.getComponent('innerpanel').getComponent('results_tabs');
        this.data_tabs=this.getComponent('innerpanel').getComponent('data_tabs');
                 
	  },

	  onRowSelect: function(sm, rowIdx, r) {
        this.data_tabs.getComponent('pubsummary').updateDetail(r.data);
    },


}

);



Ext.onReady(function() {
 
    Ext.QuickTips.init();
        
    main=new PaperPile.Main;
    
    main.show();

    var button=main.getComponent('navigation').getComponent('new_file_button');

    button.on('click', main.results_tabs.newFileTab,main.results_tabs);



     
});
