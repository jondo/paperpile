Paperpile.DataTabs = Ext.extend(Ext.Panel, {

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
            bbar: [{ text: 'Abstract',
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
                     itemId: 'save_notes_button',
                     cls: 'x-btn-text-icon save',
                     listeners: {
                         click:  { 
                             fn: function(){
                                 this.findByType(Paperpile.PubNotes)[0].onSave();
                             },
                             scope: this
                         }
                     },

                     hidden:true
                   },
                   { text: 'Cancel',
                     itemId: 'cancel_notes_button',
                     cls: 'x-btn-text-icon cancel',
                     listeners: {
                         click:  { 
                             fn: function(){
                                 this.findByType(Paperpile.PubNotes)[0].onCancel();
                             },
                             scope: this
                         },
                     },
                     hidden:true
                   },
                  ]}
                 );
       
        Paperpile.DataTabs.superclass.initComponent.apply(this, arguments);
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

Ext.reg('datatabs', Paperpile.DataTabs);