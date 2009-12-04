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
      createToolbarMenu: grid.createToolbarMenu.createSequence(function() {
	var tbar = this.getTopToolbar();

	if (this.actions['NEW'] != null) {
	  var item = this.getToolbarByItemId(this.actions['NEW'].itemId);
	  item.setVisible(false);
	}

	var filterFieldIndex = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
	tbar.insertButton(filterFieldIndex+1,this.actions['IMPORT']);
	tbar.insertButton(filterFieldIndex+1,this.actions['IMPORT_ALL']);
      },grid),

      createContextMenu: grid.createContextMenu.createSequence(function() {
	this.context.insert(0,this.actions['IMPORT']);

	this.getContextByItemId(this.actions['VIEW_PDF'].itemId).setVisible(false);
	//this.getContextByItemId(this.actions['EDIT'].itemId).setVisible(false);
	this.getContextByItemId(this.actions['DELETE'].itemId).setVisible(false);

      },grid),

      updateContextItem: grid.updateContextItem.createSequence(function(item,record) {
	if (item.itemId == this.actions['IMPORT'].itemId) {
	  if (record.data._imported) {
	    item.disable();
	    item.setText("Already imported.");
	  } else {
	    item.enable();
	    item.setText("Import");
	  }
	}

	if (item.itemId == this.actions['EDIT'].itemId) {
	  record.data._imported ? item.setVisible(false) : item.setVisible(true);
	}

      },grid),

      updateToolbarItem: grid.updateToolbarItem.createSequence(function(item) {
	var selected = this.getSelection().length;
	var totalCount = this.store.getTotalCount();

	if (item.itemId == this.actions['IMPORT'].itemId) {
	  (selected > 0 ? item.enable() : item.disable());
	  if (selected == 1) {
	    // Check for an already-imported item.
	    var data = this.getSelectionModel().getSelected().data;
	    if (data._imported) {
	      item.disable();
	    }
	  }
	}

	if (item.itemId == this.actions['IMPORT_ALL'].itemId) {
	  (totalCount > 0 ? item.enable() : item.disable());
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
    });

  }
});

Ext.reg("import-grid-plugin",Paperpile.ImportGridPlugin);