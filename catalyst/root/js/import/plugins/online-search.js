Paperpile.PluginGridOnlineSearch = Ext.extend(Paperpile.PluginGrid, {

    initComponent:function() {

        Paperpile.PluginGridOnlineSearch.superclass.initComponent.apply(this, arguments);

        var tbar=this.getTopToolbar();

        tbar.unshift(new Ext.app.SearchField({width:250,
                                              store: this.store}));

        this.actions['NEW'].hide();

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Searching '+this.plugin_name);
                      }, this);

        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
                      }, this);

    },
    
    onRender: function() {
        Paperpile.PluginGridOnlineSearch.superclass.onRender.apply(this, arguments);

        this.store.on('load', function(){
            this.getSelectionModel().selectFirstRow();
        }, this, {
            single: false
        });

        if (this.plugin_query != ''){
            this.store.load({params:{start:0, limit:this.limit }});
        }
    }


});
