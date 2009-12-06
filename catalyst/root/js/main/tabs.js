Paperpile.Tabs = Ext.extend(Ext.TabPanel, {
    initComponent:function() {

        Ext.apply(this, {
            id: 'pp-tabs',
            //margins: '2 2 2 2',
            //Have at least one item on rendering to get it rendered correctly
            items: [{title:'Welcome',
                     itemId: 'welcome'
                    }
                   ]
        });

        Paperpile.Tabs.superclass.initComponent.call(this);

    },

    newDBtab:function(query, itemId){

        var gridParams = {
            plugin_name: 'DB',
            plugin_mode: 'FULLTEXT',
            plugin_query: query,
            plugin_base_query:''
        };

        var newView=this.add(new Paperpile.PluginPanelDB({
	  title:'All Papers',
          iconCls: 'pp-icon-page',
          itemId:itemId,
	  gridParams: gridParams
	}));
        newView.show();
    },

    newTrashTab:function(){

        var gridParams = {
            plugin_name: 'Trash',
            plugin_mode: 'FULLTEXT',
            plugin_query: '',
            plugin_base_query:''
        };

        var newView=this.add(new Paperpile.PluginPanelTrash({
	  gridParams:gridParams,
	  title:'Trash',
          closable:true,
          itemId:'trash'
	}));
        newView.show();
    },


    // If itemId is given it is checked if the same tab already is
    // open and it activated instead of creating a new one
    newPluginTab:function(name, pars, title, iconCls, itemId){
      var javascript_ui = pars.plugin_name || name;
      if (pars.plugin_query != null && pars.plugin_query.indexOf('folder:') > -1) {
	javascript_ui = "Folder";
      }

        //var newGrid=new Paperpile['Plugin'+javascript_ui](pars);
        var openTab=Paperpile.main.tabs.getItem(itemId);
        if (openTab) {
	  this.activate(openTab);
	  return;
        } else {
	  var viewParams = {
	    title:title,
	    iconCls:iconCls,
            gridParams: pars,
            closable:true,
            itemId: itemId
	  };
	  Paperpile.log(viewParams);
	  if (iconCls) viewParams.iconCls = iconCls;
	  if (title) viewParams.title = title;
          var newView=this.add(new Paperpile['PluginPanel'+javascript_ui](viewParams));
	  newView.show();
	  return;
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
                      title: name.title
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
        var panel=Paperpile.main.tabs.add(new Paperpile.PDFviewer(pars));
        panel.show();
    }

}

);

Ext.reg('tabs', Paperpile.Tabs);