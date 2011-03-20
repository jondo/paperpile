Ext.define('Paperpile.app.GridActions', {
  statics: {
    getActions: function() {
      return {

        'EXPORT_VIEW': new Ext.Action({
          itemId: 'EXPORT_VIEW',
          text: 'Export References to File',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.exportSelectionHandler(grid.id, 'all');

          }
        }),
        'SHOW_SETTINGS': new Ext.Action({
          itemId: 'SHOW_SETTINGS',
          text: 'Settings',
          iconCls: 'pp-icon-dashboard',
          tooltip: 'Change your settings and view library stats',
          handler: function() {
            Paperpile.main.tabs.showDashboardTab();
          }
        }),
        'UP_HOME': new Ext.Action({
          text: 'Move the cursor to the top',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            var cursor = grid.getSelectionModel().getCursor();
            if (cursor !== null) {
              var distance = -cursor;
              grid.getSelectionModel().keyNavMove(distance, event);
            } else {
              grid.getSelectionModel().selectFirstRow();
            }
          }
        }),
        'DOWN_END': new Ext.Action({
          text: 'Move the cursor to the bottom',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            var rowCount = grid.getStore().getCount();
            var cursor = grid.getSelectionModel().getCursor();
            if (cursor !== null) {
              var distance = rowCount - cursor;
              grid.getSelectionModel().keyNavMove(distance, event);
            } else {
              grid.getSelectionModel().selectLastRow();
            }
          }
        }),
        'DOWN_PAGE': new Ext.Action({
          text: 'Move the cursor down one page',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            var rows = grid.getVisibleRows();
            grid.getSelectionModel().keyNavMove(rows.length, event);
          }
        }),
        'UP_PAGE': new Ext.Action({
          text: 'Move the cursor up one page',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            var rows = grid.getVisibleRows();
            grid.getSelectionModel().keyNavMove(-rows.length, event);
          }
        }),
        'DOWN_ONE': new Ext.Action({
          text: 'Move the cursor to the next reference',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();

            var sm = grid.getSelectionModel();
            var t = grid.pager;
            var activePage = Math.ceil((t.cursor + t.pageSize) / t.pageSize);
            if (sm.getCount() == 1 && grid.getStore().indexOf(grid.getSingleSelection()) == grid.pager.pageSize - 1 && !grid.pager.next.disabled) {
              grid.pager.moveNext();
              grid.doAfterNextReload.push(function() {
                grid.selectRowAndSetCursor(0);
              });
            } else {
              grid.getSelectionModel().keyNavMove(1, event);
            }
          }
        }),
        'UP_ONE': new Ext.Action({
          text: 'Move the cursor to the previous reference',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            var sm = grid.getSelectionModel();
            if (sm.getCount() == 1 && grid.getStore().indexOf(grid.getSingleSelection()) == 0 && !grid.pager.prev.disabled) {
              grid.pager.movePrevious();
              grid.doAfterNextReload.push(function() {
                grid.selectRowAndSetCursor(grid.pager.pageSize - 1);
              });
            } else {
              grid.getSelectionModel().keyNavMove(-1, event);
            }
          }
        }),
        'MOVE_FIRST': new Ext.Action({
          text: 'Move the cursor to the first reference',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            grid.selectRowAndSetCursor(0);
          }
        }),
        'MOVE_LAST': new Ext.Action({
          text: 'Move the cursor to the last reference',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            grid.selectRowAndSetCursor(grid.getStore().getCount() - 1);
          }
        }),
        'SELECT_ALL': new Ext.Action({
          text: 'Select all',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            event.stopEvent();
            grid.selectAll();
          },
          scope: this,
          itemId: 'SELECT_ALL'
        }),
        'FOCUS_SEARCH': new Ext.Action({
          text: 'Search',
          handler: function(keyCode, event) {
            var grid = Paperpile.main.getCurrentGrid();
            grid.handleFocusSearch();
          },
        }),
        'CLEAR_SEARCH': new Ext.Action({
          text: 'Clear Search Query',
          handler: function(event) {
            var grid = Paperpile.main.getCurrentGrid();

          }
        })
      }
    }
  }
});