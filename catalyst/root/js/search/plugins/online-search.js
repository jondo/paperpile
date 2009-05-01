Paperpile.PluginGridOnlineSearch = Ext.extend(Paperpile.PluginGrid, {

    initComponent:function() {

        Paperpile.PluginGridOnlineSearch.superclass.initComponent.apply(this, arguments);

        var tbar=this.getTopToolbar();

        tbar.unshift(new Ext.app.SearchField({width:320,
                                              store: this.store}));

        console.log('OnlineSearch');

        var addButton = { xtype:'button',
                          itemId: 'add_button',
                          text: 'Import',
                          cls: 'x-btn-text-icon add',
                          listeners: {
                              click:  {
                                  fn: function(){
                                      this.insertEntry();
                                  },
                                  scope: this
                              },
                          },
                          disabled: true,
                        };

        tbar.splice(this.getButtonIndex('new_button'), 1, addButton);

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
