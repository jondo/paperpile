Paperpile.DragDropManager = Ext.extend(Ext.util.Observable, {
  registerGridListeners: function(grid) {

    grid.getView().mainBody.dom.addEventListener("dragover", this.gridDragOver.createDelegate(grid), false);
    grid.getView().mainBody.dom.addEventListener("dragenter", this.gridDragOver.createDelegate(grid), false);
    grid.getView().mainBody.dom.addEventListener("dragleave", this.gridDragOver.createDelegate(grid), false);
    grid.getView().mainBody.dom.addEventListener("drop", this.gridDrop.createDelegate(grid), false);
  },

  fileFromURL: function(url) {
    var file = url.replace("file://", "");
    file = decodeURIComponent(file);
    file = file.replace(/\n|\r|\r\n/g, "");
    return file;
  },

  gridDrop: function(event) {
    var dd = Paperpile.main.dd;

    this.dragTargetRow = -1;
    this.dragToolTip.hide();

    var rowIndex = dd.targetRowForEvent(this, event);
    var row = this.getStore().getAt(rowIndex);
    var guid = row.data.guid;
    var grid = this;

    var action = dd.gridDropAction(this, event);

    var panel = this.getPluginPanel();
    var overview = panel.getOverview();

    if (action == 'pdf') {
      var fileURLs = event.dataTransfer.getData("text/uri-list").split("\n");
      var file = fileURLs[0];
      file = dd.fileFromURL(file);
      Paperpile.main.attachFile(grid, guid, file, true);
    } else if (action == 'supp_single' || action == 'supp_multiple') {
      Paperpile.log(event.dataTransfer.getData("text/uri-list"));
      var fileURLs = event.dataTransfer.getData("text/uri-list").split("\n");
      for (var i = 0; i < fileURLs.length; i++) {
        var file = fileURLs[i];
        var fileName = dd.fileFromURL(file);
        Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, guid, fileName, false]);
      }
    }
  },

  // Called from the scope of the DragDropManager.
  isValidGridDrag: function(grid, event) {
    var dd = Paperpile.main.dd;
    var rowIndex = dd.targetRowForEvent(grid, event);
    var row = grid.getStore().getAt(rowIndex);
    var fileURLs = event.dataTransfer.getData("text/uri-list").split("\n");
    if (fileURLs.length == 0) return false;

    for (var i = 0; i < fileURLs.length; i++) {
      var fileURL = fileURLs[i];
      fileURL = dd.fileFromURL(fileURL);
      var file = Titanium.Filesystem.getFile(fileURL);
      // Don't allow drag-dropping folders into grid.
      if (file.isDirectory()) {
        return false;
      }
    }

    // Don't allow drag-dropping onto trashed articles.
    if (row.data.trashed) {
      return false;
    }

    if (!row.data._imported) {
      return false;
    }

    return true;
  },

  gridDropAction: function(grid, event) {
    var rowIndex = this.targetRowForEvent(grid, event);
    // Assumption: rowIndex isn't undefined.
    if (rowIndex === undefined) return;
    var row = grid.getStore().getAt(rowIndex);

    var fileURLs = event.dataTransfer.getData("text/uri-list").split("\n");
    for (var i = 0; i < fileURLs.length; i++) {
      var fileURL = fileURLs[i];
      fileURL = Paperpile.main.dd.fileFromURL(fileURL);
      var file = Titanium.Filesystem.getFile(fileURL);
      if (file.extension().toLowerCase() == 'pdf' && fileURLs.length == 1 && !this.alreadyHasPdf(row)) {
        return "pdf";
      }
    }

    if (fileURLs.length == 1) {
      return "supp_single";
    } else {
      return "supp_multiple";
    }
    return "error";
  },

  // Come up with a message for a given drag event.
  gridDragMessage: function(grid, event) {
    var message = '';
    var dropAction = this.gridDropAction(grid, event);
    if (dropAction == 'pdf') {
      return 'Add PDF to reference'
    } else if (dropAction == 'supp_single') {
      return 'Add file to supplementary material';
    } else if (dropAction == 'supp_multiple') {
      return 'Add files to supplementary material';
    } else {
      return 'error!';
    }
  },

  alreadyHasPdf: function(gridRowData) {
    if (gridRowData.data.pdf) {
      return true;
    }
    return false;
  },

  targetRowForEvent: function(grid, event) {
    var v = grid.getView();
    var index = v.findRowIndex(event.target);
    return index;
  },

  // Called from the scope of the grid object.
  gridDragOver: function(event) {
    // Gotta match up the effectAllowed and dropEffect. Complete crap.
    // See for a useful overview: http://www.useragentman.com/blog/2010/01/10/cross-browser-html5-drag-and-drop/
    if (!this.dragToolTip) {
      Paperpile.log("New tooltip!");
      this.dragToolTip = new Ext.ToolTip({
        renderTo: document.body,
        targetXY: [0, 0],
        anchor: 'left',
        showDelay: 0,
        hideDelay: 0
      });
    }

    if (this.dragTargetRow === undefined) this.dragTargetRow = -1;

    var v = this.getView();
    var index = v.findRowIndex(event.target);
    if (index != this.dragTargetRow && index !== undefined) {
      // Un-highlight the previously highlighted row.
      if (this.dragTargetRow != -1) {
        Ext.fly(v.getRow(this.dragTargetRow)).removeClass('drag-target');
      }
      if (Paperpile.main.dd.isValidGridDrag(this, event)) {
        this.dragTargetValid = true;
        // highlight the new drag target.
        Ext.fly(v.getRow(index)).addClass('drag-target');
        this.dragToolTip.target = v.getRow(index);
        this.dragToolTip.anchorTarget = v.getRow(index);
        this.dragToolTip.update(Paperpile.main.dd.gridDragMessage(this, event));
        this.dragToolTip.show();
        this.dragTargetRow = index;
      } else {
        this.dragTargetValid = false;
      }
    }

    if (event.type == 'dragleave') {
      var currentRow = Ext.fly(v.getRow(this.dragTargetRow));

      var el = document.elementFromPoint(event.x, event.y);
      var foundWithin = false;
      while (el) {
        if (Ext.getDom(currentRow) === el) {
          foundWithin = true;
          break;
        }
        el = el.parentNode;
      }
      if (!foundWithin && this.dragTargetRow != -1) {
        Ext.fly(v.getRow(this.dragTargetRow)).removeClass('drag-target');
        this.dragTargetRow = undefined;
        this.dragToolTip.hide();
      }
    }

    if (this.dragTargetValid) {
      event.dataTransfer.effectAllowed = 'copy';
      event.dataTransfer.dropEffect = 'copy';
      event.preventDefault();
      return true;
    } else {
      event.dataTransfer.effectAllowed = 'none';
      event.dataTransfer.dropEffect = 'move';
      event.preventDefault();
      return false;
    }
  }
});