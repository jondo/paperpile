Paperpile.PluginPanelPubMed = function(config) {
  Ext.apply(this,config);

  Paperpile.PluginPanelPubMed.superclass.constructor.call(this, {    
  });
};

Ext.extend(Paperpile.PluginPanelPubMed, Paperpile.PluginPanel, {

  title: 'PubMed',
  iconCls: 'pp-icon-pubmed',

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridPubMed(gridParams);
  }

});

Paperpile.PluginGridPubMed = function(config) {
  Ext.apply(this, config);
  Paperpile.PluginGridPubMed.superclass.constructor.call(this, {    
  });
};

Ext.extend(Paperpile.PluginGridPubMed, Paperpile.PluginGrid, {

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