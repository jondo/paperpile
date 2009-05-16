Paperpile.PDFmanager = Ext.extend(Ext.Panel, {
	  
    markup: [

        // Yellow box
        '<div class="pp-box pp-box-yellow"',
        
        '<dl>',
        '<dt>Publication type: </dt><dd>{_pubtype_name}</dd>',
        '<tpl if="_imported"><dt>Imported: </dt><dd>{created}</dd></tpl>',
        '<tpl if="doi"><dt>DOI: </dt><dd>{doi}</dd></tpl>',
        '<tpl if="pmid"><dt>PubMed ID: </dt><dd>{pmid}</dd></tpl>',
        '<dt>Tags: </dt><dd>',
        '<div id="tag-container-{id}" class="pp-tag-container"></div>',
        '<div id="tag-control-{id}" class="pp-tag-control"></div>',
        '<div id="tag-add-link-{id}" ><a href="#">Add&nbsp;tag</a></div>',
        '</dd>',
        '</dl>',

        '<tpl if="linkout">',
        '<p><a href="{linkout}" target="_blank" class="pp-action-go">Go to publisher site</a></p>',
        '</tpl>',
        '<tpl if="!linkout">',
        '<p class="pp-action-go">[No publisher link available]</p>',
        '</tpl>',
        '</div>',


        // Gray box
        '<div class="pp-box pp-box-gray"',

        '<h2>PDF</h2>',
        '<ul class="pp-pdf-manager" id="markup-{id}">',

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

        '<h2>Supplementary material</h2>',
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

        '</div>',

	  ],

    initComponent: function() {
		this.tpl = new Ext.XTemplate(this.markup);
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
    
    updateDetail: function(data) {
        this.data=data;
        this.data.id=this.id;

        this.grid_id=this.ownerCt.ownerCt.items.get('center_panel').items.get(0).id;

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
                      this.installEvents(this.tpl.overwrite(this.body, this.data, true));
                  }, 
                  scope:this,
                });
        } else {
            this.installEvents(this.tpl.overwrite(this.body, this.data, true));
        }
        
        this.renderTags();
        
	},

    //
    // Event handling for the HTML. Is called with 'el' as the Ext.Element of the HTML 
    // after the template was written in updateDetail
    //
    
    installEvents: function(el){

        Ext.get('tag-add-link-'+this.id).setVisibilityMode(Ext.Element.DISPLAY);
        Ext.get('tag-add-link-'+this.id).on('click',
                                   function(){
                                       Ext.get('tag-add-link-'+this.id).hide();
                                       this.showTagControls();
                                   }, this);

            
        // All "action" links in panel
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

        
        // Delete function for tags
        Ext.get("tag-container-"+this.id).on('click',
                                             function(e){
                                                 var t=e.getTarget('div.pp-tag-remove');
                                                 if (!t) return;
                                                 console.log(t);
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

        Ext.get('tag-add-link-'+this.id).addClass('pp-clear-left');
        Ext.get('tag-control-'+this.id).addClass('pp-clear-left');

        container.show();

        var store=Ext.StoreMgr.lookup('tag_store');

        var tags=this.data.tags.split(/\s*,\s*/);

        for (var i =0; i< tags.length; i++){

            var name = tags[i];
            var style = store.getAt(store.find('tag',name)).get('style');

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
        
        // Skip tags for combo which are already in list
        var list=[];
        Ext.StoreMgr.lookup('tag_store').each(function(rec){
            var tag=rec.data.tag;
            if (this.data.tags.match(new RegExp(","+tag+"$"))) return; // ,XXX
            if (this.data.tags.match(new RegExp("^"+tag+"$"))) return; //  XXX
            if (this.data.tags.match(new RegExp("^"+tag+","))) return; //  XXX,
            if (this.data.tags.match(new RegExp(","+tag+","))) return; // ,XXX,
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

        var cancel = new Ext.BoxComponent({
            autoEl: {tag:'div', 
                     cls:'pp-textlink-control',
                     children:[{
                         tag: 'a',
                         id: 'tag-control-cancel-'+this.id,
                         href:'#',
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

        Ext.get('tag-control-ok-'+this.id).on('click', this.onAddTag, this);
       
    },


    onAddTag: function(){

        var combo=Ext.getCmp('tag-control-combo-'+this.id);
        var tag=combo.getValue();

        combo.setValue('');

        this.hideTagControls();

        if (this.data.tags != ''){
            this.data.tags=this.data.tags+","+tag;
        } else {
            this.data.tags=tag;
        }

        var store=Ext.StoreMgr.lookup('tag_store');
        
        if (store.find('tag',tag) == -1){
            this.updateTags(true);
        } else {
            this.updateTags(false);
        }

        Ext.get('tag-add-link-'+this.id).show();
       
    },

    onRemoveTag: function(el){

        tag=el.getAttribute('name');

        Ext.get(el).parent().remove();
        
        var tags=[];

        Ext.each(Ext.query('div.pp-tag-remove', 'tag-container-'+this.id), 
                 function(tag){
                     tags.push(tag.getAttribute('name'));
                 }
                );


        if (tags.length>0){
            this.data.tags=tags.join(',');
        } else {
            this.data.tags='';
        }

        this.updateTags(false);

    },


    updateTags: function(isNew){

        Ext.Ajax.request({
            url: '/ajax/crud/update_tags',
            params: { rowid: this.data._rowid,
                      tags: this.data.tags,
                    },
            method: 'GET',
                                        
            success: function(){
                // Update local data

                console.log(isNew);

                Ext.StoreMgr.lookup('tag_store').reload();
                if (isNew){
                    Paperpile.main.tree.getNodeById('TAGS_ROOT').reload();
                }

                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Updated tags.');
            },
            scope: this,
            
        });

        this.renderTags();

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