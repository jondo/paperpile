Paperpile.QueueControl = Ext.extend(Ext.Panel, {
	
    markup: [
        '<div class="pp-box pp-box-style1"',
        '<h2>Progress</h2>',
        '<p id="queue-status"></p>',
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


    
    updateView: function(){
        //var list=this.getUnimportedList();

        var tpl= new Ext.XTemplate(this.markup);
        tpl.overwrite(this.body, {});
       
        
    },

    /*
    
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