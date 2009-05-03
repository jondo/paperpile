Paperpile.PdfExtractView = Ext.extend(Ext.Panel, {

    closable: true,

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            items:[
                { xtype:'panel',
                  region:'west',
                  split: true,
                  itemId: 'west_panel',
                  layout: 'border',
                  width: 720,
                  minSize:720,
                  items:[
                      new Paperpile.PdfExtractGrid(),
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
                { region:'center',
                  itemId: 'center_panel',
                  xtype: 'panel',
                },
               
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
