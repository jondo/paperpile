Paperpile.PubView = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            hideBorders:true,
            items:[
                { xtype:'panel',
                  region:'center',
                  itemId: 'center_panel',
                  layout: 'border',
                  items:[
                      this.grid,
                      {border: false,
                       split: true,
                       xtype: 'datatabs',
                       itemId: 'data_tabs',
                       activeItem:0,
                       height:200,
                       region:'south',
                       collapsible:true,
                       animCollapse:false
                      },
                  ]
                 },
                { region:'east',
                  itemId: 'east_panel',
                  activeItem:0,
                  split: true,
                  layout: 'card',
                  width:300,
                  items: [
                      new Paperpile.PDFmanager(
                          {itemId:'overview',
                          }
                      ),
                      new Paperpile.PubDetails(
                          {itemId:'details',
                          }
                      )
                  ],
                  bbar: [{ text: 'Overview',
                           itemId: 'overview_tab_button',
                           enableToggle: true,
                           toggleHandler: this.onControlToggle,
                           toggleGroup: 'control_tab_buttons',
                           scope: this,
                           allowDepress : false,
                           pressed: true
                         },
                         { text: 'Details',
                           itemId: 'details_tab_button',
                           enableToggle: true,
                           toggleHandler: this.onControlToggle,
                           toggleGroup: 'control_tab_buttons',
                           scope: this,
                           allowDepress : false,
                           pressed: false
                         }
                        ],
                },
               
            ],
        });
       
        Paperpile.PubView.superclass.initComponent.apply(this, arguments);

    },

    onControlToggle:function (button, pressed){

        if (button.itemId == 'overview_tab_button' && pressed){
            this.items.get('east_panel').getLayout().setActiveItem('overview');
        }

        if (button.itemId == 'details_tab_button' && pressed){
            this.items.get('east_panel').getLayout().setActiveItem('details');
        }

    },
    

    onRowSelect: function() {

        var datatabs=this.items.get('center_panel').items.get('data_tabs');

        datatabs.items.get('pubsummary').updateDetail();
        datatabs.items.get('pubnotes').updateDetail();        
        this.items.get('east_panel').items.get('overview').updateDetail();
        this.items.get('east_panel').items.get('details').updateDetail();
    },

    



});
