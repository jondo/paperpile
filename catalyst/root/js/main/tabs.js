Paperpile.Tabs = Ext.extend(Ext.TabPanel, {

    initComponent:function() {
        
        Ext.apply(this, {
            id: 'tabs',
            //margins: '2 2 2 2',
            //Have at least one item on rendering to get it rendered correctly
            items: [{title:'Welcome', 
                     itemId: 'welcome'
                    }
                   ],
        });
       
        Paperpile.Tabs.superclass.initComponent.apply(this, arguments);

    },

    newDBtab:function(query){
        
        var newGrid=new Paperpile.PluginGridDB({
            plugin_name: 'DB',
            plugin_mode: 'FULLTEXT',
            plugin_query: query,
            plugin_base_query:'',
        });

        var newView=this.add(new Paperpile.PubView({title:'All Papers', 
                                                    grid:newGrid,
                                                    closable:false,
                                                    iconCls: 'pp-icon-page',
                                                   }));
        newView.show();
    },

    
    newPluginTab:function(name, pars, title, iconCls){

        var newGrid=new Paperpile['PluginGrid'+name](pars);
        
        var newView=this.add(new Paperpile.PubView({title: (title) ? title:newGrid.plugin_title, 
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: (iconCls) ? iconCls : newGrid.plugin_iconCls,
                                                   }));
        newView.show();
        
        
    },

    newScreenTab:function(name){
        var panel=main.tabs.add(new Paperpile[name]());
        panel.show();
    }
    
}                                 
 
);

Ext.reg('tabs', Paperpile.Tabs);