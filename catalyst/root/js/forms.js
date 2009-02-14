PaperPile.Forms = Ext.extend(Ext.FormPanel, {

    initComponent: function() {
		Ext.apply(this, {
            method: 'GET',
            bodyStyle:'padding:5px 5px 0',
            defaultType: 'textfield',
        });
		PaperPile.Forms.superclass.initComponent.call(this);
    }});


PaperPile.Forms.Settings = Ext.extend(PaperPile.Forms, {

    initComponent: function() {
		Ext.apply(this, {
            labelWidth: 150,
            url:'/ajax/forms/settings',
            items:[
                { name:'user_db',
                  fieldLabel:"Paperpile database",
                },
                { name:"paper_root",
                  fieldLabel:"PDF folder",
                  xtype:"textfield"
                },
                { name:"paper_pattern",
                  fieldLabel:"PDF file name pattern",
                  xtype:"textfield"
                }
            ],
            buttons: [{text:'Save'},
                      {text:'Cancel'},
                     ]
        });
		
        PaperPile.Forms.Settings.superclass.initComponent.call(this);

        this.load({
            url:'/ajax/forms/settings',
            success: function(){alert('yes')},
            failure: function(){alert('nope')},
        });

      
    }

});
        