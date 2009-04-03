Paperpile.PluginGridDB = Ext.extend(Paperpile.PluginGrid, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',

    initComponent:function() {
        
        var _filterField=new Ext.app.FilterField({
            width:320,
        });


        var tbar=[_filterField, 
                  {xtype:'tbfill'},
                  {   xtype:'button',
                      itemId: 'new_button',
                      text: 'New',
                      cls: 'x-btn-text-icon add',
                      listeners: {
                          click:  {fn: this.newEntry, scope: this}
                      },
                  },
                  {   xtype:'button',
                      text: 'Delete',
                      itemId: 'delete_button',
                      cls: 'x-btn-text-icon delete',
                      listeners: {
                          click:  {fn: this.deleteEntry, scope: this}
                      },
                  },
                  {   xtype:'button',
                      itemId: 'edit_button',
                      text: 'Edit',
                      cls: 'x-btn-text-icon edit',
                      listeners: {
                          click:  {fn: this.editEntry, scope: this}
                      },
                  },
                 ];

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

            tbar[3]= {   xtype:'button',
                         text: 'Delete',
                         itemId: 'delete_button',
                         cls: 'x-btn-text-icon delete',
                         menu: menu
                     };

        }

        Ext.apply(this, {
            plugin_name: 'DB',
            tbar:  tbar
        });

        Paperpile.PluginGridDB.superclass.initComponent.apply(this, arguments);
        _filterField.store=this.store;
        _filterField.base_query=this.plugin_base_query;

        this.getColumnModel().setHidden(0,true);



    },

    onRender: function() {
        Paperpile.PluginGridDB.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25 }});
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
