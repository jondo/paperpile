Paperpile.PluginGridGoogleScholar = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'GoogleScholar',
    plugin_iconCls: 'pp-icon-google',
    limit:10,

    initComponent:function() {

        this.plugin_name = 'GoogleScholar';


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

        Paperpile.PluginGridPubMed.superclass.initComponent.apply(this, arguments);
    },
 

});
