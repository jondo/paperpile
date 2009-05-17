Paperpile.PdfExtractControl = Ext.extend(Ext.Panel, {
	
    markup: [
        '<div class="pp-box pp-box-yellow"',
        '<p>Inhere {number}</p>',
        '</div>',
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
		
        Paperpile.PDFmanager.superclass.initComponent.call(this);
	},


    showControls: function(data){

        this.grid=this.ownerCt.items.get('west_panel').items.get('grid');

        console.log(this.grid);

        console.log(this.tpl);

        var tpl= new Ext.XTemplate(this.markup);

        this.tpl.overwrite(this.body, {number: 10});
    },


    importPDF: function(){

        var sm = this.grid.getSelectionModel();
        var file_name = sm.getSelected().get('file_name');

        var row=this.grid.store.indexOfId(file_name);

        Ext.DomHelper.overwrite(this.grid.getView().getCell(row, 4), 'Loading');
        
        //return;

        Ext.Ajax.request({
            url: '/ajax/pdfextract/import',
            params: { root: this.grid.root,
                      grid_id: this.grid.id,
                      file_name: file_name,
                    },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                var record=this.grid.store.getAt(row);
                record.beginEdit();
                for ( var i in json.data){
                    record.set(i,json.data[i]);
                }
                record.endEdit();
            },
            scope:this,
            timeout: 600000,
        });
    },
    


	
});