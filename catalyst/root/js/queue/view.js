Paperpile.QueueView = Ext.extend(Ext.Panel, {

    closable: true,

    initComponent:function() {
        
        Ext.apply(this, {
            layout:'border',
            hideBorders:true,
            items:[
                new Paperpile.QueueGrid(
                    { itemId:'grid',
                      border: false,
                      region: 'center',
                      split: true,
                    }),
                { region:'east',
                  itemId: 'east_panel',
                  split: true,
                  width: 300,
                  activeItem:0,
                      layout: 'card',
                  items: [
                      new Paperpile.QueueControl({region:'center',
                                                  itemId: 'control_panel'}
                                                ),
                  ],
                }
            ],
        });
       
        Paperpile.QueueView.superclass.initComponent.apply(this, arguments);
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
