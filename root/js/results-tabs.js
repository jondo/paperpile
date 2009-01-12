PaperPile.ResultsTabs = Ext.extend(Ext.TabPanel, {

    initComponent:function() {
        
        Ext.apply(this, {
            id: 'results_tabs',
            margins: '2 2 2 2',
            items: [{title:'Welcome'}],
        });
       
        PaperPile.ResultsTabs.superclass.initComponent.apply(this, arguments);

    },

    newFileTab:function(file){
        this.add(new PaperPile.ResultsGridFile({
            title: 'test2.ris',
            iconCls: 'tabs',
            source_file: file,
            source_type: 'FILE',
            closable:true
        })).show();
    },

    newDBtab:function(query){
        var newGrid=this.add(new PaperPile.ResultsGridDB({
            title: 'DB',
            iconCls: 'tabs',
            source_type: 'DB',
            source_query: query,
            closable:true
        }));

        newGrid.show();

    },

    newPubMedTab:function(query){
        this.add(new PaperPile.ResultsGridPubMed({
            source_query: query,
            iconCls: 'tabs',
        })).show();
    }
  

}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);