Paperpile.PluginGridPubMed = Ext.extend(Paperpile.PluginGridOnlineSearch, {

    
    plugin_title: 'PubMed',
    //loadMask: {msg:"Searching PubMed"},
    plugin_iconCls: 'pp-icon-pubmed',

    
    limit: 25,

    initComponent:function() {

        this.plugin_name = 'PubMed';

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);

        this.sidePanel = new Paperpile.PluginSidepanelPubMed({ itemId:'about',
                                                             });

    },

});

Paperpile.PluginSidepanelPubMed = Ext.extend(Ext.Panel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-pubmed-logo">&nbsp</div>',
        '<p>The PubMed database comprises more than 19 million citations for biomedical articles from MEDLINE and life science journals.</p>',
        '<p><a target=_blank href="http://pubmed.gov" class="pp-textlink">pubmed.gov</a></p>',
        '</div>'],


    initComponent: function() {
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
		});

	    this.tpl = new Ext.XTemplate(this.markup).compile();
	
        Paperpile.PluginSidepanelPubMed.superclass.initComponent.call(this);
	},

    
    update: function(){

        this.tpl.overwrite(this.body, {}, true);

    }
});