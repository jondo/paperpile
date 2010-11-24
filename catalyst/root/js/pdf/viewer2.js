Paperpile.PDFPanel = Ext.extend(Ext.Panel, {

  viewX: -100,
  viewY: -100,
  viewZ: 1.23,
  minZ: 0.01,
  maxZ: 10,
  curPageIndex: 0,

  initComponent: function() {

    Ext.apply(this, {

    });

    Paperpile.PDFPanel.superclass.initComponent.call(this);

    this.on('render', function() {
      this.loadKeys();

      this.mon(this.el, 'keydown', this.keyDown, this);
      this.mon(this.el, 'keyup', this.keyUp, this);
      this.mon(this.el, 'mousedown', this.mouseDown, this);
      this.mon(this.el, 'mouseup', this.mouseUp, this);
      this.mon(this.el, 'mousemove', this.mouseMove, this);
      this.mon(this.el, 'mousewheel', this.mouseWheel, this);
      this.mon(this.el, 'dblclick', this.doubleClick, this);

      this.mon(this.el, 'contextmenu', Ext.emptyFn, null, {
        preventDefault: true
      });

      this.viewportEl = this.el.createChild({
        tag: 'div',
        cls: 'pp-pdf-viewport',
        style: {
          position: 'absolute',
          border: '1px solid green'
        }
      });

      this.canvasEl = this.el.createChild({
        tag: 'div',
        cls: 'pp-pdf-canvas',
        style: {
          width: 30,
          height: 30,
          top: 0,
          left: 0,
          position: 'absolute',
          border: '1px solid blue'
        }
      });

      if (this.file != "") {
        this.initPDF(this.file);
      }

    },
    this);

  },

  initPDF: function(file) {
    this.file = file,

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/pdf/extpdf'),
      params: {
        command: 'INFO',
        inFile: this.file
      },
      success: function(response) {
        var doc = response.responseXML;

        this.pages = new Ext.util.MixedCollection();

        this.pageN = Ext.DomQuery.selectNumber("pageNo", doc);
        var p = Ext.DomQuery.select("page", doc);
        for (var i = 0; i < this.pageN; i++) {
          var width = Ext.DomQuery.selectNumber("width", p[i]);
          var height = Ext.DomQuery.selectNumber("height", p[i]);

          this.pages.add({
            pageNum: i,
            pageWidth: width,
            pageHeight: height
          });
        }
        this.layoutPages();
        this.recalcViewport();

        this.loadVisiblePages();

      },
      scope: this
    });

  },

  loadVisiblePages: function() {
    var visiblePages = this.visiblePages;

    if (visiblePages.length > 8) {
      Paperpile.log("Too many visible pages! Not loading full...");
      return;
    }

    for (var i = visiblePages.length - 1; i >= 0; i--) {
      var pageIndex = visiblePages[i];
      this.addBackgroundTask("Visible Pages", this.loadFullPage, [pageIndex], this, 10, 'urgent');
    }
  },

  loadVisibleThumbnails: function() {
    var visiblePages = this.visiblePages;

    for (var i = 0; i < visiblePages.length; i++) {
      var pageIndex = visiblePages[i];
      var pageObj = this.getPageBoxByNumber(pageIndex);
      if (this.isThumbnailLoaded(pageObj)) {
        var img = this.fly('img-' + pageIndex);
        if (img) {
          img.dom.src = this.getThumbnailUrl(pageObj);
        }
      } else {
        this.loadThumbnail(pageIndex, true);
      }
    }
  },

  layoutPages: function(direction) {

    if (direction === undefined) {
      direction = 'vertical';
    }

    if (direction == 'vertical') {
      var curY = 0;
      for (var i = 0; i < this.pages.getCount(); i++) {
        var page = this.pages.get(i);
        Ext.apply(page, {
          layoutX: 0,
          layoutY: curY,
          layoutWidth: page.pageWidth,
          layoutHeight: page.pageHeight
        });
        curY += page.pageHeight;
        curY += this.getPageMargin();
      }
    } else if (direction == 'horizontal') {
      var curX = 0;
      for (var i = 0; i < this.pages.getCount(); i++) {
        var page = this.pages.get(i);
        Ext.apply(page, {
          layoutX: curX,
          layoutY: 0,
          layoutWidth: page.pageWidth,
          layoutHeight: page.pageHeight
        });
        curX += page.pageWidth;
        curX += this.getPageMargin();
      }

    }

  },

  get: function(id) {
    return Ext.get(this.prefix() + id);
  },

  fly: function(id) {
    return Ext.fly(this.prefix() + id);
  },

  flyImage: function(i) {
    return Ext.fly(this.prefix() + "img-" + i);
  },

  getPage: function(i) {
    return Ext.get(this.prefix() + "page-" + i);
  },

  flyPage: function(i) {
    return Ext.fly(this.prefix() + "page-" + i);
  },

  contentId: function() {
    return this.prefix() + 'content';
  },

  pagesId: function() {
    return this.prefix() + 'pages';
  },

  prefix: function() {
    return this.id + "_";
  },

  getPageBoxByNumber: function(pageNum) {
    return this.pages.get(pageNum);
  },

  getOnePixel: function() {
    return Paperpile.Url("/images/1px-tsp.png");
  },

  pageTemplate: function(pageNum) {
    var pageObj = this.getPageBoxByNumber(pageNum);
    var prefix = this.prefix();
    var pageIndex = pageObj.pageNum;

    var src = this.getOnePixel();
    if (this.isThumbnailLoaded(pageObj)) {
      src = this.getThumbnailUrl(pageObj);
    } else {
      this.addBackgroundTask("Thumbnails", this.loadThumbnail, [pageIndex, true], this, 50, 'background');
    }

    var page = {
      id: prefix + 'page-' + pageIndex,
      tag: 'div',
      cls: 'pp-pdf-page',
      style: {
        display: 'block',
        position: 'absolute',
        top: pageObj.y,
        left: pageObj.x,
        width: pageObj.width,
        height: pageObj.height,
        border: '1px solid red'
      },

      children: [{
        id: prefix + "sticky-" + pageIndex,
        tag: "div",
        style: "display:none;"
      },
      {
        id: prefix + "highlight-" + pageIndex,
        tag: "div",
        style: "display:none;"
      },
      {
        id: prefix + "search-" + pageIndex,
        style: "position:absolute;z-index:-1",
        tag: "div",
        style: "display:none;"
      },
      {
        id: prefix + "img-" + pageIndex,
        tag: "img",
        src: src,
        width: this.roundedWidth(pageObj),
        height: this.roundedWidth(pageObj),
        style: "position:relative;z-index:1;top:0px;left:0px;",
        cls: "pdf-page-img"
      }]

    };

    return page;
  },

  getView: function() {
    return {
      x: this.viewX,
      y: this.viewY,
      z: this.viewZ
    };
  },

  recalcViewport: function(newZoom, animate) {
    if (newZoom === undefined) {
      newZoom = true;
    }
    if (animate === undefined) {
      animate = false;
    }

    var thisBox = this.getBox();
    if (this.viewportEl) {
      this.viewportEl.setBox(this.getBox());
    }

    this.visiblePages = [];
    this.hiddenPages = [];
    for (var i = 0; i < this.pages.getCount(); i++) {
      var pageObj = this.pages.get(i);
      this.applyTransform(pageObj, true);
      if (this.boxesIntersect(thisBox, pageObj)) {
        this.visiblePages.push(pageObj.pageNum);
      } else {
        this.hiddenPages.push(pageObj.pageNum);
      }
    }

    for (var i = 0; i < this.hiddenPages.length; i++) {
      var ind = this.hiddenPages[i];
      var existingPage = this.fly('page-' + ind);
      if (existingPage) {
        existingPage.remove();
      }
    }

    for (var i = 0; i < this.visiblePages.length; i++) {
      var ind = this.visiblePages[i];
      var page = this.fly('page-' + ind);
      var newEl = false;
      if (!page) {
        // Page doesn't exist yet; add it to the DOM.
        if (this.canvasEl) {
          newEl = true;
          var pdfContainer = this.canvasEl;
          Ext.DomHelper.append(pdfContainer, this.pageTemplate(ind), true);
          page = this.fly('page-' + ind);
        }
      }

      var box = this.getPageBoxByNumber(ind);
      var scale = this.formatScale(this.viewZ);
      this.applyTransform(box, false);
      if (newZoom || newEl) {
        if (animate) {
          var s = page.dom.style;
          s.width = box.width;
          s.height = box.height;
          s.top = box.y;
          s.left = box.x;

          var img = this.fly('img-' + ind);
          s = img.dom.style;
          s.width = this.roundedWidth(box);
          s.height = this.roundedHeight(box);

        } else {
          var s = page.dom.style;

          s.width = box.width;
          s.height = box.height;
          s.top = box.y;
          s.left = box.x;
          var img = this.fly('img-' + ind);
          s = img.dom.style;
          s.width = this.roundedWidth(box);
          s.height = this.roundedHeight(box);
        }
      }
    }

    if (this.canvasEl) {
      if (animate && !newZoom) {
        var s = this.canvasEl.dom.style;
        var x = -thisBox.x - this.viewX;
        var y = -thisBox.y - this.viewY;
        s.webkitTransitionProperty = '-webkit-transform';
        s.webkitTransitionDuration = '200ms';
        this.canvasEl.dom.style.webkitTransform = 'translate(' + x + 'px,' + y + 'px)';
      } else {
        var x = -thisBox.x - this.viewX;
        var y = -thisBox.y - this.viewY;
        var s = this.canvasEl.dom.style;
        s.webkitTransitionProperty = '';
        s.webkitTransitionDuration = '';
        s.webkitTransform = 'translate(' + x + 'px,' + y + 'px)';
      }
    }
  },

  getThumbnailScale: function(pageBox) {
    var scale = this.thumbnailSize / pageBox.pageWidth;
    return this.formatScale(scale);
  },

  getThumbnailUrl: function(pageBox) {
    var scale = this.getThumbnailScale(pageBox);
    var url = this.getUrl(pageBox.pageNum, scale);
    return url;
  },

  getFullUrl: function(pageBox) {
    var scale = this.formatScale(this.viewZ);
    var url = this.getUrl(pageBox.pageNum, scale);
    return url;
  },

  boxesIntersect: function(box1, box2) {
    // X intersect.
    var int_x = (box1.x < box2.x && box1.x + box1.width > box2.x) || (box2.x < box1.x && box2.x + box2.width > box1.x);

    // Y intersect.
    var int_y = (box1.y < box2.y && box1.y + box1.height > box2.y) || (box2.y < box1.y && box2.y + box2.height > box1.y);

    return (int_x && int_y);
  },

  getPageMargin: function() {
    return 10;
  },

  getViewCoords: function(input) {
    return {
      x: input.layoutX * this.viewZ,
      y: input.layoutY * this.viewZ,
      width: input.layoutWidth * this.viewZ,
      height: input.layoutHeight * this.viewZ
    };
  },

  applyTransform: function(input, includeTranslation) {
    if (includeTranslation === true) {
      Ext.apply(input, {
        x: (input.layoutX * this.viewZ) + -this.viewX,
        y: (input.layoutY * this.viewZ) + -this.viewY,
        width: (input.layoutWidth) * this.viewZ,
        height: (input.layoutHeight) * this.viewZ
      });
    } else {
      Ext.apply(input, {
        x: (input.layoutX * this.viewZ),
        y: (input.layoutY * this.viewZ),
        width: (input.layoutWidth) * this.viewZ,
        height: (input.layoutHeight) * this.viewZ
      });
    }
  },

  keyDown: function(e) {
    var be = e.browserEvent;
    //      Paperpile.log(be);
    if (be.ctrlKey) {
      this.ctrlDown = true;
    }
    if (be.shiftKey) {
      this.shiftDown = true;
    }
    if (be.metaKey) {
      this.metaDown = true;
    }
  },

  keyUp: function(e) {
    var be = e.browserEvent;
    if (!be.ctrlKey) {
      this.ctrlDown = false;
    }
    if (!be.shiftKey) {
      this.shiftDown = false;
    }
    if (!be.metaKey) {
      this.metaDown = false;
    }

  },

  mouseDown: function(e) {
    var be = e.browserEvent;

    this.downPt = e.getXY();
    this.downView = this.getView();
    this.downCanvas = this.canvasEl.getBox();

    if (be.button === 0) {
      this.isDown = 1; // Left mouse button.
    } else if (be.button === 2) {
      this.isDown = 2; // Right mouse button.
      this.loadVisibleThumbnails();
    }
    e.stopEvent();
  },

  mouseMove: function(e) {
    if (this.isDown === 1) {
      // Left mouse down -- dragging.
      var cur_xy = e.getXY();
      var dx = cur_xy[0] - this.downPt[0];
      var dy = cur_xy[1] - this.downPt[1];
      var downView = this.downView;
      this.viewX = downView.x - dx;
      this.viewY = downView.y - dy;

      this.recalcViewport(false);
    } else if (this.isDown === 2) {
      // Right mouse down -- zooming.
      var cur_xy = e.getXY();
      var dx = cur_xy[0] - this.downPt[0];
      var dy = cur_xy[1] - this.downPt[1];

      var downView = this.downView;
      var dir = 1;
      if (dy > 0) {
        dir = -1;
      }
      var factor = 1 + Math.abs(dy / 50);
      var mult = Math.pow(factor, dir);
      mult = this.formatScale(mult);

      this.viewZ = downView.z * mult;

      if (this.viewZ < this.minZ) {
        this.viewZ = this.minZ;
      }
      if (this.viewZ > this.maxZ) {
        this.viewZ = this.minZ;
      }

      // This correction keeps the zoom origin around the mousedown point.
      var downCanvasDx = this.downPt[0] - this.downCanvas.x;
      var zoomRatio = this.viewZ / downView.z;
      var desiredCanvasDx = downCanvasDx * zoomRatio;
      this.viewX = downView.x + (desiredCanvasDx - downCanvasDx);

      var downCanvasDy = this.downPt[1] - this.downCanvas.y;
      var zoomRatio = this.viewZ / downView.z;
      var desiredCanvasDy = downCanvasDy * zoomRatio;
      this.viewY = downView.y + (desiredCanvasDy - downCanvasDy);

      this.recalcViewport(true);

    }
  },

  mouseWheel: function(e) {
    this.downPt = e.getXY();
    this.downView = this.getView();
    this.downCanvas = this.canvasEl.getBox();
    var downView = this.downView;

    var be = e.browserEvent;
    var cur_xy = e.getXY();

    // 120 or -120
    var wheelDelta = be.wheelDelta;

    var rotDir = 1;
    if (wheelDelta < 0) {
      rotDir = -1;
    }

    if (this.ctrlDown) {
      var rotVal = 1.25;
      var mult = Math.pow(rotVal, rotDir);
      this.viewZ = this.viewZ * mult;

      // This correction keeps the zoom origin around the  mouse down -- very slick.
      this.adjustToZoomPoint(this.downPt, this.downCanvas, this.downView);

      this.recalcViewport(true);

      this.loadVisibleThumbnails();

      this.delayImageLoad();

    } else {
      var dY = -150 * rotDir;
      this.viewY += dY;
      this.recalcViewport(false, true);
      this.delayImageLoad();
    }
  },

  doubleClick: function(e) {
    this.downPt = e.getXY();
    this.downView = this.getView();
    this.downCanvas = this.canvasEl.getBox();
    var downView = this.downView;

    var be = e.browserEvent;

    var mult = Math.pow(2.5, 1);
    this.viewZ = this.viewZ * mult;

    // This correction keeps the zoom origin around the  mouse down -- very slick.
    this.adjustToZoomPoint(this.downPt, this.downCanvas, this.downView);

    this.recalcViewport(true, true);

    this.loadVisibleThumbnails();

    this.delayImageLoad();

  },

  adjustToZoomPoint: function(downPt, downCanvas, downView) {
    var downCanvasDx = downPt[0] - downCanvas.x;
    var zoomRatio = this.viewZ / downView.z;
    var desiredCanvasDx = downCanvasDx * zoomRatio;
    this.viewX = downView.x + (desiredCanvasDx - downCanvasDx);

    var downCanvasDy = downPt[1] - downCanvas.y;
    var zoomRatio = this.viewZ / downView.z;
    var desiredCanvasDy = downCanvasDy * zoomRatio;
    this.viewY = downView.y + (desiredCanvasDy - downCanvasDy);
  },

  mouseUp: function(e) {
    this.isDown = 0;

    this.loadVisiblePages();
  },

  delayRecalcViewport: function(newZoom, timeout) {
    if (timeout === undefined) {
      timeout = 50;
    }

    if (!this.recalcViewportDelay) {
      this.recalcViewportDelay = new Ext.util.DelayedTask();
    }

    this.recalcViewportDelay.delay(timeout, function() {
      this.recalcViewport(newZoom);
    },
    this);

  },

  delayImageLoad: function(timeout) {
    if (timeout === undefined) {
      timeout = 200;
    }

    if (!this.imageLoadDelay) {
      this.imageLoadDelay = new Ext.util.DelayedTask();
    }

    this.imageLoadDelay.delay(timeout, function() {
      this.loadVisiblePages();
    },
    this);
  },

  loadKeys: function() {
    // Borrowed from Window.js
    this.focusEl = this.el.createChild({
      tag: 'a',
      href: '#',
      cls: 'pp-focus',
      tabIndex: '1',
      html: '&#160;'
    });

    // This will hold keyboard shortcuts that should only be active when nothing else has
    // keyboard focus. Mostly for forwarding stuff on to the currently active grid.
    this.sometimesKeys = new Ext.ux.KeyboardShortcuts(this.focusEl, {
      disableOnBlur: true
    });

    var k = this.sometimesKeys;

    k.bindCallback('n', this.scrollNext, this);
    k.bindCallback('p', this.scrollPrev, this);
    k.bindCallback('j', this.scrollNext, this);
    k.bindCallback('k', this.scrollPrev, this);

    k.bindCallback('z', this.zoomToggle, this);

    k.bindCallback('ctrl-[plu,187]', this.zoomIn, this);
    k.bindCallback('ctrl-[min,189]', this.zoomOut, this);
    k.bindCallback('up', this.nudgeUp, this);
    k.bindCallback('down', this.nudgeDown, this);
    k.bindCallback('left', this.nudgeLeft, this);
    k.bindCallback('right', this.nudgeRight, this);
    k.bindCallback('[PgUp,33]', this.pageUp, this);
    k.bindCallback('[PgDown,34]', this.pageDown, this);

    k.bindAction('[End,35]', this.scrollFirst);
    k.bindAction('[Home,36]', this.scrollLast);

    this.focusEl.focus();
  },

  zoomToggle: function() {
    var curPage = this.curPageIndex;
    if (this.isFullPageZoom(curPage)) {

    } else {

    }
  },

  zoomIn: function() {
    this.zoomFactor(1.5);
  },

  zoomOut: function() {
    this.zoomFactor(1 / 1.5);
  },

  zoomFactor: function(factor) {
    var box = this.getBox();
    var pt = [box.x + box.width / 2, box.y + box.height / 2];
    this.downPt = pt;
    this.downView = this.getView();
    this.downCanvas = this.canvasEl.getBox();

    this.viewZ *= factor;

    this.adjustToZoomPoint(this.downPt, this.downCanvas, this.downView);

    this.recalcViewport(true);
    this.loadVisiblePages();

  },

  scrollNext: function() {
    this.scrollDirection(1);
  },

  scrollPrev: function() {
    this.scrollDirection(-1);
  },

  scrollDirection: function(numPages) {
    var curPage = this.curPageIndex;
    curPage = curPage + numPages;
    if (curPage >= this.pages.getCount()) {
      curPage = this.pages.getCount() - 1;
    }
    if (curPage < 0) {
      curPage = 0;
    }

    var box = this.getPageBoxByNumber(curPage);
    var coords = this.getViewCoords(box);
    this.scrollToCenterBox(coords);

    this.curPageIndex = curPage;
  },

  nudgeDist: 100,
  nudgeUp: function() {
    this.nudge(0, -this.nudgeDist);
  },

  nudgeDown: function() {
    this.nudge(0, this.nudgeDist);
  },

  nudgeLeft: function() {
    this.nudge(-this.nudgeDist, 0);
  },

  nudgeRight: function() {
    this.nudge(this.nudgeDist, 0);
  },

  nudge: function(dx, dy) {
    this.viewX += dx;
    this.viewY += dy;

    this.recalcViewport(false, true);
    this.loadVisiblePages();
  },

  scrollToCenterBox: function(box) {
    var thisBox = this.getBox();
    var offsetX = (this.getWidth() - box.width) / 2;
    this.viewX = box.x - thisBox.x - offsetX;
    var offsetY = (this.getHeight() - box.height) / 2;
    this.viewY = box.y - thisBox.y - offsetY;
    this.recalcViewport(false, true);
    this.loadVisiblePages();
  },

  loadSearchAndAnnotations: function(pageIndex) {
    this.loadSearchResultsIntoPage(pageIndex);
    this.loadWords(pageIndex);
    this.updateSearchResultsView();
  },

  urgentTasks: [],
  normalTasks: [],
  backgroundTasks: [],
  bgDT: null,
  boredomDT: null,

  workerDelay: 50,
  boredomDelay: 5000,
  addBackgroundTask: function(name, fn, paramArray, scope, delay, priority) {
    if (delay === undefined) {
      delay = 10;
    }
    if (priority === undefined) {
      priority = 'normal';
    }
    if (scope === undefined) {
      scope = this;
    }
    if (paramArray === undefined) {
      paramArray = [];
    }

    var bgTask = {
      name: name,
      fn: fn,
      params: paramArray,
      scope: scope,
      delay: delay,
      priority: priority
    };
    if (priority == 'background') {
      this.backgroundTasks.push(bgTask);
    } else if (priority == 'urgent') {
      this.urgentTasks.push(bgTask);
    } else {
      this.normalTasks.push(bgTask);
    }

    if (this.bgDT == null) {
      this.bgDT = new Ext.util.DelayedTask();
    }
    if (this.boredomDT == null) {
      this.boredomDT = new Ext.util.DelayedTask();
    }

    this.bgDT.delay(this.workerDelay, this.backgroundWorker, this);
  },

  removeBackgroundTasksByName: function(name) {
    if (name == "") {
      // Remove all tasks.
      this.normalTasks = [];
      this.urgentTasks = [];
      this.backgroundTasks = [];
      return;
    }
    for (var i = 0; i < this.normalTasks.length; i++) {
      var bgTask = this.normalTasks[i];
      if (bgTask.name.match(name)) {
        this.normalTasks.splice(i, 1);
        i--;
      }
    }
    for (var i = 0; i < this.urgentTasks.length; i++) {
      var bgTask = this.urgentTasks[i];
      if (bgTask.name.match(name)) {
        this.urgentTasks.splice(i, 1);
        i--;
      }
    }
    for (var i = 0; i < this.backgroundTasks.length; i++) {
      var bgTask = this.backgroundTasks[i];
      if (bgTask.name.match(name)) {
        this.backgroundTasks.splice(i, 1);
        i--;
      }
    }

  },

  backgroundWorker: function() {
    if (this.destroyedFlag) return;

    var bgTask;
    if (this.urgentTasks.length > 0) {
      bgTask = this.urgentTasks.shift();
    } else if (this.normalTasks.length > 0) {
      bgTask = this.normalTasks.shift();
    } else if (this.backgroundTasks.length > 0) {
      bgTask = this.backgroundTasks.shift();
    }

    if (bgTask != null) {
      this.boredomDT.cancel();
      try {
        //this.log(bgTask);
        //        bgTask.fn.createDelegate(bgTask.scope,bgTask.params);
        bgTask.fn.defer(0, bgTask.scope, bgTask.params);
      } catch(err) {
        Paperpile.log("ERROR Running bgWorker:");
        Paperpile.log(err);
      }
    }

    if (this.urgentTasks.length > 0 || this.normalTasks.length > 0 || this.backgroundTasks.length > 0) {
      this.backgroundWorker.defer(bgTask.delay + 10, this);
    } else {
      this.boredomDT.delay(this.boredomDelay, this.whatToDoWhenBored, this);
      //Paperpile.log("  -> No work left to do! Starting boredom delay...");
    }
  },

  whatToDoWhenBored: function() {
    Paperpile.log("I'm bored! Give me something to do!");

    // Load up the next N full pages.
    var lookAheadPages = 5;
    var pageIndex = this.currentPage;
    while (lookAheadPages >= 0 && pageIndex < this.pageN - 1) {
      if (!this.isPageLoaded(pageIndex)) {
        lookAheadPages--;
        var obj = this.getPageBoxByNumber(pageIndex);
        this.addBackgroundTask("Bored Look-ahead Thumb", this.loadThumbnail, [pageIndex], this, 200, 'background');
        this.addBackgroundTask("Bored Look-ahead", this.loadFullPage, [pageIndex], this, 2000, 'background');
      }
      pageIndex++;
    }
  },

  thumbnailSize: 250,
  loadThumbnail: function(pageIndex, setAsTarget) {
    var pageObj = this.getPageBoxByNumber(pageIndex);
    var i = pageObj.pageNum;
    if (setAsTarget) {
      var imgEl = this.fly('img-' + i);
      if (imgEl != null && imgEl.dom.src.indexOf(this.getOnePixel()) > -1) {
        this.desiredUrls[i] = this.getThumbnailUrl(pageObj);
      }
    }

    var scale = this.getThumbnailScale(pageObj);
    this.loadImage(i, scale);
  },

  isThumbnailLoaded: function(pageBox) {
    var pageIndex = pageBox.pageNum;
    var thumbUrl = this.getThumbnailUrl(pageBox);
    return (this.images[thumbUrl] != null && this.images[thumbUrl].complete);
  },

  roundedWidth: function(pageBox) {
    var w = pageBox.pageWidth;
    return Math.floor(w * this.formatScale(this.viewZ));
  },

  roundedHeight: function(pageBox) {
    var h = pageBox.pageHeight;
    return Math.floor(h * this.formatScale(this.viewZ));
  },

  formatScale: function(scale) {
    return Math.round(scale * 100) / 100;
  },

  desiredUrls: [],
  loadFullPage: function(pageIndex) {
    var obj = this.getPageBoxByNumber(pageIndex);
    var pageIndex = obj.pageNum;
    var scale = this.viewZ;
    scale = this.formatScale(scale);
    if (scale > 8) {
      scale = 8;
    }
    if (scale < 0.1) {
      scale = 0.1;
    }

    this.desiredUrls[pageIndex] = this.getFullUrl(obj);
    var pg = this.getPage(pageIndex);
    if (pg != null) {
      pg.addClass("pdf-page-loading");
    }
    var pageNeedsLoading = this.loadImage(pageIndex, scale);
    return pageNeedsLoading;
  },

  imageLoaded: function(img, pageIndex) {
    //Paperpile.log(pageIndex + "loaded");
    if (pageIndex >= 0) {
      var imgEl = this.fly("img-" + pageIndex);
      if (imgEl != null) {
        var desiredUrl = this.desiredUrls[pageIndex];
        if (img.src.indexOf(desiredUrl) > -1) {
          imgEl.set({
            src: img.src
          });
          var pgEl = this.fly("page-" + pageIndex);
          pgEl.removeClass("pdf-page-loading");

        }
      }
    }
  },

  images: [],

  getUrl: function(pageIndex, scale) {
    return Paperpile.Url("/ajax/pdf/render" + this.file + "/" + pageIndex + "/" + scale);
  },

  loadImage: function(pageIndex, scale) {
    var url = this.getUrl(pageIndex, scale);
    if (this.images[url] != null && this.images[url].complete) {
      //Paperpile.log("  -> No need to reload:" + url);
      this.imageLoaded(this.images[url], pageIndex);
      return false;
    } else {
      var obj = this.getPageBoxByNumber(pageIndex);
      var w = this.roundedWidth(obj);
      var h = this.roundedHeight(obj);
      var imgO = new Image(w, h);
      imgO.src = url;
      imgO.onload = this.imageLoaded.createDelegate(this, [imgO, pageIndex]);
      this.images[url] = imgO;
      return true;
    }
  }

});