Paperpile.PluginPanelACM = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'ACM Portal',
      iconCls: 'pp-icon-acm'
    });
    Paperpile.PluginPanelACM.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridACM(params);
  }
});

Paperpile.PluginGridACM = Ext.extend(Paperpile.PluginGrid, {    

    plugins:[
      new Paperpile.OnlineSearchGridPlugin(),
      new Paperpile.ImportGridPlugin()
    ],
    limit: 20,

    initComponent:function() {
      this.plugin_name = 'ACM';
      this.aboutPanel = new Paperpile.AboutACM();

      Paperpile.PluginGridACM.superclass.initComponent.call(this);
    }
 
});

Paperpile.AboutACM = Ext.extend(Paperpile.PluginAboutPanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-acm-logo">&nbsp</div>',
        '<p class="pp-plugins-description">The ACM Digital Library is the full-text repository of papers from publications that have been published, co-published or co-marketed by the Association for Computing Machinery (ACM). The archive comprises 54000 on-line articles from 30 journals and 900 proceedings.</p>',
        '<p><a target=_blank href="http://portal.acm.org" class="pp-textlink">portal.acm.org</a></p>',
        '</div>'],

    tabLabel: 'About ACM'
});
