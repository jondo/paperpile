PaperPile.PDFmanager = Ext.extend(Ext.Panel, {
	  
    markup: [
        '<div id="mybox">',
        '<ul class="pp-pdf-manager">',
        '<tpl if="url">',
        '<li class="pp-publisher-link"><a href="{url}"><img src="{icon}"/>Go to publisher site</a></li>',
        '<li class="pp-action-download-pdf"><a href="#" onClick="{scope}.searchPDF()">Download PDF</a></li>',
        '</tpl>',
        '<tpl if="!url">',
        '<li>No links available for this citation.</li>',
        '</tpl>',
        '<li><div id="pbar"></div></li>',
        '</ul>',
        '</div>',
	  ],

	  startingMarkup: '',
	  
    initComponent: function() {
		    this.tpl = new Ext.XTemplate(this.markup);
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
        this.data.scope='Ext.getCmp(\'pdf_manager\')';
        //this.source_id=Ext.getCmp('tabs').getActiveTab().id;
        this.source_id=PaperPile.main.tabs.getActiveTab().id;
        

        this.tpl.overwrite(this.body, this.data);

        var el = Ext.get("mybox");
        el.boxWrap();
        
        this.progressBar = new Ext.ProgressBar({
            id: 'progress_bar',
            hidden:true,
            applyTo: 'pbar'
        });

        if (data.pdf){
            Ext.getCmp('canvas_panel').getLayout().setActiveItem('pdf_viewer');
            Ext.getCmp('pdf_viewer').initPDF(data.pdf);
        } else {
            Ext.getCmp('canvas_panel').getLayout().setActiveItem('pdf_manager');
        }

	  },

    searchPDF: function(){

        this.progressBar.wait({text:"Searching PDF on publisher site", interval:100});
        this.progressBar.show();

        Ext.Ajax.request(
            {   url: '/ajax/download/search',
                params: { sha1: this.data.sha1,
                          source_id: this.source_id,
                          url:this.data.url,
                        },
                method: 'GET',
                success: this.foundPDF,
                scope: this,
            });

    },

    foundPDF: function(response){

        var json = Ext.util.JSON.decode(response.responseText);

        this.progressBar.reset();
        
        if (json.pdf){
            this.progressBar.text="Starting download...";
            this.downloadPDF(json.pdf);
        }
        
        Ext.getCmp('statusbar').clearStatus();
        Ext.getCmp('statusbar').setText(json.pdf);
    },


    downloadPDF: function(pdf){

        Ext.Ajax.request(
            {   url: '/ajax/download/get',
                params: { sha1: this.data.sha1,
                          source_id: this.source_id,
                          url:pdf,
                        },
                method: 'GET',
                success: this.finishDownload,
                scope: this
            });

        var task = {
            run: this.checkProgress,
            scope: this,
            interval: 500
        }
        Ext.TaskMgr.start(task);
        
    },

    finishDownload: function(){
        Ext.TaskMgr.stopAll();
        this.checkProgress();
        Ext.Ajax.request({
            url: '/ajax/download/finish',
            params: { sha1: this.data.sha1,
                      source_id: this.source_id,
                    },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                this.progressBar.hide();
                Ext.getCmp(this.source_id).store.getById(this.data.sha1).set('pdf',json.pdf_file);
                Ext.getCmp('pdf_viewer').initPDF(json.pdf_file);
                Ext.getCmp('canvas_panel').getLayout().setActiveItem('pdf_viewer');
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Download finished.');
            },
            scope: this,
        });

    },

    checkProgress: function(sha1){
        
        Ext.Ajax.request({
            url: '/ajax/download/progress',
            params: { sha1: this.data.sha1,
                     source_id: this.source_id,
            },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                var fraction;

                if (json.current_size){
                    fraction=json.current_size/json.total_size;
                } else {
                    fraction=0;
                }
                var pbar=this.progressBar;
                pbar.updateProgress(fraction, "Downloading ("
                                    +Ext.util.Format.fileSize(json.current_size) 
                                    +" / "+ Ext.util.Format.fileSize(json.total_size)+")");
                pbar.show();
                
                Ext.getCmp('statusbar').setText(fraction);
            },
            scope:this
        })
    },

    showPDF: function(file){

        Ext.getCmp('pdf_viewer').initPDF(file);
        Ext.getCmp('canvas_panel').getLayout().setActiveItem('pdf_viewer');
    }



});


Ext.reg('pdfmanager', PaperPile.PDFmanager);