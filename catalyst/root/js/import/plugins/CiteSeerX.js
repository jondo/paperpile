Paperpile.PluginPanelCiteSeerX = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'CiteSeerX',
      iconCls: 'pp-icon-citeseerx'
    });
    Paperpile.PluginPanelCiteSeerX.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridCiteSeerX(params);
  }
});

Paperpile.PluginGridCiteSeerX = Ext.extend(Paperpile.PluginGrid, {
    
    plugins:[
      new Paperpile.OnlineSearchGridPlugin(),
      new Paperpile.ImportGridPlugin()
    ],
    plugin_title: 'CiteSeerX',
    plugin_iconCls: 'pp-icon-citeseerx',
    limit:25,

    initComponent:function() {

        this.plugin_name = 'CiteSeerX';

        // Multiple selection behaviour and double-click import turned
        // out to be really difficult for plugins where we have a two
        // step process to get the data. Needs more thought, for now
        // we just turn these features off.

        this.sm=new Ext.grid.RowSelectionModel({singleSelect:true});
        this.onDblClick=function( grid, rowIndex, e ){
            Paperpile.status.updateMsg(
                { msg: 'Hint: use the "Add" button to import papers to your library.',
                  hideOnClick: true,
                }
            );
        };
	this.aboutPanel = new Paperpile.AboutCiteSeerX();

        Paperpile.PluginGridCiteSeerX.superclass.initComponent.call(this);
    }

});

Paperpile.AboutCiteSeerX = Ext.extend(Paperpile.PluginAboutPanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-citeseerx-logo">&nbsp</div>',
        '<p class="pp-plugins-description">CiteSeerX is a scientific literature digital library and search engine that focuses primarily on the literature in computer and information science.</p>',
        '<p><a target=_blank href="http://citeseerx.ist.psu.edu/" class="pp-textlink">citeseerx.ist.psu.edu</a></p>',
        '</div>'],

    tabLabel: 'About CiteSeerX'
   
});
