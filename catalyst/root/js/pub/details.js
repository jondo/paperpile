Paperpile.PubDetails = Ext.extend(Ext.Panel, {
	  
    markup: [
        '<div id=main-container-{id}>',
        '<div class="pp-box pp-box-top pp-box-style2"',
        '<dl>',
        '<tpl if="citekey"><dt>Key: </dt><dd>[{citekey}]</dd></tpl>',
        '<dt>Type: </dt><dd>{pubtype}</dd>',
        '<tpl for="fields">',
        '<dt>{label}:</dt><dd>{value}</dd>',        
        '</tpl>',
        '</dl>',
        '</div>',
        '</div>'
    ],

    initComponent: function() {
		this.tpl = new Ext.XTemplate(this.markup);
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
		});
		
        Paperpile.PubDetails.superclass.initComponent.call(this);

	},
	

    //
    // Redraws the HTML template panel with new data from the grid
    //
    
    updateDetail: function() {

        if (!this.grid){
            this.grid=this.findParentByType(Ext.PubView).items.get('center_panel').items.get('grid');
        }

        sm=this.grid.getSelectionModel();

        var numSelected=sm.getCount();
        if (this.grid.allSelected){
            numSelected=this.grid.store.getTotalCount();
        }

        if (numSelected==1){

            this.data=sm.getSelected().data;

            var currFields=Paperpile.main.globalSettings.pub_types[this.data.pubtype];
     
            var allFields=['title', 'authors','booktitle','series','editors',
                           'howpublished','school','journal', 'chapter', 'edition', 
                           'volume', 'issue', 'pages', 'year', 'month', 'day', 
                           'publisher', 'organization','address', 'issn', 'isbn', 
                           'pmid', 'doi', 'url','note'];

            var list=[];

            for (i=0;i<allFields.length;i++){
                if (currFields.fields[allFields[i]]){
                    var value=this.data[allFields[i]];
                    if (!value) value='&nbsp';
                
                    list.push({label: currFields.fields[allFields[i]].label,
                               value: value
                              });
                }
            }

            this.tpl.overwrite(this.body, {pubtype: currFields.name, citekey: this.data.citekey, fields:list}, true);
        } else {

            var empty = new Ext.Template('');
            empty.overwrite(this.body);

        }

   	},
});

Ext.reg('pubdetails', Paperpile.PubDetails);