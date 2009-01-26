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
            source_mode: 'FULLTEXT',
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
    },
  

    showDBQueryResults: function(mode,query,tabTitle){

        // If some database tab(s) is/are open choose the first of them;
        // if not create new
        var DBtabs=this.findBy(function(c){return c.source_type=='DB'});

        var targetTab;

        if (DBtabs.length>0){
            targetTab=DBtabs[0];
            targetTab.source_mode=mode;
            targetTab.source_query=query;
            targetTab.store.baseParams.source_query=query;
            targetTab.store.baseParams.source_mode=mode;
            targetTab.store.baseParams.source_task='NEW';
            targetTab.store.load({params:{start:0, limit:25}});

        } else {
            targetTab=new PaperPile.ResultsGridDB({
                title: 'DB',
                iconCls: 'tabs',
                source_type: 'DB',
                source_query: query,
                source_mode: mode,
                closable:true
            });
            this.add(targetTab);
        }                                   

        targetTab.setTitle(tabTitle);

        this.activate(targetTab.id);


    }






}                                 
 
);

Ext.reg('resultstabs', PaperPile.ResultsTabs);