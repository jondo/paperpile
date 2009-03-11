PaperPile.PubView = Ext.extend(Ext.Panel, {

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            iconCls: 'pp-icon-page',
            items:[
                { region:'east',
                  id: 'canvas_panel',
                  activeItem:0,
                  layout: 'card',
                  items: [
                      new PaperPile.PDFmanager(
                          {id:'pdf_manager',
                           itemId:'pdf_manager',
                          }
                      ),
                      new PaperPile.PDFviewer(
                          {id:'pdf_viewer',
                           itemId:'pdf_viewer',
                          }
                      )
                  ],
                  bbar: [{ text: 'Manage PDF',
                           id: 'pdf_manager_tab_button',
                           enableToggle: true,
                           toggleHandler: this.onPDFtabToggle,
                           toggleGroup: 'pdf_tab_buttons',
                           scope: this,
                           allowDepress : false,
                           pressed: true
                         },
                           { text: 'View PDF',
                             id: 'pdf_view_tab_button',
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
                  itemId: 'center',
                  layout: 'border',
                  items:[
                      this.grid,
                      {border: false,
                       xtype: 'datatabs',
                       id: 'data_tabs',
                       activeItem:0,
                       height:200,
                       region:'south'
                      },
                  ]
                }
            ],
        });
       
        PaperPile.PubView.superclass.initComponent.apply(this, arguments);

    }});
