Paperpile.Forms = Ext.extend(Ext.FormPanel, {

    initComponent: function() {
        Ext.apply(this, {
            method: 'GET',
            bodyStyle: 'padding:5px 5px 0',
            //defaultType: 'textfield',
        });
        Paperpile.Forms.superclass.initComponent.call(this);
    }
});

Paperpile.Forms.Settings = Ext.extend(Paperpile.Forms, {

    initComponent: function() {
        Ext.apply(this, {
            labelWidth: 150,
            url: Paperpile.Url('/ajax/forms/settings'),
            defaultType: 'textfield',
            items: [{
                name: 'user_db',
                fieldLabel: "Paperpile database",
            },
            {
                name: "paper_root",
                fieldLabel: "PDF folder",
                xtype: "textfield"
            },
            {
                name: "key_pattern",
                fieldLabel: "Citation key pattern",
                xtype: "textfield"
            },
            {
                name: "pdf_pattern",
                fieldLabel: "PDF file name pattern",
                xtype: "textfield"
            },
            {
                name: "attachment_pattern",
                fieldLabel: "Supplementary files directory",
                xtype: "textfield"
            },

            ],
            buttons: [{
                text: 'Save',
                handler: function() {
                    this.getForm().submit({
                        url: Paperpile.Url('/ajax/forms/settings'),
                        params: {
                            action: 'SUBMIT'
                        },
                        success: function() {
                            Ext.getCmp('statusbar').clearStatus();
                            Ext.getCmp('statusbar').setText('Saved settings.');
                            this.findParentByType(Paperpile.Settings).close();
                        },
                        scope: this,
                        failure: function() {
                            alert('nope')
                        },
                    })
                },
                scope: this
            },
            {
                text: 'Cancel',
                handler: function() {
                    this.findParentByType(Paperpile.Settings).close();
                },
                scope: this
            },
            ]
        });

        Paperpile.Forms.Settings.superclass.initComponent.call(this);

        this.load({
            url: Paperpile.Url('/ajax/forms/settings'),
            params: {
                action: 'LOAD'
            },
            success: function() {
                console.log(Paperpile.main.globalSettings);
            },
            failure: function() {
                alert('nope')
            },
        });

    }
});