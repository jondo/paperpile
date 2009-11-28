Paperpile.PluginGrid = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGrid.superclass.constructor.call(this, {

  });

  this.on('rowcontextmenu', this.onContextClick, this);
};


Ext.extend(Paperpile.PluginGrid, Ext.grid.GridPanel, {

    plugin_query:'',
    closable:true,
    region:'center',
    limit: 25,
    allSelected:false,
    itemId:'grid',
    sidePanel:null,

    tagStyles:{},

    author_shrink_threshold: 255,
                                    
    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: Paperpile.Url('/ajax/plugins/resultsgrid'),
                timeout: 10000000, // Think about this, different plugins need different timeouts...
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
            emptyMsg: "No papers to display"
        });
      
        this.pubTemplate = new Ext.XTemplate(
            '<div class="pp-grid-data" sha1="{sha1}">',
            '<div>',
            '<span class="pp-grid-title {_highlight}">{title}</span>{[this.tagStyle(values.tags)]}',
            '</div>',
	    '<tpl if="_authors_display && _long_authorlist">',
    	      '<p class="pp-grid-authors">',
  	      '<tpl if="!_shrink_authors">',
		'<span class="pp-author-full">{_authors_display}</span>',
	      '</tpl>',
	      '<tpl if="_shrink_authors">',
		'<span class="pp-author-short">{_authors_display_short} ... {_authors_display_short_tail}</span>',
	      '</tpl>',
	      '</p>',
	    '</tpl>',
            '<tpl if="_authors_display && !_long_authorlist">',
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
              '<tpl if="pdf">',
                '<div class="pp-grid-status pp-grid-status-pdf" ext:qtip="<b>{pdf}</b><br/>{_last_readPretty}<br/><img src=\'/ajax/pdf/render/{pdf_path}/0/0.2\' width=\'100\'/>"></div>',
              '</tpl>',
              '<tpl if="attachments">',
                '<div class="pp-grid-status pp-grid-status-attachments" ext:qtip="{attachments} attached file(s)"></div>',
              '</tpl>',
              '<tpl if="annote">',
                '<div class="pp-grid-status pp-grid-status-notes" ext:qtip="{_notes_tip}"></div>',
              '</tpl>',
            '</div>'
        ).compile();

        this.actions={
            'EDIT': new Ext.Action({
                text: 'Edit',
                handler: this.handleEdit,
                scope: this,
                cls: 'x-btn-text-icon edit',
		icon: '/images/icons/pencil.png',
                itemId:'edit_button',
                tooltip: 'Edit citation data of the selected reference'
            }),

            'DELETE': new Ext.Action({
                text: 'Delete',
                handler: this.handleDelete,
                scope: this,
                cls: 'x-btn-text-icon',
                itemId:'delete_button',
                tooltip: 'Move selected references to Trash'
            }),

            'IMPORT': new Ext.Action({
                text: 'Import',
                handler: function() {this.insertEntry();},
                scope: this,
                iconCls:'pp-icon-add',
                itemId:'import_button',
                tooltip: 'Import selected references to your library.'
            }),

            'IMPORT_ALL': new Ext.Action({
                text: 'Import all',
                handler: function() {this.insertAll();},
                scope: this,
		iconCls:'pp-icon-add-all',
                itemId:'import_all_button',
                tooltip: 'Import all references to your library.'
            }),

            'EXPORT': new Ext.Action({
                text: 'Export',
                handler: this.handleExport,
                scope: this,
                itemId:'export_button'
            }),

            'SELECT_ALL': new Ext.Action({
                text: 'Select all',
                handler: this.selectAll,
                scope: this,
                itemId:'select_all'
            }),

            'FORMAT': new Ext.Action({
                text: 'Format',
                handler: this.formatEntry,
                scope: this,
                itemId:'format_button'
            }),

            'SAVE_AS_ACTIVE': new Ext.Action({
                text: 'Save as active view',
                handler: this.handleSaveActive,
                scope: this,
                itemId:'save_active_button'
					     }),

            'VIEW_PDF': new Ext.Action({
                text: 'View PDF',
                handler: this.openPDF,
                scope: this,
		iconCls:'pp-icon-import-pdf',
                itemId:'view_pdf'
					     }),
            'VIEW_AUTHOR': new Ext.Action({
                text: 'First author',
                handler: this.viewByAuthor,
                scope: this,
                itemId:'view_author_button'
					     }),
            'VIEW_JOURNAL': new Ext.Action({
                text: 'Journal',
                handler: this.viewByJournal,
                scope: this,
                itemId:'view_journal_button'
					     }),
            'VIEW_YEAR': new Ext.Action({
                text: 'Year',
                handler: this.viewByYear,
                scope: this,
                itemId:'view_year_button'
	    }),
	    'SEARCH_TB_FILL': new Ext.Toolbar.Fill({
		width:'10px',
		itemId:'search_tb_fill'
	    })
        };

	this.actions['SAVE_MENU'] = new Ext.Button({
	  itemId:'save_menu',
	  iconCls:'pp-icon-save',
	  cls:'x-btn-text-icon',
	  menu:{
	    items:[
            { text:'Save as Active View',
	      iconCls:'pp-icon-glasses',
	      handler:this.handleSaveActive,
	      scope:this
	    },
	    { text:'Export contents to file',
	      iconCls:'pp-icon-disk',
	      handler:this.handleExport,
	      scope:this
	    }
	  ]}
	});

        var tbar=[
	  this.actions['SEARCH_TB_FILL'],
	  this.actions['SAVE_MENU']
/*	  {itemId:this.actions['SAVE_MENU'].itemId,
	   iconCls:'pp-icon-save',
	   menu:{items:[
            { text:'Save as Active View',
	      handler:this.actions['SAVE_AS_ACTIVE'].handler
	    },
	    { text:'Export contents to file',
	      handler:this.actions['EXPORT'].handler
	    }
	  ]}
	  }
*/
        ];

        var renderPub=function(value, p, record){
            // Can possibly be speeded up with compiling the template.
            record.data._notes_tip=Ext.util.Format.stripTags(record.data.annote);
            record.data._citekey=Ext.util.Format.ellipsis(record.data.citekey,18);

	    // Shrink very long author lists.
	    record.data._long_authorlist = 0;
	    var ad = record.data._authors_display;
	    if (record.data._shrink_authors == null)
	      record.data._shrink_authors = 1;
	    if (ad.length > this.author_shrink_threshold) {
	      record.data._long_authorlist = 1;
	      record.data._authors_display_short = ad.substring(0,this.author_shrink_threshold);
	      record.data._authors_display_short_tail = ad.substring(ad.lastIndexOf(","),ad.length);
	    } 
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

            record.data.pdf_path=Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, record.data.pdf);
            return this.iconTemplate.apply(record.data);
        };

        Ext.apply(this, {
            ddGroup  : 'gridDD',
            enableDragDrop   : true,
	    appendOnly:true,
            itemId:'grid',
            store: _store,
            bbar: _pager,
            tbar: tbar,
            enableHdMenu : false,
            autoExpandColumn:'publication',

            columns:[
                {header: "",
                 id: 'icons',
                 dataIndex: 'title',
                 renderer:renderIcons.createDelegate(this),
                 width: 50,
                 sortable:false,
                 resizable: false
                },
                {header: "",
                 id: 'publication',
                 dataIndex: 'title',
                 renderer: renderPub.createDelegate(this),
                 resizable: false,
                 sortable:false,
                 scope:this
                }
            ]
        });

        Paperpile.PluginGrid.superclass.initComponent.call(this);

	this.on({
	  // Delegate to class methods.
	  afterrender:{scope:this,fn:this.myAfterRender},
	  beforedestroy:{scope:this,fn:this.onClose},
	  rowdblclick:{scope:this,fn:this.onDblClick},
	  nodedragover:{scope:this,fn:this.onNodeDrag},
	  // Inline handlers.
	  click:{scope:this,
	    fn:function(e) {
              if (Ext.get(e.target).hasClass('pp-grid-status-notes')) {
		this.findParentByType(Paperpile.PubView).items.get('center_panel').items.get('data_tabs').showNotes();
              }
	    }
	  }
	});

	this.store.on({
	  loadexception:{scope:this,
	    fn:function(exception,options,response,error) {
	      Paperpile.main.onError(response);
	    }
	  },
	  load:{scope:this,fn:this.onStoreLoad}
	});
    },

    onNodeOver: function(target, dd, e, data) {
      if (data.node != null) {
	return "x-dd-drop-ok-add";
      } else {
	return Ext.dd.DropZone.prototype.dropNotAllowed;
      }
    },

    onNodeDrop: function(target, dd, e, data) {
      if (data.node != null) {
	var r = e.getTarget(this.grid.getView().rowSelector);

	var index = this.grid.getView().findRowIndex(r);
	var record = this.grid.store.getAt(index);
	var tagName = data.node.text;

	Ext.Ajax.request({
	  url: Paperpile.Url('/ajax/crud/add_tag'),
	  params: {
	    grid_id:this.grid.id,
            selection: record.get('sha1'),
            tag: tagName
	  },
	  method: 'GET',
	  success: function(response){
	    var json = Ext.util.JSON.decode(response.responseText);
	    this.grid.updateData(json.data);
	  },
	  failure: Paperpile.main.onError,
	  scope: this
	});
	return true;
      } else {
	return false;
      }
    },

    addGridExpanders: function() {
      var els = Ext.select(".pp-author-expander");
      els.on({click:{
	fn: function(e) {
	  var el = Ext.get(e.getTarget());
	  var p = el.findParent(".pp-grid-data",10,true);

	  var sha1 = p.getAttribute("sha1");
	  var record=this.store.getAt(this.store.find('sha1',sha1));
	  
	  if (el.findParent("span",10,true).hasClass('pp-author-short')) {
	    // Already showing short name. Hide short, show full.
	    record.set("_shrink_authors",1);
	  } else {
	    record.set("_shrink_authors",0);
	  }
	  this.updateGrid();
	},scope:this
      }});
    },

    onStoreLoad: function() {

      this.addGridExpanders();

      var container= this.findParentByType(Paperpile.PubView);
      var ep = container.items.get('east_panel');
      var tb_side = ep.getBottomToolbar();
      var activeTab=ep.getLayout().activeItem.itemId;
      if (this.store.getCount()>0) {
        if (activeTab === 'about') {
          ep.getLayout().setActiveItem('overview');
          activeTab='overview';
        }
      }  else {
        container.onEmpty('');
        if (this.sidePanel) {
          ep.getLayout().setActiveItem('about');
          activeTab='about';
        }
      }
      tb_side.items.get(activeTab+'_tab_button').toggle(true);
      container.updateButtons();

      // If nothing is selected, select first row
      if (!this.getSelectionModel().getSelected()) {
        this.getSelectionModel().selectRow(0);
      };// else {
            // else re-focus on last selection
          //  var row=this.store.indexOf(this.getSelectionModel().getSelected());
           // (function(){this.getView().focusRow( row )}).defer(1000,this);
           // console.log(row);
      //  }
      this.updateButtons();
    },

    myAfterRender: function(ct){

      this.getSelectionModel().on('rowselect',
	function(sm, rowIdx, r) {
          var container= this.findParentByType(Paperpile.PubView);
          this.completeEntry();
        },this);
      this.getSelectionModel().on('selectionchange',
	function(sm) {
	  var container= this.findParentByType(Paperpile.PubView);
          this.updateButtons();
          container.onRowSelect();
	},this);	

      var map=new Ext.KeyMap(this.el, {
	key: Ext.EventObject.DELETE,
	handler: function() {
	  var imported=this.getSelection('IMPORTED').length;
          if (imported>0) {
            // Handle both cases of normal grids and Trash grid
            if (this.getSelectionModel().getSelected().get('trashed')) {
              this.deleteEntry('DELETE');
            } else {
              this.deleteEntry('TRASH');
            }
          }
        },
	scope : this
      });

      this.dz = new Paperpile.GridDropZone(this,{ddGroup:this.ddGroup});
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

    onContextClick: function(grid,index,e) {
      if (this.context == null) {
        this.context = new Ext.menu.Menu({
	  id:'pp-grid-context',
	  items:[
            this.actions['VIEW_PDF'],
	    '-',
	    this.actions['EDIT'],
	    this.actions['DELETE'],
            this.actions['SELECT_ALL'],
	    '-',
	    { text:'Search by...',
	      itemId:'search_by',
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
      }

      e.stopEvent();
      var record = this.store.getAt(index);
      this.context.items.each(function(item,index,length) {
	// TODO: logic to decide when to show different items.
	if (this.shouldShowContextItem(item,record)) {
	  item.setDisabled(false);
	} else {
	  item.setDisabled(true);
	}
      },this);

      if (!this.getSelectionModel().isSelected(index)) {
	this.getSelectionModel().selectRow(index);
      }

      
      (function(){
	 this.context.showAt(e.getXY());
	 this.updateButtons();
       }).defer(20,this);
    },

    shouldShowContextItem: function(menuItem,record) {
      // To override with extending classes.
      // This mechanism also gives us a chance to modify the context menu items at each right-click.

      if (menuItem.itemId == this.actions['VIEW_PDF'].itemId && record.data.pdf == '') {
	// Gray out if no PDF available to view.
	return false;
      }

      if (menuItem.itemId == this.actions['SELECT_ALL'].itemId && this.allSelected) {
	// Gray out if already all selected.
	return false;
      }

      return true;
    },

    updateButtons: function(){

      var tbar = this.getTopToolbar();

      tbar.items.each(function(item,index,length) {
	if (this.shouldShowButton(item)) {
	  item.setDisabled(false);
	} else {
	  item.setDisabled(true);
	}
      },this);
    },

    shouldShowButton: function(menuItem) {
      if (menuItem.itemId == this.actions['SELECT_ALL'].itemId && this.allSelected) {
	return false;
      }
      return true;
    },

    updateGrid: function() {
      Paperpile.main.onUpdateDB();
    },

   // Small helper functions to get the index of a given item in the toolbar configuration array
   // We have to use the text instead of itemId. Actions do not seem to support itemIds.
   // A better solution should be possible with ExtJS 3

    getButtonIndex: function(itemId){
        var tbar=this.getTopToolbar();
        for (var i=0; i<tbar.items.length;i++){
	  var item = tbar.items.itemAt(i);
	  if (item.itemId == itemId) return i;
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
            timeout: 10000000,
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

    handleDelete: function() {
      this.deleteEntry('TRASH');
    },

    handleSaveActive: function() {
      Paperpile.main.tree.newActive();
    },

    handleExport: function() {
        selection=this.getSelection();
        var window=new Paperpile.ExportWindow({grid_id:this.id,
                                               selection:selection,
                                              });
        window.show();
    },

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
            timeout: 10000000,
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

    handleEdit: function(){

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


    batchDownload: function(){

        selection=this.getSelection();

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/crud/batch_download'),
            params: { selection: selection,
                      grid_id: this.id,
                    },
            method: 'GET',
            timeout: 10000000,
            success: function(response){
                Paperpile.main.tabs.showQueueTab();
            }
        });

        
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
      var sm = this.getSelectionModel();

      var authors = sm.getSelected().data.authors;
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
        var sm = this.getSelectionModel();
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
        var sm = this.getSelectionModel();
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

Paperpile.GridDropZone = function(grid,config) {
  this.grid = grid;
  Paperpile.GridDropZone.superclass.constructor.call(this, grid.view.scroller.dom,config);
}

Ext.extend(Paperpile.GridDropZone, Ext.dd.DropZone, {
  getTargetFromEvent: function(e) {
    return e.getTarget(this.grid.getView().rowSelector);
  },

  onNodeEnter : function(target, dd, e, data){ 
  },

  onNodeOver : function(target, dd, e, data){ 
    return this.grid.onNodeOver.call(this,target,dd,e,data);
  },

  onNodeDrop: function(target, dd, e, data) {
    return this.grid.onNodeDrop.call(this,target,dd,e,data);
  },
  containerScroll:true
});

Ext.reg('pp-plugin-grid', Paperpile.PluginGrid);