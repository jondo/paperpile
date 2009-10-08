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

    initComponent: function() {
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffff44',
				padding: '7px'
			},
            autoScroll: true,
		});
		
        Paperpile.PluginSidepanelPubMed.superclass.initComponent.call(this);
        
	}
});