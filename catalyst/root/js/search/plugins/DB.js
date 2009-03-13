PaperPile.PluginGridDB = Ext.extend(PaperPile.PluginGrid, {

    base_query:'',
    
    initComponent:function() {
        
        var _filterField=new Ext.app.FilterField({
            width:320,
        });

        Ext.apply(this, {
            plugin_type: 'DB',
            tbar:  [_filterField, 
                    {xtype:'tbfill'},
                    {   xtype:'button',
                        itemId: 'new_button',
                        text: 'New',
                        cls: 'x-btn-text-icon add',
                        listeners: {
                            click:  {fn: this.editEntry, scope: this}
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
                    
                   ]
            
        });

        PaperPile.PluginGridDB.superclass.initComponent.apply(this, arguments);
        _filterField.store=this.store;
        _filterField.base_query=this.base_query;

        this.getColumnModel().setHidden(0,true);

    },

    onRender: function() {
        PaperPile.PluginGridDB.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25 }});
    }
});
