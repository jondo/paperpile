Paperpile.PluginGridTrash = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-trash',
    plugin_name:'Trash',
    
    initComponent:function() {

        Paperpile.PluginGridFile.superclass.initComponent.apply(this, arguments);

        this.actions['NEW'].hide();
        this.actions['EDIT'].hide();
        this.actions['TRASH'].hide();

        this.actions['DELETE']= new Ext.Action({
            text: 'Delete',
            handler: function(){
                this.deleteEntry(0);
            },
            scope: this,
            cls: 'x-btn-text-icon delete',
            disabled:false,
            itemId:'delete_button',
            tooltip: 'Delete permanently from your library',
        });

        this.actions['EMPTY']= new Ext.Action({
            text: 'Empty Trash',
            handler: function(){
                this.allSelected=true;
                this.deleteEntry(0);
                this.allSelected=false;
            },
            scope: this,
            cls: 'x-btn-text-icon clean',
            disabled:false,
            itemId:'empty_button',
            tooltip: 'Delete all references from Trash',
        });


        var tbar=this.getTopToolbar();

        tbar.splice(3,0, this.actions['EMPTY'], this.actions['DELETE'] );
        

    },






});
