PaperPile.PDFmanager = Ext.extend(Ext.Panel, {
	  tplMarkup: [
		    '<p><a href="#" onClick="{scope}.searchPDF()">Search PDF for {sha1}</a></p>',
	  ],
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
	  },

    searchPDF: function(){
        Ext.Ajax.request({
            url: '/ajax/download/get',
            params: { sha1: this.data.sha1,
                      source_id: this.source_id,
                      url:'http://paperpile.org/test.pdf',
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Download finished.');
                Ext.TaskMgr.stopAll();
            },
        });

        var task = {
            run: this.checkProgress,
            interval: 1000
        }
        Ext.TaskMgr.start(task);
        
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
                Ext.getCmp('statusbar').setText(json.percent);
            }
        })
    },


});


Ext.reg('pdfmanager', PaperPile.PDFmanager);