
PaperPile.PubSummary = Ext.extend(Ext.Panel, {
	  tplMarkup: [
		    'Abstract: {abstract}<br/>',
	  ],
	  startingMarkup: 'Empty',
	  
    initComponent: function() {
		    this.tpl = new Ext.Template(this.tplMarkup);
		    Ext.apply(this, {
			      bodyStyle: {
				        background: '#ffffff',
				        padding: '7px'
			      },
			      html: this.startingMarkup
		    });
		    PaperPile.PubSummary.superclass.initComponent.call(this);
	  },
	  updateDetail: function(data) {
		    this.tpl.overwrite(this.body, data);		
	  }
});

Ext.reg('pubsummary', PaperPile.PubSummary);

