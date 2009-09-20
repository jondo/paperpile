Paperpile.QueueControl = Ext.extend(Ext.Panel, {
	
    statusMsgTpl: [
        '<tpl if="number">',
        '<b>{number}</b> PDFs in the list are not yet in your library and can be automatically imported.',
        '</tpl>',
        '<tpl if="!number">',
        'All files imported.',
        '</tpl>',
    ],

    markup: [
        '<div class="pp-box pp-box-style1"',
        '<h2>Import PDFs</h2>',
        '<p id="status-msg-{id}"></p>',
        '<div class="pp-control-container">',
        '<table><tr>',
        '</tr></table>',
        '</div>',
        '<div id="start-container-{id}" class="pp-control-container"></div>',
        '<p>&nbsp;</p>',
        '<div id="pbox-container-{id}" class="pp-control-container"></div>',
        '</div>',
	],

    initComponent: function() {
		Ext.apply(this, {
            cancelProcess:0,
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
		});
		
        Paperpile.QueueControl.superclass.initComponent.call(this);
	},


    /*
    updateView: function(){
        var list=this.getUnimportedList();

        var tpl= new Ext.XTemplate(this.statusMsgTpl);
        tpl.overwrite('status-msg-'+this.id, {number: list.length});

        if (list.length==0){
            this.startButton.disable();
        }
        
        
    },

    initControls: function(data){
        this.grid=this.ownerCt.ownerCt.items.get('center_panel').items.get('grid');

        var list=this.getUnimportedList();

        var tpl= new Ext.XTemplate(this.markup);

        tpl.overwrite(this.body, {number: list.length, id: this.id});

               
        this.startButton=new Ext.Button(
            { renderTo: "start-container-"+this.id,
              text: 'Match and import all PDFs',
              handler: function(){
                  this.importAll();
              },
              scope:this,
            });

        this.updateView();

        
    },*/

    
});