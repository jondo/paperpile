Paperpile.PluginGridArXiv = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'ArXiv',
    plugin_iconCls: 'pp-icon-arxiv',
    limit: 25,

    initComponent:function() {

        this.plugin_name = 'ArXiv';

        Paperpile.PluginGridArXiv.superclass.initComponent.apply(this, arguments);
	this.sidePanel = new Paperpile.PluginSidepanelArXiv();
    },
 
});

Paperpile.PluginSidepanelArXiv = Ext.extend(Paperpile.PluginSidepanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-arxiv-logo">&nbsp</div>',
        '<p class="pp-plugins-description">arXiv is an e-print service in the fields of physics, mathematics, non-linear science, computer science, quantitative biology and statistics. It currently offers open access to more than 570,000 e-prints.</p>',
        '<p><a target=_blank href="http://arxiv.org/" class="pp-textlink">http://arxiv.org/</a></p>',
        '</div>'],

    tabLabel: 'About ArXiv',
   
});
