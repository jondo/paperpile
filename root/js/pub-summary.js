
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



        this.form = new Ext.form.FormPanel({
            autoHeight: true,
            hideLabels: true,
            baseCls: 'x-plain',
			      items: [
                new PaperPile.BoxSelect({
                    id: 'tag_select',
			              name: 'to[]',
                    value:this.data.tags,
                    store: store,
                    emptyMsg: '[Add Tags]',
                    anchor:'90%',
			              mode: 'local',
			              displayField: 'tag',
			              valueField: 'tag',
			              addUniqueValues: false,
                    listeners: {
                        modified:  {fn: 
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
      
    },

    updateTags: function(){

        Ext.getCmp('tag_save_button').hide();

        Ext.Ajax.request({
            url: '/ajax/crud/update_tags',
            params: { rowid: this.data._rowid,
                      tags: Ext.getCmp('tag_select').getValue()
                    },
            method: 'GET',
            success: function(){
                //this.data.tags=Ext.getCmp('tag_select').store.reload();
                this.data.tags=Ext.getCmp('tag_select').getValue();
                Ext.StoreMgr.lookup('tag_store').reload();
                Ext.getCmp('treepanel').getNodeById('tags').reload();
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Updated tags.');
            },
            scope: this,

           
            //failure: this.markInvalid,
        });

    }


});

Ext.reg('pubsummary', PaperPile.PubSummary);

