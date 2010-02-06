Paperpile.ImportGridPlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.ImportGridPlugin, Ext.util.Observable, {
  init: function(grid) {

    grid.actions['IMPORT'] = new Ext.Action({
      text: 'Import',
      handler: function() {
        this.insertEntry();
      },
      scope: grid,
      iconCls: 'pp-icon-add',
      itemId: 'import_button',
      tooltip: 'Import selected references to your library.'
    });

    grid.actions['IMPORT_ALL'] = new Ext.Action({
      text: 'Import all',
      handler: function() {
        this.insertEntry(true);
      },
      scope: grid,
      iconCls: 'pp-icon-add-all',
      itemId: 'import_all_button',
      tooltip: 'Import all references to your library.'
    });

    Ext.apply(grid, {
      createToolbarMenu: grid.createToolbarMenu.createSequence(function() {
        var tbar = this.getTopToolbar();

        if (this.actions['NEW'] != null) {
          var item = this.getToolbarByItemId(this.actions['NEW'].itemId);
          item.setVisible(false);
        }

        var filterFieldIndex = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
        tbar.insertButton(filterFieldIndex + 1, this.actions['IMPORT_ALL']);
        tbar.insertButton(filterFieldIndex + 1, this.actions['IMPORT']);
      },
      grid),

      createContextMenu: grid.createContextMenu.createSequence(function() {
        this.context.insert(0, this.actions['IMPORT']);

        this.getContextByItemId(this.actions['VIEW_PDF'].itemId).setVisible(false);
        this.getContextByItemId(this.actions['DELETE'].itemId).setVisible(false);

      },
      grid),

      updateContextItem: grid.updateContextItem.createSequence(function(item, record) {
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

      },
      grid),

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

      },
      grid),

      insertAll: function() {
        this.allSelected = true;
        this.insertEntry(function() {
          this.allSelected = false;
          Paperpile.main.onUpdate();
        },
        this);
      },

      insertEntry: function(all) {

        if (all){
          this.allSelected = true;
        }

        var selection = this.getSelection('NOT_IMPORTED');
        if (selection.length == 0) return;
        var many = false;
        if (selection == 'ALL') {
          this.allImported = true;
          many = true;
        } else {
          if (selection.length > 10) {
            many = true;
          }
        }

        if (many) {
          Paperpile.status.showBusy('Importing references to library');
        }

        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/crud/insert_entry'),
          params: {
            selection: selection,
            grid_id: this.id
          },
          timeout: 10000000,
          method: 'GET',
          success: function(response) {
            var json = Ext.util.JSON.decode(response.responseText);
            if (all){
              this.allSelected=false;
            }
            Paperpile.main.onUpdate(json.data);
            Paperpile.status.clearMsg();
          },
          failure: Paperpile.main.onError,
          scope: this
        });
      },

      getMultipleSelectionTemplate: function() {

        var template = [
          '<div id="main-container-{id}">',
          '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
          '    <tpl if="numSelected==0">',
          '      <p>No references in here.</p>',
          '    </tpl>',
          '<p>numSelected: {numSelected}; numImported: {numImported}; allSelected: {allSelected}; allImported: {allImported}</p>',
          '    <tpl if="numSelected &gt;0">',
          '      <p><b>{numSelected}</b> references selected.</p>',
          '      <div class="pp-vspace"></div>',
          '      <ul>',
          '      <tpl if="numImported==0 || (allSelected && !allImported)">',
          '        <li class="pp-action pp-action-add"> <a  href="#" class="pp-textlink" action="import-ref">Import</a> </li>',
          '      </tpl>',
          '      <tpl if="(numImported || allImported) && (!allSelected||allImported)">',
          '        <li class="pp-action pp-action-search-pdf"> <a  href="#" class="pp-textlink" action="batch-download">Download PDFs</a> </li>',
          '        <li class="pp-action pp-action-trash"> <a  href="#" class="pp-textlink" action="delete-ref">Move to Trash</a> </li>',
          '      </tpl>',
          '      </ul>',
          '    </tpl>',
          '  </div>',
          '</div>'];
        return[].concat(template);
      }

    });
  },

});

Ext.reg("import-grid-plugin", Paperpile.ImportGridPlugin);