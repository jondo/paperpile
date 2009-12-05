Paperpile.PluginPanelArXiv = Ext.extend(Paperpile.PluginPanel, {
  createGrid: function(params) {
    return new Paperpile.PluginGridArXiv(params);
  }
});

Paperpile.PluginGridArXiv = Ext.extend(Paperpile.PluginGrid, {
  
    plugins:[
      new Paperpile.OnlineSearchGridPlugin(),
      new Paperpile.ImportGridPlugin()
    ],
    plugin_title: 'ArXiv',
    plugin_iconCls: 'pp-icon-arxiv',
    limit: 25,

    initComponent:function() {
      this.plugin_name = 'ArXiv';
      this.aboutPanel = new Paperpile.AboutArXiv();
      
      Paperpile.PluginGridArXiv.superclass.initComponent.call(this);
    }
 
});

Paperpile.AboutArXiv = Ext.extend(Paperpile.PluginAboutPanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-arxiv-logo">&nbsp</div>',
        '<p class="pp-plugins-description">arXiv is an e-print service in the fields of physics, mathematics, non-linear science, computer science, quantitative biology and statistics. It currently offers open access to more than 570,000 e-prints.</p>',
        '<p><a target=_blank href="http://arxiv.org/" class="pp-textlink">arxiv.org</a></p>',
        '</div>'],

    tabLabel: 'About ArXiv'
   
});
