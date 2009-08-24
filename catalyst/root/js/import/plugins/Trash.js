Paperpile.PluginGridTrash = Ext.extend(Paperpile.PluginGridDB, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-trash',
    plugin_name:'Trash',
    
    initComponent:function() {

        Paperpile.PluginGridFile.superclass.initComponent.apply(this, arguments);

        this.actions['NEW'].hide();
        this.actions['EDIT'].hide();
        this.actions['TRASH'].hide();
        this.actions['EXPORT'].hide();
        this.actions['SAVE_AS_ACTIVE'].hide();

        this.actions['DELETE']= new Ext.Action({
            text: 'Delete',
            handler: function(){
                this.deleteEntry('DELETE');
            },
            scope: this,
            cls: 'x-btn-text-icon delete',
            disabled:true,
            itemId:'delete_button',
            tooltip: 'Delete selected references permanently from your library',
        });

        this.actions['EMPTY']= new Ext.Action({
            text: 'Empty Trash',
            handler: function(){
                this.allSelected=true;
                this.deleteEntry('DELETE');
                this.allSelected=false;
            },
            scope: this,
            cls: 'x-btn-text-icon clean',
            disabled:true,
            itemId:'empty_button',
            tooltip: 'Delete all references in Trash permanently form your library.',
        });

        this.actions['RESTORE']= new Ext.Action({
            text: 'Restore',
            handler: function(){
                this.deleteEntry('RESTORE');
            },
            scope: this,
            cls: 'x-btn-text-icon restore',
            disabled:true,
            itemId: 'restore_button',
            tooltip: 'Restore selected references from Trash',
        });


        var tbar=this.getTopToolbar();

        tbar.splice(3,0, 
                    this.actions['EMPTY'], 
                    this.actions['DELETE'],
                    this.actions['RESTORE']
                   );
        

    },

    
    updateButtons: function(){

        var imported=this.getSelection('IMPORTED').length;
        var notImported=this.getSelection('NOT_IMPORTED').length;
        var selected=imported+notImported;

        if (selected>0){
            this.actions['DELETE'].enable();
            this.actions['RESTORE'].enable();
            this.actions['VIEW_YEAR'].enable();
	        this.actions['VIEW_JOURNAL'].enable();
	        this.actions['VIEW_AUTHOR'].enable();

        } else {
            this.actions['DELETE'].disable();
            this.actions['RESTORE'].disable();
            this.actions['VIEW_YEAR'].disable();
	        this.actions['VIEW_JOURNAL'].disable();
	        this.actions['VIEW_AUTHOR'].disable();
        }

        if (selected==1){
            if (this.getSelectionModel().getSelected().data.pdf) {
	            this.actions['VIEW_PDF'].setDisabled(false);
            } else {
	            this.actions['VIEW_PDF'].setDisabled(true);
            }
        }

        if (this.store.getCount()>0){
            this.actions['EMPTY'].enable();
            this.actions['SELECT_ALL'].enable();
        } else {
            this.actions['EMPTY'].disable();
            this.actions['SELECT_ALL'].disable();
        }


    }


});
