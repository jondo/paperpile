Paperpile.PubView = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            items:[
                { xtype:'panel',
                  region:'west',
                  split: true,
                  itemId: 'center_panel',
                  layout: 'border',
                  width: 720,
                  minSize:720,
                  items:[
                      this.grid,
                      {border: false,
                       split: true,
                       xtype: 'datatabs',
                       itemId: 'data_tabs',
                       activeItem:0,
                       height:200,
                       region:'south'
                      },
                  ]
                 },
                { region:'center',
                  itemId: 'east_panel',
                  activeItem:0,
                  layout: 'card',
                  items: [
                      new Paperpile.PDFmanager(
                          {itemId:'pdf_manager',
                          }
                      ),
                      new Paperpile.PDFviewer(
                          {itemId:'pdf_viewer',
                          }
                      )
                  ],
                  bbar: [{ text: 'Manage PDF',
                           itemId: 'pdf_manager_tab_button',
                           enableToggle: true,
                           toggleHandler: this.onPDFtabToggle,
                           toggleGroup: 'pdf_tab_buttons',
                           scope: this,
                           allowDepress : false,
                           pressed: true
                         },
                           { text: 'View PDF',
                             itemId: 'pdf_view_tab_button',
                             enableToggle: true,
                             toggleHandler: this.onPDFtabToggle,
                             toggleGroup: 'pdf_tab_buttons',
                             disabled:true,
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


    onRowSelect: function(sm, rowIdx, r) {

        Ext.getCmp('statusbar').clearStatus();
        Ext.getCmp('statusbar').setText(r.data.sha1);

        var datatabs=this.items.get('center_panel').items.get('data_tabs');

        datatabs.items.get('pubsummary').updateDetail(r.data);
        datatabs.items.get('pubnotes').updateDetail(r.data);        

        this.items.get('east_panel').items.get('pdf_manager').updateDetail(this.grid);
    },

});
