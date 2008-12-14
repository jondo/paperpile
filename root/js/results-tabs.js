PaperPile.ResultsTabs = Ext.extend(Ext.TabPanel, {

    initComponent:function() {
        
        Ext.apply(this, {
            itemId: 'results_tabs',
            margins: '2 2 2 2',
            items: [{title: 'File',
                     border: true
                    }]
        });
       
        PaperPile.ResultsTabs.superclass.initComponent.apply(this, arguments);
    },

    newFileTab:function(){
        this.add({
            title: 'New Tab',
            iconCls: 'tabs',
            xtype:'resultsgrid',
            closable:true
        }).show();
    }
}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);