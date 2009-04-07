Paperpile.PubSummary = Ext.extend(Ext.Panel, {
		  
    initComponent: function() {

        // The template for the abstract
	    this.abstractMarkup= [
	        '{abstract}'
        ];
        this.abstractTemplate = new Ext.Template(this.abstractMarkup);
	    
        // Overall HTML of this panel
        var html= [
            '<div class="pp-summary-form" id="tags-'+this.id+'">',
            '</div>',
		    '<div id="abstract-'+this.id+'" class="pp-summary-abstract"></div>',
        ];
        
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
			html: html
		});
		
        Paperpile.PubSummary.superclass.initComponent.call(this);
        
	},


    //
    // Main function that is called from outside to update the summary
    // panel with 'data' for the current entry
    //

    updateDetail: function(data) {
        this.data=data;
        this.data.id=this.id;

        // Update abstract
		this.abstractTemplate.overwrite(Ext.get('abstract-'+this.id), data);		

        // Get application wide store with tags and make a local 
        // copy as simple store which can be modified without
        // affecting other things. Will not scale, once we want to 
        // have a shared list of tags from many users here. Then 
        // we will need a true remote lookup

        var list=[];
        Ext.StoreMgr.lookup('tag_store').each(function(rec){
            list.push([rec.data.tag]);
		}, this);
        
        var store = new Ext.data.SimpleStore({
			fields: ['tag'],
            data: list,
		});

        // Create boxselect field if not already exists. 
        // We create this element only once an then use hide/show to toggle
        if (!this.boxselect){
            this.boxselect=new Paperpile.BoxSelect({
			    name: 'tags[]',
                value:this.data.tags,
                store: store,
			    mode: 'local',
			    displayField: 'tag',
			    valueField: 'tag',
                width: 150,
			    addUniqueValues: false,
                listeners: {
                    modified:  {fn: 
                                function(){
                                    
                                    // Only call when the user changes
                                    // it not when it is updated
                                    // programtically

                                    if (!this.interactive) {
                                        return;
                                    };
                                    
                                    Ext.Ajax.request({
                                        url: '/ajax/crud/update_tags',
                                        params: { rowid: this.data._rowid,
                                                  tags: this.boxselect.getValue(),
                                                },
                                        method: 'GET',
                                        success: function(){
                                            console.log(this.boxselect.getValue());
                                            console.log(this.data);
                                            this.data.tags=this.boxselect.getValue();
                                            Ext.StoreMgr.lookup('tag_store').reload();
                                            Paperpile.main.tree.getNodeById('TAGS_ROOT').reload();
                                            Ext.getCmp('statusbar').clearStatus();
                                            Ext.getCmp('statusbar').setText('Updated tags.');
                                        },
                                        scope: this,
                                        
                                    });
                                },
                                scope: this}
                },
                renderTo:'tags-'+this.id,
            });
        }
        
        // If no tags are given we show a link to add tags
        if (this.data.tags==''){
            
            // We create this element only once an then use hide/show to toggle
            if (!this.emptyMsg){
                this.emptyMsg=Ext.DomHelper.insertFirst(Ext.get('tags-'+this.id), '<span>[Add tags]</span>', true);
                this.emptyMsg.setVisibilityMode(Ext.Element.DISPLAY);
                this.emptyMsg.on('click', 
                                 function(){
                                     this.emptyMsg.hide();
                                     this.updateBoxselect(store);
                                     this.boxselect.show();
                                     this.boxselect.focus();
                                 }, this);
            }
            this.emptyMsg.show();
            this.boxselect.hide();
        } else {
            this.updateBoxselect(store);
            this.boxselect.show();
            if (this.emptyMsg){
                this.emptyMsg.hide();
            }
        }
    },


    //
    // Updates the selection field, 'store' is the local store of all tags that is created in UpdateDetails
    //

    updateBoxselect: function(store){

        this.interactive=false;
        this.boxselect.store=store;

        this.boxselect.setValue(this.data.tags);
        this.interactive=true;
    },

});

Ext.reg('pubsummary', Paperpile.PubSummary);

