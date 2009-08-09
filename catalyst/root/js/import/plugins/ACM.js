Paperpile.PluginGridACM = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'ACM Portal',
    plugin_iconCls: 'pp-icon-acm',
    limit: 20,

    initComponent:function() {

        this.plugin_name = 'ACM';

        Paperpile.PluginGridACM.superclass.initComponent.apply(this, arguments);
    },
 
});
