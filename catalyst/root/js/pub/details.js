Paperpile.PubDetails = Ext.extend(Ext.Panel, {
	  
    markup: [
        '<div id=main-container-{id}>',
        '<div class="pp-box pp-box-top pp-box-style2"',
        '<dl>',
        '<dt>Type: </dt><dd>{name}</dd>',
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

        this.multipleSelection=(numSelected > 1 );

        this.data=sm.getSelected().data;

        /*
        if (!this.multipleSelection){
        
            this.data.id=this.id;

            this.grid_id=this.grid.id;

            this.data._pubtype_name=Paperpile.main.globalSettings.pub_types[this.data.pubtype].name;

            this.tpl.overwrite(this.body, this.data, true);
        }
*/
        var currFields=Paperpile.main.globalSettings.pub_types[this.data.pubtype];
     
        var allFields=['title', 'authors','booktitle','series','editors',
                       'howpublished','school','journal', 'chapter', 'edition', 
                       'volume', 'issue', 'pages', 'year', 'month', 'day', 
                       'publisher', 'organization','address', 'issn', 'isbn', 
                       'pmid', 'doi', 'url'];

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

        this.tpl.overwrite(this.body, {name: currFields.name, fields:list}, true);

   	},
});

Ext.reg('pubdetails', Paperpile.PubDetails);