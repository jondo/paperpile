Paperpile.PluginGridOnlineSearch = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGridOnlineSearch.superclass.constructor.call(this, {
    });

};


Ext.extend(Paperpile.PluginGridOnlineSearch, Paperpile.PluginGrid, {

    initComponent:function() {
        Paperpile.PluginGridOnlineSearch.superclass.initComponent.call(this);

        var tbar=this.getTopToolbar();
        tbar.unshift(new Ext.app.SearchField({width:200,
                                              store: this.store}));

        this.store.on('beforeload',
                      function(){
                          Paperpile.status.showBusy('Searching '+this.plugin_name);
                      }, this);

        this.store.on('load',
                      function(){
                          Paperpile.status.clearMsg();
			this.getSelectionModel().selectFirstRow();
                      }, this);
        if (this.plugin_query != ''){
            this.store.load({params:{start:0, limit:this.limit }});
        }

	this.on({afterrender:{scope:this,fn:this.myOnRender}});
    },

    myOnRender: function() {
      var tbar = this.getTopToolbar();
      var index = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
      tbar.insertButton(index+1,this.actions['IMPORT_ALL']);
      tbar.insertButton(index+1,this.actions['IMPORT']);
    }
    
});
