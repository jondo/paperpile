Paperpile.PluginGridSpringerLink = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'SpringerLink',
    plugin_iconCls: 'pp-icon-springerlink',
    limit: 10,

    initComponent:function() {

        this.plugin_name = 'SpringerLink';

        Paperpile.PluginGridSpringerLink.superclass.initComponent.apply(this, arguments);
    },
 
});
