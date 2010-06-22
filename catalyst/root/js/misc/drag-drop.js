Paperpile.DragDropManager = Ext.extend(Ext.util.Observable, {
  initListeners: function() {

    var el = Ext.getBody();
    //    Paperpile.log("Body id: " + el.id);
    this.addAllDragEvents(el, this.bodyDragEvent);

    this.createToolTip();
  },

  createToolTip: function() {
    this.dragToolTip = new Ext.ToolTip({
      renderTo: document.body,
      targetXY: [0, 0],
      anchor: 'left',
      anchorToTarget: true,
      showDelay: 0,
      hideDelay: 0
    });
      var el = this.dragToolTip.getEl();
      el.setStyle('position', 'absolute');
      el.setStyle('z-index', '1'); // Important -- hover above everything else.
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

    if (this.isFolderDrag(event)) {
      // 1) 'Import PDF folder' to All Papers (and folders) tree nodes
      // 2) 'Attach contained files' to visible grid rows
      this.targetsList = this.targetsList.concat(this.getDropTargetsForTreeImport(event));

    } else if (this.isPdfDrag(event)) {
      // 1) 'import PDF' to All Papers (and folders) tree node
      // 2) 'Attach PDF' to visible grid rows
      var activeTab = Paperpile.main.tabs.getActiveTab();
      if (activeTab instanceof Paperpile.PluginPanel) {

        this.targetsList = this.targetsList.concat(this.getDropTargetsForGrid(activeTab.getGrid(), event));
      }
      this.targetsList = this.targetsList.concat(this.getDropTargetsForTreeImport(event));

    } else if (this.isReferenceFileDrag(event)) {
      // 1) 'Open reference file' over whole Grid.
      this.targetsList = this.targetsList.concat(this.getDropTargetsForLibraryImport(event));

    } else if (this.isFileDrag(event)) {
      // 1) 'Attach supp. file' to visible grid rows
      var activeTab = Paperpile.main.tabs.getActiveTab();
      if (activeTab instanceof Paperpile.PluginPanel) {
        this.targetsList = this.targetsList.concat(this.getDropTargetsForGrid(activeTab.getGrid(), event));
      }
    }

    // Sort the targets by the z-index.
    var collection = new Ext.util.MixedCollection();
    collection.addAll(this.targetsList);
    var sortFn = function(a, b) {
      return a.targetZIndex - b.targetZIndex;
    };
    collection.sort('DESC', sortFn);

    this.targetsList = [];
    for (var i = 0; i < collection.getCount(); i++) {
      this.targetsList.push(collection.itemAt(i));
    }
    /*
    // Add a canvas overlay.
      var canvas = Ext.DomHelper.append(Ext.getBody(),{
	  tag: 'canvas',
	  width:200,
	  height:200
      });
      var c = canvas.getContext("2d");
          c.fillStyle = 'red';
      c.fillRect(0, 0, 200,200);
*/
  },

  getDropTargetsForLibraryImport: function(event) {
    var targets = [];

    var tree = Paperpile.main.tree;
    var node = tree.getNodeById('IMPORT_PLUGIN_ROOT');
    node = node.findChildBy(function(node) {
      if (node.text == 'Import File') {
        return true;
      }
      return false;
    });

    var el = Ext.get(node.ui.getTextEl()).up('div');
    var activeTab = Paperpile.main.tabs.getActiveTab();
    if (activeTab instanceof Paperpile.PluginPanel) {
      el = activeTab.getGrid().getEl();
    }
    var target = new Paperpile.DragDropTarget({
      hint: 'import',
      dragMessage: 'Open library file',
      action: 'file-import',
      object: node
    });
    target.setTargetEl(el);
    return target;
  },

  getDropTargetsForTreeImport: function(event) {
    var targets = [];

    var tree = Paperpile.main.tree;

    var noun = '';
    if (this.isFolderDrag(event)) {
      noun = 'PDF folder';
    } else if (this.isPdfDrag(event)) {
      noun = 'PDF';
    }
    var mult = this.isMultipleFileDrag(event) ? 's' : '';

    // Add a catch-all target to just import into the library.
    var node = tree.getNodeById('LOCAL_ROOT');
    var message = 'Import ' + noun + mult + ' into library';
    var target = new Paperpile.DragDropTarget({
      invisible: false,
      hint: 'import',
      dragMessage: message,
      action: 'pdf-import',
      object: node,
      targetZIndex: -1 // Keep on 'bottom' of the target stack.
    });
    target.setTargetEl(Ext.get(node.ui.getEl()));
    targets.push(target);

    // Add targets for each individual folder or tag.
    var nodes = [];
    var allPapersNode = tree.getNodeById('FOLDER_ROOT');
    var nodes = nodes.concat(tree.getAllNodes(allPapersNode));

    var allTagsNode = tree.getNodeById('TAGS_ROOT');
    nodes = nodes.concat(tree.getAllNodes(allTagsNode));

    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
            var el = Ext.get(node.ui.getTextEl()).up('div');
      //var el = Ext.get(node.ui.getEl());
      var dragMessage;

      if (node == allTagsNode || node == allPapersNode) {
        continue;
      }

      if (node.type == 'FOLDER') {
        dragMessage = 'Import ' + noun + mult + ' into folder ' + node.text;
      } else if (node.type == 'TAGS') {
        dragMessage = 'Import ' + noun + mult + ' with label ' + node.text;
      }
      var target = new Paperpile.DragDropTarget({
        invisible: true,
        hint: 'import',
        dragMessage: dragMessage,
        action: 'pdf-import',
        object: node
      });
      target.setTargetEl(el);
      targets.push(target);
    }

    return targets;
  },

  getDropTargetsForGrid: function(gridPanel, event) {
    // Go through and create drop targets for each visible grid row.
    var targets = [];
    var preferPdfAction = this.isPdfDrag(event);

    // Get the list of visible row indices.
    var visibleRows = [];
    var gridBox = gridPanel.getBox();
    var rowCount = gridPanel.getStore().getCount();
    for (var i = 0; i < rowCount; i++) {
      var row = Ext.fly(gridPanel.getView().getRow(i));
      if (row.getY() < gridBox.y + gridBox.height) {
        visibleRows.push(i);
      }
    }

    var mult = this.isMultipleFileDrag(event) ? 's' : '';

    // One target for the whole grid.
    var target = new Paperpile.DragDropTarget({
      invisible: false,
      hint: '',
      dragMessage: '',
      action: null,
      targetZIndex: -1 // Keep on 'bottom' of the target stack.
    });
    target.setTargetEl(gridPanel.el);
    targets.push(target);

    // One invisible target per visible row.
    for (var i = 0; i < visibleRows.length; i++) {
      var rowIndex = visibleRows[i];
      var row = gridPanel.getStore().getAt(i);
      var rowEl = Ext.get(gridPanel.getView().getRow(i)); // Can't use Ext.fly here, since we're storing the element in the droptarget objects.
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
        invisible: true,
        hint: hint,
        dragMessage: dragMessage,
        action: action,
        object: [row, gridPanel]
      });
      target.setTargetEl(rowEl);
      targets.push(target);
    }
    return targets;
  },

  bodyDragEvent: function(event) {
    //    Paperpile.log("bodyDrag, type: " + event.type + "  target:" + event.target.id + " " + event.getXY());
    if (event.type == 'dragleave') {
      return;
    }

    // Create the 'drag pane'. This is a transparent pane that
    // entire window, catching drag events and detecting when
    // they overlap with drag targets.
    if (!this.dragPane) {
      this.dragPane = Ext.getBody().createChild({
        id: 'drag-pane',
        cls: 'pp-drag-pane'
      });
      var el = this.dragPane;
      el.setBox(Paperpile.main.getBox()); // Set to window size.
      el.setOpacity(0);
      el.setStyle('z-index', '100'); // Important -- hover above everything else.
      el.setStyle('position', 'absolute');
    }

    // The dragPane should capture drag events now, not the bod.
    this.removeAllDragEvents(Ext.getBody(), this.bodyDragEvent);
    this.addAllDragEvents(this.dragPane, this.paneDragEvent);

    this.dragPane.setVisible(true);

    // Create the necessary drop targets.
    this.createDropTargets(event);
  },

  hideDragPane: function() {
    this.dragPane.setVisible(false);

    // Hide the tooltip and destroy any dragdrop targets.
    this.destroyAllTargets();

    // Put drag events back onto the body.
    this.removeAllDragEvents(this.dragPane, this.paneDragEvent);
    this.addAllDragEvents(Ext.getBody(), this.bodyDragEvent);

    this.effectBlock = false;
  },

  paneDragEvent: function(event) {
    //    Paperpile.log("PaneDrag, type: " + event.type + "  target:" + event.target.id + " dragPane:" + this.dragPane.id + "  " + event.getXY());
    // Dispatching other events to relevant functions.
    if (event.type == 'drop') {
      this.onDrop(event);
      return;
    }
    var tgt = event.getTarget('#drag-pane', 3, false);
    if (event.type == 'dragleave' && tgt !== null) {
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
    be.dataTransfer.effectAllowed = 'copy';
    be.dataTransfer.dropEffect = 'copy';
    be.preventDefault();
  },

  destroyAllTargets: function() {
    if (this.currentlyHoveredTarget != null) {
      this.currentlyHoveredTarget.out(event);
	this.currentlyHoveredTarget = null;
    }
    for (var i = 0; i < this.targetsList.length; i++) {
      var target = this.targetsList[i];
      target.destroy();
    }
    this.targetsList = [];
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
    var file = url.replace("file://", "");
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

      this.dragToolTip.hide();

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
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, row.data.guid, file, true]);
      }
    } else if (action == 'supplement-attach') {
      var row = object[0];
      var grid = object[1];
      var files = this.getFilesFromEvent(event);
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, row.data.guid, file, false]);
      }
    } else if (action == 'pdf-import') {
      var files = this.getFilesFromEvent(event);
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        if (file.extension() == 'pdf') {
          Paperpile.main.submitPdfExtractionJobs.defer(100 * (i + 1), this, [file.nativePath()]);
        }
      }
    } else if (action == 'file-import') {
      var files = this.getFilesFromEvent(event);
      for (var i = 0; i < files.length; i++) {
        var file = files[i];
        var path = file.nativePath();
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
    if (fileURLs.length == 0) return false;
    for (var i = 0; i < fileURLs.length; i++) {
      var fileURL = fileURLs[i];
      fileURL = this.fileFromURL(fileURL);
      var file = Titanium.Filesystem.getFile(fileURL);
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
      if (file.extension() == 'pdf') {
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
      if (file.isDirectory()) {
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
    var ext = file.extension();
    if (file.extension().match(/(bib|ris|xml|sqlite|db|ppl|mods|rss)/)) {
      return true;
    }
  },

  // Return true if there is at least one file in the drag event.
  isFileDrag: function(event) {
    var files = this.getFilesFromEvent(event);

    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.isFile()) {
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
Paperpile.DragDropTarget = Ext.extend(Ext.Panel, {
  invisible: false,
  floating: true,
  shadow: false,
  renderTo: document.body,
  cls: 'pp-drag-target',
  targetZIndex: 0,
  initComponent: function() {
    Paperpile.DragDropTarget.superclass.initComponent.call(this);
  },
  onRender: function(ct, position) {
    Paperpile.DragDropTarget.superclass.onRender.call(this, ct, position);

    if (this.invisible && this.el) {
      this.el.addClass('pp-drag-target-invisible');
    }

    this.body.setOpacity(0);
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
      el.setStyle('z-index', '20'); // Important -- make sure the z-index i set so we display BELOW the 'drag pane' element.
    }
  },
  over: function(event) {
    if (!this.getDragMessage()) {
      return;
    }

    var tip = Paperpile.main.dd.dragToolTip;
    tip.target = this.targetEl;
    tip.anchorTarget = this.targetEl;
    tip.update(this.getDragMessage());
    tip.show();
    if (this.el) {
      this.el.addClass('pp-drag-target-over');
      if (this.invisible) {
        this.el.removeClass('pp-drag-target-invisible');
      }
    }

  },
  out: function(event) {
    var tip = Paperpile.main.dd.dragToolTip;
    tip.hide();
    if (this.el) {
      this.el.removeClass('pp-drag-target-over');
      if (this.invisible) {
        this.el.addClass('pp-drag-target-invisible');
      }
    }
  },
  getHint: function() {
    return this.hint;
  },
  setHint: function(hint) {
    this.hint = hint;
  },
  getDragMessage: function() {
    return this.dragMessage;
  },
  setDragMessage: function(dragMessage) {
    this.dragMessage = dragMessage;
  }

});