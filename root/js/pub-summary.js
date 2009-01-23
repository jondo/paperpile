
PaperPile.PubSummary = Ext.extend(Ext.Panel, {
	  tplMarkup: [
        '<div class="pp-summary-form" id="tags"></div>',
		    '<div class="pp-summary-abstract">{abstract}</div>',
	  ],
	  startingMarkup: 'Empty',
	  
    initComponent: function() {
		    this.tpl = new Ext.Template(this.tplMarkup);
		    Ext.apply(this, {
			      bodyStyle: {
				        background: '#ffffff',
				        padding: '7px'
			      },
            autoScroll: true,
			      html: this.startingMarkup
		    });
		    PaperPile.PubSummary.superclass.initComponent.call(this);
        
	  },

	  updateDetail: function(data) {

        this.data=data;
		    this.tpl.overwrite(this.body, data);		

        this.form = new Ext.form.FormPanel({
            autoHeight: true,
            hideLabels: true,
            baseCls: 'x-plain',
			      items: [new PaperPile.BoxSelect({
                        id: 'tag_select',
			                  name: 'to[]',
                 	      store: Ext.StoreMgr.lookup('tag_store'),
                        anchor:'90%',
			                  mode: 'local',
			                  displayField: 'tag',
			                  valueField: 'tag',
			                  addUniqueValues: false,
                        listeners: {
                            focus:  {fn: 
                                     function(){
                                         Ext.getCmp('tag_save_button').show();
                                     },
                                     scope: this}
                        },
                    }),
                    new Ext.Button({
                        id: 'tag_save_button',
                        text: 'Ok',
                        hidden:true,
                        listeners: {
                            click:  {fn: this.updateTags, scope: this}
                        },
                        
                    }),
                    
                   ],
		    });

        this.form.render('tags');
        Ext.getCmp('tag_select').setValue(this.data.tags);

        //Ext.dump(Ext.getCmp('tag_select').store);

      
    },

    updateTags: function(){

        Ext.Ajax.request({
            url: '/ajax/crud/update_tags',
            params: { rowid: this.data._rowid,
                      tags: Ext.getCmp('tag_select').getValue()
                    },
            method: 'GET',
            success: function(){
                //this.data.tags=Ext.getCmp('tag_select').store.reload();
                this.data.tags=Ext.getCmp('tag_select').getValue();
                Ext.StoreMgr.lookup('tag_store').load({
                    callback: function(r){
                    }
                }
                );
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Updated tags.');
            },
            scope: this,

           
            //failure: this.markInvalid,
        });

    }


});

Ext.reg('pubsummary', PaperPile.PubSummary);

