Paperpile.PluginGridPubMed = Ext.extend(Paperpile.PluginGrid, {

    loadMask: {msg:"Searching PubMed"},

    initComponent:function() {

        var _searchField=new Ext.app.SearchField({
            width:320,
        })

        Ext.apply(this, {
            plugin_type: 'PubMed',
            plugin_title: 'PubMed',
            plugin_iconCls: 'pp-icon-pubmed',
            tbar:[_searchField,
                  {xtype:'tbfill'},
                  {   xtype:'button',
                      itemId: 'add_button',
                      text: 'Import',
                      cls: 'x-btn-text-icon add',
                      listeners: {
                          click:  {fn: this.insertEntry, scope: this}
                      },
                  },
                 ],
        });

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);

        _searchField.store=this.store;

    },
    
    onRender: function() {
        Paperpile.PluginGridPubMed.superclass.onRender.apply(this, arguments);
        
        if (this.plugin_query != ''){
            this.store.load({params:{start:0, limit:25 }});
        }
    }


});
