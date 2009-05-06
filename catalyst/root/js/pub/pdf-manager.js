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
        '<li id="open-pdf-{id}"><a href="/serve/{pdf}" target="_blank" action="open-pdf">Open PDF</a></li>',
        '<tpl if="_imported">',
        '<li id="delete-pdf-{id}"><a href="#" action="delete-pdf">Delete PDF</a></li>',
        '</tpl>',
        '<tpl if="!_imported">',
        '<li id="import-pdf-{id}"><a href="#" action="import-pdf">Import PDF into local library.</a></li>',
        '</tpl>',
        
        '</tpl>',

        '<tpl if="!pdf">',
        '<tpl if="linkout">',
        '<li id="search-pdf-{id}"><a href="#" action="search-pdf">Get PDF</a></li>',
        '</tpl>',
        '<tpl if="_imported">',
        '<li id="attach-pdf-{id}"><a href="#" action="attach-pdf">Attach PDF</a></li>',
        '</tpl>',
        '</tpl>',

        '<tpl if="_imported">',
        '<li id="attach-file-{id}"><a href="#" action="attach-file">Attach File</a></li>',
        '</tpl>',

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
	

    //
    // Redraws the HTML template panel with new data from the grid
    //
    
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
	},

    //
    // Event handling for the HTML. Is called with 'el' as the Ext.Element of the HTML 
    // after the template was written in updateDetail
    //
    
    installEvents: function(el){
        el.on('click', function(e, el, o){
            switch(el.getAttribute('action')){

                // Choose local PDF file and attach to database entry
            case 'attach-pdf': 
                this.chooseFile(true);
                break;

                // Search and download PDF file; if entry is already in database 
                // attach PDF directly to it
            case 'search-pdf':                 
                this.searchPDF(true);
                break;

                // If PDF has been downloaded for an entry that is not
                // already imported, import entry and attach PDF
            case 'import-pdf':
                var grid=this.ownerCt.ownerCt.items.get('center_panel').items.get(0);
                var pdf=this.data.pdf;
                grid.insertEntry(
                    // Callback comes with updated data that includes
                    // _rowid of newly inserted entry
                    function(data){
                        this.data=data;
                        this.attachFile(1,pdf);
                    }, this
                );
                break;
                
                // Delete attached PDF file from database entry
            case 'delete-pdf':
                this.deleteFile(true);
                break;
                
                // Attach an arbitrary number of files of any type to an entry in the database
            case 'attach-file':
                this.chooseFile(false);
                break;
                
                // Delete attached files
            case 'delete-file':
                this.deleteFile(false, el.getAttribute('rowid'));
                break;
            }

        }, this, {delegate:'a'});
    },

    //
    // Choose a file from harddisk to attach. Either it is *the* PDF of the citation or a
    // supplementary file (given by isPDF).
    //
    
    chooseFile: function(isPDF){

        var fc=new Paperpile.FileChooser({
            currentRoot: main.globalSettings.user_home,
            callback:function(button,path){
                console.log(this);
                if (button == 'OK'){
                    this.attachFile(isPDF, path);
                }
            },
            scope:this
        });
        
        fc.show();
    },


    //
    // Attach a file. Either it is *the* PDF of the citation or a
    // supplementary file (given by isPDF).
    //
            
    attachFile: function(isPDF, path){

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
                Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('attachments',this.data.attachments-1);
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

    //
    // Searches for a PDF link on the publisher site
    //

    searchPDF: function(){

        var li=Ext.get('search-pdf-'+this.id);
        var div=Ext.DomHelper.append(li, '<div id="progress-bar"></div>');

        this.progressBar = new Ext.ProgressBar({
            width: 300,
            renderTo: 'progress-bar'
        });

        this.progressBar.wait({text:"Searching PDF on publisher site", interval:100});

        Ext.Ajax.request(
            {   url: '/ajax/download/search',
                params: { sha1: this.data.sha1,
                          grid_id: this.grid_id,
                          linkout:this.data.linkout,
                        },
                method: 'GET',
                success: function(response){
                    var json = Ext.util.JSON.decode(response.responseText);
                    Ext.getCmp('statusbar').clearStatus();
                    if (json.pdf){
                        this.downloadPDF(json.pdf);
                        Ext.getCmp('statusbar').setText(json.pdf);
                    } else {
                        this.progressBar.destroy();
                        Ext.getCmp('statusbar').setText('Could not find PDF');
                    }
                    
                },

                scope: this,
            });

    },

    //
    // Downloads a PDF and saves it to a temporary location. If
    // citation data is already imported, the PDF is attached to this entry
    //
    
    downloadPDF: function(pdf){

        this.progressBar.reset();
        this.progressBar.text="Starting download...";

        Ext.Ajax.request(
            {   url: '/ajax/download/get',
                params: { sha1: this.data.sha1,
                          grid_id: this.grid_id,
                          url:pdf,
                        },
                method: 'GET',
                success: function(response){
                    var json = Ext.util.JSON.decode(response.responseText);
                    Ext.getCmp('statusbar').clearStatus();
                    Ext.TaskMgr.stop(this.progressTask);
                    this.progressTask=null;
                    if (json.pdf){
                        this.checkProgress();
                        if (this.data._imported){
                            this.attachFile(true,json.pdf);
                        } else {
                            Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('pdf',json.pdf);
                            this.updateDetail(this.data);
                        }
                        Ext.getCmp('statusbar').setText('Downloaded '+json.pdf);
                    } else {
                        Ext.getCmp('statusbar').clearStatus();
                        Ext.getCmp('statusbar').setText("Could not download PDF.");
                        this.updateDetail(this.data);
                    }
                },
                scope: this,
                timeout: 60000,
            });

        this.progressTask = {
            run: this.checkProgress,
            scope: this,
            interval: 500
        }
        Ext.TaskMgr.start(this.progressTask);
        
    },

    //
    // Polls progress of current download and updates progress bar
    //
    checkProgress: function(sha1){

        Ext.Ajax.request({
            url: '/ajax/download/progress',
            params: { sha1: this.data.sha1,
                      grid_id: this.grid_id,
            },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);

                // If polling progress task is not running any longer, we are finished.
                if (!this.progressTask){
                    this.progressBar.updateProgress(1.0,'Download finished.');
                    return;
                } else {
                    var fraction;
                    if (json.current_size){
                        fraction=json.current_size/json.total_size;
                    } else {
                        fraction=0.0;
                    }
                    this.progressBar.updateProgress(fraction, "Downloading ("
                                                    +Ext.util.Format.fileSize(json.current_size) 
                                                    +" / "+ Ext.util.Format.fileSize(json.total_size)+")");
                }
                    
            },
            scope:this
        })
    },


});


Ext.reg('pdfmanager', Paperpile.PDFmanager);