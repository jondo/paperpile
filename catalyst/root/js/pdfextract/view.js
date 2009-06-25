Paperpile.PdfExtractView = Ext.extend(Ext.Panel, {

    closable: true,

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            hideBorders:true,
            items:[
                { xtype:'panel',
                  region:'center',
                  split: true,
                  itemId: 'center_panel',
                  layout: 'border',
                  items:[
                      new Paperpile.PdfExtractGrid({itemId:'grid', path: this.path}),
                      {border: false,
                       split: true,
                       xtype: 'panel',
                       itemId: 'pdf_viewer',
                       activeItem:0,
                       height:200,
                       region:'south'
                      },
                  ]
                 },
                { region:'east',
                  itemId: 'east_panel',
                  split: true,
                  width: 300,
                  activeItem:0,
                  layout: 'card',
                  items: [
                      new Paperpile.PdfExtractControl({region:'center',
                                                       itemId: 'control_panel'}
                                                     ),
                  ],
                }
            ],
        });
       
        Paperpile.PdfExtractView.superclass.initComponent.apply(this, arguments);
    },

    onRowSelect: function(sm, rowIdx, r) {

        /*

        Ext.getCmp('statusbar').clearStatus();
        Ext.getCmp('statusbar').setText(r.data.sha1);

        var datatabs=this.items.get('center_panel').items.get('data_tabs');

        datatabs.items.get('pubsummary').updateDetail(r.data);
        datatabs.items.get('pubnotes').updateDetail(r.data);        

        this.items.get('east_panel').items.get('pdf_manager').updateDetail(r.data);

*/        


    },

});
