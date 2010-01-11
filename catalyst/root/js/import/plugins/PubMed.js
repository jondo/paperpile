Paperpile.PluginPanelPubMed = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'PubMed',
      iconCls: 'pp-icon-pubmed'
    });
    Paperpile.PluginPanelPubMed.superclass.initComponent.call(this);
  },
  createGrid: function(gridParams) {
    return new Paperpile.PluginGridPubMed(gridParams);
  }
});

Paperpile.PluginGridPubMed = Ext.extend(Paperpile.PluginGrid, {

  plugins:[
    new Paperpile.OnlineSearchGridPlugin(),
    new Paperpile.ImportGridPlugin()
  ],
  initComponent:function() {
    this.limit = 25;
    this.plugin_name = 'PubMed';
    this.aboutPanel = new Paperpile.AboutPubMed();
			
    Paperpile.PluginGridPubMed.superclass.initComponent.call(this);
  }

});

Paperpile.AboutPubMed = Ext.extend(Paperpile.PluginAboutPanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-pubmed-logo">&nbsp</div>',
        '<p>The PubMed database comprises more than 19 million citations for biomedical articles from MEDLINE and life science journals.</p>',
        '<p><a target=_blank href="http://pubmed.gov" class="pp-textlink">pubmed.gov</a></p>',
        '</div>'],

    tabLabel: 'About PubMed'
});