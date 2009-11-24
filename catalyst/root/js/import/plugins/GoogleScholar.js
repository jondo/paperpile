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

        Paperpile.PluginGridGoogleScholar.superclass.initComponent.call(this);
	this.sidePanel = new Paperpile.AboutGoogleScholar();
    },
 

});

Paperpile.AboutGoogleScholar = Ext.extend(Paperpile.PluginAboutPanel, {

    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-googlescholar-logo">&nbsp</div>',
        '<p class="pp-plugins-description">Google Scholar provides a simple way to broadly search for scholarly literature. From one place, you can search across many disciplines and sources: peer-reviewed papers, theses, books, abstracts and articles, from academic publishers, professional societies, preprint repositories, universities and other scholarly organizations. Google Scholar helps you identify relevant research across the world of scholarly research.</p>',
        '<p><a target=_blank href="http://scholar.google.com" class="pp-textlink">scholar.google.com</a></p>',
        '</div>'],

    tabLabel: 'About GoogleScholar'
   
});
