PaperPile.PubEdit = Ext.extend(Ext.FormPanel, {
	  
    initComponent: function() {

    	  Ext.apply(this, {
			      bodyStyle: {
				        background: '#ffffff',
				        padding: '7px'
			      },
            bbar: [{ text: 'Save',
                     id: 'edit_save_button',
                   },
                   { text: 'Cancel',
                     id: 'edit_cancel_button',
                   }
                  ],
            
            labelWidth: 75,
            width: 350,
            defaults: {width: 230},
            defaultType: 'textfield',
            items:{id:'dummy'}, // one field is always needed
		    });
		    PaperPile.PubEdit.superclass.initComponent.call(this);

        
        Ext.Ajax.request({
            url: '/ajax/generate_edit_form',
            params: { pubtype: 'journal',
                    },
            method: 'GET',
            success: this.setForm,
            //failure: this.markInvalid,
        });


	  },
    updateDetail: function(data) {
        //this.getForm().loadRecord(data);

        /*this.getForm().findField('title').setValue(data.title);
        this.getForm().findField('pubtype').setValue(data.pubtype);
        this.getForm().findField('journal_id').setValue(data.journal_id);
        this.getForm().findField('year').setValue(data.year);
        this.getForm().findField('pages').setValue(data.pages);
        this.getForm().findField('authors_flat').setValue(data.authors_flat);
        */

	  },

    setForm: function(response,options){
        var json = Ext.util.JSON.decode(response.responseText);

        Ext.getCmp('pub_edit').remove('dummy');

        for(var i=0; i<json.form.length; i++){
            Ext.getCmp('pub_edit').add( new Ext.form.Field(json.form[i]));
        }
        Ext.getCmp('pub_edit').doLayout();

        var data=Ext.getCmp('pub_edit').data;

        Ext.getCmp('pub_edit').getForm().loadRecord(data);


    }


});

Ext.reg('pubedit', PaperPile.PubEdit);
