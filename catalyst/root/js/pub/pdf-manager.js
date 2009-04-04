Paperpile.PDFmanager = Ext.extend(Ext.Panel, {
	  
    markup: [
        '<ul class="pp-pdf-manager" id="markup-{id}">',
        
        '<tpl if="linkout">',
        '<li id="linkout-{id}"><a href="{linkout}" target="_blank">Go to publisher site</a></li>',
        '</tpl>',

        '<tpl if="!linkout">',
        '<li>No links available for this citation.</li>',
        '</tpl>',
        
        '<tpl if="pdf">',
        '<li id="open-pdf-{id}"><a href="#" action="open-pdf">Open PDF</a></li>',
        '<li id="delete-pdf-{id}"><a href="#" action="delete-pdf">Delete PDF</a></li>',
        '</tpl>',

        '<tpl if="!pdf">',
        '<tpl if="linkout">',
        '<li id="download-pdf-{id}"><a href="#" action="download-pdf">Download PDF</a></li>',
        '</tpl>',
        '<li id="attach-pdf-{id}"><a href="#" action="attach-pdf">Attach PDF</a></li>',
        '</tpl>',
        '<li id="attach-file-{id}"><a href="#" action="attach-file">Attach File</a></li>',
       
        '<tpl if="attachments">',
        '<ul class="pp-attachments">',
        '<tpl for="attachments_list">',
        '<li><a href="{link}" target="_blank">{file}</a><a href="#" action="delete-file" rowid="{rowid}">Delete</a></li>',
        '</tpl>',
        '</ul>',
        
        '</tpl>',
        '<li><div id="pbar"></div></li>',
        '</ul>',
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
		
        Paperpile.PDFmanager.superclass.initComponent.call(this);
	},
	  
    updateDetail: function(data) {
        this.data=data;
        this.data.id=this.id;
                
        this.grid_id=this.ownerCt.ownerCt.items.get('center_panel').items.get(0).id;

        this.data.attachments_list=[];
        if (this.data.attachments > 0){
            Ext.Ajax.request(
                { url: '/ajax/attachments/list_files',
                  params: { sha1: this.data.sha1,
                            rowid: this.data._rowid,
                            grid_id: this.grid_id,
                          },
                  method: 'GET',
                  success: function(response){
                      var json = Ext.util.JSON.decode(response.responseText);
                      this.data.attachments_list=json.list;
                      this.installEvents(this.tpl.overwrite(this.body, this.data, true));
                  }, 
                  scope:this,
                });
        } else {
            this.installEvents(this.tpl.overwrite(this.body, this.data, true));
        }

        //var attachPDF_link=Ext.Element.get('attach-pdf-'+this.id);
        //var attachFile_link=Ext.Element.get('attach-file-'+this.id);

        /*
        
        this.progressBar = new Ext.ProgressBar({
            id: 'progress_bar',
            hidden:true,
            applyTo: 'pbar'
        });

        if (data.pdf){
            this.ownerCt.getLayout().setActiveItem('pdf_viewer');
            //Ext.getCmp('pdf_viewer').initPDF(data.pdf);
        } else {
            this.ownerCt.getLayout().setActiveItem('pdf_manager');
        }
        */
	},

    //
    // Event handling for the HTML. Is called with the Ext.Element of the HTML 
    // after the template is written
    //
    
    installEvents: function(el){
        el.on('click', function(e, el, o){
            switch(el.getAttribute('action')){
            case 'attach-pdf':
                this.attachFile(true);
                break;
            case 'delete-pdf':
                this.deleteFile(true);
                break;
            case 'attach-file':
                this.attachFile(false);
                break;
            case 'delete-file':
                this.deleteFile(false, el.getAttribute('rowid'));
                break;

            }

        }, this, {delegate:'a'});
    },

    //
    // Attach a file. Either it is *the* PDF of the citation or a
    // supplementary file (given by isPDF).
    //
            
    attachFile: function(isPDF){

        var fc=new Paperpile.FileChooser({
            callback:function(button,path){
                console.log(this);
                if (button == 'OK'){
                    Ext.Ajax.request(
                        { url: '/ajax/attachments/attach_file',
                          params: { sha1: this.data.sha1,
                                    rowid: this.data._rowid,
                                    grid_id: this.grid_id,
                                    file:path,
                                    is_pdf: (isPDF) ? 1:0
                                  },
                          method: 'GET',
                          success: function(response){
                              var json = Ext.util.JSON.decode(response.responseText);
                              if (json.pdf_file){
                                  Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('pdf',json.pdf_file);
                              } else {
                                  Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('attachments',this.data.attachments+1);
                              }
                              this.updateDetail(this.data);
                          }, 
                          scope:this,
                        });
                }
            },
            scope:this
        });
        
        fc.show();

    },

    //
    // Delete file. isPDF controls whether it is *the* PDF or some
    // other attached file. In the latter case rowid has to be
    // specified as the rowid of the file in the 'Attachments' table
    //
    
    deleteFile: function(isPDF, rowid){

        var successFn;

        if (isPDF) {
            successFn=function(response){
                Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('pdf','');
                this.updateDetail(this.data);
            }
        } else {
            successFn=function(response){
                Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('attachments',this.data.attachments+1);
                this.updateDetail(this.data);
            }
        }

        Ext.Ajax.request(
            { url: '/ajax/attachments/delete_file',
              params: { sha1: this.data.sha1,
                        rowid: isPDF ? this.data._rowid : rowid,
                        is_pdf: (isPDF) ? 1:0,
                        grid_id: this.grid_id,
                      },
              method: 'GET',
              success: successFn,
              scope:this,
            });

    },


    searchPDF: function(){

        this.progressBar.wait({text:"Searching PDF on publisher site", interval:100});
        this.progressBar.show();

        Ext.Ajax.request(
            {   url: '/ajax/download/search',
                params: { sha1: this.data.sha1,
                          source_id: this.source_id,
                          linkout:this.data.linkout,
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


Ext.reg('pdfmanager', Paperpile.PDFmanager);