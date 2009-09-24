Paperpile.QueueControl = Ext.extend(Ext.Panel, {

    markup: [
        '<div class="pp-box pp-box-style1"',
        '<h2>Progress</h2>',
        '<p id="queue-progress"></p>',
        '<div id="queue-status"><div>',
        '</div>',
	],

    markupProgress: [
        '<p>{num_done} of {num_all} tasks completed.</p>',
	],

    markupDone: [
        '<p>All jobs done</p>',
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

        if (! Ext.get('queue-status')){
            var bodyTpl= new Ext.XTemplate(this.markup);
            bodyTpl.overwrite(this.body, {});
            this.pbar=new Ext.ProgressBar({cls: 'pp-basic'});
            this.pbar.render('queue-progress',0);
        }



        var currTpl;
        var tplProgress= new Ext.XTemplate(this.markupProgress);
        var tplDone= new Ext.XTemplate(this.markupDone);

        var r=this.ownerCt.ownerCt.items.get('grid').getStore().getAt(0);

        d={};

        if (r){
            var num_done = parseInt(r.data.num_done);
            var num_pending = parseInt(r.data.num_pending);
            var num_all = num_done + num_pending;

            if (num_done < num_all){
                d =  { num_done:num_done, 
                       num_all: num_all,
                     };
                currTpl = tplProgress;
                this.pbar.updateProgress(num_done/num_all, num_done+ ' of '+num_all);

            } else {
                currTpl = tplDone;
            }
        } else {
            currTpl = tplDone;
        }

        console.log(Ext.get('queue-status'));
        
        currTpl.overwrite(Ext.get('queue-status'), d);

               
    },

      
    initControls: function(data){

        this.grid=this.ownerCt.ownerCt.items.get('grid');

               
    },

    
});