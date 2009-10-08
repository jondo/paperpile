Paperpile.PubView = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            tabType: 'PLUGIN',
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
                           toggleGroup: 'control_tab_buttons'+this.id,
                           scope: this,
                           allowDepress : false,
                           disabled: true,
                           pressed: false
                         },
                         { text: 'Details',
                           itemId: 'details_tab_button',
                           enableToggle: true,
                           toggleHandler: this.onControlToggle,
                           toggleGroup: 'control_tab_buttons'+this.id,
                           scope: this,
                           allowDepress : false,
                           disabled: true,
                           pressed: false
                         },'->',
                         { text: 'About',
                           itemId: 'about_tab_button',
                           enableToggle: true,
                           toggleHandler: this.onControlToggle,
                           toggleGroup: 'control_tab_buttons'+this.id,
                           scope: this,
                           disabled: true,
                           allowDepress : false,
                           pressed: false,
                           hidden:true,
                         }
                        ],
                },
               
            ],
        });


        this.on('afterLayout', 
                function(){
                    if (this.grid.sidePanel){
                        this.items.get('east_panel').items.add(this.grid.sidePanel);
                        this.items.get('east_panel').items.add(this.grid.sidePanel);
                        var button = this.items.get('east_panel').getBottomToolbar().items.get('about_tab_button');
                        button.show();
                        button.enable();
                        button.toggle(true);
                        this.items.get('east_panel').getLayout().setActiveItem('about');
                    }
                }, this);


        
        Paperpile.PubView.superclass.initComponent.apply(this, arguments);

    },

    onControlToggle:function (button, pressed){

        if (button.itemId == 'overview_tab_button' && pressed){
            this.items.get('east_panel').getLayout().setActiveItem('overview');
        }

        if (button.itemId == 'details_tab_button' && pressed){
            this.items.get('east_panel').getLayout().setActiveItem('details');
        }

        if (button.itemId == 'about_tab_button' && pressed){
            this.items.get('east_panel').getLayout().setActiveItem('about');
        }


    },
    

    onRowSelect: function() {

        var datatabs=this.items.get('center_panel').items.get('data_tabs');

        datatabs.items.get('pubsummary').updateDetail();
        datatabs.items.get('pubnotes').updateDetail();        
        this.items.get('east_panel').items.get('overview').updateDetail();
        this.items.get('east_panel').items.get('details').updateDetail();
    },

    onEmpty: function(tpl){
        this.items.get('east_panel').items.get('overview').showEmpty(tpl);
    }



});
