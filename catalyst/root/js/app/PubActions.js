Ext.define('Paperpile.app.PubActions', {
  statics: {
    getActions: function() {
      return {
        'LOOKUP_DETAILS': new Ext.Action({

        }),
        'VIEW_PDF': new Ext.Action({
          handler: function(grid_id, guid) {
            var grid = Ext.getCmp(grid_id);
            var pub = grid.getSingleSelection();
            if (pub.get('pdf')) {
              var pdf = pub.get('pdf_name');
              var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
              Paperpile.main.tabs.newPdfTab({
                file: path,
                filename: pdf
              });
              //Paperpile.main.inc_read_counter(this.getSingleSelection().data);
            }
          },
          iconCls: 'pp-icon-import-pdf',
          itemId: 'VIEW_PDF',
          text: 'View PDF',
          triggerKey: 'v',
          disabledTooltip: 'No PDF attached to this reference'
        }),
        'TRASH': new Ext.Action({
          text: 'Move to Trash',
          iconCls: 'pp-icon-trash',
          scope: this,
          cls: 'x-btn-text-icon',
          itemId: 'TRASH',
          triggerKey: 'd',
          tooltip: 'Move selected references to Trash',
          handler: function(grid_guid, selection) {
            var grid = this.getCurrentGrid();
            var selection = grid.getSelection();

            var firstRecord = grid.getSelectionModel().getLowestSelected();
            var firstIndex = grid.getStore().indexOf(firstRecord);

            Paperpile.Ajax({
              url: '/ajax/crud/delete_entry',
              params: {
                selection: selection,
                grid_id: grid_guid,
                mode: mode
              },
              timeout: 10000000,
              success: function(response) {
                var data = Ext.util.JSON.decode(response.responseText);
                var num_deleted = data.num_deleted;
              }
            });
          },
        })
      };
    }
  }
});