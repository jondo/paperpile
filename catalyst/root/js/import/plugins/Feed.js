Paperpile.PluginGridFeed = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-feed',
    plugin_name:'Feed',
    
    initComponent:function() {

        Paperpile.PluginGridFeed.superclass.initComponent.apply(this, arguments);

        this.store.baseParams['plugin_url']= this.plugin_url ;
        this.store.baseParams['plugin_id']= this.plugin_id ;

        this.actions['IMPORT'].show();
        this.actions['NEW'].hide();
        this.actions['EDIT'].hide();
        this.actions['TRASH'].hide();

        this.actions['IMPORT_ALL'].show();
        this.actions['IMPORT_ALL'].enable();

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Loading feed.');
                      }, this);
        
        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

    },

});
