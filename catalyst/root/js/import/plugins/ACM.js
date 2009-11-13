Paperpile.PluginGridACM = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'ACM Portal',
    plugin_iconCls: 'pp-icon-acm',
    limit: 20,

    initComponent:function() {

        this.plugin_name = 'ACM';

        Paperpile.PluginGridACM.superclass.initComponent.apply(this, arguments);
	this.sidePanel = new Paperpile.PluginSidepanelACM();
    },   
 
});

Paperpile.PluginSidepanelACM = Ext.extend(Paperpile.PluginSidepanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-acm-logo">&nbsp</div>',
        '<p class="pp-plugins-description">The ACM Digital Library is the full-text repository of papers from publications that have been published, co-published or co-marketed by the Association for Computing Machinery (ACM). The archive comprises 54000 on-line articles from 30 journals and 900 proceedings.</p>',
        '<p><a target=_blank href="http://portal.acm.org" class="pp-textlink">portal.acm.org</a></p>',
        '</div>'],

    tabLabel: 'About ACM',
   
});
