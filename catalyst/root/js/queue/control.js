Paperpile.QueueControl = Ext.extend(Ext.Panel, {

    markup: [
        '<div class="pp-box pp-box-style1" style="height:200px;"',
        '<h2>Progress</h2>',
        '<p id="queue-progress"></p>',
        '<div id="queue-status"></div>',
        '<center><div id="queue-button"></div></center>',
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
            this.initControls();
        }
        
        var currTpl;
        var tplProgress= new Ext.XTemplate(this.markupProgress);
        var tplDone= new Ext.XTemplate(this.markupDone);

        var r=this.ownerCt.ownerCt.items.get('grid').getStore().getAt(0);

        d={};

        if (r){

            this.status = r.data.queue_status;

            var num_done = parseInt(r.data.num_done);
            var num_pending = parseInt(r.data.num_pending);
            var num_all = num_done + num_pending;

            if (this.status === 'RUNNING'){
                this.button.setText('Pause tasks');
            }

            if (num_done < num_all){
                d =  { num_done:num_done, 
                       num_all: num_all,
                     };
                currTpl = tplProgress;
                this.pbar.updateProgress(num_done/num_all, num_done+ ' of '+num_all+' tasks completed');

            } else {
                currTpl = tplDone;
                console.log("inhere");
                this.button.setText('Close tab');
            }
        } else {
            currTpl = tplDone;
            this.button.setText('Close tab');
        }

            
        currTpl.overwrite(Ext.get('queue-status'), d);

               
    },

      
    initControls: function(data){

        this.grid=this.ownerCt.ownerCt.items.get('grid');

        var bodyTpl= new Ext.XTemplate(this.markup);
        bodyTpl.overwrite(this.body, {});
        this.pbar=new Ext.ProgressBar({cls: 'pp-basic'});
        this.pbar.render('queue-progress',0);

        this.button=new Ext.Button(
            { text: '',
              handler: function(){
                  alert("inhere");
              },
              scope:this,
            });

        this.button.render('queue-button',0);

    },

    
});