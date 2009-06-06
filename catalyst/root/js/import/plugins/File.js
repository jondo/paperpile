Paperpile.PluginGridFile = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'File',
    
    initComponent:function() {

        Paperpile.PluginGridFile.superclass.initComponent.apply(this, arguments);

        this.actions['IMPORT'].show();
        this.actions['NEW'].hide();
        this.actions['EDIT'].hide();
        this.actions['DELETE'].hide();

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Parsing file.');
                      }, this);
        
        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

    },

});
