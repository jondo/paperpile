PaperPile.ResultsTabs = Ext.extend(Ext.TabPanel, {

    initComponent:function() {
        
        Ext.apply(this, {
            itemId: 'results_tabs',
            xtype: 'tabpanel',
            margins: '2 2 2 2',
            items: [{title: 'File',
                     xtype:'resultsgrid',
                     itemId:'results_grid',
                     border: false
                    }]
        });

        
        PaperPile.ResultsTabs.superclass.initComponent.apply(this, arguments);

    } 
}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);