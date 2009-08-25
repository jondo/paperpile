Paperpile.PluginGrid = Ext.extend(Ext.grid.GridPanel, {

    plugin_query:'',
    closable:true,
    region:'center',
    limit: 25,
    allSelected:false,
    itemId:'grid',

    tagStyles:{},
                                    
    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: Paperpile.Url('/ajax/plugins/resultsgrid'),
                method: 'GET'
            }),
               baseParams:{grid_id: this.id,
                           plugin_file: this.plugin_file,
                           plugin_name: this.plugin_name,
                           plugin_query: this.plugin_query,
                           plugin_mode: this.plugin_mode,
                           plugin_order: "created DESC",
                           limit:this.limit
                          },
               reader: new Ext.data.JsonReader(),
            });

        var _pager=new Ext.PagingToolbar({
            pageSize: this.limit,
            store: _store,
            displayInfo: true,
            displayMsg: 'Displaying papers {0} - {1} of {2}',
            emptyMsg: "No papers to display",
        });
      
        this.pubTemplate = new Ext.XTemplate(
            '<div class="pp-grid-data">',
              '<div>',
            '<span class="pp-grid-title">{title}</span>{[this.tagStyle(values.tags)]}',
            '</div>',
            '<tpl if="_authors_display">',
            '<p class="pp-grid-authors">{_authors_display}</p>',
            '</tpl>',
            '<tpl if="_citation_display">',
            '<p class="pp-grid-citation">{_citation_display}</p>',
            '</tpl>',
            '<tpl if="_snippets_text">',
            '<p class="pp-grid-snippets"><span class="heading">PDF:</span> {_snippets_text}</p>',
            '</tpl>',
            '<tpl if="_snippets_abstract">',
            '<p class="pp-grid-snippets"><span class="heading">Abstract:</span> {_snippets_abstract}</p>',
            '</tpl>',
            '<tpl if="_snippets_notes">',
            '<p class="pp-grid-snippets"><span class="heading">Notes:</span> {_snippets_notes}</p>',
            '</tpl>',
            '</div>',
            {
            tagStyle:function(tag_string) {
              var returnMe = '';//<div class="pp-tag-grid-block">';
              var tags = tag_string.split(/\s*,\s*/);
              var totalChars = 0;
              for (var i=0; i < tags.length; i++) {
                var tag = tags[i];
                var style = Paperpile.main.tagStore.getAt(Paperpile.main.tagStore.find('tag',tag));
                if (style != null) {
                  style = style.get('style');
                  totalChars += tag.length;
                  returnMe += '<div class="pp-tag-grid-inline pp-tag-style-'+style+'">'+tag+'&nbsp;</div>&nbsp;';
                }
              }
//              returnMe += '</div>';
              if (tags.length > 0)
                returnMe = "&nbsp;&nbsp;&nbsp;" + returnMe;
              return returnMe;
            }          
            }
        ).compile();

        this.iconTemplate = new Ext.XTemplate(
            '<div class="pp-grid-info">',
            '<tpl if="_imported">',
            '<tpl if="trashed==0">',
            '<div class="pp-grid-status pp-grid-status-imported" ext:qtip="[<b>{_citekey}</b>]<br>added {_createdPretty}"></div>',
            '</tpl>',
            '<tpl if="trashed==1">',
            '<div class="pp-grid-status pp-grid-status-deleted" ext:qtip="[<b>{_citekey}</b>]<br>deleted {_createdPretty}"></div>',
            '</tpl>',
            '</tpl>',
//            '<div>',
            '<tpl if="pdf">',
            '<div class="pp-grid-status pp-grid-status-pdf" ext:qtip="<b>{pdf}</b><br>{_last_readPretty}"></div>',
            '</tpl>',
            '<tpl if="attachments">',
            '<div class="pp-grid-status pp-grid-status-attachments" ext:qtip="{attachments} attached file(s)"></div>',
            '</tpl>',
            '<tpl if="annote">',
            '<div class="pp-grid-status pp-grid-status-notes" ext:qtip="{_notes_tip}"></div>',
            '</tpl>',
            '</div>'
//            '</div>'
        ).compile();

        this.actions={
            'NEW': new Ext.Action({
                text: 'New',
                handler: this.newEntry,
                scope: this,
                cls: 'x-btn-text-icon add',
                disabled:true,
                itemId:'new_button',
                tooltip: 'Create a new reference and add it to your library',
            }),

            'EDIT': new Ext.Action({
                text: 'Edit',
                handler: this.editEntry,
                scope: this,
                cls: 'x-btn-text-icon edit',
                disabled:true,
                itemId:'edit_button',
                tooltip: 'Edit citation data of the selected reference',
            }),

            'TRASH': new Ext.Action({
                text: 'Delete',
                handler: function(){
                    this.deleteEntry('TRASH');
                },
                scope: this,
                cls: 'x-btn-text-icon delete',
                disabled:true,
                itemId:'delete_button',
                tooltip: 'Move selected references to Trash',
            }),

            'IMPORT': new Ext.Action({
                text: 'Import',
                handler: function() {this.insertEntry()},
                scope: this,
                cls: 'x-btn-text-icon add',
                disabled:true,
                itemId:'import_button',
                tooltip: 'Import selected references to your library.',
            }),

            'IMPORT_ALL': new Ext.Action({
                text: 'Import all',
                handler: function() {this.insertAll()},
                scope: this,
                cls: 'x-btn-text-icon add-all',
                disabled:true,
                itemId:'import_button',
                tooltip: 'Import all references to your library.',
            }),

            'EXPORT': new Ext.Action({
                text: 'Export',
                handler: this.exportEntry,
                scope: this,
                disabled:true,
                itemId:'export_button'
            }),

            'SELECT_ALL': new Ext.Action({
                text: 'Select all',
                handler: this.selectAll,
                scope: this,
                disabled:true,
                itemId:'select_all_button'
            }),

            'FORMAT': new Ext.Action({
                text: 'Format',
                handler: this.formatEntry,
                scope: this,
                disabled:true,
                itemId:'format_button'
            }),

            'SAVE_AS_ACTIVE': new Ext.Action({
                text: 'Save as active view',
                handler: Paperpile.main.tree.newActive,
                scope: Paperpile.main.tree,
                disabled:true,
                itemId:'save_active_button'
					     }),

            'VIEW_PDF': new Ext.Action({
                text: 'View PDF',
                handler: this.openPDF,
                scope: this,
                disabled:true,
		iconCls:'pp-icon-import-pdf',
                itemId:'view_pdf_button'
					     }),
            'VIEW_AUTHOR': new Ext.Action({
                text: 'First author',
                handler: this.viewByAuthor,
                scope: this,
                disabled:false,
                itemId:'view_author_button'
					     }),
            'VIEW_JOURNAL': new Ext.Action({
                text: 'Journal',
                handler: this.viewByJournal,
                scope: this,
                disabled:true,
                itemId:'view_journal_button'
					     }),
            'VIEW_YEAR': new Ext.Action({
                text: 'Year',
                handler: this.viewByYear,
                scope: this,
                disabled:true,
                itemId:'view_year_button'
					     }),
        };


        var tbar=[{xtype:'tbfill'},
                  this.actions['NEW'],
                  this.actions['IMPORT'],
                  this.actions['IMPORT_ALL'],
                  this.actions['TRASH'],
                  this.actions['EDIT'],
                  { xtype:'button',
                    itemId: 'more_menu',
                    menu:new Ext.menu.Menu({
                        items:[
                            this.actions['EXPORT'],
                            this.actions['SELECT_ALL'],
                            this.actions['SAVE_AS_ACTIVE'],
                        ]
                    })
                  }
                 ];

        this.contextMenu=new Ext.menu.Menu({
            items:[
                this.actions['VIEW_PDF'],
		'-',
		this.actions['IMPORT'],
                this.actions['TRASH'],
                this.actions['EDIT'],
                this.actions['EXPORT'],
//                this.actions['FORMAT'],
                this.actions['SELECT_ALL'],
		'-',
		{ text:'Search by...',
		  menu:{
		    items:[
		      this.actions['VIEW_AUTHOR'],
		      this.actions['VIEW_JOURNAL'],
		      this.actions['VIEW_YEAR']
		    ]
		  }
		}
            ]
        });

        this.on('rowcontextmenu',
                function(grid, row, e){
                    this.getSelectionModel().selectRow(row);
		    this.updateButtons();
                    this.contextMenu.showAt(e.getXY());
                }, this, {stopEvent:true});


        var renderPub=function(value, p, record){

            // Can possibly be speeded up with compiling the template.

            record.data._notes_tip=Ext.util.Format.stripTags(record.data.annote);
            record.data._citekey=Ext.util.Format.ellipsis(record.data.citekey,18);


            return this.pubTemplate.apply(record.data);

        };

        var renderIcons=function(value, p, record){

            // Can possibly be speeded up with compiling the template.

            record.data._notes_tip=Ext.util.Format.stripTags(record.data.annote);
            record.data._citekey=Ext.util.Format.ellipsis(record.data.citekey,18);

            record.data._createdPretty = Paperpile.utils.prettyDate(record.data.created);

            if (record.data.last_read){
                record.data._last_readPretty = 'Last read: '+ Paperpile.utils.prettyDate(record.data.last_read);
            } else {
                record.data._last_readPretty='Never read';
            }


            return this.iconTemplate.apply(record.data);

        }


        Ext.apply(this, {
            ddGroup  : 'gridDD',
            enableDragDrop   : true,
            itemId:'grid',
            store: _store,
            bbar: _pager,
            tbar: tbar,
            enableHdMenu : false,
            autoExpandColumn:'publication',

            columns:[
                {header: "Papers",
                 id: 'icons',
                 dataIndex: 'title',
                 renderer:renderIcons.createDelegate(this),
                 width: 70,
                 sortable:false,
                 resizable: false,
                },
                {header: "",
                 id: 'publication',
                 dataIndex: 'title',
                 renderer: renderPub.createDelegate(this),
                 resizable: false,
                 sortable:false,
                 scope:this,
                },
            ],
        });

        Paperpile.PluginGrid.superclass.initComponent.apply(this, arguments);


        this.on('beforedestroy', this.onClose, this);

        this.on('rowdblclick', this.onDblClick, this);



        // A bug in ExtJS 2.2 does not allow clearing a multiple selection when an item is clicked
        // This hack should become unnecessary in future versions of ExtJS
        this.on('rowclick',
                function( grid, rowIndex, e ){

                    if (e.hasModifier()){
                        return;
                    }
                    var sm=this.getSelectionModel();
                    if (sm.getCount()>1 && sm.isSelected(rowIndex)){
                        sm.clearSelections();
                    }
                }, this);

        this.on('click',
                function( e ){
                    if (Ext.get(e.target).hasClass('pp-grid-status-notes')){
                        this.findParentByType(Paperpile.PubView).items.get('center_panel').items.get('data_tabs').showNotes();
                    }
                }, this);





        this.store.on('loadexception',
                      function(exception, options, response, error){
                          Paperpile.main.onError(response);
                      });


        this.store.on('load', 
                      function() {
                          // If nothing is selected, select first row
                          if (!this.getSelectionModel().getSelected()){
                              this.getSelectionModel().selectRow(0);
                          };
                          this.updateButtons();
                      },
                      this);

    },


    onStoreLoad: function() {
        // If nothing is selected, select first row
        if (!this.getSelectionModel().getSelected()){
            this.getSelectionModel().selectRow(0);
        };// else {
            // else re-focus on last selection
          //  var row=this.store.indexOf(this.getSelectionModel().getSelected());
           // (function(){this.getView().focusRow( row )}).defer(1000,this);
           // console.log(row);
      //  }


    },


    afterRender: function(){

        this.getSelectionModel().on('rowselect',
                                    function(sm, rowIdx, r){
                                        var container= this.findParentByType(Paperpile.PubView);
                                        this.updateButtons();
                                        container.onRowSelect(sm, rowIdx, r);
                                        this.completeEntry();
                                    },this);

        /*
        this.getSelectionModel().on('rowdeselect',
                                    function(sm, rowIdx, r){
                                        var container= this.findParentByType(Paperpile.PubView);
                                        container.onRowSelect(sm, rowIdx, r);
                                    },this);
*/

        this.el.on({
			contextmenu:{fn:function(){return false;},stopEvent:true}
		});

        Paperpile.PluginGrid.superclass.afterRender.apply(this, arguments);

    },

    getDragDropText: function(){

        var num = this.getSelectionModel().getCount();

        if ( num == 1){
            var key=this.getSelectionModel().getSelected().get('citekey');
            if (key){
                return "["+key+"]";
            } else {
                return " 1 selected reference";
            }
        } else {
            return num+" selected references";
        }
    },

    updateButtons: function(){

        var imported=this.getSelection('IMPORTED').length;
        var notImported=this.getSelection('NOT_IMPORTED').length;
        var selected=imported+notImported;

        if (selected == 0){
            for (b in this.actions){
                this.actions[b].disable();
            }
            this.actions['NEW'].enable();
        }

        if (selected > 0 ){
            this.actions['NEW'].enable();
            this.actions['EXPORT'].enable();
            this.actions['FORMAT'].enable();
            this.actions['SAVE_AS_ACTIVE'].enable();
	        this.actions['VIEW_YEAR'].enable();
	        this.actions['VIEW_JOURNAL'].enable();
	        this.actions['VIEW_AUTHOR'].enable();

            if (this.getSelectionModel().getSelected().data.pdf) {
	            this.actions['VIEW_PDF'].setDisabled(false);
            } else {
	            this.actions['VIEW_PDF'].setDisabled(true);
            }
        }

        if (selected == 1){
            this.actions['EDIT'].setDisabled(imported==0);
            this.actions['IMPORT'].setDisabled(imported);
            this.actions['TRASH'].setDisabled(imported==0);
        }

        if (selected > 1 ){
            this.actions['EDIT'].disable();
            this.actions['TRASH'].setDisabled(imported==0);
            this.actions['IMPORT'].setDisabled(notImported==0);
        }


        this.actions['SELECT_ALL'].setDisabled(this.allSelected);
    },

   // Small helper functions to get the index of a given item in the toolbar configuration array
   // We have to use the text instead of itemId. Actions do not seem to support itemIds.
   // A better solution should be possible with ExtJS 3

    getButtonIndex: function(itemId){
        var tbar=this.getTopToolbar();
        for (var i=0; i<tbar.length;i++){
            if (tbar[i].getText){
                if (tbar[i].getText() == itemId) return i;
            }
        }
    },

    // Returns list of sha1s for the selected entries, either ALL, IMPORTED, NOT_IMPORTED

    getSelection: function(what){

        if (!what) what='ALL';

        if (this.allSelected){
            return 'ALL';
        }

        var selection=[];

        this.getSelectionModel().each(
            function(record){
                if ((what == 'ALL') ||
                    (what == 'IMPORTED' && record.get('_imported')) ||
                    (what == 'NOT_IMPORTED' && !record.get('_imported'))){
                    selection.push(record.get('sha1'));
                }
            });

        return selection;

    },

    // Some plugins use a two-stage process for showing entries: First
    // only minimal info is scraped from site to build list quickly
    // without harassing the site too much. Then the details are
    // fetched only when user clicks the entry.

    completeEntry: function(callback,scope){

        var data=this.getSelectionModel().getSelected().data;

        // _details_link indicates if an entry still needs to be completed or not
        if (data._details_link){

            Paperpile.status.showBusy('Looking up bibliographic data');

            var sha1=this.getSelectionModel().getSelected().data.sha1;

            Ext.Ajax.request({
                url: Paperpile.Url('/ajax/crud/complete_entry'),
                params: { sha1: sha1,
                          grid_id: this.id,
                        },
                method: 'GET',
                success: function(response){
                    var json = Ext.util.JSON.decode(response.responseText);
                    var record=this.store.getAt(this.store.find('sha1',sha1));
                    record.beginEdit();
                    for ( var i in json.data){
                        record.set(i,json.data[i]);
                    }
                    record.endEdit();

                    this.findParentByType(Paperpile.PubView).onRowSelect();

                    Paperpile.status.clearMsg();

                    if (callback) callback.createDelegate(scope)();
                },
                failure: Paperpile.main.onError,
                scope:this
            });
        } else {
            if (callback) callback.createDelegate(scope)();
        }

    },


    //
    // Inserts the entry into local database. Optionally a callback function+scope can be given;
    // If no callback function is needed make sure function is called with insertEntry()
    //

    insertEntry: function(callback,scope){

        var selection=this.getSelection('NOT_IMPORTED');

        if (selection.length==0) return;

        var many=false;

        if (selection == 'ALL'){
            many=true;
        } else {
            if (selection.length > 10){
                many=true;
            }
        }

        if (many){
            Paperpile.status.showBusy('Importing references to library');
        }

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/crud/insert_entry'),
            params: { selection: selection,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);

                this.store.suspendEvents();
                for (var sha1 in json.data){
                    var record=this.store.getAt(this.store.find('sha1',sha1));
                    if (!record) continue;
                    record.beginEdit();
                    record.set('citekey',json.data[sha1].citekey);
                    record.set('created', json.data[sha1].created);
                    record.set('_imported',1);
                    record.set('_rowid', json.data[sha1]._rowid);
                    record.endEdit();
                }
                this.store.resumeEvents();
                this.store.fireEvent('datachanged',this.store);

                this.updateButtons();

                if (callback){
                    callback.createDelegate(scope,[json.data])();
                }

                Paperpile.main.onUpdateDB();

                Paperpile.status.clearMsg();

            },
            failure: Paperpile.main.onError,
            scope:this
        });

    },

    insertAll: function(){

        this.allSelected=true;
        this.insertEntry(function(){
            this.allSelected=false;
            var container= this.findParentByType(Paperpile.PubView);
            container.onRowSelect();
        },this);

    },

    // If trash is set entries are moved to trash, otherwise they are
    // deleted completely
    // mode: TRASH ... move to trash
    //       RESTORE ... restore from trash
    //       DELETE ... delete permanently

    deleteEntry: function(mode){

        selection=this.getSelection();

        var index=this.store.indexOf(this.getSelectionModel().getSelected());

        var many=false;

        //if (selection == 'ALL'){
        //    many=true;
        //} else {
        //    if (selection.length > 10){
        //        many=true;
        //    }
        //}

        //if (many){
        if (mode == 'DELETE'){
            Paperpile.status.showBusy('Deleting references from library');
        }
        if (mode == 'TRASH'){
            Paperpile.status.showBusy('Moving references to Trash');
        }

        if (mode == 'RESTORE'){
            Paperpile.status.showBusy('Restoring references');
        }

       
        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/crud/delete_entry'),
            params: { selection: selection,
                      grid_id: this.id,
                      mode: mode,
                    },
            method: 'GET',
            success: function(response){

                var num_deleted = Ext.util.JSON.decode(response.responseText).num_deleted;

                this.updateButtons();
                this.store.suspendEvents();
                if (selection == 'ALL'){
                    this.store.removeAll();
                } else {
                    for (var i=0;i<selection.length;i++){
                        this.store.remove(this.store.getAt(this.store.find('sha1',selection[i])));
                    }
                    this.getSelectionModel().selectRow(index);
                }

                this.store.resumeEvents();
                this.store.fireEvent('datachanged',this.store);

                var container= this.findParentByType(Paperpile.PubView);
                if (this.getSelectionModel().getCount()!=0){
                    container.onRowSelect();
                } else {
                    container.onEmpty('');
                }

                if (mode == 'TRASH'){
                    var msg= num_deleted + ' references moved to Trash';

                    if (num_deleted == 1){
                        msg="1 reference moved to Trash"
                    }

                    Paperpile.status.updateMsg(
                        { msg: msg,
                          action1: 'Undo',
                          callback: function(action){
                              // TODO: does not show up, don't know why:
                              Paperpile.status.showBusy('Undo...');
                              Ext.Ajax.request({
                                  url: Paperpile.Url('/ajax/crud/undo_trash'),
                                  method: 'GET',
                                  success: function(){
                                      Paperpile.main.onUpdateDB();
                                      Paperpile.status.clearMsg();
                                  }, 
                                  scope:this
                              });
                          },
                          scope: this,
                          hideOnClick: true,
                        }
                    );
                } else {
                    Paperpile.status.clearMsg();
                }

                Paperpile.main.onUpdateDB();

            },
            failure: Paperpile.main.onError,
            scope: this
        });

    },

    exportEntry: function(){

        selection=this.getSelection();

        var window=new Paperpile.ExportWindow({grid_id:this.id,
                                               selection:selection,
                                              });

        window.show();

    },

    editEntry: function(){

        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().data.sha1;

        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');

        var form=new Paperpile.Forms.PubEdit({data:this.getSelectionModel().getSelected().data,
                                              grid_id: this.id,
                                              spotlight: true,
                                              callback: function(status,data){
                                                  east_panel.remove('pub_edit');
                                                  if (oldSize<500) east_panel.setSize(oldSize);
                                                  east_panel.doLayout();
                                                  east_panel.getLayout().setActiveItem('overview');
                                                  east_panel.showBbar();
                                                  if (status == 'SAVE'){
                                                      this.updateData(data);
                                                      this.findParentByType(Paperpile.PubView).onRowSelect();
                                                      Paperpile.status.clearMsg();
                                                  }
                                              },
                                              scope:this
                                             });

        var oldSize=east_panel.getInnerWidth();
        if (oldSize<500) east_panel.setSize(500);
        east_panel.hideBbar();
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');
    },

    newEntry: function(){
        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');

        var form=new Paperpile.Forms.PubEdit({data:{pubtype:'ARTICLE'},
                                              grid_id: null,
                                              spotlight: true,
                                              callback: function(status,data){
                                                  east_panel.remove('pub_edit');
                                                  if (oldSize<500) east_panel.setSize(oldSize);
                                                  east_panel.doLayout();
                                                  east_panel.getLayout().setActiveItem('overview');
                                                  east_panel.showBbar();
                                                  if (status == 'SAVE'){
                                                      this.store.reload();
                                                      Paperpile.status.clearMsg();
                                                  }
                                              },
                                              scope:this
                                             });

        var oldSize=east_panel.getInnerWidth();

        if (oldSize<500) east_panel.setSize(500);

        east_panel.hideBbar();
        east_panel.add(form);
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pub_edit');

    },


    formatEntry: function(){

        selection=this.getSelection();

        Paperpile.main.tabs.add(new Paperpile.Format(
            {grid_id:this.id,
             selection:selection,
            }
        ));
    },




    // Update specific fields of specific entries to avoid complete
    // reload of everything data is a hash of a hash with sha1 as the
    // first key and the other fields that need to be udpated as the
    // other keys

    updateData: function(data){
        this.store.suspendEvents();
        for (var sha1 in data){
            var record=this.store.getAt(this.store.find('sha1',sha1));
            if (!record) continue;
            var update=data[sha1];
            record.beginEdit();
            for (var field in update){
                record.set(field,update[field]);
            }
            record.endEdit();
        }
        this.store.resumeEvents();
        this.store.fireEvent('datachanged',this.store);
    },


    selectAll: function(){
        this.allSelected=true;
        this.getSelectionModel().selectAll();
        this.getSelectionModel().on('selectionchange',
                                    function(sm){
                                        this.allSelected=false;
                                    }, this, {single:true});
        this.getSelectionModel().on('rowdeselect',
                                    function(sm){
                                        sm.clearSelections();
                                    }, this, {single:true});

    },

    viewByAuthor:function() {
      var authors = sm.getSelected().data.authors;
      console.log(authors);
      var arr = authors.split(/\s+and\s+/,2);
      if (arr.length > 1) {
	var first_author = arr[0];
	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'author:'+'"'+first_author+'"'},
					 first_author,
					 '',
					 first_author
					);
      }
    },
    viewByYear:function() {
      var year = sm.getSelected().data.year;
      if (year) {
	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'year:'+'"'+year+'"'},
					 year,
					 '',
					 year
					);
      }
    },
    viewByJournal:function() {
      var journal = sm.getSelected().data.journal;
      if (journal) {
	Paperpile.main.tabs.newPluginTab('DB',
					 {plugin_mode:'FULLTEXT',
					 plugin_query:'journal:'+'"'+journal+'"'},
					 journal,
					 '',
					 journal
					);
      }
    },

    openPDF: function() {
        var sm = this.getSelectionModel();
        if (sm.getSelected().data.pdf){
            var pdf=sm.getSelected().data.pdf;
            var path=Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf );
            Paperpile.main.tabs.newPdfTab({file:path, title:pdf});
            Paperpile.main.inc_read_counter(sm.getSelected().data._rowid);
        }
    },

    onDblClick: function( grid, rowIndex, e ){

        var sm=this.getSelectionModel();
        if (sm.getCount() == 1){
            if (!sm.getSelected().data._imported){
                this.insertEntry();
                return;
            }
	    this.openPDF();
         }
    },

    onClose: function(cont, comp){
        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/plugins/delete_grid'),
            params: { grid_id: this.id,
                    },
            method: 'GET'
        });
    },
});








