PaperPile.Tabs = Ext.extend(Ext.TabPanel, {

    initComponent:function() {
        
        Ext.apply(this, {
            id: 'tabs',
            margins: '2 2 2 2',
            //Have at least one item on rendering to get it rendered correctly
            items: [{title:'Welcome', 
                     itemId: 'welcome'
                    }
                   ],
        });
       
        PaperPile.Tabs.superclass.initComponent.apply(this, arguments);

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
            source_type: 'DB',
            source_mode: 'FULLTEXT',
            source_query: query,
        }));

        var newView=this.add(new PaperPile.PubView({title:'Local library', 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: 'pp-icon-page',
                                                   }));
        newView.show();
    },

    newPubMedTab:function(query){
        this.add(new PaperPile.ResultsGridPubMed({
            source_query: query,
            iconCls: 'tabs',
        })).show();
    },
  

    showDBQueryResults: function(mode,query,base_query,tabTitle,iconCls){

        var targetTab;

        targetTab=new PaperPile.ResultsGridDB({
            title: 'DB',
            iconCls: iconCls,
            source_type: 'DB',
            source_query: base_query,
            source_mode: mode,
            base_query: base_query,
            closable:true
        });
        
        this.add(targetTab);
        targetTab.setTitle(tabTitle);
        this.activate(targetTab.id);

    }


}                                 
 
);

Ext.reg('tabs', PaperPile.Tabs);