Paperpile.PDFmanager = Ext.extend(Ext.Panel, {
	  
    markupSingle: [

        '<div id=main-container-{id}>',

        // Yellow box
        '<div class="pp-box pp-box-top pp-box-style1"',
        '<dl>',
        '<dt>Publication type: </dt><dd>{_pubtype_name}</dd>',
        '<tpl if="_imported"><dt>Imported: </dt><dd>{created}</dd></tpl>',
        '<tpl if="doi"><dt>DOI: </dt><dd>{doi}</dd></tpl>',
        '<tpl if="pmid"><dt>PubMed ID: </dt><dd>{pmid}</dd></tpl>',
        '<dt>Tags: </dt><dd>',
        '<div id="tag-container-{id}" class="pp-tag-container"></div>',
        '<div id="tag-control-{id}" class="pp-tag-control"></div>',
        '<div id="tag-add-link-{id}" ><a href="#" class="pp-textlink">Add&nbsp;tag</a></div>',
        '</dd>',
        '</dl>',
        '</div>',

        '<div class="pp-box pp-box-bottom pp-box-style1"',
        '<tpl if="linkout">',
        '<p><a href="{linkout}" target="_blank" class="pp-textlink pp-action pp-action-go">Go to publisher site</a></p>',
        '</tpl>',
        '<tpl if="!linkout">',
        '<p class="pp-action pp-action-go">[No publisher link available]</p>',
        '</tpl>',
        '</div>',

        // Gray box
        '<tpl if="pdf || _imported || linkout">',
        '<div class="pp-box pp-box-style2"',
        '<h2>PDF</h2>',
        '<ul>',
        '<tpl if="pdf">',
        '<li id="open-pdf-{id}" class="pp-action pp-action-open-pdf" ><a href="/serve/{pdf}" target="_blank" class="pp-textlink" action="open-pdf">Open PDF</a></li>',
        '<tpl if="_imported">',
        '<li id="delete-pdf-{id}" class="pp-action pp-action-delete-pdf"><a href="#" class="pp-textlink" action="delete-pdf">Delete PDF</a></li>',
        '</tpl>',
        '<tpl if="!_imported">',
        '<li id="import-pdf-{id}" class="pp-action pp-action-import-pdf"><a href="#" class="pp-textlink" action="import-pdf">Import PDF into local library.</a></li>',
        '</tpl>',
        '</tpl>',

        '<tpl if="!pdf">',
        '<tpl if="linkout">',
        '<li id="search-pdf-{id}" class="pp-action pp-action-get-pdf"><a href="#" class="pp-textlink" action="search-pdf">Download PDF</a></li>',
        '<li><div id="pbar"></div></li>',
        '</tpl>',
        '<tpl if="_imported">',
        '<li id="attach-pdf-{id}" class="pp-action pp-action-attach-pdf"><a href="#" class="pp-textlink" action="attach-pdf">Attach PDF</a></li>',
        '</tpl>',
        '</tpl>',
        '</ul>',

        '<tpl if="_imported">',
        '<p>&nbsp;</p>',
        '<h2>Supplementary material</h2>',
        '<tpl if="attachments">',
        '<ul class="pp-attachments">',
        '<tpl for="attachments_list">',
        '<li> - <a href="{link}" target="_blank">{file}</a>&nbsp;&nbsp;(<a href="#" class="pp-textlink" action="delete-file" rowid="{rowid}">Delete</a>)</li>',
        '</tpl>',
        '</ul>',
        '<p>&nbsp;</p>',
        '</tpl>',
        '<ul>',
        '<li id="attach-file-{id}" class="pp-action pp-action-attach-file"><a href="#" class="pp-textlink" action="attach-file">Attach File</a></li>',      '</ul>',
        '</tpl>',
        '</div>',
        '</tpl>',
        '</div>',
    ],

    markupMultiple: [

        '<div id=main-container-{id}>',
        '<div class="pp-box pp-box-top pp-box-style1">',
        '<p><b>{numSelected}</b> papers selected.</p>',
        '<div class="pp-control-container">',
        '<div id="tag-container-{id}" class="pp-tag-container"></div>',
        '<div id="tag-control-{id}" class="pp-tag-control"></div>',
        '</div>',
        '<div class="pp-vspace"></div>',
        '</div>',
        '</div>',

    ],

    initComponent: function() {
		this.tplSingle = new Ext.XTemplate(this.markupSingle);
        this.tplMultiple = new Ext.XTemplate(this.markupMultiple);
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
		});
		
        Paperpile.PDFmanager.superclass.initComponent.call(this);


	},
	

    //
    // Redraws the HTML template panel with new data from the grid
    //
    
    updateDetail: function() {

        if (!this.grid){
            this.grid=this.findParentByType(Ext.PubView).items.get('center_panel').items.get('grid');
        }

        sm=this.grid.getSelectionModel();

        var numSelected=sm.getCount();
        if (this.grid.allSelected){
            numSelected=this.grid.store.getTotalCount();
        }

        this.multipleSelection=(numSelected > 1 );
        
        console.log(numSelected, this.multipleSelection);

        if (!this.multipleSelection){
            this.data=sm.getSelected().data;
            this.data.id=this.id;

            this.grid_id=this.grid.id;

            this.data._pubtype_name=Paperpile.main.globalSettings.pub_types[this.data.pubtype].name;

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
                          this.tplSingle.overwrite(this.body, this.data, true);
                          this.installEvents();
                          this.renderTags();
                      }, 
                      scope:this,
                    });
            } else {
                this.tplSingle.overwrite(this.body, this.data, true);
                this.installEvents();
                this.renderTags();
            }
        } else { // single selection

            this.tplMultiple.overwrite(this.body, {numSelected: numSelected, id: this.id}, true);
            //this.installEvents();
            this.showTagControls();
        }
   	},

    //
    // Event handling for the HTML. Is called with 'el' as the Ext.Element of the HTML 
    // after the template was written in updateDetail
    //
    
    installEvents: function(){

        Ext.get('tag-add-link-'+this.id).setVisibilityMode(Ext.Element.DISPLAY);
        Ext.get('tag-add-link-'+this.id).on('click',
                                   function(){
                                       Ext.get('tag-add-link-'+this.id).hide();
                                       this.showTagControls();
                                   }, this);

        // All "action" links in panel
        Ext.get('main-container-'+this.id).on('click', function(e, el, o){

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

        
        // Delete function for tags
        Ext.get("tag-container-"+this.id).on('click',
                                             function(e){
                                                 var t=e.getTarget('div.pp-tag-remove');
                                                 if (!t) return;
                                                 this.onRemoveTag(t);
                                                 e.stopEvent();
                                             }, this);

    },


    renderTags: function(){

        var container=Ext.get("tag-container-"+this.id);

        container.setVisibilityMode(Ext.Element.DISPLAY);

        if (this.data.tags==''){
            Ext.get('tag-add-link-'+this.id).removeClass('pp-clear-left');
            Ext.get('tag-control-'+this.id).removeClass('pp-clear-left');
            container.hide();
            return;
        } 

        // We only have this control for a single selection
        if (!this.multipleSelection){
            Ext.get('tag-add-link-'+this.id).addClass('pp-clear-left');
        }
        
        Ext.get('tag-control-'+this.id).addClass('pp-clear-left');

        container.show();

        var store=Ext.StoreMgr.lookup('tag_store');

        var tags=this.data.tags.split(/\s*,\s*/);

        for (var i =0; i< tags.length; i++){

            var name = tags[i];
            var style = '0';
            if (store.getAt(store.find('tag',name))){
                style=store.getAt(store.find('tag',name)).get('style');
            }

            var el= { tag: 'div',
                      cls: 'pp-tag-box pp-tag-style-'+style,
                      children: [{tag: 'div',
                                  cls: 'pp-tag-name pp-tag-style-'+style,
                                  html: name
                                 },
                                 {tag: 'div',
                                  cls: 'pp-tag-remove pp-tag-style-'+style,
                                  html: 'x',
                                  name: name
                                 }
                                ]
                    };

            if (i==0){
                Ext.DomHelper.overwrite(container,el);
            } else {
                Ext.DomHelper.append(container,el);
            }
        }

           
    },

    hideTagControls: function(){
        var container=Ext.get('tag-control-'+this.id);
        while (container.first()){
            container.first().remove();
        }
    },

    showTagControls: function(){
        
        // Skip tags for combo which are already in list (unless we have multiple selection where this
        // does not make too much sense
        var list=[];

        Ext.StoreMgr.lookup('tag_store').each(function(rec){
            var tag=rec.data.tag;
            if (!this.multipleSelection){
                if (this.data.tags.match(new RegExp(","+tag+"$"))) return; // ,XXX
                if (this.data.tags.match(new RegExp("^"+tag+"$"))) return; //  XXX
                if (this.data.tags.match(new RegExp("^"+tag+","))) return; //  XXX,
                if (this.data.tags.match(new RegExp(","+tag+","))) return; // ,XXX,
            }
            list.push([tag]);
		}, this);

        var store = new Ext.data.SimpleStore({
			fields: ['tag'],
            data: list,
		});
     
        var combo = new Ext.form.ComboBox({
            id: 'tag-control-combo-'+this.id,
            store: store,
            displayField:'tag',
            forceSelection: false,
            triggerAction:'all',
            mode:'local',
            enableKeyEvents: true,
            renderTo:'tag-control-'+this.id,
            width: 120,
            listWidth: 120,
            initEvents: function(){
		        this.constructor.prototype.initEvents.call(this);
		        Ext.apply(this.keyNav, {
			        "enter" : function(e){
					    this.onViewClick();
					    this.delayedCheck = true;
					    this.unsetDelayCheck.defer(10, this);
                        scope=Ext.getCmp(this.id.replace('tag-control-combo-',''));
                        scope.onAddTag();
                        this.destroy();
                    }, 
			        doRelay : function(foo, bar, hname){
				        if(hname == 'enter' || hname == 'down' || this.scope.isExpanded()){
				            return Ext.KeyNav.prototype.doRelay.apply(this, arguments);
				        }
				        return true;
			        }
		        });
            }
        });

        combo.focus();

        var button = new Ext.Button({
            id: 'tag-control-ok-'+this.id,
            text: 'Add Tag',
        });

        button.render(Ext.DomHelper.append('tag-control-'+this.id,
                                           {tag:'div',
                                            cls:'pp-button-control',
                                           }
                                          ));

        if (! this.multipleSelection){

            var cancel = new Ext.BoxComponent({
                autoEl: {tag:'div', 
                         cls:'pp-textlink-control',
                         children:[{
                             tag: 'a',
                             id: 'tag-control-cancel-'+this.id,
                             href:'#',
                             cls: 'pp-textlink',
                             html: 'Cancel'
                         }],
                        },
            });

            cancel.render('tag-control-'+this.id);

            Ext.get('tag-control-cancel-'+this.id).on('click',
                                                      function(){
                                                          Ext.get('tag-add-link-'+this.id).show();
                                                          this.hideTagControls();
                                                      }, this);
        }
            
        Ext.get('tag-control-ok-'+this.id).on('click', this.onAddTag, this);
       
    },


    onAddTag: function(){

        var combo=Ext.getCmp('tag-control-combo-'+this.id);
        var tag=combo.getValue();

        combo.setValue('');

        if (this.data.tags != ''){
            this.data.tags=this.data.tags+","+tag;
        } else {
            this.data.tags=tag;
        }
        
        if (!this.multipleSelection){
            this.hideTagControls();
            this.renderTags();
            Ext.get('tag-add-link-'+this.id).show();
        }


        Ext.Ajax.request({
            url: '/ajax/crud/add_tag',
            params: { 
                grid_id:this.grid_id,
                selection: Ext.getCmp(this.grid_id).getSelection(),
                tag: tag,
            },
            method: 'GET',
                                        
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                var grid=Ext.getCmp(this.grid_id);
                grid.updateData(json.data);

                var store=Ext.StoreMgr.lookup('tag_store');
                if (store.find('tag',tag) == -1){
                    Paperpile.main.tree.getNodeById('TAGS_ROOT').reload();
                    Ext.StoreMgr.lookup('tag_store').reload();
                }
            },
            scope: this,
        });

       
    },

    onRemoveTag: function(el){

        tag=el.getAttribute('name');

        Ext.get(el).parent().remove();

        Ext.Ajax.request({
            url: '/ajax/crud/remove_tag',
            params: { 
                grid_id:this.grid_id,
                selection: Ext.getCmp(this.grid_id).getSelection(),
                tag: tag,
            },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                var grid=Ext.getCmp(this.grid_id);
                grid.updateData(json.data);
            },
            scope: this,
        });
    },

    //
    // Choose a file from harddisk to attach. Either it is *the* PDF of the citation or a
    // supplementary file (given by isPDF).
    //
    
    chooseFile: function(isPDF){

        var fc=new Paperpile.FileChooser({
            currentRoot: main.globalSettings.user_home,
            callback:function(button,path){
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
                  this.updateDetail();
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
                this.updateDetail();
            }
        } else {
            successFn=function(response){
                Ext.getCmp(this.grid_id).store.getById(this.data.sha1).set('attachments',this.data.attachments-1);
                this.updateDetail();
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
        var div=Ext.DomHelper.append(li, '<div class="pp-control-container" id="progress-bar"></div>');

        this.progressBar = new Ext.ProgressBar({
            width: 240,
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
                            this.updateDetail();
                        }
                        Ext.getCmp('statusbar').setText('Downloaded '+json.pdf);
                    } else {
                        Ext.getCmp('statusbar').clearStatus();
                        Ext.getCmp('statusbar').setText("Could not download PDF.");
                        this.updateDetail();
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