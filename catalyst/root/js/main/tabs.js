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

    newDBtab:function(query, itemId){

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
                                                    itemId:itemId,
                                                   }));
        newView.show();
    },

    newTrashTab:function(){

        var newGrid=new Paperpile.PluginGridTrash({
            plugin_name: 'Trash',
            plugin_mode: 'FULLTEXT',
            plugin_query: '',
            plugin_base_query:'',
        });

        var newView=this.add(new Paperpile.PubView({title:'Trash',
                                                    grid:newGrid,
                                                    closable:true,
                                                    iconCls: 'pp-icon-trash',
                                                    itemId:'trash',
                                                   }));
        newView.show();
    },



    // If itemId is given it is checked if the same tab already is
    // open and it activated instead of creating a new one
    newPluginTab:function(name, pars, title, iconCls, itemId){

        var newGrid=new Paperpile['PluginGrid'+name](pars);

        var openTab=Paperpile.main.tabs.getItem(itemId);

        if (openTab){
            this.activate(openTab);
        } else {
	  title = (title) ? title: newGrid.plugin_title;
//	  title = title.substring(0,32);
            var newView=this.add(new Paperpile.PubView({title: title,
                                                        grid:newGrid,
                                                        closable:true,
                                                        iconCls: (iconCls) ? iconCls : newGrid.plugin_iconCls,
                                                        itemId: itemId,
                                                       }));
            newView.show();
        }
    },


    // Opens a new tab with some specialized screen. Name is either the name of a preconficured panel-class, or
    // an object specifying url and title of the tab.

    newScreenTab:function(name, itemId){

        var openTab=Paperpile.main.tabs.getItem(itemId);

        if (openTab){
            this.activate(openTab);
        } else {

            var panel;

            // Pre-configured class
            if (Paperpile[name]){
                panel=Paperpile.main.tabs.add(new Paperpile[name]({itemId:itemId}));

            // Generic panel
            } else {

                panel=Paperpile.main.tabs.add(new Ext.Panel(
                    { closable:true,
                      autoLoad:{url:Paperpile.Url(name.url),
                                callback: this.setupFields,
                                scope:this
                               },
                      autoScroll: true,
                      title: name.title,
                    }
                ));
            }

            panel.show();

        }
    },


    showQueueTab:function(){
        var openTab=Paperpile.main.tabs.getItem('queue-tab');

        if (openTab){
            openTab.items.get('grid').getStore().reload();
            this.activate(openTab);
        } else {
            var panel=Paperpile.main.tabs.add(new Paperpile.QueueView({title:'Background tasks',
                                                                       iconCls: 'pp-icon-queue',
                                                                       itemId:'queue-tab'
                                                                      }
                                                                     ));
            panel.show();

        }
        
    },


    pdfViewerCounter:0,
    newPdfTab:function(config){
      this.pdfViewerCounter++;
        var defaults = { id:'pdf_viewer_'+this.pdfViewerCounter,
                         region:'center',
	                 search:'',
			 zoom:'width',
		         columns:1,
		         pageLayout:'flow',
                         closable:true,
                         iconCls: 'pp-icon-import-pdf'
                       };
        var pars={};

        Ext.apply(pars, config, defaults);
        console.log(pars);
        var panel=Paperpile.main.tabs.add(new Paperpile.PDFviewer(pars));
        panel.show();
    }

}

);

Ext.reg('tabs', Paperpile.Tabs);