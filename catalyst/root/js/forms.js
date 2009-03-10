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
            buttons: [{ text:'Save',
                        handler: function(){
                            this.getForm().submit({
                                url:'/ajax/forms/settings',
                                params: {action:'SUBMIT'},
                                success: function(){
                                    Ext.getCmp('statusbar').clearStatus();
                                    Ext.getCmp('statusbar').setText('Saved settings.');
                                    this.findParentByType(PaperPile.Settings).close();
                                },
                                scope:this,
                                failure: function(){
                                    alert('nope')
                                },
                            })
                        },
                        scope: this
                      },
                      {text:'Cancel',
                       handler: function(){
                           this.findParentByType(PaperPile.Settings).close();
                       },
                       scope:this
                      },
                     ]
        });
		
        PaperPile.Forms.Settings.superclass.initComponent.call(this);
        
        this.load({
            url:'/ajax/forms/settings',
            params: {action:'LOAD'},
            success: function(){
                console.log(PaperPile.Main.globalSettings);
            },
            failure: function(){alert('nope')},
        });
      
    }
});
        