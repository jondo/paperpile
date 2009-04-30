Paperpile.PluginGridGoogleScholar = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'GoogleScholar',
    loadMask: {msg:"Searching Google Scholar"},
    plugin_iconCls: 'pp-icon-google',
    limit:25,

    initComponent:function() {

        this.plugin_name = 'GoogleScholar';

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);
    },
 

});
