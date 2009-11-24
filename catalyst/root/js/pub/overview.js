Paperpile.PubOverview = Ext.extend(Ext.Panel, {
	  
  itemId: 'overview',

    initComponent: function() {
      Ext.apply(this,{
	  bodyStyle: {
	    background: '#ffffff',
	    padding: '7px'
	  },
	  autoScroll: true
      });
		
      Paperpile.PubOverview.superclass.initComponent.call(this);
      
      this.on('afterrender',this.installEvents,this);
      },
	
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
        
        if (numSelected == 1) {
            this.data=sm.getSelected().data;
            this.data.id=this.id;

            if (this.data.created){
                this.data.createdPretty = Paperpile.utils.prettyDate(this.data.created);
                this.data.createdFull = Paperpile.utils.localDate(this.data.created);
            }

            this.grid_id=this.grid.id;

            if (this.data.pubtype){
                this.data._pubtype_name=Paperpile.main.globalSettings.pub_types[this.data.pubtype].name;
            } else {
                this.data._pubtype_name=false;
            }

            this.data.attachments_list=[];
            if (this.data.attachments > 0){
                Ext.Ajax.request(
                    { url: Paperpile.Url('/ajax/attachments/list_files'),
                      params: { sha1: this.data.sha1,
                                rowid: this.data._rowid,
                                grid_id: this.grid_id
                              },
                      method: 'GET',
                      success: function(response){
                          var json = Ext.util.JSON.decode(response.responseText);
                          this.data.attachments_list=json.list;
                          this.grid.getSidebarTemplate().singleSelection.overwrite(this.body, this.data, true);
                          this.renderTags();
                      },
                      failure: Paperpile.main.onError,
                      scope:this
                    });
            } else {
                this.grid.getSidebarTemplate().singleSelection.overwrite(this.body, this.data, true);
                this.renderTags();
            }
        } 

        if (numSelected > 1) {
            this.grid.getSidebarTemplate().multipleSelection.overwrite(this.body, {numSelected: numSelected, id: this.id}, true);

            Ext.get('main-container-'+this.id).on('click', function(e, el, o){
                switch(el.getAttribute('action')){
                case 'batch-download':
                    this.grid.batchDownload();
                    break;
                }        
            }, this, {delegate:'a'});
            this.showTagControls();
        }

        if (numSelected == 0) {
            var empty = new Ext.Template('');
            empty.overwrite(this.body);
            
        }

	if (this.grid.updateDetail != null) {
	  this.grid.updateDetail();
	}

   	},

    //
    // Event handling for the HTML. Is called with 'el' as the Ext.Element of the HTML 
    // after the template was written in updateDetail
    //
    
    installEvents: function(){
	var el = Ext.get('tag-add-link-'+this.id);
	/*
        if (el != null) {
	  Ext.get('tag-add-link-'+this.id).setVisibilityMode(Ext.Element.DISPLAY);
          Ext.get('tag-add-link-'+this.id).on('click',
                                   function(){
                                       Ext.get('tag-add-link-'+this.id).hide();
                                       this.showTagControls();
                                   }, this);

        // Delete function for tags
        Ext.get("tag-container-"+this.id).on('click',
                                             function(e){
                                                 var t=e.getTarget('div.pp-tag-remove');
                                                 if (!t) return;
                                                 this.onRemoveTag(t);
                                                 e.stopEvent();
                                             }, this);

	}
	 */
      this.el.on('click',this.handleClick,this);
    },

    showOverview: function() {
      var view = Paperpile.main.getActiveView();
      view.depressButton('overview_tab_button');
    },

    showDetails: function() {
      var view = Paperpile.main.getActiveView();
      view.depressButton('details_tab_button');
    },

    handleClick: function(e) {
      e.stopEvent();
	var el = e.getTarget();
      
	switch(el.getAttribute('action')) {

          case 'open-pdf':
            var path=this.data.pdf;
            if (!Paperpile.utils.isAbsolute(path)){
	      path=Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, path);
            }
            Paperpile.main.tabs.newPdfTab({file:path, title:this.data.pdf});
            Paperpile.main.inc_read_counter(this.data._rowid);
            break;

          case 'open-pdf-external':
            var path=Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, this.data.pdf);
            Paperpile.utils.openFile(path);
            Paperpile.main.inc_read_counter(this.data._rowid);
            break;
               
	  case 'attach-pdf':
            // Choose local PDF file and attach to database entry
            this.chooseFile(true);
            break;

          case 'search-pdf':
            // Search and download PDF file; if entry is already in database 
            // attach PDF directly to it
            this.searchPDF(el.getAttribute('plugin'));
            break;

          case 'import-pdf':
            // If PDF has been downloaded for an entry that is not
            // already imported, import entry and attach PDF
            var grid=this.ownerCt.ownerCt.items.get('center_panel').items.get(0);
            var pdf=this.data.pdf;
            grid.insertEntry(
              function(data){
		this.attachFile(1,pdf);
              }, this
            );
            break;
                
          case 'delete-pdf':
            // Delete attached PDF file from database entry
            this.deleteFile(true);
            break;
                
          case 'attach-file':
            // Attach an arbitrary number of files of any type to an entry in the database 
            this.chooseFile(false);
            break;

          case 'open-attachment':
            // Open attached files
            var path= el.getAttribute('path');
	    Paperpile.utils.openFile(path);
	    break;
            
          case 'delete-file':
            // Delete attached files
            this.deleteFile(false, el.getAttribute('rowid'));
            break;

	  case 'edit-ref':
	    var grid = Paperpile.main.getActiveGrid();
	    grid.handleEdit();
	    break;

	  case 'delete-ref':
	    var grid = Paperpile.main.getActiveGrid();
	    grid.handleDelete();
	    break;

	  case 'show-details':
	    this.showDetails();
	    break;

            }
    },

    renderTags: function(){
      var container=Ext.get("tag-container-"+this.id);

      if (container == null)
	return;

      //container.setVisibilityMode(Ext.Element.DISPLAY);

      var asdf = new Paperpile.LabelWidget({
	  grid_id:this.grid_id,
	  renderTo:'tag-container-'+this.id,
	  data:this.data
      });

      return;

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

	//name=name.replace(/ +/g,"&nbsp;");

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
            { tag: 'div',
              cls: 'pp-tag-remove pp-tag-style-'+style,
              html: 'x',
              name: name
	    }
	    ]
          };

        if (i==0){
	  //Ext.DomHelper.overwrite(container,el);
        } else {
	  //Ext.DomHelper.append(container,el);
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
            data: list
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
            text: 'Add Label',
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
                         }]
                        }
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
            url: Paperpile.Url('/ajax/crud/add_tag'),
            params: { 
                grid_id:this.grid_id,
                selection: Ext.getCmp(this.grid_id).getSelection(),
                tag: tag
            },
            method: 'GET',
                                        
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                var grid=Ext.getCmp(this.grid_id);
                grid.updateData(json.data);

                var store=Ext.StoreMgr.lookup('tag_store');
                if (store.find('tag',tag) == -1){
                    Paperpile.main.tree.getNodeById('TAGS_ROOT').reload();
                    Ext.StoreMgr.lookup('tag_store').reload({
                                                            callback: function() {
                                                              grid.getView().refresh();             
                                                            }
                                                            });
                }
               
            },
            failure: Paperpile.main.onError,
            scope: this
        });

       
    },


    //
    // Choose a file from harddisk to attach. Either it is *the* PDF of the citation or a
    // supplementary file (given by isPDF).
    //
    
    chooseFile: function(isPDF){

        var fc=new Paperpile.FileChooser({
            currentRoot: Paperpile.main.globalSettings.user_home,
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
            { url: Paperpile.Url('/ajax/attachments/attach_file'),
              params: { sha1: this.data.sha1,
                        rowid: this.data._rowid,
                        grid_id: this.grid_id,
                        file:path,
                        is_pdf: (isPDF) ? 1:0
                      },
              method: 'GET',
              success: function(response){
                  var json = Ext.util.JSON.decode(response.responseText);
                  var record=this.grid.store.getAt(this.grid.store.find('sha1',this.data.sha1));

                  if (json.pdf_file){
                      record.set('pdf',json.pdf_file);
                  } else {
                      record.set('attachments',this.data.attachments+1);
                  }
                  this.updateDetail();
                  Paperpile.main.onUpdateDB(this.grid_id);
              },
              failure: Paperpile.main.onError,
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

        var record= this.grid.store.getAt(this.grid.store.find('sha1',this.data.sha1));

        if (isPDF) {
            successFn=function(response){
                record.set('pdf','');
                this.updateDetail();
                Paperpile.main.onUpdateDB(this.grid_id);
            };
        } else {
            successFn=function(response){
                record.set('attachments',this.data.attachments-1);
                this.updateDetail();
                Paperpile.main.onUpdateDB(this.grid_id);
            };
        }

        Ext.Ajax.request(
            { url: Paperpile.Url('/ajax/attachments/delete_file'),
              params: { sha1: this.data.sha1,
                        rowid: isPDF ? this.data._rowid : rowid,
                        is_pdf: (isPDF) ? 1:0,
                        grid_id: this.grid_id,
                      },
              method: 'GET',
              success: function(response){
                  var undo_msg='';
                  if (isPDF){
                      undo_msg='Deleted PDF file '+ record.get('pdf');
                      record.set('pdf','');
                  } else {
                      undo_msg="Deleted one attached file"
                      record.set('attachments',this.data.attachments-1);
                  }
                  this.updateDetail();

                  Paperpile.status.updateMsg(
                        { msg: undo_msg,
                          action1: 'Undo',
                          callback: function(action){
                              Ext.Ajax.request({
                                  url: Paperpile.Url('/ajax/attachments/undo_delete'),
                                  method: 'GET',
                                  success: function(response){
                                      var json = Ext.util.JSON.decode(response.responseText);
                                      var record=this.grid.store.getAt(this.grid.store.find('sha1',this.data.sha1));
                                      if (json.pdf_file){
                                          record.set('pdf',json.pdf_file);
                                      } else {
                                          record.set('attachments',this.data.attachments+1);
                                      }
                                      this.updateDetail();
                                      Paperpile.main.onUpdateDB(this.grid_id);
                                      Paperpile.status.clearMsg();
                                  }, 
                                  scope:this
                              });
                          },
                          scope: this,
                          hideOnClick: true,
                        }
                    );

                  Paperpile.main.onUpdateDB(this.grid_id);

              },
              failure: Paperpile.main.onError,
              scope:this,
            });

    },

    //
    // Searches for a PDF link on the publisher site
    //

    searchPDF: function(plugin){

        var li=Ext.get('search-pdf-'+this.id);
        var div=Ext.DomHelper.append(li, '<div class="pp-control-container" id="progress-bar"></div>');

        this.progressBar = new Ext.ProgressBar({
            width: 220,
            renderTo: 'progress-bar'
        });

        if (this.data.pdf_url){
            this.downloadPDF(this.data.pdf_url);
            return;
        }

        var msg='Searching online for PDF...';

        if (plugin){
            msg='Searching for PDF via '+plugin+"...";
        }

        this.progressBar.wait({text:msg, interval:100});

	var url = this.data.linkout;
	if (!this.data.linkout && this.data.doi) {
	  url = "http://dx.doi.org/"+this.data.doi;
	}

        Ext.Ajax.request(
            {   url: Paperpile.Url('/ajax/download/search'),
                params: { sha1: this.data.sha1,
                          grid_id: this.grid_id,
                          linkout:url,
                          plugin: plugin
                        },
                method: 'GET',
                success: function(response){
                    var json = Ext.util.JSON.decode(response.responseText);
                    if (json.pdf){
                        this.downloadPDF(json.pdf);
                    } else {
                        Paperpile.main.onError(response);
                        this.progressBar.destroy();
                    }
                },
                failure: function(response){
                    Paperpile.main.onError(response);
                    this.progressBar.destroy();
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
        this.progressBar.updateProgress(0.0,'Starting download.');
        Ext.Ajax.request(
            {   url: Paperpile.Url('/ajax/download/get'),
                params: { sha1: this.data.sha1,
                          grid_id: this.grid_id,
                          url:pdf,
                        },
                method: 'GET',
                success: function(response){
                    var json = Ext.util.JSON.decode(response.responseText);
                    Ext.TaskMgr.stop(this.progressTask);
                    this.progressTask=null;
                    if (json.pdf){
                        this.checkProgress();
                        if (this.data._imported){
                            this.attachFile(true,json.pdf);
                        } else {
                            var store=this.grid.store;
                            store.getAt(store.find('sha1',this.data.sha1)).set('pdf',json.pdf);
                            this.updateDetail();
                        }
                    } else {
                        Paperpile.main.onError(response);
                        this.updateDetail();
                    }
                },
                failure: function(response){
                    Ext.TaskMgr.stop(this.progressTask);
                    this.progressTask=null;
                    Paperpile.main.onError(response);
                    this.progressBar.destroy();
                },

                scope: this,
                timeout: 60000,
            });

        this.progressTask = {
            run: this.checkProgress,
            scope: this,
            interval: 500
        };
        Ext.TaskMgr.start(this.progressTask);
        
    },

    //
    // Polls progress of current download and updates progress bar
    //
    checkProgress: function(sha1){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/download/progress'),
            params: { sha1: this.data.sha1,
                      grid_id: this.grid_id,
            },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);

                // If polling progress task is not running any longer, we are finished.
                if (!this.progressTask){
                    this.progressBar.reset();
                    this.progressBar.updateProgress(1.0,'Download finished.');
                    return;
                } else {
                    var fraction;
                    var current_size=0.0;

                    // We only show stats when download has started and we know the total size.
                    if (json.current_size > 0 && json.total_size){
                        fraction=json.current_size/json.total_size;
                        this.progressBar.updateProgress(fraction, "Downloading ("
                                                        +Ext.util.Format.fileSize(json.current_size) 
                                                        +" / "+ Ext.util.Format.fileSize(json.total_size)+")");
                    } else {
                        // If download has started and we do not know
                        // the total size we just show a generic wait bar.
                        if (json.current_size > 0){
                            this.progressBar.wait({text: 'Downloading PDF', interval:100 });
                        }
                    }
                }
                    
            },
            failure: function(response){
                Ext.TaskMgr.stop(this.progressTask);
                Paperpile.main.onError(response);
            },

            scope:this
        });
    },

    showEmpty: function(tpl){

        var empty = new Ext.Template(tpl);
        empty.overwrite(this.body);
  
    }

    
});


Ext.reg('puboverview', Paperpile.PubOverview);