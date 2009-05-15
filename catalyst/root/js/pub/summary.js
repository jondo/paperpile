Paperpile.PubSummary = Ext.extend(Ext.Panel, {
		  
    initComponent: function() {

        // The template for the abstract
	    this.abstractMarkup= [
            '<div class="pp-summary-abstract">{abstract}</div>',
        ];

        this.abstractTemplate = new Ext.Template(this.abstractMarkup);
	    
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
		});
		
        Paperpile.PubSummary.superclass.initComponent.call(this);
        
	},

    updateDetail: function(data, needsUpdate) {
        this.data=data;
        this.data.id=this.id;
		this.abstractTemplate.overwrite(this.body, data);		

    }

});

Ext.reg('pubsummary', Paperpile.PubSummary);

