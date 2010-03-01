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

Paperpile.PDFviewer = Ext.extend(Ext.Panel, {
  id: '',
  pageN: 0,
  // The total number of pages in the document.
  pageSizes: [],
  // A list of page size objects in the form {w,h}
  words: [],
  // A list of words in the form {x1,y1,x2,y2}
  lines: [],
  searchResults: [],
  // A list of search result rectangles, in the form {x1,y1,x2,y2}
  images: {},
  // A hash containing the URLs of images that have already been loaded.
  delayedTask: null,

  // Internal options and parameters.
  maxPages: 25,

  // In a continuous layout, we have pages from startPage to (startPage+maxPages).
  continuous: true,
  // Whether or not we're laying out continuously or in single-block mode.
  pageLayout: 'flow',
  LAYOUT_CONTINUOUS: 'continuous',
  LAYOUT_FLOW: 'flow',
  LAYOUT_SINGLE: 'single',
  startPage: 0,
  endPage: 0,
  columnCount: 2,
  // In both single and continuous layout, pages are grouped into page
  // blocks according to the columnCount value.
  // Reading state.
  toolMode: 'select',
  currentPage: 0,
  // The current "active" page being viewed
  currentZoom: 1,
  // The current numerical zoom value.
  specialZoom: '',
  // either '' (no special zoom), 'page', or 'width'. If set, then the layout
  // will maintain the full-page zoom upon resizing.
  currentSearchResultPage: 0,
  currentSearchResultPageIndex: 0,
  currentSearchResult: 0,

  viewStartPage: 0,
  // The page at which to start a single-block layout.
  // Initial config options. Only relevant at startup.
  search: '',
  file: '',
  zoom: 'width',
  columns: 0,
  maxInitialWidth: 800,
  //  pageLayout:'continuous',
  // Selection state.
  selection: [],
  selectionStartWord: -1,
  selectionPrevWord: -1,

  // Layout parameters.
  betweenPagePaddingFraction: 1 / 50,
  imageBorderW: 1,

  // UI components.
  keyMap: null,
  searchBar: null,
  slide: null,
  focusEl: null,

  destroyedFlag: false,

  debug: true,
  log: function() {
    if (this.debug) {
      Paperpile.log(arguments);
    }
  },

  initComponent: function() {
    Ext.QuickTips.init();

    this.createZoomArrays();
    var transparentDot = new Image(1, 1);
    transparentDot.src = this.getOnePixel();

    // Handle initial options.
    //    this.columnCount = this.columns;
    //    if (this.pageLayout == "continuous")
    //      this.continuous = true;
    //    else
    //      this.continuous = false;
    // GJ 2009-10-20 override defaults.
    this.columnCount = 1;
    this.continuous = true;
    if (this.zoom == "page") this.specialZoom = 'page';
    if (this.zoom == "width") this.specialZoom = 'width';

    // Ensure that the initial page size isn't too huge.
    this.on('render', function() {
      if (this.specialZoom != '') {
        var currentWidth = this.getRealWidth();
        if (currentWidth > this.maxInitialWidth) {
          this.specialZoom = '';
          var scaleBy = this.maxInitialWidth / currentWidth;
          this.currentZoom = this.currentZoom * scaleBy;
          this.updateZoom();
        }
      }
    },
    this, {
      single: true
    });

    var triggerDelay = new Ext.util.DelayedTask(this.clearSearch, this);

    this.tbItems = {
      'PAGE_NEXT': new Ext.Button({
        handler: this.pageNext,
        scope: this,
        cls: 'x-btn-icon',
        icon: "/ext/resources/images/default/grid/page-next.gif",
        disabled: true,
        tooltip: "Next Page",
        i: this.prefix() + 'next_button'
      }),
      'PAGE_PREV': new Ext.Button({
        handler: this.pagePrev,
        scope: this,
        cls: 'x-btn-icon',
        icon: "/ext/resources/images/default/grid/page-prev.gif",
        disabled: true,
        tooltip: "Previous Page",
        id: this.prefix() + 'pdf_prev_button'
      }),
      'PAGE_FIELD': new Ext.form.TextField({
        enableKeyEvents: true,
        id: this.prefix() + 'pageField',
        name: 'page',
        fieldLabel: 'Page',
        width: 25,
        listeners: {
          keypress: function(f, e) {
            if (e.getKey() == e.ENTER) {
              var newPage = parseInt(f.getValue()) - 1;
              if (newPage != this.currentPage) {
                this.scrollTarget = newPage;
                this.pageScroll(0);
              }
            }
          },
          blur: function(f, e) {
            this.log("Scroll to page!");
            var newPage = parseInt(f.getValue()) - 1;
            if (newPage != this.currentPage) {
              this.scrollTarget = newPage;
              this.pageScroll(0);
            }
          },
          scope: this
        }
      }),
      'PAGE_COUNT': new Ext.Toolbar.TextItem({
        id: this.prefix() + 'page_counter',
        text: 'of 0'
      }),
      'SEARCH_FIELD': new Ext.form.TriggerField({
        enableKeyEvents: true,
        id: this.prefix() + 'search_field',
        name: 'pdfSearch',
        fieldLabel: 'Search',
        triggerClass: 'x-form-search-trigger',
        onTriggerClick: function(e) {
          this.scope.searchDelay();
        },
        width: 100,
        listeners: {
          keypress: function(f, e) {
            if (e.getKey() == Ext.EventObject.ENTER) {
              this.searchDelay();
            }
          },
          scope: this
        },
        scope: this,
        value: this.search
      }),
      'LOAD': new Ext.Button({
        handler: this.openFile,
        icon: "/images/icons/folder_page_white.png",
        cls: 'x-btn-icon',
        tooltip: "Load File",
        scope: this
      }),
      'OPEN_EXTERNAL': new Ext.Button({
        handler: this.openInExternalViewer,
        icon: "/images/icons/page-external.png",
        cls: 'x-btn-icon',
        tooltip: "Open in External Viewer",
        scope: this
      }),
      'ONE_UP': new Ext.Button({
        handler: this.layoutOneUp,
        icon: "/images/icons/1-up.png",
        cls: 'x-btn-icon',
        enableToggle: true,
        //				  toggleGroup:'onetwo',
        tooltip: "One-Up Layout",
        scope: this
      }),
      'TWO_UP': new Ext.Button({
        handler: this.layoutTwoUp,
        icon: "/images/icons/2-up.png",
        cls: 'x-btn-icon',
        enableToggle: true,
        toggleGroup: 'onetwo',
        tooltip: "Two-Up Layout",
        scope: this
      }),
      'FOUR_UP': new Ext.Button({
        id: this.prefix() + 'four_up',
        handler: this.layoutFourUp,
        icon: "/images/icons/4-up.png",
        cls: 'x-btn-icon',
        enableToggle: true,
        toggleGroup: 'onetwo',
        tooltip: "Four-Up Layout",
        scope: this
      }),
      'SINGLE': new Ext.Button({
        handler: this.viewSingle,
        cls: 'x-btn-icon',
        icon: "/images/icons/single-page.png",
        enableToggle: true,
        toggleGroup: 'flow',
        tooltip: "Single Block",
        scope: this
      }),
      'CONTINUOUS': new Ext.Button({
        handler: this.viewContinuous,
        cls: 'x-btn-icon',
        icon: "/images/icons/continuous-pages.png",
        enableToggle: true,
        toggleGroup: 'flow',
        tooltip: "Continuous",
        scope: this
      }),
      'FIT_PAGE': new Ext.Button({
        handler: this.zoomPage,
        text: 'P',
        tooltip: "Fit Page",
        scope: this
      }),
      'FIT_WIDTH': new Ext.Button({
        handler: this.zoomWidth,
        text: 'W',
        tooltip: "Fit Width",
        scope: this
      })
    };

    this.slide = new Ext.Slider({
      cls: 'x-btn-icon',
      vertical: true,
      height: 80,
      value: Math.floor(this.slideZoomArray.length / 2),
      increment: 1,
      minValue: 0,
      maxValue: this.slideZoomArray.length - 1
    });
    this.zmW = new Ext.Toolbar.Button({
      handler: this.zoomWidth,
      //cls:'x-btn-icon',
      scope: this,
      tooltip: "Zoom to Width",
      icon: "/images/icons/fit-width.png"
    });
    this.zmP = new Ext.Toolbar.Button({
      handler: this.zoomPage,
      //cls:'x-btn-icon',
      scope: this,
      tooltip: "Zoom to Page",
      icon: "/images/icons/fit-page.png"
    });

    bi = function(button) {
      cfg = button.initialConfig;
      //return new Ext.menu.ButtonItem(cfg);
      return button;
    };

    this.tbItems['ZOOM_MENU'] = new Ext.ux.AutoHideMenuButton({
      menu: {
        cls: 'no-icon-menu',
        showSeparator: false,
        items: [
          this.slide,
          this.zmW,
          this.zmP]
      },
      icon: "/images/icons/zoom.png",
      enableToggle: false
    });

    this.tbItems['LAYOUT_MENU'] = new Ext.ux.AutoHideMenuButton({
      menu: {
        cls: 'no-icon-menu',
        items: [
          this.tbItems['ONE_UP'],
          this.tbItems['TWO_UP'],
          this.tbItems['FOUR_UP'],
          "-",
          this.tbItems['SINGLE'],
          this.tbItems['CONTINUOUS']]
      },
      icon: "/images/icons/continuous-pages.png",
      enableToggle: false
    });

    this.tbItems['ZOOM_IN'] = new Ext.Button({
      handler: this.zoomIn,
      icon: "/images/icons/zoom-in.png",
      tooltip: "Zoom In",
      scope: this
    });
    this.tbItems['ZOOM_OUT'] = new Ext.Button({
      handler: this.zoomOut,
      icon: "/images/icons/zoom-out.png",
      tooltip: "Zoom Out",
      scope: this
    });

    this.tbItems['SR_PREV'] = bi(new Ext.Button({
      handler: this.searchPrev,
      scope: this,
      cls: 'x-btn-icon',
      icon: "/ext/resources/images/default/grid/page-prev.gif",
      disabled: true,
      //tooltip:"Previous Result",
      id: this.prefix() + 'pdf_prev_search'
    }));
    this.tbItems['SR_NEXT'] = bi(new Ext.Button({
      handler: this.searchNext,
      scope: this,
      //				    cls:'x-btn-icon',
      icon: "/ext/resources/images/default/grid/page-next.gif",
      disabled: true,
      //tooltip:"Next Result",
      id: this.prefix() + 'pdf_next_search'
    }));
    this.tbItems['SR_CLOSE'] = new Ext.Button({
      handler: this.clearSearch,
      scope: this,
      //				    cls:'x-btn-icon',
      icon: "/ext/resources/images/default/tabs/tab-close.gif",
      disabled: false,
      id: this.prefix() + 'pdf_clear_search'
    });
    this.tbItems['SR_TEXT'] = new Ext.Toolbar.TextItem({
      text: '',
      id: this.prefix() + "_sr_text",
      cls: 'search-result-text'
    });

    var searchToolbar = new Ext.Toolbar({
      items: [
        this.tbItems['SR_PREV'],
        this.tbItems['SR_NEXT'],
        this.tbItems['SR_TEXT'],
        this.tbItems['SR_CLOSE']]
    });

    this.searchBar = new Ext.Window({
      id: this.prefix() + 'search_bar',
      draggable: false,
      shadow: true,
      hideCollapseTool: true,
      closable: false,
      collapsible: false,
      floating: true,
      draggable: false,
      resizable: false,
      unstyled: true,
      bbar: searchToolbar,
      cls: 'pdf-search',
      width: 180
    });

    var bbar = {
      items: [
      // this.tbItems['LOAD'], 
      this.tbItems['OPEN_EXTERNAL'], {
        xtype: 'tbseparator'
      },
      this.tbItems['PAGE_PREV'],
      this.tbItems['PAGE_FIELD'],
      this.tbItems['PAGE_COUNT'],
      this.tbItems['PAGE_NEXT'], {
        xtype: 'tbseparator'
      },
      this.tbItems['ZOOM_MENU'],
      this.tbItems['ZOOM_IN'],
      this.tbItems['ZOOM_OUT'], {
        xtype: 'tbseparator'
      },
      this.tbItems['SEARCH_FIELD']],
      plugins: [new Paperpile.CenterToolbar()]
    };

    var pagesId = this.prefix() + "pages";
    var contentId = this.prefix() + "content";

    Ext.apply(this, {
      autoScroll: true,
      enableKeyEvents: true,
      keys: {},
      bbar: bbar,
      html: '<div id="' + contentId + '" class="content-pane" style="left:0pt;top:0pt"><center class="page-pane" id="' + pagesId + '"></center>'
    });

    Paperpile.PDFviewer.superclass.initComponent.call(this);

    this.on('render', this.myAfterRender, this);
    this.on('resize', this.myOnResize, this);
  },

  myAfterRender: function() {
    if (this.file != "") {
      this.initPDF(this.file);
    }

    this.focusEl = this.el.createChild({
      tag: 'a',
      cls: 'x-menu-focus',
      href: '#',
      onclick: 'return false;',
      tabIndex: '-1'
    });

    this.on('activate', this.onActivate, this);
    this.on('deactivate', this.onDeactivate, this);
    this.on('beforedestroy', this.destroy, this);

    this.body.on('scroll', this.onScroll, this);
    this.body.on('mousedown', this.onMouseDown, this);
    this.body.on('mousemove', this.onMouseMove, this);
    //this.body.on('mouseup', this.onMouseUp, this);
    //this.body.on('mouseover',this.onMouseOver,this);
    this.body.on("mousewheel", this.onMouseWheel, this);

    this.tbItems['ZOOM_MENU'].show();

    this.searchBar.show();
    this.searchBar.hide();

    this.delayedTask = new Ext.util.DelayedTask();
    this.loadKeyEvents();

    var bbar = this.getBottomToolbar();
    bbar.getEl().setStyle("z-index", 50);
    bbar.getEl().setStyle("position", "relative");

    this.slide.on("changecomplete", function() {
      this.slideZoom();
    },
    this);
    this.slide.on("change", function() {
      this.slidePreview();
    },
    this);
  },

  getOnePixel: function() {
    return Paperpile.Url("/images/1px-tsp.png");
  },

  focus: function() {
    this.log("Focus!");
    this.focusEl.focus.defer(50, this.focusEl);
  },

  myOnResize: function() {
    if (this.pageSizes.length == 0) {
      // We're probably getting a resize event before the pdf is loaded.
      return;
    }

    //var s = Ext.fly(this.tbItems['SPACER'].getEl());
    //s.setStyle("width","0px");
    //var barWidth = this.getBottomToolbar().getBox().width;
    //var totalWidth = this.getInnerWidth();
    //var spacerWidth = (totalWidth-barWidth)/2;
    //s.setStyle("width",spacerWidth+"px");
    this.updateZoom();
    this.resizePages();
  },

  updateZoom: function() {
    // A zoom level of "1" will always correspond to fitting the page-block width!.
    if (this.pageSizes.length == 0) return;

    if (this.specialZoom == "page") {
      var pageWidth = this.pageSizes[this.currentPage].width;
      var pageHeight = this.pageSizes[this.currentPage].height;

      if (this.columnCount > 1) {
        var cols = this.columnCount;
        var pad = this.betweenPagePaddingFraction;
        pageWidth = pageWidth * cols + (pageWidth * pad * (cols + 1));
      } else {
        var cols = this.columnCount;
        var pad = this.betweenPagePaddingFraction;
        pageWidth = pageWidth * cols + (pageWidth * pad * (cols) + 1);
      }

      var pageRatio = pageWidth / pageHeight;
      var viewRatio = this.getRealWidth() / this.getRealHeight();
      if (pageRatio > viewRatio) {
        // page is wider, so constrain to width.
        this.currentZoom = 1;
      } else {
        // page is taller, so constrain to height.
        this.currentZoom = pageRatio / viewRatio;
      }
    } else if (this.specialZoom == "width") {
      this.currentZoom = 1;
    } else {
      // Do nothing.
    }

    for (var i = 0; i < this.slideZoomArray.length; i++) {
      if (this.currentZoom < this.slideZoomArray[i]) {
        //        this.slide.suspendEvents();
        //        this.slide.setValue(i-1,false);
        //        this.slide.resumeEvents();
        break;
      }

    }
  },

  initPDF: function(file) {
    this.file = file,

    //    this.log("Init!");
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/pdf/extpdf'),
      params: {
        command: 'INFO',
        inFile: this.file
      },
      success: function(response) {
        var doc = response.responseXML;

        this.pageSizes = [];
        this.images = {};
        this.searchResults = [];
        this.words = [];
        this.lines = [];

        this.pageN = Ext.DomQuery.selectNumber("pageNo", doc);
        var p = Ext.DomQuery.select("page", doc);
        for (var i = 0; i < this.pageN; i++) {
          var width = Ext.DomQuery.selectNumber("width", p[i]);
          var height = Ext.DomQuery.selectNumber("height", p[i]);
          this.pageSizes.push({
            width: width,
            height: height
          });
          this.words[i] = [];
          this.lines[i] = [];
        }

        this.setCurrentPage(this.currentPage);
        this.updateButtons();
        this.updateZoom();

        if (this.search != "") {
          this.searchDelay();
        }

        this.startPage = 0;
        this.endPage = (this.pageN >= this.maxPages ? this.maxPages - 1 : this.pageN);
        this.layoutPages();

      },
      scope: this
    });

  },

  prefix: function() {
    return this.id + "_";
  },

  layoutPages: function() {
    if (this.pageLayout == this.LAYOUT_CONTINUOUS) {
      this.log("CONT");
    } else if (this.pageLayout == this.LAYOUT_FLOW) {
      this.log("FLOW");
      this.continuous = true;
      this.columnCount = 1;
      this.layoutFlow();
    } else {

    }
    /*    if (!this.continuous) {
      this.layoutSingle();
    } else {
      this.layoutContinuous();
    }
*/
  },

  pageTemplate: function(pageIndex) {
    var prefix = this.prefix();
    var w = this.getPageWidth(pageIndex);
    var margin = Math.floor(w * this.betweenPagePaddingFraction / 2);

    var src = this.getOnePixel();
    if (this.isThumbnailLoaded(pageIndex)) {
      src = this.getThumbnailUrl(pageIndex);
    }

    var page = {
      id: prefix + "page." + pageIndex,
      tag: "div",
      cls: 'pdf-page',
      style: {
        margin: margin + "px " + margin + "px"
      },
      children: [{
        id: "",
        tag: "div",
        style: {
          position: 'relative',
          'z-index': 0
        },
        children: [{
          id: prefix + "sticky." + pageIndex,
          tag: "div"
        },
        {
          id: prefix + "highlight." + pageIndex,
          tag: "div"
        },
        {
          id: prefix + "search." + pageIndex,
          style: "position:absolute;z-index:-1",
          tag: "div"
        },
        {
          id: prefix + "img." + pageIndex,
          tag: "img",
          src: src,
          width: this.getAdjustedWidth(pageIndex),
          height: this.getAdjustedHeight(pageIndex),
          style: "position:aboslute;z-index:1;top:0px;left:0px;",
          cls: "pdf-page-img"
        }]
      }]
    };

    return page;
  },

  layoutSingle: function() {
    var i;
    //var numPages = this.pageN;
    //var columns = this.columnCount;
    //var continuous = this.continuous;
    //var maxPages = this.maxPages;
    var pagesId = this.prefix() + "pages";
    var pageBlocks = Ext.select("#" + pagesId + " > *");
    pageBlocks.remove();

    var children = [];
    for (var i = 0; i < this.columnCount; i++) {
      var pageIndex = this.viewStartPage + i;
      this.log(pageIndex);
      if (pageIndex > this.pageN - 1) {
        break;
      }
      children.push(this.pageTemplate(pageIndex));
    }

    this.log(children);
    var pdfContainer = this.fly("pages");
    var block = Ext.DomHelper.append(pdfContainer, {
      id: this.prefix() + "pageblock.0",
      tag: "div",
      cls: "pdfblock",
      children: children
    },
    true);
    this.positionBlock(block);

    // Remove old annotation retrieval.
    this.removeBackgroundTasksByName("Layout Annotations");
    this.removeBackgroundTasksByName("Visible Pages");

    // FOR EACH: visible page
    for (i = 0; i < this.columnCount; i++) {
      var pageIndex = this.viewStartPage + i;
      if (pageIndex > this.pageN - 1) {
        break;
      }
      //var imgEl = this.getImage(pageIndex);
      //imgEl.set({src:this.getThumbnailUrl(pageIndex)});
    }

    // FOR EACH: visible page
    for (i = 0; i < this.columnCount; i++) {
      var pageIndex = this.viewStartPage + i;
      if (pageIndex > this.pageN - 1) {
        break;
      }
      this.addBackgroundTask("Layout Annotations", this.loadSearchAndAnnotations, [pageIndex]);
      //      if (!this.isThumbnailLoaded(pageIndex))
      //	this.addBackgroundTask("Thumbnails",this.loadThumbnail,[pageIndex,true],this,500,'background');
    }

    this.addBackgroundTask("Visible Pages", this.loadVisiblePages, [], this, 10, 'urgent');
    this.addBackgroundTask("Update Search Bar", this.updateSearchResultsView, [], this, 10);
  },

  positionBlock: function(block) {
    block.setStyle("width", this.getBlockWidth());
    block.setStyle("position", "relative");
    if (this.getPageHeight() < this.getRealHeight() && !this.continuous) {
      var heightDiff = this.getRealHeight() - this.getPageHeight(0);
      block.setStyle("top", heightDiff / 2);
    } else {
      block.setStyle("top", "0px");
    }
  },

  getBlockWidth: function() {
    var pgW = Math.ceil(this.getPageWidth());
    var pad = Math.ceil(pgW * this.betweenPagePaddingFraction + 1);
    var blockW = (pgW * this.columnCount + pad * (this.columnCount + 1) + this.imageBorderW * 4 * this.columnCount);
    if (blockW < 200 || this.currentZoom <= 1 || this.columnCount == 1) {
      return "";
    } else {
      return blockW + "px";
    }
  },

  layoutFlow: function() {
    var pagesId = this.prefix() + "pages";
    var pageBlocks = Ext.select("#" + pagesId + " > *");
    pageBlocks.remove();
    this.suspendEvents();

    // Remove old annotation retrieval.
    this.removeBackgroundTasksByName("Layout Annotations");
    this.removeBackgroundTasksByName("Visible Pages");

    //    this.addBackgroundTask("Load visible",this.loadVisiblePages,[],this,100,'urgent');
    var numPages = this.endPage - this.startPage;
    var pages = [];
    for (var i = 0; i < numPages; i++) {
      var pageIndex = this.startPage + i;
      var pg = this.pageTemplate(pageIndex);
      var pdfContainer = this.fly("pages");
      var block = Ext.DomHelper.append(pdfContainer, pg, true);

      if (!this.isThumbnailLoaded(pageIndex)) {
        var priority = 'background';
        var time = 500;
        if (pageIndex == 0) {
          priority = 'urgent';
          time = 50;
        }
        this.addBackgroundTask("Thumbnails", this.loadThumbnail, [pageIndex, true], this, time, priority);
      }
      this.addBackgroundTask("Layout Annotations", this.loadSearchAndAnnotations, [pageIndex]);
    }

    this.addBackgroundTask("Update Search Bar", this.updateSearchResultsView);
    this.addBackgroundTask("ScrollDelay", this.scrollDelay, [], this, 50, 'urgent');
    this.resumeEvents();
  },

  layoutContinuous: function() {
    var numPages = this.pageN;
    var columns = this.columnCount;
    var startPage = this.startPage;
    var maxPages = this.maxPages;

    numPages = Math.min(maxPages, numPages);
    var numBlocks = Math.ceil(numPages / columns);

    var pagesId = this.prefix() + "pages";
    var pageBlocks = Ext.select("#" + pagesId + " > *");
    pageBlocks.remove();

    this.suspendEvents();

    for (var i = 0; i < numBlocks; i++) {
      var children = [];

      /*
// TODO: Figure out some way of making a clickable link to show the previous / next N pages.
       if (this.startPage > 0 && i == 0) {
        var previousBlockIndex = Math.max(this.startPage-this.maxPages,0);
        children.push({
          tag:'div',
          id:this.prefix()+" prev-pages",
          html:'<h2>Click to view pages '+this.previousBlockIndex+1+" to "+this.startPage
        });
      }
*/

      for (var j = 0; j < columns; j++) {
        var pageIndex = i * columns + j + this.startPage;
        if (pageIndex > this.pageN - 1) break;
        if (!this.isThumbnailLoaded(pageIndex)) {
          children.push(this.pageTemplate(pageIndex));
        } else {
          children.push(this.pageTemplate(pageIndex));
        }
      }

      var pdfContainer = Ext.get(this.prefix() + "pages");
      var block = Ext.DomHelper.append(pdfContainer, {
        id: this.prefix() + "pageblock." + i,
        tag: "div",
        cls: "pdfblock",
        children: children
      },
      true);
      this.positionBlock(block);

      // FOR EACH: page
      for (var j = 0; j < columns; j++) {
        var pageIndex = i * columns + j + this.startPage;
        if (pageIndex > this.pageN - 1) break;

        this.addBackgroundTask("Layout Annotations", this.loadSearchAndAnnotations, [pageIndex]);
        if (!this.isThumbnailLoaded(pageIndex)) this.addBackgroundTask("Thumbnails", this.loadThumbnail, [pageIndex, true], this, 500, 'background');
      }
    }

    this.addBackgroundTask("Update Search Bar", this.updateSearchResultsView);
    this.resumeEvents();
  },

  resizePages: function(previewMode) {
    if (previewMode === undefined) previewMode = false;

    // Resize each page image.
    for (var i = this.startPage; i < this.startPage + this.maxPages; i++) {
      var pgImg = Ext.fly(this.prefix() + "img." + i);
      if (pgImg != null) {
        //this.log("Resizing page "+i);
        var adjW = this.getAdjustedWidth(i);
        var h = this.getAdjustedHeight(i);
        //this.log("w:"+adjW+" h:"+h);
        pgImg.set({
          width: adjW,
          height: h
        });
        var pgBlinder = Ext.fly(this.prefix() + "blinder." + i);
        if (pgBlinder != null) {
          pgBlinder.setStyle({
            width: adjW,
            height: h,
            top: 0,
            left: 0
          });
        }
      }
    }

    // Re-adjust the between-page padding amounts.
    var pages = Ext.select("#" + this.getId() + " .pdf-page");
    var w = this.getPageWidth(0);
    var margin = Math.floor(w * this.betweenPagePaddingFraction / 2);
    pages.setStyle("margin", margin + "px " + margin + "px");

    // Set the width on the block containers (most important when we're zoomed in with two-up layout)
    var blocks = Ext.select("#" + this.getId() + " .pdfblock");
    //blocks.setStyle("width",this.getBlockWidth());
    this.positionBlock(blocks);

    // Remove all annotations and whatnot.
    var searches = Ext.select("#" + this.getId() + " .pdf-search-result");
    searches.remove();

    if (this.rsDelay == null) {
      this.rsDelay = new Ext.util.DelayedTask();
    }
    this.removeBackgroundTasksByName("Visible Pages");
    this.removeBackgroundTasksByName("Resize Annotations");
    if (!previewMode) {
      this.rsDelay.delay(100, this.resizeTask, this);
    }
  },

  rsDelay: null,
  resizeTask: function() {
    this.log("RESIZING!");
    // Reset the positions of all search results, stickies, annotations, etc.
    // Note: we put these actions on the bg queue, so the resizing happens first.
    // Load the full image of all visible pages.
    this.loadVisiblePages();
    for (var i = this.startPage; i < this.startPage + this.maxPages; i++) {
      var pageIndex = i;
      var img = this.getImage(pageIndex);
      if (img == null) continue;
      this.addBackgroundTask("Resize Annotations", this.loadSearchAndAnnotations, [pageIndex]);
    }
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
        this.log("ERROR Running bgWorker:");
        this.log(err);
      }
    }

    if (this.urgentTasks.length > 0 || this.normalTasks.length > 0 || this.backgroundTasks.length > 0) {
      this.backgroundWorker.defer(bgTask.delay + 10, this);
    } else {
      this.boredomDT.delay(this.boredomDelay, this.whatToDoWhenBored, this);
      this.log("  -> No work left to do! Starting boredom delay...");
    }
  },

  whatToDoWhenBored: function() {
    this.log("I'm bored! Give me something to do!");

    // Load up the next N full pages.
    var lookAheadPages = 5;
    var pageIndex = this.currentPage;
    while (lookAheadPages >= 0 && pageIndex < this.pageN - 1) {
      if (!this.isPageLoaded(pageIndex)) {
        lookAheadPages--;
        this.addBackgroundTask("Bored Look-ahead Thumb", this.loadThumbnail, [pageIndex], this, 200, 'background');
        this.addBackgroundTask("Bored Look-ahead", this.loadFullPage, [pageIndex], this, 2000, 'background');
      }
      pageIndex++;
    }
  },

  getImage: function(i) {
    return Ext.get(this.prefix() + "img." + i);
  },

  getImageFly: function(i) {
    return Ext.fly(this.prefix() + "img." + i);
  },

  getPage: function(i) {
    return Ext.get(this.prefix() + "page." + i);
  },

  getPageFly: function(i) {
    return Ext.fly(this.prefix() + "page." + i);
  },

  getRealHeight: function() {
    var realHeight = this.getInnerHeight() - 2;
    return realHeight;
  },

  getRealWidth: function() {
    var realWidth = this.getInnerWidth() - 2;
    return realWidth;
  },

  getPageHeight: function(i) {
    if (!i) {
      i = 0;
    }
    if (!this.pageSizes[i]) {
      return this.getPageWidth();
    }
    var width = this.getPageWidth();
    var aspectRatio = this.pageSizes[i].height / this.pageSizes[i].width;
    return aspectRatio * width;
  },

  getPageWidth: function() {
    var totalWidth = this.getRealWidth();
    var columns = this.columnCount;

    totalWidth -= totalWidth * this.betweenPagePaddingFraction * 2;
    totalWidth *= this.currentZoom;
    var intWidthPerPage = Math.floor(totalWidth / columns);
    var pagePadding = Math.floor(intWidthPerPage * this.betweenPagePaddingFraction);
    intWidthPerPage -= pagePadding;
    return intWidthPerPage;

    // Tried a more mathematical approach, but rounding errors in CSS are a bitch. Fail.
    // n*x + x*(n+1)/pad = total
    // x = total / (n + [n+1]/pad)
    //var pgW = (totalWidth*this.currentZoom - (2*this.imageBorderW*columns)) / (columns + this.betweenPagePaddingFraction*(columns+1));
    //this.log("pgW: "+pgW);
    //return pgW-2;
  },

  getAdjustedHeight: function(i, scale) {
    if (!scale) {
      scale = this.getScale(i);
    }
    var width = this.getAdjustedWidth(i);
    var ratio = this.pageSizes[i].height / this.pageSizes[i].width;
    var newHeight = width * ratio;
    newHeight = Math.floor(scale * this.pageSizes[i].height);
    return newHeight;
  },

  getAdjustedWidth: function(pageIndex, scale) {
    if (!scale) {
      scale = this.getScale(pageIndex);
    }
    var newWidth = Math.floor(this.pageSizes[pageIndex].width * scale);
    return newWidth;
  },

  getScale: function(pageIndex) {
    var width = this.getPageWidth();
    var scale = (width) / this.pageSizes[pageIndex].width;
    scale = Math.round(scale * 100) / 100;
    return scale;
  },

  getThumbnailUrl: function(pageIndex) {
    var scale = this.thumbnailSize / this.pageSizes[pageIndex].width;
    scale = Math.round(scale * 100) / 100;
    return Paperpile.Url("/ajax/pdf/render" + this.file + "/" + pageIndex + "/" + scale);
  },

  getFullUrl: function(pageIndex) {
    var scale = this.getScale(pageIndex);
    var url = Paperpile.Url("/ajax/pdf/render" + this.file + "/" + pageIndex + "/" + scale);
    return url;
  },

  isThumbnailLoaded: function(pageIndex) {
    var thumbUrl = this.getThumbnailUrl(pageIndex);
    return (this.images[thumbUrl] != null && this.images[thumbUrl].complete);
  },

  isPageLoaded: function(pageIndex) {
    var fullUrl = this.getFullUrl(pageIndex);
    return (this.images[fullUrl] != null && this.images[fullUrl].complete);
  },

  loadImage: function(pageIndex, scale) {
    var url = Paperpile.Url("/ajax/pdf/render" + this.file + "/" + pageIndex + "/" + scale);
    if (this.images[url] != null && this.images[url].complete) {
      //this.log("  -> No need to reload:"+url);
      this.imageLoaded(this.images[url], pageIndex);
      return false;
    } else {
      var w = this.getAdjustedWidth(pageIndex, scale);
      var h = this.getAdjustedHeight(pageIndex, scale);
      var imgO = new Image(w, h);
      imgO.src = url;
      var images = this.images;
      imgO.onload = this.imageLoaded.createDelegate(this, [imgO, pageIndex]);

      this.images[url] = imgO;
      return true;
    }
  },

  thumbnailSize: 150,
  loadThumbnail: function(i, setAsTarget) {
    var scale = this.thumbnailSize / this.pageSizes[i].width;
    scale = Math.round(scale * 100) / 100;
    if (setAsTarget) {
      var imgEl = this.getImageFly(i);
      this.log(imgEl);
      if (imgEl != null && imgEl.dom.src.indexOf(this.getOnePixel()) > -1) {
        this.desiredUrls[i] = this.getThumbnailUrl(i);
      }
    }
    var neededLoading = this.loadImage(i, scale);
    return neededLoading;
  },

  desiredUrls: [],
  loadFullPage: function(pageIndex) {
    var scale = this.getScale(pageIndex);
    if (scale > 10 || scale < 0.1) {
      return false;
    }

    this.desiredUrls[pageIndex] = this.getFullUrl(pageIndex);
    var pg = this.getPage(pageIndex);
    if (pg != null) {
      pg.addClass("pdf-page-loading");
    }
    var pageNeedsLoading = this.loadImage(pageIndex, scale);
    return pageNeedsLoading;
  },

  imageLoaded: function(img, pageIndex) {
    //    this.log(pageIndex + "loaded");
    if (pageIndex >= 0) {
      var imgEl = this.fly("img." + pageIndex);
      if (imgEl != null) {
        var desiredUrl = this.desiredUrls[pageIndex];
        //        this.log(img.src);
        //        this.log(desiredUrl);
        if (img.src.indexOf(desiredUrl) > -1) {
          imgEl.set({
            src: img.src
          });
          var pgEl = this.fly("page." + pageIndex);
          pgEl.removeClass("pdf-page-loading");

        }
      }
    }
  },

  onSearch: function(e) {
    this.log(e);
  },

  clearSearch: function() {
    this.fly("search_field").removeClass("pdf-search-busy");
    var allResults = Ext.select("#" + this.id + " .pdf-search-result");
    allResults.remove();

    this.searchResults = [];
    this.numSearchResults = 0;
    this.searchBar.hide();

    //this.tbItems['SEARCH_FIELD'].trigger.hide();
    this.tbItems['SEARCH_FIELD'].el.dom.value = "";
    this.lastSearchText = "";
  },

  get: function(id) {
    return Ext.get(this.prefix() + id);
  },

  fly: function(id) {
    return Ext.fly(this.prefix() + id);
  },

  lastSearchText: '',
  searchDelay: function(f, e) {
    var sf = this.tbItems['SEARCH_FIELD'];
    var searchText = sf.getValue();
    if (searchText == this.lastSearchText) {
      this.log("No need to repeat search for " + searchText);
      return;
    } else if (searchText === '') {
      this.clearSearch();
      return;
    } else {
      this.tbItems['SEARCH_FIELD'].trigger.show();
    }
    this.lastSearchText = searchText;
    this.fly("search_field").addClass("pdf-search-busy");

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/pdf/extpdf'),
      params: {
        command: 'SEARCH',
        inFile: this.file,
        term: searchText
      },
      success: function(response) {
        this.fly("search_field").removeClass("pdf-search-busy");
        var doc = response.responseXML;

        var allResults = Ext.select("#" + this.id + " .pdf-search-result");
        allResults.remove();

        this.searchResults = [];
        this.numSearchResults = 0;
        this.currentSearchResult = -1;
        var hits = Ext.DomQuery.select("hit", doc);
        var hitDivs = [];
        for (var i = 0; i < hits.length; i++) {
          var value = Ext.DomQuery.selectValue("", hits[i]);
          var values = value.split(' ');
          var pg = values[0];
          var x1 = values[1];
          var y1 = values[2];
          var x2 = values[3];
          var y2 = values[4];
          if (this.searchResults[pg] == null) {
            this.searchResults[pg] = [];
          }
          this.searchResults[pg].push({
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            index: i
          });
          this.numSearchResults++;
        }

        for (var i = this.startPage; i < this.startPage + this.maxPages; i++) {
          if (this.getPage(i) != null) this.addBackgroundTask("Search Loading", this.loadSearchResultsIntoPage, [i]);
        }
        this.addBackgroundTask("Search View Refresh", this.updateSearchResultsView);
      },
      failure: function(response) {
        this.fly("search_field").removeClass("pdf-search-busy");
      },
      scope: this
    });
  },

  updateSearchResultsView: function() {
    this.tbItems['SR_PREV'].disable();
    this.tbItems['SR_NEXT'].disable();

    // Remove the "cur-search-result" class from any other hits.
    var allResults = Ext.select("#" + this.id + " .pdf-search-result");
    allResults.removeClass("pdf-cur-search-result");

    if (this.numSearchResults == 0 && this.lastSearchText == '') {
      this.searchBar.hide();
      return;
    }

    if (this.currentSearchResult > -1) {
      var curResultEl = this.fly("pdf-search-result." + this.currentSearchResultPage + "." + this.currentSearchResultPageIndex);
      if (curResultEl != null && this.isElInView(curResultEl) > 0) {
        curResultEl.addClass("pdf-cur-search-result");
      }
    } else {
      if (this.numSearchResults > 0) {
        this.searchNext();
        return;
      }
    }

    if (this.currentSearchResult > 0) {
      this.tbItems['SR_PREV'].enable();
    }
    if (this.currentSearchResult < this.numSearchResults - 1) {
      this.tbItems['SR_NEXT'].enable();
    }

    var textEl = this.tbItems['SR_TEXT'].el.dom;
    if (this.numSearchResults == 0 && this.lastSearchText != '') {
      textEl.innerHTML = "No results.";
      this.tbItems['SR_TEXT'].render();
    } else if (this.numSearchResults > 0) {
      textEl.innerHTML = (this.currentSearchResult + 1) + " of " + this.numSearchResults + " results";
      this.tbItems['SR_TEXT'].render();
    } else if (this.numSearchResults > 0 && this.currentSearchResult == -1) {
      textEl.innerHTML = this.numSearchResults + " results";
    } else {
      this.searchBar.hide();
      return;
    }
    var sEl = this.tbItems['SEARCH_FIELD'].getEl();
    var xy = this.searchBar.el.getAlignToXY(sEl, 'bl-tl');
    this.searchBar.setPosition(xy);
    //this.searchBar.show(this.tbItems['SEARCH_FIELD'].getEl());
    this.searchBar.show();

    this.focus();
  },

  setCurrentSearchResultToFirstVisible: function() {
    var pages = this.getVisiblePages();
    for (var i = 0; i < pages.length; i++) {
      var curPage = pages[i];
      var srs = this.searchResults[curPage];
      if (srs != null) {
        var j, el;
        for (j = 0; j < srs.length; j++) {
          el = this.fly("pdf-search-result." + curPage + "." + j);
          var amt = this.isElInView(el);
          if (amt > 0.5) {
            this.currentSearchResult = srs[j].index;
            this.currentSearchResultPageIndex = j;
            this.currentSearchResultPage = curPage;
            el.addClass("pdf-cur-search-result");
            break;
          }
        }
      }
    }
  },

  searchNext: function() {
    if (this.currentSearchResult == -1) {
      // This is a little hacky. If we just ran a search. we want to make it so that
      // the currentSearchResult becomes the first result on the currently viewed page.
      this.setCurrentSearchResultToFirstVisible();
      this.updateSearchResultsView();
      this.searchMoveUpdate();
      return;
    }

    if (this.currentSearchResult < this.numSearchResults - 1) this.currentSearchResult++;
    this.searchMoveUpdate();
  },

  searchPrev: function() {
    if (this.currentSearchResult > 0) this.currentSearchResult--;
    this.searchMoveUpdate();
  },

  searchMoveUpdate: function() {
    this.focus();
    if (this.numSearchResults == 0) {
      this.updateSearchResultsView();
      return;
    }

    var count = 0;
    var targetPage = 0;
    var pageIndex = 0;
    for (var i = 0; i < this.pageN; i++) {
      var srs = this.searchResults[i];
      if (srs != null) {
        var endIndex = count + srs.length - 1;
        this.log(i + "  end index:" + endIndex);
        if (endIndex >= this.currentSearchResult) {
          targetPage = i;
          pageIndex = this.currentSearchResult - count;
          break;
        } else {
          count += srs.length;
        }
      }
    }

    this.log("Current result:" + this.currentSearchResult + " page:" + targetPage + " pageind:" + pageIndex);

    // Scroll to a new page if necessary.
    this.log("Search page scroll from:" + this.viewStartPage + " to: " + targetPage);
    this.currentSearchResultPageIndex = pageIndex;
    this.currentSearchResultPage = targetPage;

    if (!this.continuous) {
      var newPage = (targetPage < this.viewStartPage || targetPage > this.viewStartPage);
      if (newPage) {
        this.log("New page!");
        this.scrollTarget = targetPage;
        this.pageScroll(0);
      }
    }

    var curResultEl = this.fly("pdf-search-result." + targetPage + "." + pageIndex);
    this.log(curResultEl);
    if (curResultEl != null) {
      // Scroll to make the target element in view.
      curResultEl.scrollIntoView(this.body, true, false, this.getRealHeight() / 2);
    }
    this.updateSearchResultsView();
  },

  loadSearchResultsIntoPage: function(pageIndex) {
    var results = this.searchResults[pageIndex];
    var pg = pageIndex;

    if (results == null) {
      return;
    }
    var searchHolder = Ext.fly(this.prefix() + "search." + pageIndex);
    if (searchHolder == null) return;

    var hitDivs = [];
    for (var i = 0; i < results.length; i++) {
      bx = results[i];
      var left = this.page2px(bx.x1, pg);
      var top = this.page2px(bx.y1, pg);
      var width = this.page2px(bx.x2 - bx.x1, pg);
      var height = this.page2px(bx.y2 - bx.y1, pg);
      var style = {
        position: 'absolute',
        left: left,
        top: this.getPageHeight(pg) - top - height - 1,
        height: height,
        width: width
      };

      hitDivs.push({
        id: this.prefix() + "pdf-search-result." + pg + "." + i,
        tag: "div",
        cls: 'pdf-search-result',
        style: style
      });
    }

    if (searchHolder != null) {
      var block = Ext.DomHelper.overwrite(searchHolder,
        hitDivs,
        true);
    }
  },

  page2px: function(pageCoord, pageIndex) {
    var pageW = this.getPageWidth(pageIndex);
    var origW = this.pageSizes[pageIndex].width;
    //    this.log(pageW/origW);
    return Math.round(pageCoord * pageW / origW);
    //    var scale=this.canvasWidth/this.pageSizes[pageIndex].width*this.currentZoom;
    //    scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);
    //    return Math.round(pageCoord*scale);
  },

  px2page: function(px, pageIndex) {
    var pageW = this.getPageWidth(pageIndex);
    var origW = this.pageSizes[pageIndex].width;
    //    this.log(px+"  "+pageW+"  "+origW);
    return Math.round(px * origW / pageW);
  },

  holdScroll: false,
  onScroll: function(el) {
    if (!this.holdScroll) {
      this.delayedTask.delay(100, this.scrollDelay, this);;
    }
  },

  getVisiblePages: function() {
    var visiblePages = [];
    var i;
    for (i = 0; i < this.pageN; i++) {
      var pageIndex = i;
      var img = this.getImage(pageIndex);
      if (img == null) continue;
      var amountInView = this.isElInView(img);
      if (amountInView > 0.05) {
        visiblePages.push(pageIndex);
      }
    }
    return visiblePages;
  },

  loadVisibleThumbnails: function() {
    var visiblePages = this.getVisiblePages();
    for (var i = 0; i < visiblePages.length; i++) {
      var pageIndex = visiblePages[i];
      if (!this.isThumbnailLoaded(pageIndex)) this.addBackgroundTask("Visible Thumbnails", this.loadThumbnail, [pageIndex]);
    }
  },

  loadVisiblePages: function() {
    var visiblePages = this.getVisiblePages();

    if (visiblePages.length > 8) {
      this.log("Too many visible pages! Not loading full...");
      return;
    }

    for (var i = visiblePages.length - 1; i >= 0; i--) {
      var pageIndex = visiblePages[i];
      this.addBackgroundTask("Visible Pages", this.loadFullPage, [pageIndex], this, 10, 'urgent');
    }
  },

  timeoutNum: 0,
  scrollDelay: function(el) {
    var i;
    //this.log("Scroll delay!");
    var mostVisiblePage;
    var mostVisibleAmount = 0;
    var curPageVisibleAmount = 0;
    var visiblePages = [];
    for (i = 0; i < this.maxPages; i++) {
      var pageIndex = this.startPage + i;

      var pg = this.getPage(pageIndex);
      var img = this.getImage(pageIndex);
      if (img == null) continue;
      var amountInView = this.isElInView(img);
      if (pageIndex == this.currentPage) curPageVisibleAmount = amountInView;
      if (amountInView > 0) {
        if (amountInView > mostVisibleAmount) {
          mostVisibleAmount = amountInView;
          mostVisiblePage = pageIndex;
        }
        if (amountInView > 0.05) {
          visiblePages.push(pageIndex);
        }
      }
    }

    if (mostVisibleAmount > curPageVisibleAmount) {
      this.setCurrentPage(mostVisiblePage);
    }

    this.loadVisibleThumbnails();
    this.loadVisiblePages();
    this.updateButtons();
    this.updateSearchResultsView();
  },

  isElInView: function(el) {
    if (el == null) return false;
    var bot = el.getBottom() - 1;
    var top = el.getTop() + 1;
    if (bot > this.body.getTop() && top < this.body.getBottom()) {
      var amountInView = this.rangeOverlap(top, bot, this.body.getTop(), this.body.getBottom());
      //      this.log(el.id+"  "+amountInView);
      return amountInView / el.getHeight();
    }
    return 0;
  },

  rangeOverlap: function(a1, a2, b1, b2) {
    var overlap = 0;
    if (a2 < b2 && a1 > b1) {
      return a2 - a1;
    }
    if (a2 > b2 && a1 < b1) {
      return b2 - b1;
    }
    if (a2 < b2) overlap += Math.max(0, a2 - b1);
    if (a1 > b1) overlap += Math.max(0, b2 - a1);
    return overlap;
  },

  loadWords: function(pageIndex) {
    if (this.words[pageIndex].length > 0) return;

    //this.log("Loading words...");
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/pdf/extpdf'),
      params: {
        command: 'WORDLIST',
        page: pageIndex,
        inFile: this.file
      },
      success: function(response) {
        var doc = response.responseXML;
        //this.log("Response: "+response.responseText);
        var words = Ext.DomQuery.select("word", doc);

        for (var i = 0; i < words.length; i++) {
          var value = Ext.DomQuery.selectValue("", words[i]);
          //this.log("Word "+i+" "+value);
          var values = value.split(',');
          var x1 = values[0];
          var y1 = values[1];
          var x2 = values[2];
          var y2 = values[3];
          this.words[pageIndex].push({
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2
          });
        }
        this.calculateLines(pageIndex);
      },

      scope: this
    });
  },

  calculateLines: function(pageIndex) {
    if (this.words[pageIndex].length == 0) return;

    var lines = [];
    var currWord;
    var prevWord;
    var firstWordForLine;

    prevWord = this.words[pageIndex][0];
    var currLine = [prevWord];
    var cutoffX = 5.0;
    var cutoffY = 0.1;
    var distX;
    var distY;

    for (var i = 1; i < this.words[pageIndex].length; i++) {
      currWord = this.words[pageIndex][i];
      prevWord = currLine[currLine.length - 1];

      distX = Math.abs(currWord.x1 - prevWord.x2);
      distY = Math.abs(currWord.y2 - prevWord.y2);

      if ((distY <= cutoffY) || ((currWord.x1 - prevWord.x2 <= cutoffX) && (currWord.y2 > prevWord.y1 && currWord.y2 <= prevWord.y2))) {
        currLine.push(currWord);
      } else {
        lines.push({
          x1: currLine[0].x1,
          y1: currLine[0].y1,
          x2: currLine[currLine.length - 1].x2,
          y2: currLine[0].y2,
          lastWord: i,
          firstWord: firstWordForLine
        });
        currLine = [currWord];
        firstWordForLine = i + 1;
      }
    }

    // push last line
    lines.push({
      x1: currLine[0].x1,
      y1: currLine[0].y1,
      x2: currLine[currLine.length - 1].x2,
      y2: currLine[0].y2,
      lastWord: this.words[pageIndex].length - 1,
      firstWord: firstWordForLine
    });

    this.lines[pageIndex] = lines;
  },

  delaySelect: function(args) {
    if (this.delayS == null) {
      this.delayS = new Ext.util.DelayedTask();
    }
    //this.select.defer(0,this,args);
    this.delayS.delay(10, this.select, this, args);
  },

  lineWithinRegion: function(line, x1, y1, x2, y2) {
    return ((line.y1 > y1 && line.y1 < y2 || y1 > line.y1 && y1 < line.y2) && !(line.x2 < x1 || line.x1 > x2));
  },

  select: function(pageIndex, x1, y1, x2, y2) {
    var i;
    var lines = this.lines[pageIndex];
    var selectedLines = [];
    var selectedWords = [];

    var pi = pageIndex;
    x1 = this.px2page(x1, pi);
    x2 = this.px2page(x2, pi);
    y1 = this.px2page(y1, pi);
    y2 = this.px2page(y2, pi);

    var minX = x1;
    var maxX = x2;

    for (i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (this.lineWithinRegion(line, x1, y1, x2, y2)) {
        selectedLines.push({
          x1: line.x1,
          y1: line.y1,
          x2: line.x2,
          y2: line.y2,
          firstWord: line.firstWord,
          lastWord: line.lastWord
        });
      } else if (i > 0 && this.lineWithinRegion(lines[i - 1], x1, y1, x2, y2) &&
      i < lines.length - 1 && this.lineWithinRegion(lines[i + 1], x1, y1, x2, y2)) {
        selectedLines.push({
          x1: line.x1,
          y1: line.y1,
          x2: line.x2,
          y2: line.y2,
          firstWord: line.firstWord,
          lastWord: line.lastWord
        });
      }
    }

    if (selectedLines.length == 0) {
      return;
    }

    // Adjust the first and last lines if necessary.
    var first = selectedLines[0];
    var minXValue = -1;
    for (i = first.firstWord; i <= first.lastWord; i++) {
      var word = this.words[pageIndex][i];
      if (word.x2 >= x1) {
        if (word.x1 < minXValue || minXValue == -1) minXValue = word.x1;
      }
    }
    first.x1 = minXValue;

    var last = selectedLines[selectedLines.length - 1];
    var maxXValue = -1;
    for (i = last.firstWord; i <= last.lastWord; i++) {
      var word = this.words[pageIndex][i];
      if (word.x1 <= x2) {
        if (word.x2 > maxXValue || maxXValue == -1) maxXValue = word.x2;
      }
    }
    last.x2 = maxXValue;

    Ext.select("#" + this.id + " .pdf-selection").remove();
    var selBoxes = [];
    for (i = 0; i < selectedLines.length; i++) {
      var line = selectedLines[i];

      pi = pageIndex;
      var top = this.page2px(line.y1, pi);
      var left = this.page2px(line.x1, pi);
      var width = this.page2px(line.x2 - line.x1, pi);
      var height = this.page2px(line.y2 - line.y1, pi);

      selBoxes.push({
        'class': 'pdf-selection',
        tag: 'div',
        style: {
          top: top,
          left: left,
          width: width,
          height: height,
          position: 'absolute',
          background: "#1188FF",
          opacity: "0.5"
        }
      });
    }

    var holder = Ext.fly(this.prefix() + "highlight." + pageIndex);
    Ext.DomHelper.append(holder, selBoxes);
  },

  getWord: function(pageIndex, x, y) {
    var words = this.words[pageIndex];
    var word = null;

    x = this.px2page(x, pageIndex);
    y = this.px2page(y, pageIndex);

    for (var i = 0; i < words.length; i++) {
      if (! (x < words[i].x1 || x > words[i].x2) && !(y < words[i].y1 || y > words[i].y2)) {
        word = words[i];
        return i;
      }
    }

    return -1;

  },

  clearSelection: function(i) {
    Ext.select("#" + this.id + " .pdf-selection").remove();
  },

  viewSingle: function() {
    this.continuous = false;
    this.viewStartPage = this.currentPage;
    this.updateLayout();
  },
  viewContinuous: function() {
    this.continuous = true;
    this.viewStartPage = this.startPage;
    this.updateLayout();
  },
  layoutOneUp: function() {
    this.columnCount = 1;
    this.updateLayout();
  },
  layoutTwoUp: function() {
    this.columnCount = 2;
    this.updateLayout();
  },
  layoutFourUp: function() {
    this.columnCount = 4;
    this.updateLayout();
  },

  updateLayout: function() {
    this.updateZoom();
    this.layoutPages();
    this.pageScroll(0);
  },

  pagePrev: function() {
    this.pageScrollPrev();
  },
  pageNext: function() {
    this.pageScrollNext();
  },

  zoomPage: function() {
    this.specialZoom = 'page';
    this.updateZoom();
    this.resizePages();
  },
  zoomWidth: function() {
    this.specialZoom = 'width';
    this.updateZoom();
    this.resizePages();
  },

  getSpecialZoomLevel: function(type) {
    var origZoom = this.currentZoom;
    var origSpecial = this.specialZoom;
    this.specialZoom = type;
    this.updateZoom();
    var destZoom = this.currentZoom;
    this.currentZoom = origZoom;
    this.specialZoom = origSpecial;
    return destZoom;
  },

  between: function(a, b, c) {
    if (a > b && a < c) return true;
    if (a > c && a < b) return true;
    return false;
  },

  slideDelay: null,
  slideZoom: function(preview) {
    if (preview === undefined) preview = false;
    var i = this.slide.getValue();
    var z = this.slideZoomArray[i];
    this.currentZoom = z;
    if (this.currentZoom === "page" || this.currentZoom === "width") this.specialZoom = this.currentZoom;
    else this.specialZoom = '';

    if (this.slideDelay == null) {
      this.slideDelay = new Ext.util.DelayedTask();
    }
    this.slideDelay.delay(50,
      function() {
        this.updateZoom();
        this.resizePages(preview);
        var pgEl = this.getPage(this.currentPage);
        this.holdScroll = true;
        pgEl.scrollIntoView();
        this.holdScroll = false;
      },
      this);
  },

  slidePreview: function() {
    this.slideZoom(true);
  },

  createZoomArrays: function() {
    var i;
    this.smallZoomArray = [];
    this.slideZoomArray = [];
    for (i = -1; i <= 0.8; i += 0.1) {
      this.smallZoomArray.push(Math.pow(10, i));
      this.slideZoomArray.push(Math.pow(10, i));
    }

    this.bigZoomArray = [];
    for (i = -2; i <= 0.8; i += 0.25) {
      this.bigZoomArray.push(Math.pow(10, i));
    }

  },

  slideZoomArray: [],
  bigZoomArray: [],
  smallZoomArray: [],
  zoomInOut: function(dir, big, preview) {
    if (big === undefined) {
      big = true;
    }
    if (preview === undefined) {
      preview = false;
    }

    var curZoom = this.currentZoom;
    this.specialZoom = '';

    var zoomArray = this.bigZoomArray;
    if (!big) {
      zoomArray = this.smallZoomArray;
    }

    var pgZ = this.getSpecialZoomLevel('page');

    var eqIndex = 0;
    var hiIndex = 0;
    for (var i = 0; i < zoomArray.length; i++) {
      if (curZoom > zoomArray[i]) {
        hiIndex = i + 1;
      }
      if (curZoom == zoomArray[i]) {
        hiIndex = i + 1;
        if (dir == -1) hiIndex = i;
        break;
      }
    }

    var destZoom = curZoom;
    if (dir == 1) {
      if (hiIndex >= zoomArray.length) hiIndex = zoomArray.length - 1;
      destZoom = zoomArray[hiIndex];
    } else {
      if (hiIndex == 0) hiIndex = 1;
      destZoom = zoomArray[hiIndex - 1];
    }

    if (destZoom < zoomArray[0]) destZoom = zoomArray[0];
    if (destZoom > zoomArray[zoomArray.length - 1]) destZoom = zoomArray[zoomArray.length - 1];

    if (this.between(pgZ, curZoom, destZoom)) {
      destZoom = pgZ;
    }

    //this.log("oldZ:"+curZoom+" newZ:"+destZoom);
    this.currentZoom = destZoom;
    this.updateZoom();
    this.resizePages(preview);
    var pgEl = this.getPage(this.currentPage);
    this.holdScroll = true;
    pgEl.scrollIntoView(this.body, true);
    this.holdScroll = false;
  },

  zoomIn: function() {
    this.zoomInOut(1, true, false);
  },
  zoomOut: function() {
    this.zoomInOut(-1, true, false);
  },

  menusNeedUpdate: true,
  updateButtons: function() {
    for (var tbItem in this.tbItems) {
      var item = this.tbItems[tbItem];
      if (item instanceof Ext.Button) item.setDisabled(false);
      if (item instanceof Ext.Button) item.toggle(false);
    }

    /*
    if (this.columnCount == 1)
      this.toggleButton(this.tbItems['ONE_UP'],true);
      this.tbItems['ONE_UP'].pressed = true;
    if (this.columnCount == 2)
      this.tbItems['TWO_UP'].toggle(true);
    if (this.columnCount == 4)
      this.tbItems['FOUR_UP'].toggle(true);

    if (this.continuous)
      this.toggleButton(this.tbItems['CONTINUOUS'],true);
    else
      this.toggleButton(this.tbItems['SINGLE'],true);
*/
    var pagesToStart = this.currentPage;
    var pagesToEnd = this.pageN - this.currentPage - 1;
    var blocksRemaining = Math.floor((this.pageN - this.currentPage - 1) / this.columnCount);
    this.tbItems['PAGE_NEXT'].setDisabled(pagesToEnd == 0 || blocksRemaining == 0);
    this.tbItems['PAGE_PREV'].setDisabled(pagesToStart == 0);
  },

  toggleButton: function(button, state) {
    if (button.rendered) {
      button.toggle(state);
    } else {
      button.pressed = state;
    }
  },

  isMouseDown: false,
  mouseDownEl: null,
  mouseDownZoom: 0,
  mouseDownWindowX: 0.0,
  mouseDownWindowY: 0.0,
  mouseDownPageIndex: 0,
  mouseDownPageX: 0,
  mouseDownPageY: 0,
  mouseDownViewportTop: 0,
  mouseDownViewportLeft: 0,
  mouseDownDistToAnchorY: 0,
  mouseDownAnchor: null,

  onMouseDown: function(e) {
    //    this.log(this.prefix()+"mouse down!");
    //    this.body.focus();
    this.focus();

    this.isMouseDown = true;
    this.mouseDownWindowX = e.getPageX();
    this.mouseDownWindowY = e.getPageY();
    var x = this.mouseX;
    var y = this.mouseY;

    if (this.toolMode == 'anchorzoom') {
      this.mouseDownWindowX = e.getPageX();
      this.mouseDownWindowY = e.getPageY();

      this.mouseDownZoom = this.currentZoom;
      this.mouseDownEl = Ext.get(e.getTarget());

      if (this.mouseDownEl.dom.tagName.toLowerCase() == "img") {
        e.stopEvent();
      }

      var el = Ext.get(e.getTarget());
      var elX = el.getX();
      var elY = el.getY();
      var elW = el.getWidth(true);
      var elH = el.getHeight(true);

      if (this.mouseDownAnchor != null) {
        this.mouseDownAnchor.remove();
      }
      var newDiv = new Ext.Element(document.createElement('div'));
      var par = el.parent("div");
      par.appendChild(newDiv);
      newDiv.set({
        id: "anchor"
      });
      //newDiv.setStyle("width",el.getWidth()+"px");
      //newDiv.setStyle("border","1px solid red");
      this.mouseDownAnchor = newDiv;
      this.mouseDownDistToAnchorY = y - this.mouseDownAnchor.getTop();
      this.mouseDownViewportTop = y - (this.body.getTop());

      this.mouseDownViewportLeft = x;
      this.mouseDownPageLeftPct = (x - el.getX()) / el.getWidth();
    }

    if (this.toolMode == 'drag') {
      e.stopEvent();
      Ext.getBody().on('mousemove', this.onMouseMove, this);
      Ext.getDoc().on('mouseup', this.onMouseUp, this);
    }

    if (this.toolMode == 'select') {
      e.stopEvent();
      var x = e.getPageX();
      var y = e.getPageY();

      this.mouseDownPageIndex = this.getPageIndexForEvent(e);
      if (this.mouseDownPageIndex > -1) {
        var img = this.getImage(this.mouseDownPageIndex);
        if (img != null) {
          var pt = img.translatePoints(x, y);

          this.mouseDownPageX = pt.left;
          this.mouseDownPageY = pt.top;

          this.clearSelection();
        }
      }

      Ext.getBody().on("mousemove", this.onMouseMove, this);
      Ext.getDoc().on("mousemove", this.onMouseMove, this);
      Ext.getBody().on("mouseup", this.onMouseUp, this);
      Ext.getDoc().on("mouseup", this.onMouseUp, this);
    }
  },

  getPageIndexForEvent: function(e) {
    var t = e.getTarget();
    var id = t.id;
    var index = id.lastIndexOf(".") + 1;
    if (index > 0) {
      var pageIndex = id.substr(index);
      //      this.log(pageIndex);
      return pageIndex;
    } else {
      return -1;
    }
  },

  anchoredZoom: function(mouseDownWindowY, mouseDownZoom, mouseDownAnchorDist, mouseDownViewportTop) {

  },

  onMouseMove: function(e) {
    var x = e.getPageX();
    var y = e.getPageY();
    this.mouseX = x;
    this.mouseY = y;

    if (this.toolMode == 'drag') {
      e.stopEvent();
      if (e.within(this.body)) {
        var xDelta = x - this.mouseX;
        var yDelta = y - this.mouseY;
        this.body.dom.scrollLeft -= xDelta;
        this.body.dom.scrollTop -= yDelta;
      }
    }

    if (this.toolMode == 'select') {
      if (this.isMouseDown) {
        var pageIndex = this.mouseDownPageIndex;
        if (pageIndex == -1) return;
        e.stopEvent();
        var img = this.getImage(pageIndex);
        if (img == null) return;
        var pt = img.translatePoints(x, y);

        var box = Ext.get(this.prefix() + "selection-box");
        if (box == null) {
          box = Ext.DomHelper.append(Ext.getBody(), {
            id: this.prefix() + "selection-box",
            tag: 'div',
            style: {
              border: "1px dashed black",
              position: "absolute"
            }
          },
          true);
          box.on("mousemove", this.onMouseMove, this);
          box.on("mouseup", this.onMouseUp, this);
        }

        var downX = this.mouseDownWindowX;
        var downY = this.mouseDownWindowY;
        var curX = x;
        var curY = y;
        box.setStyle({
          left: Math.min(downX, curX),
          top: Math.min(downY, curY),
          width: Math.abs(curX - downX),
          height: Math.abs(curY - downY)
        });

        var pageDX = this.mouseDownPageX;
        var pageDY = this.mouseDownPageY;
        var pageCX = pt.left;
        var pageCY = pt.top;

        var args = [pageIndex, pageDX, pageDY,
          pageCX, pageCY];
        this.delaySelect(args);

      }
    }
  },

  onMouseUp: function(e) {
    var x = e.getPageX();
    var y = e.getPageY();
    this.isMouseDown = false;

    if (this.toolMode == 'anchorzoom') {
      e.stopEvent();

    }

    if (this.toolMode == 'drag') {
      Ext.getBody().un('mousemove', this.onMouseMove, this);
      Ext.getDoc().un('mouseup', this.onMouseUp, this);
    }

    if (this.toolMode == 'select') {
      var box = Ext.get(this.prefix() + "selection-box");
      if (box != null) {
        box.remove();
      }

      Ext.getBody().un("mousemove", this.onMouseMove, this);
      Ext.getDoc().un("mousemove", this.onMouseMove, this);
      Ext.getBody().un("mouseup", this.onMouseUp, this);
      Ext.getDoc().un("mouseup", this.onMouseUp, this);
    }

  },

  animateZoomTo: function() {
    this.zoomCfg = {
      duration: 2,
      easing: "easeOutStrong"
    };
    this.zoomAnim = Ext.lib.Anim.motion(this.el, {
      zoomLevel: {
        from: 1,
        to: 2
      }
    });
    this.zoomAnim.onTween.addListener(
      function() {
        this.currentZoom = this.el.getStyle("zoomLevel");
        //this.log(this.el.getStyle("zoomLevel"));
        this.onResize(false);
      },
      this);
    this.zoomAnim.animate();
  },

  zoomToPage: function() {

  },

  zoomToWidth: function() {

  },

  loadKeyEvents: function() {
    this.keys = new Ext.KeyMap(this.focusEl, [{
      key: [Ext.EventObject.LEFT, Ext.EventObject.RIGHT, Ext.EventObject.UP, Ext.EventObject.DOWN,
        Ext.EventObject.PAGE_UP, Ext.EventObject.PAGE_DOWN],
      fn: this.keyNav,
      scope: this
    },
    {
      key: [191],
      fn: this.keySearch,
      scope: this
    },
    // '/' to focus search box.
    {
      key: [Ext.EventObject.F3],
      fn: this.keySearch,
      scope: this
    },
    {
      key: [Ext.EventObject.F],
      fn: this.keySearch,
      scope: this
    },
    {
      key: [Ext.EventObject.G],
      fn: this.keySearch,
      scope: this
    },
    {
      key: [107, 109],
      // ctrl_+, ctrl_-
      fn: this.keyZoom,
      ctrl: true,
      scope: this
    },
    {

    }]);
  },

  keyNav: function(k, e) {
    switch (e.getKey()) {
    case Ext.EventObject.LEFT:
      if (this.currentZoom <= 1) {
        e.preventDefault();
        this.pageScrollPrev();
      }
      break;
    case Ext.EventObject.RIGHT:
      if (this.currentZoom <= 1) {
        e.preventDefault();
        this.pageScrollNext();
      }
      break;
    case Ext.EventObject.PAGE_UP:
      e.preventDefault();
      if (!this.continuous) {
        this.pageScrollPrev();
      } else {
        var pad = this.getPageWidth() * this.betweenPagePaddingFraction;
        this.body.scroll("up", this.getPageHeight() + pad + 4);
      }
      break;
    case Ext.EventObject.PAGE_DOWN:
      e.preventDefault();
      if (!this.continuous) {
        this.pageScrollNext();
      } else {
        var pad = this.getPageWidth() * this.betweenPagePaddingFraction;
        this.body.scroll("down", this.getPageHeight() + pad + 4);
      }
      break;
    default:

      break;
    }
  },

  keySearch: function(k, e) {
    e.stopEvent();
    var key = e.getKey();
    if (key == Ext.EventObject.F || key == 191) {
      this.tbItems['SEARCH_FIELD'].focus();
    } else if (key == Ext.EventObject.F3 || key == Ext.EventObject.G) {
      if (e.shiftKey) {
        this.searchPrev();
      } else {
        this.searchNext();
      }
    }
  },

  keyZoom: function(k, e) {
    e.preventDefault();
    this.log("Zoom!" + e);
    switch (e.getKey()) {
    case 107:
      // +
      this.zoomIn();
      break;
    case 109:
      // -
      this.zoomOut();
      break;
    }
  },

  onMouseWheel: function(e) {
    if (e.ctrlKey) {

      // Set the current page by the mouse target.
      this.log(e.getTarget());
      var t = e.getTarget();
      var id = t.id;
      var index = id.lastIndexOf(".") + 1;
      if (index > 0) {
        var pageIndex = id.substr(index);
        this.setCurrentPage(parseInt(pageIndex));
      }

      var delta = e.getWheelDelta();
      if (delta > 0) {
        this.zoomInOut(1, false, true);
        //this.rsDelay.delay(300,this.resizeTask,this);
        e.stopEvent();
      } else if (delta < 0) {
        this.zoomInOut(-1, false, true);
        //this.rsDelay.delay(300,this.resizeTask,this);
        e.stopEvent();
      }
    }
  },

  pageScrollNext: function() {
    this.pageScroll(this.columnCount);
  },

  pageScrollPrev: function() {
    this.pageScroll(-this.columnCount);
  },

  scrollTarget: 0,
  pageScroll: function(dir) {
    dir = parseInt(dir);

    // Do some checks on the original scroll target to see if we don't want to scroll at all.
    if (dir < 0 && this.scrollTarget == 0) {
      this.scrollToPage(this.scrollTarget);
      return;
    }
    if (dir > 0 && this.scrollTarget + this.columnCount - 1 >= this.pageN - 1) {
      this.scrollToPage(this.scrollTarget);
      return;
    }

    this.scrollTarget += dir;
    if (this.scrollTarget < 0) this.scrollTarget = 0;
    if (this.scrollTarget > this.pageN - 1) this.scrollTarget = this.pageN - 1;

    var scrollTarget = this.scrollTarget;
    this.currentPage = this.scrollTarget;

    if (!this.continuous) {
      this.viewStartPage = scrollTarget;
      this.layoutPages();
      //this.scrollToPage(this.scrollTarget);
      return;
    } else if (scrollTarget > this.startPage + this.maxPages) {
      // Load the next bunch of pages.
      this.startPage += this.maxPages;
      this.viewStartPage = this.startPage;
      this.layoutPages();
      this.scrollToPage(this.scrollTarget);
    } else if (scrollTarget < this.startPage) {
      // Load the previous bunch.
      this.startPage -= this.maxPages;
      if (this.startPage < 0) this.startPage = 0;
      this.viewStartPage = this.startPage;
      this.layoutPages();
      this.scrollToPage(this.scrollTarget);
    }

    this.scrollToPage(this.scrollTarget);
  },

  setCurrentSearchResult: function(index) {

  },

  setCurrentPage: function(page) {
    this.currentPage = page;
    this.scrollTarget = page;

    var pf = this.tbItems['PAGE_FIELD'];
    pf.setValue((this.currentPage + 1));

    // Update the current page's CSS style.
    var pageImages = Ext.select("#" + this.id + " .pdf-page-img");
    pageImages.removeClass("pdf-cur-page");
    var img = this.getImage(this.currentPage);
    if (img != null) {
      //this.log("Setting cur pgae!");
      img.addClass("pdf-cur-page");
    }

    var pt = this.tbItems['PAGE_COUNT'];
    var totalPages = this.pageN;
    pt.setText("of " + totalPages);
  },

  scrollAnimation: null,

  scrollToPage: function(scrollTarget) {
    if (scrollTarget >= this.pageN) scrollTarget = this.pageN - 1;
    if (scrollTarget < 0) scrollTarget = 0;

    //this.log(scrollTarget);
    var pgEl = this.getPage(scrollTarget);
    pgEl.scrollIntoView(this.body, true);
    this.setCurrentPage(scrollTarget);
    this.loadVisiblePages();
    this.updateButtons();
    //this.scrollDelay();
    //this.loadFullPage(scrollTarget);
  },

  openInExternalViewer: function() {
    Paperpile.main.openPdfInExternalViewer(this.file);
  },

  openFile: function() {
    var win = new Paperpile.FileChooser({
      showFilter: true,
      filterOptions: [{
        text: 'PDF documents (.pdf)',
        suffix: ['pdf']
      },
      {
        text: 'All files',
        suffix: ['ALL']
      }],
      callback: function(button, path) {
        if (button == 'OK') {
          this.log(path);
          this.initPDF(path);
        }
      },
      scope: this
    });
    win.show();
  },

  onActivate: function() {
    this.updateSearchResultsView();
  },

  onDeactivate: function() {
    // Hide the pesky search bar if necessary.
    if (this.searchBar.isVisible) this.searchBar.hide();

    if (this.boredomDT != null) this.boredomDT.cancel();
    if (this.bgDT != null) this.bgDT.cancel();
    if (this.delayedTask != null) this.delayedTask.cancel();
    if (this.delayS != null) this.delayS.cancel();
    if (this.slideDelay != null) this.slideDelay.cancel();
  },

  destroy: function() {
    this.destroyedFlag = true;

    this.urgentTasks = [];
    this.normalTasks = [];
    this.backgroundTasks = [];
    this.boredomDT.cancel();
    this.bgDT.cancel();
    this.removeBackgroundTasksByName();

    Ext.get(this.id).remove();

    this.searchResults = null;
    this.pageSizes = null;
    this.words = null;
    this.lines = null;
    this.images = null;
    this.selection = null;
  }

});
Ext.reg('pdfviewer', Paperpile.PDFviewer);

var A = Ext.lib.Anim;
Ext.override(Ext.Element, {
  scrollTo: function(left, top, animate) {
    if (typeof left != 'number') {
      if (left.toLowerCase() == 'left') {
        left = top;
        top = this.dom.scrollTop;
      } else {
        left = this.dom.scrollLeft;
      }
    }
    if (!animate || !A) {
      this.dom.scrollLeft = left;
      this.dom.scrollTop = top;
    } else {
      this.anim({
        scroll: {
          'to': [left, top]
        }
      },
      this.preanim(arguments, 2), 'scroll');
    }
    return this;
  },

  scrollIntoCenter: function(container, padTop, padLeft) {

  },

  scrollIntoView: function(container, hscroll, animate, padding) {
    if (padding == null) {
      padding = 10;
    }

    var c = Ext.fly(container, '_scrollIntoView') || Ext.getBody();
    var el = this.dom;
    var o = this.getOffsetsTo(c),
    ct = parseInt(c.dom.scrollTop, 10),
    cl = parseInt(c.dom.scrollLeft, 10),
    ch = c.dom.clientHeight,
    cb = ct + ch,
    t = o[1] + ct,
    h = el.offsetHeight,
    b = t + h;
    if (h > ch || t < ct) {
      ct = t - padding;
    } else if (b > cb) {
      ct = b - ch + padding;
    }
    if (hscroll !== false) {
      var cw = c.dom.clientWidth,
      cr = cl + cw;
      l = o[0] + cl,
      w = el.offsetWidth,
      r = l + w;
      if (w > cw || l < cl) {
        cl = l;
      } else if (r > cr) {
        cl = r - cw;
      }
    }
    return c.scrollTo(cl, ct, animate);
  },

  scrollChildIntoView: function(child, hscroll, animate) {
    Ext.fly(child, '_scrollChildIntoView').scrollIntoView(this, hscroll, animate);
  }
});

// A plugin to make a toolbar's contents centered.
Paperpile.CenterToolbar = (function() {
  return {
    init: function(toolbar) {
      Ext.apply(toolbar, {});
      toolbar.on('afterlayout', this.myAfterLayout, this);
    },

    myAfterLayout: function(tb) {
      var tbl = tb.getEl().child('.x-toolbar-left table');
      tbl.wrap({
        tag: 'center'
      });
    }
  };
});