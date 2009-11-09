Paperpile.PluginGridPubMed = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGridPubMed.superclass.constructor.call(this, {    
    plugin_title: 'PubMed',
    //loadMask: {msg:"Searching PubMed"},
    plugin_iconCls: 'pp-icon-pubmed',
    limit: 25
  });

};

Ext.extend(Paperpile.PluginGridPubMed, Paperpile.PluginGridOnlineSearch, {

    initComponent:function() {
      Paperpile.PluginGridPubMed.superclass.initComponent.call(this);
      
      this.plugin_name = 'PubMed';
      this.sidePanel = new Paperpile.PluginSidepanelPubMed();
    }

});

Paperpile.PluginSidepanelPubMed = Ext.extend(Paperpile.PluginSidepanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-pubmed-logo">&nbsp</div>',
        '<p>The PubMed database comprises more than 19 million citations for biomedical articles from MEDLINE and life science journals.</p>',
        '<p><a target=_blank href="http://pubmed.gov" class="pp-textlink">pubmed.gov</a></p>',
        '</div>'],

    tabLabel: 'About PubMed'
   
});