PaperPile.PDFmanager = Ext.extend(Ext.Panel, {
	  tplMarkup: [
		    '<p>Notes: {abstract}</p>',
	  ],
	  startingMarkup: 'Empty2',
	  
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
		    PaperPile.PDFmanager.superclass.initComponent.call(this);
	  },
	  
    updateDetail: function(data) {
        this.data=data;
		    this.tpl.overwrite(this.body, data);
	  }
});

Ext.reg('pdfmanager', PaperPile.PDFmanager);