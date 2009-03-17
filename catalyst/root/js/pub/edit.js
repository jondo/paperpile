Paperpile.Forms.PubEdit = Ext.extend(Paperpile.Forms, {
	  
    initComponent: function() {

    	Ext.apply(this, {
			itemId:'pub_edit',
            defaultType: 'textfield',
            labelWidth: 75,
            //width: 350,
            defaults: {width: 230},
            bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            
            items:[
                {xtype:'combo',
                 editable:false,
                 forceSelection:true,
                 triggerAction: 'all',
                 //name:'pubtype',
                 disableKeyFilter: true,
                 fieldLabel:'Type',
                 mode: 'local',
                 minListWidth:230,
                 store:[['ARTICLE','Journal Article'],['BOOK','Book']],
                 hiddenName: 'pubtype'
                },
                {name:'title', fieldLabel:'Title'},
                {name:'authors', fieldLabel:'Authors'},
                {name:'booktitle', fieldLabel:'Book title'},
                {name:'series', fieldLabel:'Series'},
                {name:'editors', fieldLabel:'Editors'},
                {name:'journal', fieldLabel:'Journal'},
                {name:'chapter', fieldLabel:'Chapter'},
                {name:'volume', fieldLabel:'Volume'},
                {name:'number', fieldLabel:'Number'},
                {name:'issue', fieldLabel:'Issue'},
                {name:'edition', fieldLabel:'Edition'},
                {name:'pages', fieldLabel:'Pages'},
                {name:'publisher', fieldLabel:'Publisher'},
                {name:'school', fieldLabel:'University'},
                {name:'city', fieldLabel:'City'},
                {name:'address', fieldLabel:'Address'},
                {name:'year', fieldLabel:'Year'},
                {name:'month', fieldLabel:'Month'},
                {name:'day', fieldLabel:'Day'},
                {name:'issn', fieldLabel:'ISSN'},
                {name:'isbn', fieldLabel:'ISBN'},
                {name:'pmid', fieldLabel:'Pubmed ID'},
                {name:'abstract', fieldLabel:'Abstract'},
            ],

            bbar:[{xtype:'tbfill'},
                  new Ext.Button({
                      id: 'edit_save_button',
                      text: 'Save',
                      cls: 'x-btn-text-icon save',
                      listeners: {
                          click:  {fn: this.save, scope: this}
                      },
                  }),
                  new Ext.Button({
                      id: 'edit_cancel_button',
                      text: 'Cancel',
                      cls: 'x-btn-text-icon cancel',
                      listeners: {
                          click:  {fn: this.cancel, scope: this}
                      },
                  }),
                 ],
		});
		
        Paperpile.Forms.PubEdit.superclass.initComponent.call(this);
        
        this.setValues(this.data.data);
              
	  },

    setValues : function(values){
        for (var i = 0, items = this.items.items, len = items.length; i < len; i++) {
            var field = items[i];
            console.log(field);
            var v = values[field.id] || values[field.hiddenName || field.name];
            if (typeof v !== 'undefined') {
                console.log(v);
                field.setValue(v)
                if(this.trackResetOnLoad){
                    field.originalValue = field.getValue();
                }
            }
        }
    },
    

    afterRender: function(){
        Paperpile.Forms.PubEdit.superclass.afterRender.apply(this, arguments);
        //this.getForm().loadRecord(this.data.data);
        //this.setValues(this.data.data);

    },


     save: function(){
        // Masks form instead of whole window, should set to dedicated
        // notification area later
        this.getForm().waitMsgTarget='pub_edit';

        this.getForm().submit(
            {   url:'/ajax/crud/update_entry',
                scope:this,
                success:this.onSuccess,
                params:{rowid:this.data.get('rowid'),
                        sha1:this.data.get('sha1'),
                        source_id: this.source_id,
                       },
                waitMsg:'Saving...',
            }
        );
    },

    cancel: function(){
        this.close();
    },

    onSuccess: function(form,action){
        this.close();
    },

    close: function(){
        
        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');

        east_panel.remove('pub_edit');
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pdf_manager');
        east_panel.showBbar();
        

    }
    

});

