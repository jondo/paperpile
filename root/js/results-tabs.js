PaperPile.ResultsTabs = Ext.extend(Ext.TabPanel, {

    initComponent:function() {
        
        Ext.apply(this, {
            itemId: 'results_tabs',
            margins: '2 2 2 2',
            items: [{title: 'File',
                     xtype:'resultsgrid',
                     itemId:'results_grid',
                     border: false
                    }]
        });
       
        PaperPile.ResultsTabs.superclass.initComponent.apply(this, arguments);
    },

    newFileTab:function(){
        this.a({
            title: 'New Tab ',
            iconCls: 'tabs',
            closable:true
        }).show();
    }
}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);