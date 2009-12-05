Paperpile.PluginPanelJSTOR = Ext.extend(Paperpile.PluginPanel, {
  createGrid: function(params) {
    return new Paperpile.PluginGridJSTOR(params);
  }
});

Paperpile.PluginGridJSTOR = Ext.extend(Paperpile.PluginGrid, {
    
    plugins:[
      new Paperpile.OnlineSearchGridPlugin(),
      new Paperpile.ImportGridPlugin()
    ],
    plugin_title: 'JSTOR',
    plugin_iconCls: 'pp-icon-jstor',
    limit:25,

    initComponent:function() {
        this.plugin_name = 'JSTOR';

        // Multiple selection behaviour and double-click import turned
        // out to be really difficult for plugins where we have a to
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

	this.aboutPanel = new Paperpile.AboutJSTOR();
        Paperpile.PluginGridJSTOR.superclass.initComponent.call(this);
    }
});

Paperpile.AboutJSTOR = Ext.extend(Paperpile.PluginAboutPanel, {
    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-jstor-logo">&nbsp</div>',
        '<p class="pp-plugins-description">JSTOR (short for Journal Storage) is a online system for archiving academic journals. It provides full-text searches of digitized back issues of several hundred well-known journals.</p>',
        '<p><a target=_blank href="http://www.jstor.org" class="pp-textlink">	jstor.org</a></p>',
        '</div>'],
    tabLabel: 'About JSTOR'
});
