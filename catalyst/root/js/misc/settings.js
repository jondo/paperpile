PaperPile.Settings = Ext.extend(Ext.Window, {
	  
    initComponent: function() {

		var form=new PaperPile.Forms.Settings();

        Ext.apply(this, {
            layout: 'fit',
            width: 500,
            height: 300,
            closeAction:'hide',
            plain: true,
            items: [form],
		});
		PaperPile.Settings.superclass.initComponent.call(this);
        
    },

});

