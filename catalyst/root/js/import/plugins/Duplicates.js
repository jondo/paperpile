Paperpile.PluginGridDuplicates = Ext.extend(Paperpile.PluginGrid, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'Duplicates',
    limit: 25,

    initComponent:function() {

        Paperpile.PluginGridDB.superclass.initComponent.apply(this, arguments);

        this.limit = Paperpile.main.globalSettings['pager_limit'];


        this.actions['IMPORT'].hide();
        this.actions['NEW'].hide();
        this.actions['IMPORT_ALL'].hide();
        this.actions['EXPORT'].hide();
        this.actions['SAVE_AS_ACTIVE'].hide();

        var tbar=this.getTopToolbar();
        
        tbar.splice(1,0,{ xtype:'button',
                          itemId:'clean_duplicates', 
                          text: 'Clean all duplicates', 
                          tooltip: 'Automatically clean all duplicates',
                          cls: 'x-btn-text-icon clean',
                          handler: this.cleanDuplicates
                        }
                   );

        this.store.on('load', 
                      function(){
                          
                      }, this);

    },

    onRender: function() {
        Paperpile.PluginGridDB.superclass.onRender.apply(this, arguments);

        this.store.load({params:{start:0, limit: this.limit}});

        this.store.on('load', function(){
            this.getSelectionModel().selectFirstRow();
        }, this, {
            single: true
        });

        Paperpile.PluginGrid.superclass.afterRender.apply(this, arguments);
        
    },

    cleanDuplicates: function(){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/misc/clean_duplicates'),
            params: { grid_id: this.id,
                    },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);

            },
            failure: Paperpile.main.onError,
            scope:this
        });

    },





});
