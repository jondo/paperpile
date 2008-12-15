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
        this.add(new PaperPile.ResultsGrid({
            title: 'test2.ris',
            iconCls: 'tabs',
            source_file: '/home/wash/play/PaperPile/t/data/test2.ris',
            source_type: 'FILE',
            closable:true
        })).show();
    },

    newDBtab:function(){
        this.add(new PaperPile.ResultsGrid({
            title: 'DB',
            iconCls: 'tabs',
            source_file: '',
            source_type: 'DB',
            closable:true
        })).show();
    }





}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);