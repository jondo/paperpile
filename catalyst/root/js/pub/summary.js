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

    updateDetail: function(data, needsUpdate) {
        this.data=data;
        this.data.id=this.id;

        if (needsUpdate){
            this.needsUpdate=true;
        }

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
     
        
        // Create boxselect field if not already exists or needs to be
        // updated after a change. For efficiency reasons we create
        // this element only once an then use hide/show to toggle
        
        if (!this.boxselect || this.needsUpdate){

            if (this.boxselect){
                this.boxselect.destroy();
            }
            
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
                    modified:  {fn: this.updateTags,
                                scope: this}
                },
                renderTo:'tags-'+this.id,
            });

            this.needsUpdate=false;

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
                                     this.interactive=false;
                                     this.boxselect.setValue(this.data.tags);
                                     this.interactive=true;
                                     this.boxselect.show();
                                     this.boxselect.focus();
                                 }, this);
            }
            this.emptyMsg.show();
            this.boxselect.hide();
        } else {

            this.interactive=false;
            this.boxselect.setValue(this.data.tags);
            this.interactive=true;
            this.boxselect.show();
            if (this.emptyMsg){
                this.emptyMsg.hide();
            }
        }
    },

    updateTags: function(){
                                    
        // Only call when it is changed by
        // the user not when it is updated
        // programmatically

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

                // Update local data
                Ext.StoreMgr.lookup('tag_store').reload();
                this.data.tags=this.boxselect.getValue();
                                           
                // Ensure that boxselect
                // is initialized with new
                // tag-list next time when
                // display is updated
                this.needsUpdate=true;
                                            
                // Reload list in tree
                Paperpile.main.tree.getNodeById('TAGS_ROOT').reload();
                                            
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Updated tags.');
            },
            scope: this,
            
        });
    },



});

Ext.reg('pubsummary', Paperpile.PubSummary);

