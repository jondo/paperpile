PaperPile.DataTabs = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            itemId: 'data_tabs',
            layout:'card',
            margins: '2 2 2 2',
            items:[{xtype:'pubsummary',
                    itemId:'pubsummary',
                    border: 0,
                    height:200
                   },
                   {xtype:'pubnotes',
                    itemId:'pubnotes',
                    border: 0,
                    height:200
                   }
                  ],
            bbar: [{ text: 'Summary',
                     itemId: 'summary_tab_button',
                     enableToggle: true,
                     toggleHandler: this.onItemToggle,
                     toggleGroup: 'tab_buttons',
                     scope: this,
                     allowDepress : false,
                     pressed: true
                   },
                   { text: 'Notes',
                     itemId: 'notes_tab_button',
                     enableToggle: true,
                     toggleHandler: this.onItemToggle,
                     toggleGroup: 'tab_buttons',
                     scope: this,
                     allowDepress : false,
                     pressed: false
                   },
                   {xtype:'tbfill'},
                   { text: 'Save',
                     id: 'save_notes_button',
                     cls: 'x-btn-text-icon save',
                     listeners: {
                         click:  { fn: function()
                                   {
                                       Ext.getCmp('pubnotes').onSave();
                                   },
                                   scope: Ext.getCmp('pubnotes')}
                     },

                     hidden:true
                   },
                   { text: 'Cancel',
                     id: 'cancel_notes_button',
                     cls: 'x-btn-text-icon cancel',
                     listeners: {
                         click:  { fn: function()
                                   {
                                       Ext.getCmp('pubnotes').onCancel();
                                   },
                                   scope: Ext.getCmp('pubnotes')}
                     },
                     hidden:true
                   },

                  ]
        });
       
        PaperPile.DataTabs.superclass.initComponent.apply(this, arguments);
    },

    onItemToggle:function (button, pressed){

        if (button.itemId == 'summary_tab_button' && pressed){
            this.layout.setActiveItem('pubsummary');
        }

        if (button.itemId == 'notes_tab_button' && pressed){
            this.layout.setActiveItem('pubnotes');
        }

    }
    
}                                 
 
);

Ext.reg('datatabs', PaperPile.DataTabs);