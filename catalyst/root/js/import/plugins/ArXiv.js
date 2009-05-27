Paperpile.PluginGridArXiv = Ext.extend(Paperpile.PluginGridOnlineSearch, {

    
    plugin_title: 'ArXiv',
    loadMask: {msg:"Searching ArXiv"},
    plugin_iconCls: 'pp-icon-arxiv',
    limit: 25,

    initComponent:function() {

        this.plugin_name = 'ArXiv';

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);
    },
 

});
