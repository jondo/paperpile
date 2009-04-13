Paperpile.ExportBibfile = Ext.extend(Ext.FormPanel, {

    initComponent: function() {
		Ext.apply(this, {
            labelWidth: 150,
            url:'/ajax/forms/settings',
            defaultType: 'textfield',
            items:[
                { name:'user_db',
                  fieldLabel:"Paperpile database",
                },
                { name:"paper_root",
                  fieldLabel:"PDF folder",
                  xtype:"textfield"
                },
                { name:"key_pattern",
                  fieldLabel:"Citation key pattern",
                  xtype:"textfield"
                },
                { name:"pdf_pattern",
                  fieldLabel:"PDF file name pattern",
                  xtype:"textfield"
                },
                { name:"attachment_pattern",
                  fieldLabel:"Supplementary files directory",
                  xtype:"textfield"
                },
            ],
        });
		
        Paperpile.ExportBibfile.superclass.initComponent.call(this);
        
        
    }
});

Ext.reg('export-bibfile', Paperpile.ExportBibfile);

