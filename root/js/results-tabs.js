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
        var newGrid=this.add(new PaperPile.ResultsGridDB({
            title: 'DB',
            iconCls: 'tabs',
            source_type: 'DB',
            source_query:'',
            closable:true
        }));

        newGrid.show();

    },

    newPubMedTab:function(){
        this.add(new PaperPile.ResultsGridPubMed({
            source_query: 'Stadler PF',
        })).show();
    }
}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);