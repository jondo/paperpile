Paperpile.PluginGridGoogleBooks = Ext.extend(Paperpile.PluginGridOnlineSearch, {
    
    plugin_title: 'GoogleBooks',
    plugin_iconCls: 'pp-icon-google',
    limit:25,

    initComponent:function() {

        this.plugin_name = 'GoogleBooks';


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

        Paperpile.PluginGridGoogleBooks.superclass.initComponent.apply(this, arguments);
	this.sidePanel = new Paperpile.PluginSidepanelGoogleBooks();
    },    
});

Paperpile.PluginSidepanelGoogleBooks = Ext.extend(Paperpile.PluginSidepanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-googlebooks-logo">&nbsp</div>',
        '<p class="pp-plugins-description">GoogleBooks allows you to search the full text of books. Find the perfect book for your purposes and discover new ones that interest you.</p>',
        '<p><a target=_blank href="http://books.google.com/" class="pp-textlink">books.google.com/</a></p>',
        '</div>'],

    tabLabel: 'About GoogleBooks',
   
});
