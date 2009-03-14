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
        this.add(new PaperPile.PluginGridFile({
            title: 'test2.ris',
            iconCls: 'tabs',
            source_file: file,
            source_type: 'FILE',
            closable:true
        })).show();
    },

    newDBtab:function(query){
        
        var newGrid=new PaperPile.PluginGridDB({
            plugin_type: 'DB',
            plugin_mode: 'FULLTEXT',
            plugin_query: query,
        });

        var newView=this.add(new PaperPile.PubView({title:'Local library', 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: 'pp-icon-page',
                                                   }));
        newView.show();
    },

    
    newPluginTab:function(name, pars){

        var newGrid=new PaperPile['PluginGrid'+name](pars);
        
        var newView=this.add(new PaperPile.PubView({title: newGrid.plugin_title, 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: newGrid.plugin_iconCls,
                                                   }));
        newView.show();
    },


    newPubMedTab:function(query){
        this.add(new PaperPile.PluginGridPubMed({
            source_query: query,
            iconCls: 'tabs',
        })).show();
    },
  

    showDBQueryResults: function(mode,query,base_query,tabTitle,iconCls){

        var newGrid=new PaperPile.PluginGridDB({
            iconCls: iconCls,
            plugin_type: 'DB',
            plugin_query: base_query,
            plugin_mode: mode,
            base_query: base_query,
        });

        var newView=this.add(new PaperPile.PubView({title:tabTitle, 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: iconCls
                                                   }));
        newView.show();
    }


}                                 
 
);

Ext.reg('tabs', PaperPile.Tabs);