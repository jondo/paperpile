PaperPile.PubView = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            items:[
                { region:'east',
                  itemId: 'east_panel',
                  activeItem:0,
                  layout: 'card',
                  items: [
                      new PaperPile.PDFmanager(
                          {itemId:'pdf_manager',
                          }
                      ),
                      new PaperPile.PDFviewer(
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
                             scope: this,
                             allowDepress : false,
                             pressed: false
                           }
                        ],

                  margins: '2 2 2 2',
                  cmargins: '5 5 0 5',
                  width: 500,
                  minSize: 100,
                  maxSize: 800,
                },
                { xtype:'panel',
                  region:'center',
                  itemId: 'center_panel',
                  layout: 'border',
                  
                  items:[
                      this.grid,
                      {border: false,
                       xtype: 'datatabs',
                       itemId: 'data_tabs',
                       activeItem:0,
                       height:200,
                       region:'south'
                      },
                  ]
                }
            ],
        });
       
        PaperPile.PubView.superclass.initComponent.apply(this, arguments);
    },

    onRowSelect: function(sm, rowIdx, r) {

        Ext.getCmp('statusbar').clearStatus();
        Ext.getCmp('statusbar').setText(r.data.sha1);

        var datatabs=this.items.get('center_panel').items.get('data_tabs');

        datatabs.items.get('pubsummary').updateDetail(r.data);
        datatabs.items.get('pubnotes').updateDetail(r.data);        

        this.items.get('east_panel').items.get('pdf_manager').updateDetail(r.data);
        

    },

});
