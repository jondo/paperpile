Paperpile.PluginGridSpringerLink = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'SpringerLink',
    plugin_iconCls: 'pp-icon-springerlink',
    limit: 10,

    initComponent:function() {

        this.plugin_name = 'SpringerLink';

        Paperpile.PluginGridSpringerLink.superclass.initComponent.apply(this, arguments);
	this.sidePanel = new Paperpile.PluginSidepanelSpringerLink();
    },
 
});

Paperpile.PluginSidepanelSpringerLink = Ext.extend(Paperpile.PluginSidepanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-springerlink-logo">&nbsp</div>',
        '<p class="pp-plugins-description">SpringerLink is a databases for high-quality scientific, technological and medical journals, books series and reference works. It offers over 1,750 peer reviewed journals and 27,000 eBooks.</p>',
        '<p><a target=_blank href="http://springerlink.com" class="pp-textlink">springerlink.com</a></p>',
        '</div>'],

    tabLabel: 'About SpringerLink',
   
});
