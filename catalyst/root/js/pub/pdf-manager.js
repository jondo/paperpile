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
        '<li id="open-pdf-{id}"><a href="#">Open PDF</a></li>',
        '<li id="delete-pdf-{id}"><a href="#">Delete PDF</a></li>',
        '</tpl>',

        '<tpl if="!pdf">',
        '<tpl if="linkout">',
        '<li id="download-pdf-{id}"><a href="#">Download PDF</a></li>',
        '</tpl>',
        '<li id="attach-pdf-{id}"><a href="#">Attach PDF</a></li>',
        '</tpl>',
        '<li id="attach-file-{id}"><a href="#">Attach File</a></li>',
       
        '<tpl if="attachments">',
        '<ul class="pp-attachments">',
        '<tpl for="attachments_list">',
        '<li><a href="{link}" target="_blank">{file}</a><a href=""</li>',
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

        //if (attachPDF_link){
        //    attachPDF_link.on('click', this.attachFile, this, {isPDF:true});
        //}

        //if (attachFile_link){
        //    attachFile_link.on('click', this.attachFile, this, {isPDF:false});
        //}

        //Ext.select('a').on('click', function(e, el, o){
        //    alert('!');
        //}); 
        
        //this.html.on('click', function(e,el,o){
        ///    console.log("inhere");
        //}, null );


        //Ext.select('ul.pp-pdf-manager').on('click', function(e, el, o){
       ///     console.log("inhere");
        //});


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
            console.log("inhere");
        });
    },

        
    attachFile: function(e,el,pars){

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
                                    is_pdf: (pars.isPDF) ? 1:0
                                  },
                          method: 'GET',
                          success: function(response){
                              var json = Ext.util.JSON.decode(response.responseText);
                              if (json.pdf_file){
                                  Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('pdf',json.pdf_file);
                                  this.updateDetail(this.data);
                              }
                              
                          }, 
                          scope:this,
                        });
                }
            },
            scope:this
        });
        
        fc.show();

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