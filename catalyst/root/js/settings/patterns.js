Paperpile.PatternSettings = Ext.extend(Ext.Panel, {

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoLoad:{url:'/screens/patterns',
                      callback: this.insertFields,
                      scope:this
                     },
            //bodyStyle:'padding:5px 5px 0',
            bodyStyle:'pp-settings',
            
            bbar: [{xtype:'tbfill'},
                   { text:'Save',
                     cls: 'x-btn-text-icon save',
                     handler: function(){
                     },
                     scope: this
                   },
                   {text:'Cancel',
                    cls: 'x-btn-text-icon cancel',
                    handler: function(){
                    },
                    scope:this
                   },
                  ]
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

        
    },

    insertFields: function(){

        Ext.each(['user_db','paper_root','key_pattern','pdf_pattern','attachment_pattern'], 
                 function(item){
                     new Ext.form.TextField({value:main.globalSettings[item], 
                                             renderTo:item+'_textfield',
                                             width: 300,
                                            });
                 });

    }





});

