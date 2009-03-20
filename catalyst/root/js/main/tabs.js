Paperpile.Tabs = Ext.extend(Ext.TabPanel, {

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
       
        Paperpile.Tabs.superclass.initComponent.apply(this, arguments);

    },

    newFileTab:function(file){
        this.add(new Paperpile.PluginGridFile({
            title: 'test2.ris',
            iconCls: 'tabs',
            source_file: file,
            source_type: 'FILE',
            closable:true
        })).show();
    },

    newDBtab:function(query){
        
        var newGrid=new Paperpile.PluginGridDB({
            plugin_name: 'DB',
            plugin_mode: 'FULLTEXT',
            plugin_query: query,
            plugin_base_query:'',
        });

        var newView=this.add(new Paperpile.PubView({title:'Local library', 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: 'pp-icon-page',
                                                   }));
        newView.show();
    },

    
    newPluginTab:function(name, pars){

        var newGrid=new Paperpile['PluginGrid'+name](pars);
        
        var newView=this.add(new Paperpile.PubView({title: newGrid.plugin_title, 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: newGrid.plugin_iconCls,
                                                   }));
        newView.show();
    },


    newPubMedTab:function(query){
        this.add(new Paperpile.PluginGridPubMed({
            source_query: query,
            iconCls: 'tabs',
        })).show();
    },
  

    showDBQueryResults: function(mode,query,base_query,tabTitle,iconCls){

        var newGrid=new Paperpile.PluginGridDB({
            iconCls: iconCls,
            plugin_name: 'DB',
            plugin_query: base_query,
            plugin_mode: mode,
            plugin_base_query: base_query,
        });

        var newView=this.add(new Paperpile.PubView({title:tabTitle, 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: iconCls
                                                   }));
        newView.show();
    }


}                                 
 
);

Ext.reg('tabs', Paperpile.Tabs);