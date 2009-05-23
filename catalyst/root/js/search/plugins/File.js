Paperpile.PluginGridFile = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'File',
    
    initComponent:function() {

        Paperpile.PluginGridFile.superclass.initComponent.apply(this, arguments);

        var tbar=this.getTopToolbar();
        tbar[this.getButtonIndex('add_button')].hidden=false;
        tbar[this.getButtonIndex('new_button')].hidden=true;

    },

    

});
