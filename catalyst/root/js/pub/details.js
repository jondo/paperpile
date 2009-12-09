Paperpile.PubDetails = Ext.extend(Ext.Panel, {

  itemId: 'details',
	  
    markup: [
        '<div id=main-container-{id}>',
        '<div class="pp-box pp-box-top pp-box-style2"',
        '<dl>',
        '<tpl if="citekey"><dt>Key: </dt><dd>{citekey}</dd></tpl>',
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
            this.grid=this.findParentByType(Paperpile.PluginPanel).items.get('center_panel').items.get('grid');
        }

        sm=this.grid.getSelectionModel();

        var numSelected=sm.getCount();
        if (this.grid.allSelected){
            numSelected=this.grid.store.getTotalCount();
        }

        if (numSelected==1){

            this.data=sm.getSelected().data;

            // Don't show details if we have only partial information that lacks pubtype
            if (this.data.pubtype){

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
            }
        } else {

            var empty = new Ext.Template('');
            empty.overwrite(this.body);

        }

   	},

    showEmpty: function(tpl){
        var empty = new Ext.Template(tpl);
        empty.overwrite(this.body);
    }


});

Ext.reg('pubdetails', Paperpile.PubDetails);

/*

javascript:u=location.href;
a=false;
x=window;
e=x.encodeURIComponent;
d=document;
if((s=d.selection)?t=s.createRange().text:t=x.getSelection()+'')
(r=/(doi:)?\s?(10\.\d{4}\/\S+)/.exec(t))?u='http://dx.doi.org/'+r[2]:a=true;a?alert('Please%20highlight%20a%20full%20DOI,%20or%20deselect%20text%20to%20add%20this%20page.'):w=open('http://www.connotea.org/addpopup?continue=confirm&uri='+e(u)+'&title='+e(d.title),'add','width=720,height=755,scrollbars,resizable');
void(x.setTimeout('w.focus()',200));

javascript:location.href='http://localhost:3000/url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)



*/