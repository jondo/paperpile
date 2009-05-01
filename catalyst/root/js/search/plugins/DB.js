Paperpile.PluginGridDB = Ext.extend(Paperpile.PluginGrid, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',

    initComponent:function() {

        this.plugin_name='DB';
      
        Paperpile.PluginGridDB.superclass.initComponent.apply(this, arguments);

        var tbar=this.getTopToolbar();

        tbar.unshift(new Ext.app.FilterField({store: this.store, 
                                              base_query: this.plugin_base_query,
                                              width: 320,
                                             }));

        // If we are viewing a virtual folders we need an additional
        // button to remove an entry from a virtual folder

        if (this.plugin_base_query.match('^folders:')){

            var menu = new Ext.menu.Menu({
                itemId: 'deleteMenu',
                items: [
                    {  text: 'Delete from library',
                       listeners: {
                           click:  {fn: this.deleteEntry, scope: this}
                       },
                    },
                    {  text: 'Delete from folder',
                       listeners: {
                           click:  {fn: this.deleteFromFolder, scope: this}
                       },
                    }
                ]
            });

            tbar[this.getButtonIndex('delete_button')]= {   xtype:'button',
                                                            text: 'Delete',
                                                            itemId: 'delete_button',
                                                            cls: 'x-btn-text-icon delete',
                                                            menu: menu
                                                        };
        }

        //this.getColumnModel().setHidden(0,true);

    },

    onRender: function() {
        Paperpile.PluginGridDB.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25 }});

        this.store.on('load', function(){
            this.getSelectionModel().selectFirstRow();
        }, this, {
            single: true
        });



    },


    //
    // Delete entry from virtual folder
    //

    deleteFromFolder: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().data.sha1;

        var match=this.plugin_base_query.match('folders:(.*)$');

        Ext.Ajax.request({
            url: '/ajax/tree/delete_from_folder',
            params: { rowid: rowid,
                      grid_id: this.id,
                      folder_id: match[1]
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
        });

        this.store.remove(this.store.getAt(this.store.find('sha1',sha1)));

    },




});
