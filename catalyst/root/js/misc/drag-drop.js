Paperpile.DragDropManager = Ext.extend(Ext.util.Observable, {
  initListeners: function() {
    var el = Ext.getBody();
    // Register this object to listen for drag-drop events on the body and drag pane.
    this.addAllDragEvents(el, this.bodyDragEvent);
    this.addAllDragEvents(el, this.paneDragEvent);

    // Use this to flag whether we should be listening for events on the
    // document body or drag pane.
    this.eventMode = 'body';

    // Create a DragDropAction for each of the potential drop actions.
    this.actions = {
      OPEN_FILE: new Paperpile.DragDropAction({
        handler: this.openFile,
        iconCls: 'pp-icon-file',
        label: 'Open Library File',
        description: 'Open reference library file into a new tab'
      }),
      IMPORT_PDF_FOLDER: new Paperpile.DragDropAction({
        handler: this.importPdf,
        iconCls: 'pp-icon-import-pdf',
        label: 'Import PDF Folder',
        description: 'Import all PDFs contained in this folder'
      }),
      PREVIEW_PDF: new Paperpile.DragDropAction({
        handler: this.previewPdf,
        iconCls: 'pp-icon-glasses',
        label: 'Preview PDF',
        description: 'Preview using Paperpile\'s PDF viewer'
      }),
      IMPORT_PDF: new Paperpile.DragDropAction({
        handler: this.importPdf,
        iconCls: 'pp-icon-import-pdf',
        label: 'Import PDF',
        description: 'Import PDF to your library'
      }),
      IMPORT_MULTIPLE_PDFS: new Paperpile.DragDropAction({
        handler: this.importPdf,
        iconCls: 'pp-icon-import-pdf',
        label: 'Import PDFs',
        description: 'Import PDFs to your library'
      }),
      ATTACH_PDF: new Paperpile.DragDropAction({
        handler: this.attachPdf,
        iconCls: 'pp-icon-import-pdf',
        label: 'Attach PDF',
        description: 'Attach a PDF of the selected reference'
      }),
      ATTACH_SUPPLEMENT: new Paperpile.DragDropAction({
        handler: this.attachSupplement,
        iconCls: 'pp-file-generic',
        label: 'Attach File',
        description: 'Attach as supplementary file'
      }),
      ATTACH_MULTIPLE_SUPPLEMENTS: new Paperpile.DragDropAction({
        handler: this.attachSupplement,
        iconCls: 'pp-file-generic',
        label: 'Attach Files',
        description: 'Attach supplementary files'
      })

    };

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

  // Fills the DragDropPanels with the appropriate action boxes.
  createDropTargets: function(event) {

    if (!this.targetsList) {
      this.targetsList = [];
    }

    if (!this.ddp) {
      this.ddp = new Paperpile.DragDropPanel();
      this.ddp.actionHeight = 150;
    }
    if (!this.sideDdp) {
      this.sideDdp = new Paperpile.DragDropPanel();
      this.sideDdp.actionHeight = 100;
    }

    this.ddp.clearActions();
    this.sideDdp.clearActions();

    if (this.isFolder(event)) {
      this.ddp.addAction(this.actions['IMPORT_PDF_FOLDER']);

    } else if (this.isPdf(event)) {
      this.ddp.addAction(this.getPdfImportAction(event));
      // Maybe we'll implement this later...
      // this.ddp.addAction(this.actions['PREVIEW_PDF']); 
      if (this.activeTabIsGrid()) {
        var row = Paperpile.main.getCurrentlySelectedRow();
        if (!row.data.pdf && !this.isMultipleFiles(event)) {
          this.sideDdp.addAction(this.actions['ATTACH_PDF']);
        }
        this.sideDdp.addAction(this.getSupplementAction(event));
      }
    } else if (this.isReferenceFile(event)) {
      this.ddp.addAction(this.actions['OPEN_FILE']);

      if (this.activeTabIsGrid()) {
        this.sideDdp.addAction(this.getSupplementAction(event));
      }
    } else if (this.isFile(event)) {

      if (this.activeTabIsGrid()) {
        this.sideDdp.addAction(this.getSupplementAction(event));
      }
    }

    // Add all the actions to the targetsList. We'll use this list
    // to check the actions for mouseEvent overlap within the paneDragEvent
    // method.
    this.targetsList = this.targetsList.concat(this.ddp.getActions());
    this.targetsList = this.targetsList.concat(this.sideDdp.getActions());

    // Show the 'main' DragDropPanel if it has anything.
    if (this.ddp.getActions().length > 0) {
      this.ddp.doLayout();
      this.ddp.show();
      if (this.activeTabIsGrid()) {
        var activeTab = Paperpile.main.tabs.getActiveTab();

        var el = activeTab.getGrid().getGridEl();
        this.ddp.alignToElement(el, 'c-c');
      } else {
        this.ddp.alignToScreen('c-c');
      }
    }

    // Show the 'sidebar' DragDropPanel if it has anything.
    if (this.sideDdp.getActions().length > 0) {
      this.sideDdp.doLayout();
      this.sideDdp.show();
      var el = Ext.select(".pp-box-files").first();
      this.sideDdp.fitToEl(el);
      this.sideDdp.alignToElement(el, 't-t');
    }
  },

  // Return the appropriate supplementary material action for the given event.
  getPdfImportAction: function(event) {
    if (this.isMultipleFiles(event)) {
      return this.actions['IMPORT_MULTIPLE_PDFS'];
    } else {
      return this.actions['IMPORT_PDF'];
    }
  },

  // Return the appropriate supplementary material action for the given event.
  getSupplementAction: function(event) {
    if (this.isMultipleFiles(event)) {
      return this.actions['ATTACH_MULTIPLE_SUPPLEMENTS'];
    } else {
      return this.actions['ATTACH_SUPPLEMENT'];
    }
  },

  // The main event handler while the drag-drop is in progress.
  paneDragEvent: function(event) {
    if (this.eventMode == 'body') {
      return;
    }

    // Dispatch other events to relevant functions.
    if (event.type == 'drop') {
      this.onDrop(event);
      return;
    }

    // Detect the mouse leaving the window, and exit.
    var tgt = event.getTarget('#dd-mask', 2, false);
    if (event.type == 'dragleave' && tgt !== null) {
      event.stopEvent();
      this.hideDragPane();
      return;
    }

    this.hideTask.delay(2000);

    // If we get here, the event is a 'normal' drag event.
    // Loop through the droptargets, checking for overlap.
    var isOverSomething = false;
    for (var i = 0; i < this.targetsList.length; i++) {
      var target = this.targetsList[i];
      if (this.withinBox(event, target.getBox())) {
        // Mouse event is within this target.
        if (this.currentlyHoveredAction != target) {
          // Jumped from one target to another -- 'out' the previous, and 'over' the current target.
          if (this.currentlyHoveredAction != null) {
            this.currentlyHoveredAction.out(event);
          }
          target.over(event);
        }
        // Store the current target for later.
        this.currentlyHoveredAction = target;
        isOverSomething = true;
        break;
      }
    }

    // This should trigger when the mouse leaves a drop target.
    if (!isOverSomething && this.currentlyHoveredAction != null) {
      this.currentlyHoveredAction.out(event);
      this.currentlyHoveredAction = null;
    }

    var be = event.browserEvent;
    if (isOverSomething) {
      be.dataTransfer.effectAllowed = 'copy';
      be.dataTransfer.dropEffect = 'copy';
      be.preventDefault();
    } else {
      be.dataTransfer.effectAllowed = '';
      be.dataTransfer.dropEffect = '';
      be.preventDefault();
    }
  },

  // This should only be called once: when the drag mouse first enters the window.
  bodyDragEvent: function(event) {
    if (event.type == 'dragleave' && event.target != this.dragPane) {
      return;
    }
    if (this.eventMode == 'pane') {
      return;
    }
    if (!this.hideTask) {
      this.hideTask = new Ext.util.DelayedTask(this.hideDragPane, this);
    }
    this.hideTask.cancel();

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
    this.eventMode = 'pane';

    // Create all the drop targets.
    this.createDropTargets(event);
  },

  hideDragPane: function() {
    if (this.hideTask) {
      this.hideTask.cancel();
    }

    // Call the out() method on any hanging hovered action.
    if (this.currentlyHoveredAction != null) {
      this.currentlyHoveredAction.out(event);
      this.currentlyHoveredAction = null;
    }

    // Clear the targets.
    this.targetsList = [];

    // Clear the actions from each DragDropPanel.
    // This doesn't destroy the actions, just hides them and removes them
    // from the DragDropPanel.
    this.ddp.hide();
    this.sideDdp.hide();

    // Put drag events back onto the body and hide the drag pane.
    this.eventMode = 'body';
    this.dragPane.setVisible(false);
  },

  previewPdf: function(event) {
    // Not implemented.
  },

  attachPdf: function(event) {
    var row = Paperpile.main.getCurrentlySelectedRow();
    var grid = Paperpile.main.getCurrentGrid();
    var files = this.getFilesFromEvent(event);
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, row.get('guid'), file.canonicalFilePath, true]);
    }
  },

  importPdf: function(event) {
    var files = this.getFilesFromEvent(event);

    var newFiles =[];

    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.suffix == 'pdf' || file.isDir) {
        newFiles.push(file.canonicalFilePath);
      }
    }

    Paperpile.log(newFiles);

    Paperpile.main.submitPdfExtractionJobs(newFiles);
    
  },

  openFile: function(event) {
    var files = this.getFilesFromEvent(event);
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      var path = file.canonicalFilePath;
      if (this.hasReferenceFileExtension(file)) {
        Paperpile.main.createFileImportTab(path);
      }
    }
  },

  attachSupplement: function(event) {
    var row = Paperpile.main.getCurrentlySelectedRow();
    var grid = Paperpile.main.getCurrentGrid();

    var files = this.getFilesFromEvent(event);
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      Paperpile.main.attachFile.defer(100 * (i + 1), this, [grid, row.get('guid'), file.canonicalFilePath, false]);
    }
  },

  onDrop: function(event) {
    event.stopEvent();

    var dropAction = this.currentlyHoveredAction;
    if (!dropAction) {
      this.hideDragPane();
      return;
    }

    this.hideDragPane();

    // Call the action's handler, passing the event object.
    if (dropAction.handler) {
      var handler = dropAction.handler.createDelegate(this, [event]);
      handler();
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

  // Return true if the current tab is a grid and there is a single selection
  // of an imported reference.
  activeTabIsGrid: function() {
    var activeTab = Paperpile.main.tabs.getActiveTab();
    if (activeTab instanceof Paperpile.PluginPanel) {
      // Ensure that it's a single selection
      var grid = activeTab.getGrid();
      if (grid.getSelectionCount() == 1) {
        var row = Paperpile.main.getCurrentlySelectedRow();
        if (row.get('_imported') && !row.get('_trashed')) {
          return true;
        }
      }
    }
    return false;
  },

  isPdf: function(event) {
    var files = this.getFilesFromEvent(event);

    var hasOnePdf = false;
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.suffix.match(/pdf/i)) {
        hasOnePdf = true;
      }
    }
    if (!hasOnePdf) {
      return false;
    } else {
      return true;
    }
  },

  isFolder: function(event) {
    var files = this.getFilesFromEvent(event);

    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.isDir) {
        return true;
      }
    }
    return false;
  },

  isReferenceFile: function(event) {
    var files = this.getFilesFromEvent(event);

    var hasOneRefFile = false;
    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (this.hasReferenceFileExtension(file)) {
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

  hasReferenceFileExtension: function(file) {
    var ext = file.suffix;
    if (file.suffix.match(/(bib|ris|xml|sqlite|db|ppl|mods|rss)/i)) {
      return true;
    }
    return false;
  },

  isFile: function(event) {
    var files = this.getFilesFromEvent(event);

    for (var i = 0; i < files.length; i++) {
      var file = files[i];
      if (file.isFile) {
        return true;
      }
    }
    return false;
  },

  isMultipleFiles: function(event) {
    var files = this.getFilesFromEvent(event);

    return (files.length > 1);
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
  }

});

// This is the box that represents a given action.
Paperpile.DragDropAction = Ext.extend(Ext.BoxComponent, {
  handler: Ext.emptyFn,
  label: 'Action Label',
  height: 150,
  iconCls: 'pp-folder-generic',
  description: 'Do something when you drop here.',
  autoEl: 'div',
  initComponent: function() {
    Paperpile.DragDropAction.superclass.initComponent.call(this);

    // Get the label/description to align in the middle of the larger box.
    this.on('afterrender', function() {
      this.alignCenter();
    },
    this);
  },

  alignCenter: function() {
    this.getEl().child('.pp-dd-action').alignTo(this.getEl(), 'c-c');
  },

  onRender: function(ct, position) {

    this.tpl = new Ext.Template([
      '<div class="pp-dd-action-wrap pp-dd-action-icon {1}">',
      '  <div class="pp-dd-action">',
      '    <h1>{0}</h1>',
      '    <p>{2}</p>',
      '  </div>',
      '</div>']);
    this.el = this.tpl.append(ct, [this.label, this.iconCls, this.description]);

    Paperpile.DragDropAction.superclass.onRender.call(this, ct, position);
  },

  over: function(event) {
    this.el.addClass('pp-dd-action-wrap-over');
  },

  out: function(event) {
    this.el.removeClass('pp-dd-action-wrap-over');
  },

  getString: function() {
    return this.action + " " + this.el.id;
  },

});

Paperpile.FadingPanel = Ext.extend(Ext.Panel, {
  shadow: false,
  timeout: -1,
  initComponent: function() {
    Paperpile.FadingPanel.superclass.initComponent.call(this);

    this.on('render', function() {
      this.addClass('pp-hidden');
    },
    this);
  },
  show: function() {
    if (this.timeout != -1) {
      clearTimeout(this.timeout);
      timeout = -1;
    }
    this.el.addClass('pp-hidden');
    Paperpile.FadingPanel.superclass.show.call(this);
    this.el.replaceClass('pp-hidden', 'pp-hideable');
  },

  hide: function() {
    this.el.addClass('pp-hideable');
    this.timeout = Paperpile.FadingPanel.superclass.hide.defer(1000, this);
    this.el.replaceClass('pp-hideable', 'pp-hidden');
  }
});

Paperpile.DragDropPanel = Ext.extend(Paperpile.FadingPanel, {
  width: 300,
  autoHeight: true,
  floating: true,
  renderTo: document.body,
  cls: 'pp-dd-panel',
  bodyStyle: 'background:#F0F0F0',

  initComponent: function() {
    Paperpile.DragDropPanel.superclass.initComponent.call(this);
  },

  addAction: function(ddAction) {
    if (this.actionHeight) {
      ddAction.setHeight(this.actionHeight);
    }
    this.add(ddAction);
    // Don't forget to show the action -- it might have been hidden when
    // previously removed using clearActions!
    ddAction.show();
  },

  removeAction: function(ddAction) {
    // Remove the action *without* destroying it.
    this.remove(ddAction, false);
    // We just hide the action instead.
    ddAction.hide();
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
      this.removeAction(i);
    },
    this);
  },

  fitToEl: function(el) {
    var box = el.getBox();

    this.setWidth(box.width);

    var n = this.items.getCount();
    this.items.each(function(i) {
      i.setHeight(box.height / n);
      i.alignCenter();
    });
  },

  alignToScreen: function(string) {
    this.getEl().alignTo(Ext.getDoc(), string);
  },

  alignToElement: function(el, string) {
    this.getEl().alignTo(el, string);
  }
});