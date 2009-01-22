
PaperPile.PubSummary = Ext.extend(Ext.Panel, {
	  tplMarkup: [
		    '<div class="pp-basic"> {abstract}<br/></div>',
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
		    PaperPile.PubSummary.superclass.initComponent.call(this);
	  },
	  updateDetail: function(data) {
		    this.tpl.overwrite(this.body, data);		
	  }
});

Ext.reg('pubsummary', PaperPile.PubSummary);

