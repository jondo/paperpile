Paperpile.PluginGridPubMed = Ext.extend(Paperpile.PluginGridOnlineSearch, {

    
    plugin_title: 'PubMed',
    //loadMask: {msg:"Searching PubMed"},
    plugin_iconCls: 'pp-icon-pubmed',
    limit: 25,

    initComponent:function() {

        this.plugin_name = 'PubMed';

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Searching PubMed');
                      }, this);

        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

                    
    },
 

});
