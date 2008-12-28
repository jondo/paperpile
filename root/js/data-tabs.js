PaperPile.DataTabs = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            itemId: 'data_tabs',
            layout:'card',
            margins: '2 2 2 2',
            items:[{xtype:'pubsummary',
                    itemId:'pubsummary',
                    border: true,
                    height:200
                   },
                   {xtype:'pubnotes',
                    itemId:'pubnotes',
                    border: true,
                    height:200
                   },
                  ],
            bbar: [{ text: 'Summary',
                     id: 'summary_tab_button',
                     enableToggle: true,
                     toggleHandler: this.onItemToggle,
                     toggleGroup: 'tab_buttons',
                     allowDepress : false,
                     pressed: true
                   },
                   { text: 'Notes',
                     id: 'notes_tab_button',
                     enableToggle: true,
                     toggleHandler: this.onItemToggle,
                     toggleGroup: 'tab_buttons',
                     allowDepress : false,
                     pressed: false
                   }
                  ]
        });
       
        PaperPile.DataTabs.superclass.initComponent.apply(this, arguments);
    },

    onItemToggle:function (button, pressed){

        if (button.id == 'summary_tab_button' && pressed){
            Ext.getCmp('data_tabs').layout.setActiveItem('pubsummary');
        }

        if (button.id == 'notes_tab_button' && pressed){
            Ext.getCmp('data_tabs').layout.setActiveItem('pubnotes');
        }
        
    }
    
    
}                                 
 
);

Ext.reg('datatabs', PaperPile.DataTabs);