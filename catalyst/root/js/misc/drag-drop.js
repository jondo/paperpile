Paperpile.DragDropManager = Ext.extend(Ext.util.Observable, {
  initListeners: function() {
    this.targetsList = [];

    var el = Ext.getBody();
    this.addAllDragEvents(el, this.bodyDragEvent);

  },

  addAllDragEvents: function(el, fn, targetFilter) {
    el.on('dragover', fn, this, {});
    el.on('dragenter', fn, this, {});
    el.on('dragleave', fn, this, {});
    el.on('drop', fn, this, {});
  },
  removeAllDragEvents: function(el, fn, targetFilter) {
    el.un('dragover', fn, this, {});
    el.un('dragenter', fn, this, {});
    el.un('dragleave', fn, this, {});
    el.un('drop', fn, this, {});
  },

  createDropTargets: function(event) {
    this.targetsList = [];

    if (!this.ddp) {
      this.ddp = new Paperpile.DragDropPanel();
    }
    this.ddp.clearActions();
    this.ddp.show();
    this.ddp.getEl().alignTo(Ext.getDoc(),'c-c');
    this.targetsList.concat(this.ddp);

    if (this.isFolderDrag(event)) {
      // 1) 'Import PDF folder' to All Papers (and folders) tree nodes
      // 2) 'Attach contained files' to visible grid rows
      this.targetsList = this.targetsList.concat(this.getDropTargetsForTreeImport(event));

    } else if (this.isPdfDrag(event)) {
      // Preview PDF drop action.
      var da1 = new Paperpile.DragDropAction({
        action: 'pdf-preview',
        label: 'Preview PDF',
        description: 'Preview using Paperpile\'s PDF viewer'
      });
      var da2 = new Paperpile.DragDropAction({
        action: 'pdf-import',
        label: 'Import PDF',
        description: 'Import PDF reference to your library'
      });

      this.ddp.addAction(da1);
      this.ddp.addAction(da2);

      // Import PDF drop action.
    } else if (this.isReferenceFileDrag(event)) {
      // 1) 'Open reference file' over whole Grid.
    } else if (this.isFileDrag(event)) {
      // 1) 'Attach supp. file' to visible grid rows
      var activeTab = Paperpile.main.tabs.getActiveTab();
      if (activeTab instanceof Paperpile.PluginPanel) {
        this.targetsList = this.targetsList.concat(this.getDropTargetsForGrid(activeTab.getGrid(), event));
      }
    }

    Paperpile.log(this.ddp.getActions());
    this.targetsList = this.targetsList.concat(this.ddp.getActions());

  },

  getDropTargetsForGrid: function(gridPanel, event) {
    // Go through and create drop targets for each visible grid row.
    var targets = [];
    var preferPdfAction = this.isPdfDrag(event);

    // Get the list of visible row indices.
    // This is an override method for GridPanel -- see overrides.js
    var visibleRows = gridPanel.getVisibleRows();

    var mult = this.isMultipleFileDrag(event) ? 's' : '';

    if (visibleRows == 0) {
      return targets;
    }

    // One target per visible row.
    for (var i = 0; i < visibleRows.length; i++) {
      var rowIndex = visibleRows[i];
      var row = gridPanel.getStore().getAt(rowIndex);
      var rowEl = Ext.get(gridPanel.getView().getRow(rowIndex)); // Can't use Ext.fly here, since we're storing the element in the droptarget objects.
      var data = row.data;

      if (!data._imported || data.trashed) {
        next;
      }

      var hint = '';
      var dragMessage = '';
      var action = '';
      if (!data.pdf && preferPdfAction) {
        hint = 'Attach PDF';
        dragMessage = 'Attach PDF file' + mult + ' to this reference';
        action = 'pdf-attach';
      } else {
        hint = 'Attach Supplementary file';
        dragMessage = 'Attach supplementary file' + mult + ' to this reference';
        action = 'supplement-attach';
      }

      var target = new Paperpile.DragDropTarget({
        action: action,
        object: [row, gridPanel]
      });
      target.setTargetEl(rowEl);
      targets.push(target);
    }
    return targets;
  },

  bodyDragEvent: function(event) {
    var tgt = event.getTarget('#dd-mask', 3, false);
    //    if (event.type == 'dragleave' && tgt !== null) {
    //      this.hideDragPane();
    //      return;
    //    }
    if (!this.dragPane) {
      var box = Paperpile.main.getBox();
      this.dragPane = Ext.DomHelper.append(Ext.getBody(), {
        tag: 'div',
        id: 'dd-mask',
        style: {
          top: 0,
          left: 0,
          width: box.width,
          height: box.height,
          border: '1px solid red',
          'z-index': 100,
          position: 'absolute' // The pane won't properly hover above everything if we don't set this!
        }
      },
      true);
    } else {
      var box = Paperpile.main.getBox();
      this.dragPane.setBox(box);
      this.dragPane.setVisible(true);
    }

    // The dragPane should capture drag events now, not the bod.
    this.addAllDragEvents(this.dragPane, this.dragEvent);
    this.removeAllDragEvents(Ext.getBody(), this.bodyDragEvent);

    this.createDropTargets(event);

    /*
    var da1 = new Paperpile.DragDropAction({
      action: 'pdf-preview',
      label: 'Preview PDF',
      description: 'Preview using Paperpile\'s PDF viewer'
    });
    var da2 = new Paperpile.DragDropAction({
      action: 'pdf-import',
      label: 'Import PDF',
      description: 'Import into your library'
    });

    ddp.addAction(da1);
    ddp.addAction(da2);
    this.targetsList.push(da1);
    this.targetsList.push(da2);
    */
  },

  hideDragPane: function() {
    this.dragPane.setVisible(false);

    // Destroy any dragdrop targets.
    this.destroyAllTargets(event);

    // Put drag events back onto the body.
    this.removeAllDragEvents(this.dragPane, this.dragEvent);
    this.addAllDragEvents(Ext.getBody(), this.bodyDragEvent);
  },

  dragEvent: function(event) {
    // Dispatching other events to relevant functions.
    if (event.type == 'drop') {
      this.onDrop(event);
      return;
    }

    var tgt = event.getTarget('#dd-mask', 2, false);
    if (event.type == 'dragleave' && tgt !== null) {
      event.stopEvent();
      this.hideDragPane();
      return;
    }

    // If we get here, the event is a 'normal' drag event. We loop through the droptargets, checking for overlap.
    var isOverSomething = false;
    for (var i = 0; i < this.targetsList.length; i++) {
      var target = this.targetsList[i];
      if (this.withinBox(event, target.getBox())) {
        // Mouse event is within this target.
        if (this.currentlyHoveredTarget != target) {
          // Jumped from one target to another -- 'out' the previous, and 'over' the current target.
          if (this.currentlyHoveredTarget != null) {
            this.currentlyHoveredTarget.out(event);
          }
          target.over(event);
        }
        // Store the current target for later.
        this.currentlyHoveredTarget = target;
        isOverSomething = true;
        break;
      }
    }

    // This should trigger when the mouse leaves a drop target.
    if (!isOverSomething && this.currentlyHoveredTarget != null) {
      this.currentlyHoveredTarget.out(event);
      this.currentlyHoveredTarget = null;
    }

    var be = event.browserEvent;
    if (isOverSomething) {
//	be.dataTransfer.effectAllowed = 'copy';
//	be.dataTransfer.dropEffect = 'copy';
//	be.preventDefault();
    } else {
//	be.dataTransfer.effectAllowed = '';
//	be.dataTransfer.dropEffect = '';
//	be.preventDefault();
    }
  },

  destroyAllTargets: function(event) {
    if (this.currentlyHoveredTarget != null) {
      this.currentlyHoveredTarget.out(event);
      this.currentlyHoveredTarget = null;
    }
    for (var i = 0; i < this.targetsList.length; i++) {
      var target = this.targetsList[i];
      target.destroy();
    }
    this.targetsList = [];

    if (this.ddp) {
      this.ddp.setVisible(false);
    }
  },

  withinBox: function(obj, box) {
    var xy = obj.getXY();
    var x = xy[0];
    var y = xy[1];
    return this.valueInRange(x, box.x, box.x + box.width) && this.valueInRange(y, box.y, box.y + box.height);
  },
  valueInRange: function(value, min, max) {
    return (value <= max) && (value >= min);
  },

  fileFromURL: function(url) {
    var file = url;
    file = file.replace("file://localhost", "");
    file = file.replace("file://", "");
    file = decodeURIComponent(file);
    file = file.replace(/\n|\r|\r\n/g, "");
    return file;
  },

  onDrop: function(event) {
    event.stopEvent();

    var dd = Paperpile.main.dd;

    var currentTarget = this.currentlyHoveredTarget;

    if (!currentTarget) {
      this.hideDragPane();
      return;
    }

    var action = currentTarget.action;
    var object = currentTarget.object;

    // Immediately hide the other targets.
    for (var i = 0; i < this.targetsList.length; i++) {
      var target = this.targetsList[i];
      if (target != currentTarget) {
        target.destroy();
      }
    }

    // Clear the drag pane shadow.
    //var c = this.dragPane.dom.getContext("2d");
    //var box = this.dragPane.getBox();
    //c.clearRect(box.x, box.y, box.width, box.height);
    //this.dragToolTip.hide();
    // Cause the current target to highlight, then hide the entire drag pane after the effect is finished.
    var fxDuration = 750;
    this.effectBlock = true;
    currentTarget.getEl().highlight("00aa00", {
      attr: 'border-color',
      easing: 'easeOut',
      duration: fxDuration / 1000,
      callback: this.hideDragPane,
      scope: this
    });

    if (action == 'pdf-attach') {
      var row = object[0];
      var grid = object[1];
      var files = this.getFilesFromEvent(event);

      // Select the current row in the grid.
      var index = grid.getStore().findExact('guid', row.data.guid);
      grid.getSelectionModel().selectRow(index);

      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        Paperpile.log("Attach " + file.canonicalFilePath);
        Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, row.data.guid, file.canonicalFilePath, true]);
      }
    } else if (action == 'supplement-attach') {
      var row = object[0];
      var grid = object[1];

      // Select the current row in the grid.
      var index = grid.getStore().findExact('guid', row.data.guid);
      grid.getSelectionModel().selectRow(index);

      var files = this.getFilesFromEvent(event);
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, row.data.guid, file.canonicalFilePath, false]);
      }
    } else if (action == 'pdf-import') {
      var node = object;
      var files = this.getFilesFromEvent(event);
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        if (file.suffix == 'pdf' || file.isDir) {
          Paperpile.main.submitPdfExtractionJobs.defer(100 * (i + 1), this, [file.canonicalFilePath, node]);
        }
      }
    } else if (action == 'file-import') {
      var files = this.getFilesFromEvent(event);
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        var path = file.canonicalFilePath;
        if (this.isReferenceFile(file)) {
          Paperpile.main.createFileImportTab(path);
        }
      }
    }
  },

  getFilesFromEvent: function(event) {
    var files = [];

    if (event['browserEvent']) {
      event = event.browserEvent;
    }
    var fileURLs = event.dataTransfer.getData("text/uri-list").split("\n");
    if (fileURLs.length == 0) return files;
    for (var i = 0; i < fileURLs.length; i++) {
      var fileURL = fileURLs[i];
      if (fileURL == '') {
        continue;
      }
      fileURL = this.fileFromURL(fileURL);
      var file = QRuntime.fileInfo(fileURL);
      files.push(file);
    }
    return files;
  },

  // Return true if at least one of the files contained within
  // the drag event is a PDF file.
  isPdfDrag: function(event) {
    var files = this.getFilesFromEvent(event);

    var hasOnePdf = false;
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.suffix == 'pdf') {
        hasOnePdf = true;
      }
    }
    if (!hasOnePdf) {
      return false;
    } else {
      return true;
    }
  },

  // Return true if any of the dragged objects is a folder.
  isFolderDrag: function(event) {
    var files = this.getFilesFromEvent(event);

    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.isDir) {
        return true;
      }
    }
    return false;
  },

  // Return true if any of the dragged objects looks like
  // a reference file.
  isReferenceFileDrag: function(event) {
    var files = this.getFilesFromEvent(event);

    var hasOneRefFile = false;
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (this.isReferenceFile(file)) {
        hasOneRefFile = true;
      }
    }
    if (!hasOneRefFile) {
      return false;
    } else {
      return true;
    }

    return false;
  },

  isReferenceFile: function(file) {
    var ext = file.suffix;
    if (file.suffix.match(/(bib|ris|xml|sqlite|db|ppl|mods|rss)/)) {
      return true;
    }
    return false;
  },

  // Return true if there is at least one file in the drag event.
  isFileDrag: function(event) {
    var files = this.getFilesFromEvent(event);

    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.isFile) {
        return true;
      }
    }
    return false;
  },

  isMultipleFileDrag: function(event) {
    var files = this.getFilesFromEvent(event);

    return (files.length > 1);
  }

});

// A DragDropTarget is used to encapsulate the functionality of
// a DnD 'target' box, making it clear to the user where the
// valid drop targets are.
Paperpile.DragDropTarget = Ext.extend(Ext.BoxComponent, {
  renderTo: document.body,
  cls: 'pp-dd-target',
  targetZIndex: 0,
  initComponent: function() {
    Paperpile.DragDropTarget.superclass.initComponent.call(this);
  },
  onRender: function(ct, position) {
    Paperpile.DragDropTarget.superclass.onRender.call(this, ct, position);

    this.el.setOpacity(1);
    this.show();
  },

  setTargetEl: function(targetEl) {
    if (this.rendered) {
      this.targetEl = targetEl;
      var box = targetEl.getBox();
      box.x -= 2;
      box.y -= 2;
      box.width += 0;
      box.height += 0;
      this.updateBox(box);
      var el = this.el;
      el.setStyle('z-index', '10'); // Important -- make sure the z-index i set so we display BELOW the 'drag pane' element.
    }
  },
  over: function(event) {
      Paperpile.log("Over "+this.el.id);
      if (this.el.hasActiveFx()) {
	  return;
      }
	this.el.animate({
		'border-color':{from:'#FFFFFF',to: '#88CC88' },
			},
			    0.5,
			    null,
			    'easeOut',
			    'color'

		);
  },
  out: function(event) {
      Paperpile.log("Out "+this.el.id);
      if (this.el.hasActiveFx()) {
	  return;
      }
	this.el.animate({
		'border-color':{from:'#88CC88',to: '#FFFFFF' },
			},
			    0.2,
			    null,
			    'easeOut',
			    'color'

		);
  }
});

Paperpile.DragDropAction = Ext.extend(Ext.BoxComponent, {
  //  cls: 'pp-drag-action',
  width:'100%',
  action: 'pdf-import',
  label: 'Import PDF',
  description: 'Import the PDF(s) into your library',
  forceLayout: true,
  initComponent: function() {
    Paperpile.DragDropAction.superclass.initComponent.call(this);
  },
  onRender: function(ct, position) {
    this.tpl = new Ext.Template([
      '<div class="pp-dd-action">',
      '  <h1>',
      '  ' + this.label,
      '  </h1>',
      '  <p>' + this.description + '</p>',
      '</div>']);

    this.el = this.tpl.append(ct);

    Paperpile.DragDropAction.superclass.onRender.call(this, ct, position);
  },
  getString: function() {
    return this.action + " " + this.el.id;
  },
  over: function(event) {
      this.el.stopFx();
	this.el.animate({
		'border-color':{from:'#FFFFFF',to: '#88CC88' },
			},
			    0.2,
			    null,
			    'easeOut',
			    'color'

		);
  },
  out: function(event) {
      this.el.stopFx();
	this.el.animate({
		'border-color':{from:'#88CC88',to: '#FFFFFF' },
			},
			    0.2,
			    null,
			    'easeOut',
			    'color'

		);
  }

});

Paperpile.DragDropPanel = Ext.extend(Ext.Panel, {
  width: 250,
  height: 350,
  floating: false,
  shadow: false,
  layout: {
      type:'vbox',
      defaultMargins: '10px',
      align:'center',
  },
  defaults: {flex:1},
  renderTo: document.body,
  cls: 'pp-dd-panel',
  over: function(event) {
    if (this.el) {
    }
  },
  out: function(event) {
    if (this.el) {
      this.el.removeClass('pp-dd-panel-over');
    }
  },
  initComponent: function() {

    Ext.apply(this, {
    });

    Paperpile.DragDropPanel.superclass.initComponent.call(this);
  },
  addAction: function(ddAction) {
    this.add(ddAction);
    this.doLayout(true);
  },
  getActions: function() {
    var actions = [];
    this.items.each(function(i) {
      if (i instanceof Paperpile.DragDropAction) {
        actions.push(i);
      }
    });
    return actions;
  },
  clearActions: function() {
    var rem = [];
    this.items.each(function(i) {
      if (i instanceof Paperpile.DragDropAction) {
        rem.push(i);
      }
    });

    for (var i = 0, len = rem.length; i < len; ++i) {
      item = rem[i];
      this.remove(item, true);
    }
  }
});