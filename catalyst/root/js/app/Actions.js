Ext.define('Paperpile.app.PubActions', {
  statics: {
    getCurrentGrid: function() {
      if (!Paperpile.main.getTabs()) {
        return;
      }
      var activeTab = Paperpile.main.getTabs().getActiveTab();
      if (activeTab instanceof Paperpile.PluginPanel) {
        return activeTab.getGrid();
      }
    },
    getMainLibraryGrid: function() {
      var mainTab = Paperpile.main.getTabs().getMainLibraryTab();
      return mainTab.getGrid();
    },

    getCurrentlySelectedRow: function() {
      var activeTab = Paperpile.main.getTabs().getActiveTab();
      if (activeTab instanceof Paperpile.PluginPanel) {
        var grid = activeTab.getGrid();
        if (grid.getSelectionCount() == 1) {
          return grid.getSingleSelectionRecord();
        }
      }
      return null;
    },
    getSelection: function() {
      var grid = this.getCurrentGrid();
      return grid.getSelection();
    },

    loadActions: function() {
      if (this.actions !== undefined) {
        return;
      }
      this.actions = {
        'TRASH': new Ext.Action({
          text: 'Move to Trash',
          iconCls: 'pp-icon-trash',
          scope: this,
          cls: 'x-btn-text-icon',
          itemId: 'TRASH',
          triggerKey: 'd',
          tooltip: 'Move selected references to Trash',
          handler: function() {
            var grid = this.getCurrentGrid();
            var selection = grid.getSelection();

            var firstRecord = grid.getSelectionModel().getLowestSelected();
            var firstIndex = grid.getStore().indexOf(firstRecord);

            Paperpile.Ajax({
              url: '/ajax/crud/delete_entry',
              params: {
                selection: selection,
                grid_id: this.id,
                mode: mode
              },
              timeout: 10000000,
              success: function(response) {
                var data = Ext.util.JSON.decode(response.responseText);
                var num_deleted = data.num_deleted;

		Paperpile.log("Deleted!");
              }
            });
          },
        })
      }
    }

  }
});