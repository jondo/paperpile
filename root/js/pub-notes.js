
PaperPile.PubNotes = Ext.extend(Ext.Panel, {
	  tplMarkup: [
		    '<p>Notes: {abstract}</p>',
	  ],
	  startingMarkup: 'Empty',
	  
    initComponent: function() {
		    this.tpl = new Ext.Template(this.tplMarkup);
		    Ext.apply(this, {
			      bodyStyle: {
				        background: '#ffffff',
				        padding: '7px'
			      },
            autoScroll: true,
			      html: this.startingMarkup
		    });
		    PaperPile.PubNotes.superclass.initComponent.call(this);
	  },
	  updateDetail: function(data) {
		    this.tpl.overwrite(this.body, data);		
	  }
});

Ext.reg('pubnotes', PaperPile.PubNotes);

