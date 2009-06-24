Paperpile.PluginGridPubMed = Ext.extend(Paperpile.PluginGridOnlineSearch, {

    
    plugin_title: 'PubMed',
    //loadMask: {msg:"Searching PubMed"},
    plugin_iconCls: 'pp-icon-pubmed',
    limit: 25,

    initComponent:function() {

        this.plugin_name = 'PubMed';

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);

       
                    
    },
 

});
