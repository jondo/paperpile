Paperpile.PluginGridCiteSeerX = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'CiteSeerX',
    plugin_iconCls: 'pp-icon-citeseerx',
    limit:25,

    initComponent:function() {

        this.plugin_name = 'CiteSeerX';

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

        Paperpile.PluginGridCiteSeerX.superclass.initComponent.apply(this, arguments);
	this.sidePanel = new Paperpile.PluginSidepanelCiteSeerX();
    }, 

});


Paperpile.PluginSidepanelCiteSeerX = Ext.extend(Paperpile.PluginSidepanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-citeseerx-logo">&nbsp</div>',
        '<p class="pp-plugins-description">CiteSeerX is a scientific literature digital library and search engine that focuses primarily on the literature in computer and information science.</p>',
        '<p><a target=_blank href="http://citeseerx.ist.psu.edu/" class="pp-textlink">citeseerx.ist.psu.edu</a></p>',
        '</div>'],

    tabLabel: 'About CiteSeerX',
   
});
