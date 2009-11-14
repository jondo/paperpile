Paperpile.ImportGridPlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.ImportGridPlugin, Ext.util.Observable, {
  init:function(grid) {
    grid.actions['IMPORT'] = new Ext.Action({
      text: 'Import',
      handler: function() {this.insertEntry();},
      scope: grid,
      iconCls:'pp-icon-add',
      itemId:'import_button',
      tooltip: 'Import selected references to your library.'
    });

    grid.actions['IMPORT_ALL'] = new Ext.Action({
      text: 'Import all',
      handler: function() {this.insertAll();},
      scope: grid,
      iconCls:'pp-icon-add-all',
      itemId:'import_all_button',
      tooltip: 'Import all references to your library.'
    });

    Ext.apply(grid,{
      addImportButtons: function() {
	var tbar = this.getTopToolbar();

	// Add to top toolbar.
	var filterFieldIndex = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
	tbar.insertButton(filterFieldIndex+1,this.actions['IMPORT']);
	tbar.insertButton(filterFieldIndex+1,this.actions['IMPORT_ALL']);

      },

      createContextMenu: grid.createContextMenu.createSequence(function() {
	// Add to context menu.
	//var selectAllIndex = this.getContextIndex(this.actions['SELECT_ALL'].itemId);
	this.context.insert(0,this.actions['IMPORT']);
      },grid),

      shouldShowContextItem: grid.shouldShowContextItem.createSequence(function(item,record) {
	if (item.itemId == this.actions['IMPORT'] && record.data._imported) {
	  // TODO: disable the 'import' action for already imported items.
	}

	return true;
      },grid),

      updateButtons: grid.updateButtons.createSequence(function(item) {
	var selected = this.getSelection().length;
	if (selected > 0) {
	  this.actions['IMPORT'].enable();
	} else {
	  this.actions['IMPORT'].disable();
	}

	var totalCount = this.store.getTotalCount();
	if (totalCount > 0) {
	  this.actions['IMPORT_ALL'].enable();
	} else {
	  this.actions['IMPORT_ALL'].disable();
	}

      },grid),

      insertAll: function(){
	this.allSelected=true;
        this.insertEntry(function(){
          this.allSelected=false;
          var container= this.findParentByType(Paperpile.PubView);
          container.onRowSelect();
        },this);
      },

      insertEntry: function(){
	var selection=this.getSelection('NOT_IMPORTED');
	if (selection.length==0) return;
	var many=false;
	if (selection == 'ALL'){
	  many=true;
	} else {
	  if (selection.length > 10) {
	    many=true;
          }
	}

	if (many){
	  Paperpile.status.showBusy('Importing references to library');
	}

	Ext.Ajax.request({
	  url: Paperpile.Url('/ajax/crud/insert_entry'),
	  params: { selection: selection,
  	    grid_id: this.id
	  },
	  timeout: 10000000,
	  method: 'GET',
	  success: function(response) {
	    var json = Ext.util.JSON.decode(response.responseText);
            this.store.suspendEvents();
            for (var sha1 in json.data) {
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
	    Paperpile.main.onUpdateDB();
            Paperpile.status.clearMsg();
	  },
	  failure: Paperpile.main.onError,
	  scope:this
	});
      }
    },grid);

    grid.on({afterrender:{scope:grid,fn:grid.addImportButtons}});
  }
});