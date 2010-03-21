/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */

Paperpile.ImportGridPlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.ImportGridPlugin, Ext.util.Observable, {
  init: function(grid) {

    grid.actions['IMPORT_SELECTED'] = new Ext.Action({
      itemId: 'IMPORT_SELECTED',
      text: 'Import',
      handler: function() {
        this.insertEntry();
      },
      scope: grid,
      iconCls: 'pp-icon-add',
      tooltip: 'Import selected references to your library.'
    });

    grid.actions['IMPORT_ALL'] = new Ext.Action({
      itemId: 'IMPORT_ALL',
      text: 'Import all',
      handler: function() {
        this.insertEntry(true);
      },
      scope: grid,
      iconCls: 'pp-icon-add-all',
      tooltip: 'Import all references to your library.'
    });

    if (!grid['isLongImport']) {
      Ext.apply(grid, {
        isLongImport: function() {
          if (this.allSelected || this.getSelection('NOT_IMPORTED') == 'ALL') return true;
          if (this.getSelection('NOT_IMPORTED').length >= 10) return true;
          return false;
        }
      });
    }

    Ext.apply(grid, {
      initToolbarMenuItemIds: grid.initToolbarMenuItemIds.createSequence(function() {
        var ids = this.toolbarMenuItemIds;

        ids.remove('NEW');

        var index = ids.indexOf('TB_FILL');
        ids.insert(index + 1, 'IMPORT_SELECTED');
        ids.insert(index + 2, 'IMPORT_ALL');

        // Move the 'Edit' to after the jump.
        ids.remove('EDIT');
        index = ids.indexOf('TB_BREAK');
        ids.insert(index + 1, 'EDIT');
      },
      grid),

      initContextMenuItemIds: grid.initContextMenuItemIds.createSequence(function() {
        var ids = this.contextMenuItemIds;

        ids.remove('NEW');
        ids.remove('DELETE');

        ids.insert(0, 'IMPORT_SELECTED');
      },
      grid),

      updateButtons: grid.updateButtons.createSequence(function() {
        this.actions['EDIT'].disable();

        var selection = this.getSingleSelectionRecord();
        if (!selection) {
          this.actions['IMPORT_SELECTED'].disable();
        } else {
          if (selection && selection.data._imported) {
            this.actions['IMPORT_SELECTED'].disable();
            this.actions['EDIT'].enable();
          }
        }

        if (this.getTotalCount() == 0) {
          this.actions['IMPORT_ALL'].disable();
        }

      },
      grid),

      onDblClick: grid.onDblClick.createInterceptor(function(grid, rowIndex, e) {
        // We're using an "interceptor" here to sneak into the grid's double-click
        // handler. If the selected item is NOT imported, we call the "insertEntry" method
        // and return false, causing the original onDblClick method NOT to be called.
        // If the selected item IS already imported, we defer to the superclass method from grid.js
        if (this.getSelectionModel().getCount() == 1) {
          if (!this.getSelectionModel().getSelected().data._imported) {
            this.insertEntry();
            return false; // Avoid calling the original double-click handler!
          } else {
            // This record is already imported. Return true and defer to the superclass double-click handler.
            return true;
          }
        }
        return true;
      },
      grid),

      insertAll: function() {
        this.allSelected = true;
        this.insertEntry(true);
      },

      insertEntry: function(all) {
        if (all) {
          this.allSelected = true;
        }

        var selection = this.getSelection('NOT_IMPORTED');
        if (selection.length == 0) return;

        if (this.isLongImport()) {
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
            if (all) {
              this.allSelected = false;
            }
            Paperpile.main.onUpdate(json.data);
            if (this.isLongImport()) {
              Paperpile.status.clearMsg();
            }
          },
          failure: Paperpile.main.onError,
          scope: this
        });
      },

      getMultipleSelectionTemplate: function() {
        var template = [
          '<div id="main-container-{id}">',
          '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
          '    <p><b>{numSelected}</b> references selected.</p>',
          '    <div class="pp-vspace"></div>',
          '    <ul>',
          '    <tpl if="numImported==0 || (allSelected && !allImported)">',
          '      <li class="pp-action pp-action-add"> <a  href="#" class="pp-textlink" action="import-ref">Import</a> </li>',
          '    </tpl>',
          '    <tpl if="(numImported || allImported) && (!allSelected||allImported)">',
          '      <li class="pp-action pp-action-search-pdf"> <a  href="#" class="pp-textlink" action="batch-download">Download PDFs</a> </li>',
          '      <li class="pp-action pp-action-trash"> <a  href="#" class="pp-textlink" action="delete-ref">Move to Trash</a> </li>',
          '    </tpl>',
          '    </ul>',
          '  </div>',
          '</div>'];
        return[].concat(template);
      }

    });
  },

});

Ext.reg("import-grid-plugin", Paperpile.ImportGridPlugin);