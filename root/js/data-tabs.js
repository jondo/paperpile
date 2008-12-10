PaperPile.DataTabs = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            itemId: 'data_tabs',
            layout:'card',
            margins: '2 2 2 2',
            items:[{xtype:'pubsummary',
                    itemId:'pubsummary',
                    border: false,
                    height:200
                   }]
        });
       
        PaperPile.DataTabs.superclass.initComponent.apply(this, arguments);
    } 
}                                 
 
);

Ext.reg('datatabs', PaperPile.DataTabs);