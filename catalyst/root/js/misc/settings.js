Paperpile.Settings = Ext.extend(Ext.Window, {
	  
    initComponent: function() {

		var form=new Paperpile.Forms.Settings();

        Ext.apply(this, {
            layout: 'fit',
            width: 500,
            height: 300,
            closeAction:'hide',
            plain: true,
            items: [form],
		});
		Paperpile.Settings.superclass.initComponent.call(this);
        
    },

});

