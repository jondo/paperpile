PaperPile.PubEdit = Ext.extend(Ext.FormPanel, {
	  
    initComponent: function() {
		    Ext.apply(this, {
			      bodyStyle: {
				        background: '#ffffff',
				        padding: '7px'
			      },
            labelWidth: 75,
            width: 350,
            defaults: {width: 230},
            defaultType: 'textfield',
            items: [{
                fieldLabel: 'Type',
                name: 'pubtype',
            },{
                fieldLabel: 'Title',
                name: 'title',
            },{
                fieldLabel: 'Journal',
                name: 'journal_id',
            },{
                fieldLabel: 'Year',
                name: 'year',
            },{
                fieldLabel: 'Pages',
                name: 'pages',
            },{
                fieldLabel: 'Authors',
                name: 'authors_flat'
            }]
                    
		    });
		    PaperPile.PubEdit.superclass.initComponent.call(this);

	  },
    updateDetail: function(data) {
        //this.getForm().loadRecord(data);

        this.getForm().findField('title').setValue(data.title);
        this.getForm().findField('pubtype').setValue(data.pubtype);
        this.getForm().findField('journal_id').setValue(data.journal_id);
        this.getForm().findField('year').setValue(data.year);
        this.getForm().findField('pages').setValue(data.pages);
        this.getForm().findField('authors_flat').setValue(data.authors_flat);
        

	  }

});

Ext.reg('pubedit', PaperPile.PubEdit);
