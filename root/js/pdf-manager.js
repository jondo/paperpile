PaperPile.PDFmanager = Ext.extend(Ext.Panel, {
	  tplMarkup: [
		    '<div id="mybox" ><p><a href="{url}"><img src="{icon}"></img></a></p>\
         <p><a href="#" onClick="{scope}.searchPDF()">Search PDF for {sha1}</a></p>\
         <p><div id="searching_text"></id></p>\
         <p><div id="pbar"></id></p></div>\
	  '],
	  startingMarkup: 'Empty2',
	  
    initComponent: function() {
		    this.tpl = new Ext.XTemplate(this.tplMarkup);

        
        
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
        this.source_id=Ext.getCmp('results_tabs').getActiveTab().id;
        this.tpl.overwrite(this.body, data);
        var el = Ext.get("mybox");
        el.boxWrap();
        this.progressBar = new Ext.ProgressBar({
            id: 'progress_bar',
            text:'Starting download...',
            hidden:true,
            applyTo: 'pbar'
        });

	  },

    searchPDF: function(){

        var el = Ext.get("searching_text");

        el.insertHtml('afterBegin','<p>Searching...<p><img src="icons/waiting.gif">');

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

        var el = Ext.get("searching_text");

        if (json.pdf){
            this.downloadPDF(json.pdf);
        }
        
        Ext.getCmp('statusbar').clearStatus();
        Ext.getCmp('statusbar').setText(json.pdf);
    },


    downloadPDF: function(pdf){

        var pbar=Ext.getCmp('pdf_manager').progressBar;

        pbar.show();

        Ext.Ajax.request(
            {   url: '/ajax/download/get',
                params: { sha1: this.data.sha1,
                          source_id: this.source_id,
                          url:pdf,
                        },
                method: 'GET',
                success: this.finishDownload
            });

        var task = {
            run: this.checkProgress,
            interval: 500
        }
        Ext.TaskMgr.start(task);
        
    },

    finishDownload: function(){
        Ext.TaskMgr.stopAll();
        Ext.getCmp('pdf_manager').checkProgress();
        Ext.Ajax.request({
            url: '/ajax/download/finish',
            params: { sha1: Ext.getCmp('pdf_manager').data.sha1,
                      source_id: Ext.getCmp('pdf_manager').source_id,
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Download finished.');
                //Ext.getCmp('pdf_manager').showPDF('dummy');
            },
        });

    },

    checkProgress: function(sha1){
        
        Ext.Ajax.request({
            url: '/ajax/download/progress',
            params: { sha1: Ext.getCmp('pdf_manager').data.sha1,
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
                var pbar=Ext.getCmp('pdf_manager').progressBar;

                pbar.updateProgress(fraction, json.current_size);
                pbar.show();
                
                Ext.getCmp('statusbar').setText(fraction);
            }
        })
    },

    showPDF: function(file){

        var viewer=new PaperPile.PDFviewer(
            {id:'pdf_viewer',
             itemId:'pdf_viewer',
            }
        );

        Ext.dump(viewer);
        Ext.getCmp('canvas_panel').add(viewer);
        Ext.getCmp('canvas_panel').doLayout();
        Ext.getCmp('pdf_viewer').initPDF();
        Ext.getCmp('canvas_panel').getLayout().setActiveItem('pdf_viewer');

    }



});


Ext.reg('pdfmanager', PaperPile.PDFmanager);