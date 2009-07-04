Paperpile.TextItem = function(t){
  var s = document.createElement("span");
  s.className = "ytb-text";
  s.innerHTML = t.text ? t.text : t;
  Paperpile.TextItem.superclass.constructor.call(this, s);

  this.id = t.id ? t.id : Ext.id(this.el);
  this.el.id = this.id;
  Ext.ComponentMgr.register(this);
};
Ext.extend(Paperpile.TextItem,Ext.Toolbar.Item, {
	     enable:Ext.emptyFn,
	     disable:Ext.emptyFn,
	     focus:Ext.emptyFn,
	     setText : function (text) {
	       this.el.innerHTML = text;
	     }});
Ext.reg('pptext', Paperpile.TextItem);

log = function(text) {
  console.log(text);
};

Paperpile.PDFviewer = Ext.extend(Ext.Panel, {
  toolMode: 'anchorzoom',


  pageN:0,                         // The total number of pages in the document.
  pageSizes:[],                    // A list of page size objects in the form {w,h}
  words:[],                        // A list of words in the form {x1,y1,x2,y2}
  lines:[],
  searchResults:[],                // A list of search result rectangles, in the form {x1,y1,x2,y2}
  images:{},                       // A hash containing the URLs of images that have already been loaded.
  loadedImages:{},

  delayedTask:null,

  // In a continuous layout, we have pages from startPage to (startPage+maxPages).
  continuous:true,                 // Whether or not we're laying out continuously or in single-block mode.
  startPage:0,
  maxPages:40,

  columnCount:2,                   // In both single and continuous layout, pages are grouped into page
                                   // blocks according to the columnCount value.

  // Reading state.
  currentPage:0,                   // The current "active" page being viewed
  currentZoom: 1,                // The current numerical zoom value.
  specialZoom:'',              // either '' (no special zoom), 'page', or 'width'. If set, then the layout
                                   // will maintain the full-page zoom upon resizing.

  // Initial config options. Only relevant at startup.
  search:'',
  file:'',
  zoom:'width',
  columns:0,
  pageLayout:'continuous',

  // Selection state.
  selection:[],
  selectionStartWord:-1,
  selectionPrevWord:-1,

  slide:null,
  // Layout parameters.
  betweenPagePaddingFraction:1/50,
  imageBorderW:1,

  keyMap:null,

  floatingSearchBar:null,

  initComponent: function() {

    Ext.QuickTips.init();

    // Handle initial options.
    this.columnCount = this.columns;
    if (this.pageLayout == "continuous")
      this.continuous = true;
    else
      this.continuous = false;
    if (this.zoom == "page")
      this.specialZoom = 'page';
    if (this.zoom == "width")
      this.specialZoom = 'width';


    this.tbItems = {
      'PAGE_NEXT': new Ext.Button({
				    handler:this.pageNext,
				    scope:this,
				    cls:'x-btn-icon',
				    icon:"/ext/resources/images/default/grid/page-next.gif",
				    disabled:true,
				    tooltip:"Next Page",
				    itemId:'next_button'
				  }),
      'PAGE_PREV': new Ext.Button({
				    handler:this.pagePrev,
				    scope:this,
				    cls:'x-btn-icon',
				    icon:"/ext/resources/images/default/grid/page-prev.gif",
				    disabled:true,
				    tooltip:"Previous Page",
				    itemId:'pdf_prev_button'
				  }),
      'PAGE_FIELD': new Ext.form.TextField({
					     enableKeyEvents:true,
					     id:'pageField',
					     name:'page',
					     fieldLabel:'Page',
					     width:25,
					     listeners: {
					       keypress: function(f,e) {
						 if (e.getKey() == e.ENTER) {
						   this.scrollToPage(parseInt(f.getValue())-1);
						 }
					       },
					       blur: function(f,e) {
						 this.scrollToPage(parseInt(f.getValue())-1);
					       },
					       scope:this
					     }
					   }),
      'PAGE_COUNT': new Paperpile.TextItem({
					       xtype:'pptext',
					       id:'pageCounter',
					     itemId:'asdf',
					       text:'of 0'
					     }),
      'SEARCH_FIELD': new Ext.form.TextField({
					       enableKeyEvents:true,
					       id:'searchField',
					       name:'pdfSearch',
					       fieldLabel:'Search',
					       width:125,
					       listeners: {
						 keypress: function(f,e) {
						   this.onSearch(f,e);
						 },
						 blur: function(f,e) {
						   this.onSearch(f,e);
						 },
						 scope:this
					       },
					       value:this.search
					     }),
    'LOAD':new Ext.Button({
				  handler:this.openFile,
				  icon:"/images/icons/folder_page_white.png",
				  cls:'x-btn-icon',
				  tooltip:"Load File",
				  scope:this
			  }),
    'ONE_UP':new Ext.Button({
				  handler:this.layoutOneUp,
				  icon:"/images/icons/1-up.png",
				  cls:'x-btn-icon',
				  enableToggle:true,
				  toggleGroup:'onetwo',
				  tooltip:"One-Up Layout",
				  scope:this
			    }),
      'TWO_UP':new Ext.Button({
				  handler:this.layoutTwoUp,
				  icon:"/images/icons/2-up.png",
				  cls:'x-btn-icon',
				  enableToggle:true,
				  toggleGroup:'onetwo',
				  tooltip:"Two-Up Layout",
				  scope:this
			      }),
      'FOUR_UP':new Ext.Button({
				 id:'four_up',
				  handler:this.layoutFourUp,
				  icon:"/images/icons/4-up.png",
				  cls:'x-btn-icon',
				  enableToggle:true,
				  toggleGroup:'onetwo',
				  tooltip:"Four-Up Layout",
				  scope:this
			       }),
      'SINGLE':new Ext.Button({
				     handler:this.viewSingle,
				     cls:'x-btn-icon',
				     icon:"/images/icons/single-page.png",
				     enableToggle:true,
				     toggleGroup:'flow',
				     tooltip:"Single Block",
				     scope:this
			      }),
      'CONTINUOUS':new Ext.Button({
				     handler:this.viewContinuous,
				     cls:'x-btn-icon',
				     icon:"/images/icons/continuous-pages.png",
				     enableToggle:true,
				     toggleGroup:'flow',
				     tooltip:"Continuous",
				     scope:this
				     }),
      'FIT_PAGE': new Ext.Button({
				  handler:this.zoomPage,
				  text:'P',
				  tooltip:"Fit Page",
				  scope:this
				 }),
      'FIT_WIDTH':new Ext.Button({
				 handler:this.zoomWidth,
				 text:'W' ,
				 tooltip:"Fit Width",
				 scope:this
				 })
    };

    this.slide = new Ext.menu.SliderItem({
					   cls:'x-btn-icon',
					  vertical:true,
					  height:80,
					  value: Math.floor(this.slideZoomArray.length/2),
					  increment: 1,
					  minValue: 0,
					  maxValue: this.slideZoomArray.length-1
    });
    this.zmW = new Ext.menu.ButtonItem({handler:this.zoomWidth,
					cls:'x-btn-icon',
					scope:this,
					tooltip:"Zoom to Width",
					icon:"/images/icons/fit-width.png"
    });
    this.zmP = new Ext.menu.ButtonItem({handler:this.zoomPage,
					cls:'x-btn-icon',
					scope:this,
					tooltip:"Zoom to Page",
					icon:"/images/icons/fit-page.png"
    });


    bi = function(button) {
      cfg = button.initialConfig;
      return new Ext.menu.ButtonItem(cfg);
    };

    this.tbItems['ONE_UP_B'] = bi(this.tbItems['ONE_UP']);
    this.tbItems['TWO_UP_B'] = bi(this.tbItems['TWO_UP']);
    this.tbItems['FOUR_UP_B'] = bi(this.tbItems['FOUR_UP']);
    this.tbItems['CONTINUOUS_B'] = bi(this.tbItems['CONTINUOUS']);
    this.tbItems['SINGLE_B'] = bi(this.tbItems['SINGLE']);

    this.tbItems['ZOOM_MENU'] = new Ext.HoverButton({
					menu: {
					  items:[
					    this.slide,
					    this.zmW,
					    this.zmP
					  ]
					},
					icon:"/images/icons/zoom.png",
					cls:'x-btn-icon',
					enableToggle:false
				      });

    this.tbItems['LAYOUT_MENU'] = new Ext.HoverButton({
					menu: {
					  items:[
					    this.tbItems['ONE_UP_B'],
					    this.tbItems['TWO_UP_B'],
					    this.tbItems['FOUR_UP_B'],
					    "-",
					    this.tbItems['SINGLE_B'],
					    this.tbItems['CONTINUOUS_B']
					  ]
					},
					icon:"/images/icons/continuous-pages.png",
					cls:'x-btn-icon',
					enableToggle:false
				      });


    var inZ = new Ext.Button({
				 handler:this.zoomIn,
				 text:'+' ,
				 tooltip:"Zoom In",
				 scope:this
			       });
    var outZ = new Ext.Button({
				 handler:this.zoomOut,
				 text:'-' ,
				 tooltip:"Zoom Out",
				 scope:this
			       });

    this.tbItems['SPACER'] = new Ext.Toolbar.Spacer();

    var bbar=[
      this.tbItems['SPACER'],
      this.tbItems['LOAD'],
      {xtype:'tbseparator'},
      this.tbItems['PAGE_PREV'],
      this.tbItems['PAGE_FIELD'],
      this.tbItems['PAGE_COUNT'],
      this.tbItems['PAGE_NEXT'],
      {xtype:'tbseparator'},
//      this.tbItems['ONE_UP'],
//      this.tbItems['TWO_UP'],
//      this.tbItems['FOUR_UP'],
      this.tbItems['LAYOUT_MENU'],
//      {xtype:'tbseparator'},
//      this.tbItems['SINGLE'],
//      this.tbItems['CONTINUOUS'],
//      {xtype:'tbseparator'},
      this.tbItems['ZOOM_MENU'],
      {xtype:'tbseparator'},
      this.tbItems['SEARCH_FIELD']
    ];

    var pagesId = this.prefix()+"pages";
    var contentId = this.prefix()+"content";

    Ext.apply(this,
      {autoScroll : true,
       enableKeyEvents: true,
       keys: {},
       bbar: bbar,
       html:'<div id="'+contentId+'" class="content-pane" style="left:0pt;top:0pt"><center class="page-pane" id="'+pagesId+'"></center>'
      });

    Paperpile.PDFviewer.superclass.initComponent.apply(this,arguments);

    if (this.file != "") {
      this.initPDF(this.file);
    }
  },


  afterRender: function() {
    this.body.on('scroll',this.onScroll,this);
    this.body.on('mousedown', this.onMouseDown, this);
    this.body.on('mousemove', this.onMouseMove, this);
    this.body.on('mouseup', this.onMouseUp, this);
    this.body.on('mouseover',this.onMouseOver,this);
    this.body.on("mousewheel", this.onMouseWheel, this);

    this.delayedTask = new Ext.util.DelayedTask();
    this.loadKeyEvents();

    this.bbar.setStyle("z-index",50);
    this.bbar.setStyle("position","absolute");
    this.slide.slider.on("changecomplete",function() {
      this.slideZoom();
    },this);
    this.slide.slider.on("change",function() {
      this.slidePreview();
    },this);

    Paperpile.PDFviewer.superclass.afterRender.apply(this, arguments);
  },

  onResize: function(){
    Paperpile.PDFviewer.superclass.onResize.apply(this, arguments);

    var s = Ext.fly(this.tbItems['SPACER'].getEl());
    s.setStyle("width","0px");
    var barWidth = this.getBottomToolbar().getBox().width;
    var totalWidth = this.getInnerWidth();
    var spacerWidth = (totalWidth-barWidth)/2;
    s.setStyle("width",spacerWidth+"px");

    this.updateZoom();
    this.resizePages();
  },

  updateZoom: function() {
    // A zoom level of "1" will always correspond to fitting the page-block width!.

    if (this.pageSizes.length == 0)
      return;

    if (this.specialZoom == "page") {
      var pageWidth = this.pageSizes[this.currentPage].width;
      var pageHeight = this.pageSizes[this.currentPage].height;

      if (this.columnCount > 1) {
	var cols = this.columnCount;
	var pad = this.betweenPagePaddingFraction;
	pageWidth = pageWidth * cols + (pageWidth*pad*(cols+1));
      } else {
	var cols = this.columnCount;
	var pad = this.betweenPagePaddingFraction;
	pageWidth = pageWidth * cols + (pageWidth*pad*(cols)+1);
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
    //log(this.currentZoom);
  },

  initPDF: function(file){
    this.file=file,

    Ext.Ajax.request({
      url: '/ajax/pdf/extpdf',
      params: {
        command: 'INFO',
        inFile: this.file
      },
      success: function(response){
        var doc = response.responseXML;

        this.pageSizes=[];
	this.images={};
	this.searchResults=[];
	this.words=[];
	this.lines=[];

        this.pageN = Ext.DomQuery.selectNumber("pageNo", doc);
        var p=Ext.DomQuery.select("page", doc);
        for (var i=0;i<this.pageN;i++){
          var width=Ext.DomQuery.selectNumber("width", p[i]);
          var height=Ext.DomQuery.selectNumber("height", p[i]);
          this.pageSizes.push({width:width, height:height});
          this.words[i]=[];
          this.lines[i]=[];
	}

	this.setCurrentPage(this.currentPage);
	this.updateButtons();
	this.updateZoom();

	for (var i=0; i < this.pageN; i++) {
	  this.addBackgroundTask("initPDF thumbnails",this.loadThumbnail,[i],this,10,0,true);
	}

	this.layoutPages();
	if (this.search != "") {
	    this.onSearch();
	}
      },
      scope:this
      });

  },

  prefix: function() {
    return this.getItemId()+"_";
  },

  layoutPages: function() {
    if (!this.continuous) {
      this.layoutSingle();
    } else {
      this.layoutContinuous();
    }
  },

  pageTemplate: function(pageIndex,useBlinders) {
    var prefix = this.prefix();
    var w = this.getPageWidth(pageIndex);
    var margin = Math.floor(w * this.betweenPagePaddingFraction/2);

    var src = this.getThumbnailUrl(pageIndex);

    var blinder= {};
    if (useBlinders) {
      blinder = {
      id:prefix+"blinder."+pageIndex,
      style:[
	"position:absolute;z-index:3;",
	"width:"+this.getAdjustedWidth(pageIndex),
	"height:"+this.getAdjustedHeight(pageIndex),
	"top:0px",
	"left:0px"
      ].join(";"),
      cls:"pdf-page-blinder",
      tag:"div"
      };
    }

    var page = {
      id:prefix+"page."+pageIndex,
      tag:"div",
      cls:'pdf-page',
      style:{
	margin:margin+"px "+margin+"px"
      },
      children:[
	{id:"",tag:"div",
	style:{
	  position:'relative',
	  'z-index':0
	},
	children:[
	  {id:prefix+"sticky."+pageIndex,
	  tag:"div"},
	  {id:prefix+"highlight."+pageIndex,
	  tag:"div"},
	  {id:prefix+"search."+pageIndex,
	  style:"position:absolute;z-index:-1",
	  tag:"div"},
	  {id:prefix+"img."+pageIndex,
	  tag:"img",
	  src:src,
	  width:this.getAdjustedWidth(pageIndex),
	  height:this.getAdjustedHeight(pageIndex),
	  style:"position:aboslute;z-index:1;top:0px;left:0px;",
	  cls:"pdf-page-img"
	  },
	  blinder
	  ]
	  }
        ]
    };

    return page;
  },

  layoutSingle: function() {
    var numPages = this.pageN;
    var columns = this.columnCount;
    var continuous = this.continuous;
    var maxPages = this.maxPages;

    var pagesId = this.prefix()+"pages";
    var pageBlocks = Ext.select("#"+pagesId+" > *");
    pageBlocks.remove();

    var children = [];
    for (var i=0; i < columns; i++) {
      var pageIndex = this.currentPage + i;
      if (pageIndex > numPages-1) {
	break;
      }
      children.push(this.pageTemplate(pageIndex,true));
    }

    var pdfContainer = Ext.get(this.prefix()+"pages");
    var block = Ext.DomHelper.append(pdfContainer,
      {
      id:this.prefix()+"pageblock."+i,
      tag:"div",
      cls:"pdfblock",
      children:children
      },
      true
    );
    this.positionBlock(block);

    // Remove old annotation retrieval.
    this.removeBackgroundTasksByName("Layout Annotations");
    this.removeBackgroundTasksByName("Visible Pages");

    for (var i=0; i < columns; i++) {
      var pageIndex = this.currentPage + i;
      if (pageIndex > numPages-1) {
	break;
      }

      var newImg = Ext.get(this.prefix()+"img."+pageIndex);
      if (!this.isThumbnailLoaded(pageIndex)) {
//	newImg.on("load",this.imageLoaded,this);
      } else {
	var blinder = Ext.fly(this.prefix()+"blinder."+pageIndex);
	if (blinder != null)
	  blinder.remove();
      }

      // Trigger the full page image to load.
      //newImg.set({src:this.getFullUrl(pageIndex)});
      this.loadFullPage(pageIndex);

      this.addBackgroundTask("Layout Annotations",this.loadSearchAndAnnotations,[pageIndex],this,20,0,false);
    }
  },

  positionBlock:function(block) {
    block.setStyle("width",this.getBlockWidth());
    block.setStyle("position","relative");
    if (this.getPageHeight() < this.getRealHeight() && !this.continuous) {
      var heightDiff = this.getRealHeight() - this.getPageHeight(0);
      block.setStyle("top",heightDiff/2);
    } else {
      block.setStyle("top","0px");
    }
  },

  getBlockWidth: function() {
    var pgW = Math.ceil(this.getPageWidth());
    var pad = Math.ceil(pgW * this.betweenPagePaddingFraction+1);
    var blockW = (pgW*this.columnCount + pad*(this.columnCount+1) + this.imageBorderW*4*this.columnCount);
    if (blockW < 200 || this.currentZoom <= 1 || this.columnCount == 1) {
      return "";
    } else {
      return blockW+"px";
    }
  },

  layoutContinuous: function() {
    var numPages = this.pageN;
    var columns = this.columnCount;
    var startPage = this.startPage;
    var maxPages = this.maxPages;

    numPages = Math.min(maxPages,numPages);
    var numBlocks = Math.ceil(numPages / columns);

    var pagesId = this.prefix()+"pages";
    var pageBlocks = Ext.select("#"+pagesId+" > *");
    pageBlocks.remove();

    this.suspendEvents();
    for (var i=0; i < numBlocks; i++) {
      var children = [];
      for (var j=0; j < columns; j++) {
	var pageIndex = i*columns + j + this.startPage;
	if (pageIndex > this.pageN-1)
	  break;
	if (!this.isThumbnailLoaded(pageIndex)) {
	  children.push(this.pageTemplate(pageIndex,true));
	} else {
	  children.push(this.pageTemplate(pageIndex,true));
	}
      }

      var pdfContainer = Ext.get(this.prefix()+"pages");
      var block = Ext.DomHelper.append(pdfContainer,
	{id:this.prefix()+"pageblock."+i,
	tag:"div",
	cls:"pdfblock",
	children:children},
	true);
      this.positionBlock(block);

      for (var j=0; j < columns; j++) {
	var pageIndex = i*columns+j + this.startPage;
	if (pageIndex > this.pageN-1)
	  break;

	var newImg = Ext.get(this.prefix()+"img."+pageIndex);
	if (!this.isThumbnailLoaded(pageIndex)) {
	  newImg.on("load",this.imageLoaded,[newImg,pageIndex],this);
	} else {
	  var blinder = Ext.fly(this.prefix()+"blinder."+pageIndex);
	  if (blinder != null){
	    blinder.remove();
	  }
	  newImg.set({src:this.getThumbnailUrl(pageIndex)});
	}

	this.addBackgroundTask("Layout Annotations",this.loadSearchAndAnnotations,[pageIndex],this,10,0,false);
      }
    }

    this.loadVisiblePages();
    this.resumeEvents();
  },

  imageLoaded: function(img,pageIndex) {
    log(pageIndex + "loaded");
    if (pageIndex >= 0) {
      var blinder = Ext.fly(this.prefix()+"blinder."+pageIndex);
      if (blinder != null)
	blinder.setVisible(false);
    }
  },

  resizePages: function(previewMode) {
    if (previewMode === undefined)
      previewMode=false;

    // Resize each page image.
    for (var i=this.startPage;i<this.startPage+this.maxPages;i++) {
      var pgImg = Ext.fly(this.prefix()+"img."+i);
      if (pgImg != null) {
	//log("Resizing page "+i);
	var adjW = this.getAdjustedWidth(i);
	var h = this.getAdjustedHeight(i);
	//log("w:"+adjW+" h:"+h);
	pgImg.set({width:adjW,height:h});
	var pgBlinder = Ext.fly(this.prefix()+"blinder."+i);
	if (pgBlinder != null) {
	  pgBlinder.setStyle({width:adjW,height:h,top:0,left:0});
	}
      }
    }

    // Re-adjust the between-page padding amounts.
    var pages = Ext.select("#"+this.getItemId()+" .pdf-page");
    var w = this.getPageWidth(0);
    var margin = Math.floor(w * this.betweenPagePaddingFraction/2);
    pages.setStyle("margin",margin+"px "+margin+"px");

    // Set the width on the block containers (most important when we're zoomed in with two-up layout)
    var blocks = Ext.select("#"+this.getItemId()+" .pdfblock");
    //blocks.setStyle("width",this.getBlockWidth());
    this.positionBlock(blocks);

    // Remove all annotations and whatnot.
    var searches = Ext.select("#"+this.getItemId()+" .pdf-search-result");
    searches.remove();

    if (this.rsDelay == null) {
      this.rsDelay = new Ext.util.DelayedTask();
    }
    this.removeBackgroundTasksByName("Visible Pages");
    this.removeBackgroundTasksByName("Resize Annotations");
    if (!previewMode) {
      this.rsDelay.delay(100,this.resizeTask,this);
    }
  },

  rsDelay:null,
  resizeTask: function() {
    log("RESIZING!");
    // Reset the positions of all search results, stickies, annotations, etc.
    // Note: we put these actions on the bg queue, so the resizing happens first.
    // Load the full image of all visible pages.
    this.loadVisiblePages();
    for (var i=this.startPage;i<this.startPage+this.maxPages;i++) {
      var pageIndex = i;
      var img = this.getImage(pageIndex);
      if (img == null)
	continue;
      this.addBackgroundTask("Resize Annotations",this.loadSearchAndAnnotations,[pageIndex],this,20,0,false);
    }
  },

  bgTasks:[],
  bgDelay:null,
  loadSearchAndAnnotations: function(pageIndex) {
    //log("  -> Loading search and Annotations for page "+pageIndex+"...");
    this.loadSearchResultsIntoPage(pageIndex);
    //log("  -> Done!");
  },

  addBackgroundTask: function(name,fn,paramArray,scope,delayToNext,workerDelay,addToFront) {
    if (workerDelay === undefined) {
      workerDelay = 50;
    }
    if (delayToNext === undefined) {
      delayToNext = 0;
    }
    if (addToFront === undefined) {
      addToFront = false;
    }

    var bgTask = {
		   name:name,
		   fn:fn,
		   params:paramArray,
		   scope:scope,
		   delayToNext:delayToNext
		 };
    //log("Adding bg task: "+bgTask);
    if (addToFront) {
      this.bgTasks.unshift(bgTask);
    } else {
      this.bgTasks.push(bgTask);
    }

    if (this.bgDelay == null) {
      this.bgDelay = new Ext.util.DelayedTask();
    }
    this.bgDelay.delay(workerDelay,this.backgroundWorker,this);
  },

  removeBackgroundTasksByName: function(name) {
    for (var i=0; i < this.bgTasks.length; i++) {
      var bgTask = this.bgTasks[i];
      if (bgTask.name == name) {
	//log("Removing bg task "+i+": "+name);
	this.bgTasks.splice(i,1);
	i--;
      }
    }
  },

  backgroundWorker: function() {
    if (this.bgTasks.length > 0) {
      var bgTask = this.bgTasks.shift();
      //log("Running background task '"+bgTask.name+"'  ["+bgTask.params+"]");
      try {
	bgTask.fn.defer(0,bgTask.scope,bgTask.params);
      } catch (err) {
	log("ERROR Running bgWorker:");
	log(err);
      }
    }

    if (this.bgTasks.length > 0) {
      this.bgDelay.delay(bgTask.delayToNext,this.backgroundWorker,this);
    } else {
      //log("  -> No work left to do! Stopping bgWorker...");
    }
  },

  getImage: function(i){
    return Ext.get(this.prefix()+"img."+i);
  },

  getPage: function(i){
    return Ext.get(this.prefix()+"page."+i);
  },

  getRealHeight: function() {
    var realHeight = this.getInnerHeight() - 2;
    //log("Real height: "+realHeight);
    return realHeight;
  },

  getRealWidth: function() {
    var realWidth = this.getInnerWidth() -2;
    //log("Real width: "+realWidth);
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
    return aspectRatio*width;
  },

  getPageWidth: function() {
    var totalWidth = this.getRealWidth();
    var columns = this.columnCount;

    totalWidth -= totalWidth*this.betweenPagePaddingFraction*2;
    totalWidth *= this.currentZoom;
    var intWidthPerPage = Math.floor(totalWidth/columns);
    var pagePadding = Math.floor(intWidthPerPage*this.betweenPagePaddingFraction);
    intWidthPerPage -= pagePadding;
    return intWidthPerPage;

    // Tried a more mathematical approach, but rounding errors in CSS are a bitch. Fail.
    // n*x + x*(n+1)/pad = total
    // x = total / (n + [n+1]/pad)
    //var pgW = (totalWidth*this.currentZoom - (2*this.imageBorderW*columns)) / (columns + this.betweenPagePaddingFraction*(columns+1));
    //log("pgW: "+pgW);
    //return pgW-2;
  },

  getAdjustedHeight: function(i,scale) {
    if (!scale) {
      scale = this.getScale(i);
    }
    var width = this.getAdjustedWidth(i);
    var ratio = this.pageSizes[i].height / this.pageSizes[i].width;
    var newHeight = width * ratio;
    return Math.floor(newHeight);
  },

  getAdjustedWidth: function(pageIndex,scale) {
    if (!scale) {
      scale = this.getScale(pageIndex);
    }
    var newWidth = Math.floor(this.pageSizes[pageIndex].width * scale);
    return newWidth;
  },

  getScale: function(pageIndex) {
    var width = this.getPageWidth();
    var scale = (width)/this.pageSizes[pageIndex].width;
    scale = Math.round(scale*100)/100;
    return scale;
  },

  getThumbnailUrl: function(pageIndex) {
    var scale=this.thumbnailSize/this.pageSizes[pageIndex].width;
    scale = Math.round(scale*100)/100;
    return "ajax/pdf/render"+this.file+"/"+pageIndex+"/"+scale;
  },

  getFullUrl: function(pageIndex) {
    var scale = this.getScale(pageIndex);
    var url = "ajax/pdf/render"+this.file+"/"+pageIndex+"/"+scale;
    return url;
  },

  isThumbnailLoaded: function(pageIndex) {
    var needsLoading = this.loadThumbnail(pageIndex);
    return !needsLoading;
  },

  thumbnailSize:150,
  loadThumbnail: function(i,imgEl){
    var scale=this.thumbnailSize/this.pageSizes[i].width;
    scale = Math.round(scale*100)/100;
    var neededLoading = this.loadImage(i,scale,imgEl);
    return neededLoading;
  },

  loadImage: function(pageIndex,scale,target,removeBlinder) {
    var url = "ajax/pdf/render"+this.file+"/"+pageIndex+"/"+scale;
    if (this.images[url] != null && this.images[url].complete) {
      //log("  -> No need to reload:"+url);

      if (target) {
	if (target.dom.src.indexOf(url) == -1) {
	  log("  -> Replacing image with pre-loaded at new size: "+url);
	  target.set({src:url});
	}
      }
      return false;
    } else {
      //log("Loading image: "+url);

	var w = this.getAdjustedWidth(pageIndex,scale);
	var h = this.getAdjustedHeight(pageIndex,scale);
	var imgO = new Image(w,h);
	imgO.src = url;
	var images = this.images;
	imgO.onload = this.imageLoaded.createDelegate(this,[imgO,pageIndex]);
//	if (target !== undefined) {
//	  imgO.onload = function() {
//	    if (target) {
//	      target.set({src:url});
//	    }
//	  };
//	}

      this.images[url] = imgO;
      return true;
    }
  },

  loadFullPage: function(pageIndex) {
    var img = this.getImage(pageIndex);
    var scale = this.getScale(pageIndex);
    if (scale > 10 || scale < 0.1) {return false;}

    var pageNeedsLoading = this.loadImage(pageIndex,scale);
    var url = this.getFullUrl(pageIndex);
    img.set({src:url});

    return pageNeedsLoading;
  },

  onSearch: function(f,e) {
    this.delayedTask.delay(200,this.searchDelay,this);
  },

  searchDelay: function(f,e) {
    var sf = this.tbItems['SEARCH_FIELD'];
    var searchText = sf.getValue();

    if (searchText == "") {
      var allResults = Ext.select(".pdf-search-result");
      allResults.remove();
    }
    log("Searching for: "+searchText);

    Ext.Ajax.request({
      url: '/ajax/pdf/extpdf',
      params: {
        command: 'SEARCH',
        inFile: this.file,
	term: searchText
      },
      success: function(response){
      var doc = response.responseXML;
      //log("Response: "+response.responseText);

	this.searchResults=[];

	var hits=Ext.DomQuery.select("hit", doc);
	var hitDivs=[];
        for (var i=0;i<hits.length;i++){
          var value= Ext.DomQuery.selectValue("", hits[i]);
          var values=value.split(' ');
	  var pg = values[0];
          var x1=values[1];
          var y1=values[2];
          var x2=values[3];
          var y2=values[4];

	  if (this.searchResults[pg] == null) {
	    this.searchResults[pg] = [];
	  }

	  this.searchResults[pg].push({
					x1:x1,
					y1:y1,
					x2:x2,
					y2:y2
				      });
	}

	for (var i=this.startPage; i < this.startPage+this.maxPages; i++) {
	  this.loadSearchResultsIntoPage(i);
	}
      },
      scope: this
      });
  },

  loadSearchResultsIntoPage: function(pageIndex) {
    var results = this.searchResults[pageIndex];
    var pg = pageIndex;

    if (results==null){
      return;
    }

    var hitDivs=[];
    for (var i=0; i < results.length; i++) {
      bx = results[i];
      var left = this.page2px(bx.x1,pg);
      var top=this.page2px(bx.y1,pg);
      var width=this.page2px(bx.x2-bx.x1,pg);
      var height=this.page2px(bx.y2-bx.y1,pg);
      var style = {
	position:'absolute',
	left:left,
	top:this.getPageHeight(pg)-top-height-1,
	height:height,
	width:width
      };

      hitDivs.push({
	id:"searchResult."+i,
	tag:"div",
	cls:'pdf-search-result',
	style:style
      });
    }

    var searchHolder = Ext.get(this.prefix()+"search."+pageIndex);
    if (searchHolder != null) {
      var block = Ext.DomHelper.overwrite(searchHolder,
	hitDivs,
	true);
    }
},

  page2px: function(pageCoord,pageIndex) {
    var pageW = this.getPageWidth(pageIndex);
    var origW = this.pageSizes[pageIndex].width;
//    log(pageW/origW);
    return Math.round(pageCoord * pageW/origW);
//    var scale=this.canvasWidth/this.pageSizes[pageIndex].width*this.currentZoom;
//    scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);
//    return Math.round(pageCoord*scale);
  },

  px2page: function(px,pageIndex) {
    var scale=this.canvasWidth/this.pageSizes[pageIndex].width*this.currentZoom;
    scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);
    return px/scale;
  },

  holdScroll:false,
  onScroll: function(el) {
    if (!this.holdScroll) {
      this.delayedTask.delay(100,this.scrollDelay,this);;
    }
  },

  loadVisiblePages: function() {
    var visiblePages=[];
    for (var i=0; i < this.pageN; i++) {
      var pageIndex = i;
      var img = this.getImage(pageIndex);
      if (img == null)
	continue;
      var amountInView = this.isElInView(img);
      if (amountInView > 0.05) {
	  visiblePages.push(pageIndex);
      }
    }

    if (visiblePages.length > 8) {
      log("Too many visible pages! Not loading full...");
      return;
    }

    for (var i=0; i < visiblePages.length; i++) {
      var pageIndex = visiblePages[i];
      this.addBackgroundTask("Visible Pages",this.loadFullPage,[pageIndex],this,20,0,true);
    }
  },

  timeoutNum:0,
  scrollDelay: function(el) {
    log("Scroll delay!");
    var mostVisiblePage;
    var mostVisibleAmount=0;
    var curPageVisibleAmount=0;
    var visiblePages=[];
    for (var i=0; i < this.maxPages; i++) {
      var pageIndex = this.startPage + i;

      var pg = this.getPage(pageIndex);
      var img = this.getImage(pageIndex);
      if (img == null)
	continue;
      var amountInView = this.isElInView(img);
      if (pageIndex == this.currentPage)
	curPageVisibleAmount = amountInView;
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

    for (var i=0; i < visiblePages.length; i++) {
      var pageIndex = visiblePages[i];
      this.loadFullPage(pageIndex);
    }

    this.updateButtons();
  },

  isElInView: function(el) {
    var bot = el.getBottom()-1;
    var top = el.getTop()+1;
    if (bot > this.body.getTop() && top < this.body.getBottom()) {
      var amountInView = this.rangeOverlap(top,bot,this.body.getTop(),this.body.getBottom());
//      log(el.id+"  "+amountInView);
      return amountInView / el.getHeight();
    }
    return 0;
  },

  rangeOverlap: function(a1,a2,b1,b2) {
    var overlap = 0;
    if (a2 < b2 && a1 > b1) {
      return a2-a1;
    }
    if (a2 > b2 && a1 < b1) {
      return b2-b1;
    }
    if (a2 < b2)
      overlap += Math.max(0,a2 - b1);
    if (a1 > b1)
      overlap += Math.max(0,b2 - a1);
    return overlap;
  },

  pdf2px: function(pdfCoord){
    var scale=this.canvasWidth/this.pageSizes[this.currentPage].width*this.currentZoom;
    scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);
    return Math.round(pdfCoord*scale);
  },

  px2pdf: function(px){
    var scale=this.canvasWidth/this.pageSizes[this.currentPage].width*this.currentZoom;
    scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);
    return px/scale;
  },

  loadWords: function(pageIndex){

    Ext.Ajax.request({
      url: '/ajax/pdf/extpdf',
      params: {
        command: 'WORDLIST',
        page:pageIndex,
        inFile: this.file
      },
      success: function(response){
        var doc = response.responseXML;
//	log("Response: "+doc);
        var words=Ext.DomQuery.select("word", doc);

        for (var i=0;i<words.length;i++){
          var value= Ext.DomQuery.selectValue("", words[i]);
	  //log("Word "+i+" "+value);
          var values=value.split(',');
          var x1=values[0];
          var y1=values[1];
          var x2=values[2];
          var y2=values[3];
          this.words[pageIndex].push({x1:x1,y1:y1,x2:x2,y2:y2});
        }
        this.calculateLines(pageIndex);
      },

      scope: this
      });
  },

  calculateLines: function(pageIndex){
    if (this.words[pageIndex].length == 0)
      return;

    var lines=[];
    var currWord;
    var prevWord;

    var prevWord=this.words[pageIndex][0];
//    log(prevWord);
    var currLine=[prevWord];
    var cutoffX=5.0;
    var cutoffY=0.1;
    var distX;
    var distY;

    for (var i=1; i< this.words[pageIndex].length;i++){
      currWord=this.words[pageIndex][i];
      prevWord=currLine[currLine.length-1];

      distX=Math.abs(currWord.x1 - prevWord.x2);
      distY=Math.abs(currWord.y2 - prevWord.y2);

      if ((distY<=cutoffY) ||
        ((currWord.x1 - prevWord.x2 <= cutoffX) &&
         (currWord.y2>prevWord.y1 && currWord.y2<=prevWord.y2)
        )
         ){
           currLine.push(currWord);
         } else {
           lines.push({x1:currLine[0].x1,
           y1:currLine[0].y1,
           x2:currLine[currLine.length-1].x2,
           y2:currLine[0].y2
                      });
           currLine=[currWord];
         }
    }

    // push last line
    lines.push({x1:currLine[0].x1,
    y1:currLine[0].y1,
    x2:currLine[currLine.length-1].x2,
    y2:currLine[0].y2
               });

    this.lines[pageIndex]=lines;

  },

  select: function(x1,y1,x2,y2){

    this.clearSelection();

    var lines=this.lines[this.currentPage];
    var selected=[];

    x1=this.px2pdf(x1);
    x2=this.px2pdf(x2);
    y1=this.px2pdf(y1);
    y2=this.px2pdf(y2);

    var minX=x1;
    var maxX=x2;

    for (var i=0; i<lines.length; i++){
      var line=lines[i];
      if ((line.y1>y1 && line.y1<y2 || y1>line.y1 && y1<line.y2) &&
        !(line.x2<minX || line.x1>maxX)
         ){
           selected.push({x1:line.x1,y1:line.y1,x2:line.x2,y2:line.y2});
         }
    }

    if (selected.length==0){
      return;
      }

      if (this.selectionStartWord != -1){
        var startWord=this.words[this.currentPage][this.selectionStartWord];
        selected[0].x1=startWord.x1;
      }


      for (var i=0; i<selected.length; i++){
        var line=selected[i];

        var top=this.pdf2px(line.y1);
        var left=this.pdf2px(line.x1);
        var width=this.pdf2px(line.x2-line.x1);
        var height=this.pdf2px(line.y2-line.y1);

        var el=Ext.get(document.createElement('div'));
        el.addClass('pdf-selector');
        el.setPositioning({left:left,top:top, width:width, height:height});
        this.pdfContainer.appendChild(el);
        this.selection.push(el);
      }


  },


  getWord: function(x,y){

    var words=this.words[this.currentPage];
    var word=null;

    x=this.px2pdf(x);
    y=this.px2pdf(y);

    for (var i=0; i<words.length; i++){
      if (!(x<words[i].x1 || x>words[i].x2) &&
        !(y<words[i].y1 || y>words[i].y2)){
        word=words[i];
        return i;
      }
      }

      return -1;

  },

  selectWord: function(i){

    this.clearSelection();

    var word=this.words[this.currentPage][i];
    var top=this.pdf2px(word.y1);
    var left=this.pdf2px(word.x1);
    var width=this.pdf2px(word.x2-word.x1);
    var height=this.pdf2px(word.y2-word.y1);

    var el=Ext.get(document.createElement('div'));
    el.addClass('pdf-selector');
    el.setPositioning({left:left,top:top, width:width, height:height});
    this.pdfContainer.appendChild(el);
    this.selection.push(el);
  },

  clearSelection: function(i){

    for (var i=0; i< this.selection.length;i++){
      this.selection[i].remove();
      }
      this.selection=[];
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

  between: function(a,b,c) {
    if (a > b && a < c)
      return true;
    if (a > c && a < b)
      return true;
    return false;
  },

  slideDelay:null,
  slideZoom:function(preview) {
    if (preview === undefined)
      preview = false;
    var i = this.slide.slider.getValue();
    var z = this.slideZoomArray[i];
    this.currentZoom = z;
    if (this.currentZoom === "page" || this.currentZoom === "width")
      this.specialZoom=this.currentZoom;
    else
      this.specialZoom='';

    if (this.slideDelay == null) {
      this.slideDelay = new Ext.util.DelayedTask();
    }
    this.slideDelay.delay(50,function() {
			 this.updateZoom();
			 this.resizePages(preview);
			 var pgEl = this.getPage(this.currentPage);
			 this.holdScroll = true;
			 pgEl.scrollIntoView();
			 this.holdScroll = false;
		       },this);
  },

  slidePreview:function() {
    this.slideZoom(true);
  },

  slideZoomArray:[0.05,0.25,0.5,0.75,'page','width',1.5,2],
  bigZoomArray: [0.01,0.05,0.1,0.25,0.5,1,1.5,2,3,4,5,10],
  smallZoomArray: null,
  zoomInOut: function(dir,big,preview) {
    if (big === undefined) {
      big = true;
    }
    if (preview === undefined) {
      preview = false;
    }

    var curZoom = this.currentZoom;
    this.specialZoom = '';

    if (this.smallZoomArray == null) {
      this.smallZoomArray = [];
      for (var i=-2; i <= 0.8; i+= 0.1) {
	this.smallZoomArray.push(Math.pow(10,i));
      }
      //log(this.smallZoomArray);
    }

    var zoomArray = this.bigZoomArray;
    if (!big) {
      zoomArray = this.smallZoomArray;
    }

    var pgZ = this.getSpecialZoomLevel('page');

    var eqIndex = 0;
    var hiIndex = 0;
    for (var i=0; i < zoomArray.length; i++) {
      if (curZoom > zoomArray[i]) {
	hiIndex = i+1;
      }
      if (curZoom == zoomArray[i]) {
	hiIndex=i+1;
	if (dir == -1)
	  hiIndex = i;
	break;
      }
    }

    var destZoom = curZoom;
    if (dir == 1) {
      if (hiIndex >= zoomArray.length)
	hiIndex = zoomArray.length-1;
      destZoom = zoomArray[hiIndex];
    } else {
      if (hiIndex == 0)
	hiIndex = 1;
      destZoom = zoomArray[hiIndex-1];
    }

    if (destZoom < zoomArray[0])
      destZoom = zoomArray[0];
    if (destZoom > zoomArray[zoomArray.length-1])
      destZoom = zoomArray[zoomArray.length-1];

    if (this.between(pgZ,curZoom,destZoom)) {
      destZoom = pgZ;
    }

    //log("oldZ:"+curZoom+" newZ:"+destZoom);

    this.currentZoom = destZoom;
    this.updateZoom();
    this.resizePages(preview);
    var pgEl = this.getPage(this.currentPage);
    this.holdScroll = true;
    pgEl.scrollIntoView(this.body,true);
    this.holdScroll = false;
  },

  zoomIn:function() {
    this.zoomInOut(1,true,false);
  },
  zoomOut:function() {
    this.zoomInOut(-1,true,false);
  },

  updateButtons: function() {
    for (var tbItem in this.tbItems) {
      var item = this.tbItems[tbItem];
      if (item instanceof Ext.Button)
	item.setDisabled(false);
      if (item instanceof Ext.Button)
	item.toggle(false);
    }


    if (this.columnCount == 1)
      this.tbItems['ONE_UP_B'].button.toggle(true);
    if (this.columnCount == 2)
      this.tbItems['TWO_UP_B'].button.toggle(true);
    if (this.columnCount == 4)
      this.tbItems['FOUR_UP_B'].button.toggle(true);

    if (this.continuous)
      this.tbItems['CONTINUOUS_B'].button.toggle(true);
    else
      this.tbItems['SINGLE_B'].button.toggle(true);

    var pagesToStart = this.currentPage;
    var pagesToEnd = this.pageN - this.currentPage;
    this.tbItems['PAGE_NEXT'].setDisabled(pagesToEnd==0);
    this.tbItems['PAGE_PREV'].setDisabled(pagesToStart==0);
  },

  // Small helper functions to get the index of a given item in the toolbar configuration array
  // We have to use the text instead of itemId. Actions do not seem to support itemIds.
  // A better solution should be possible with ExtJS 3
  getButtonIndex: function(itemId) {
    var tbar=this.getTopToolbar();
    for (var i=0; i<tbar.length;i++) {
      if (tbar[i].getText) {
        if (tbar[i].getText() == itemId) return i;
      }
    }
    return 0;
  },

  isMouseDown:false,
  mouseDownEl:null,
  mouseDownZoom:0,
  mouseDownWindowX:0.0,
  mouseDownWindowY:0.0,
  mouseDownViewportTop:0,
  mouseDownViewportLeft:0,
  mouseDownDistToAnchorY:0,
  mouseDownAnchor:null,

  onMouseOver: function(e) {
    //log(e.getTarget().tagName.toLowerCase());
  },

  onMouseDown: function(e) {
    this.isMouseDown = true;
    this.mouseX = e.getPageX();
    this.mouseY = e.getPageY();
    var x = this.mouseX;
    var y = this.mouseY;

    if (this.mode == 'anchorzoom') {
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
      newDiv.set({id:"anchor"});
      //newDiv.setStyle("width",el.getWidth()+"px");
      //newDiv.setStyle("border","1px solid red");

      this.mouseDownAnchor = newDiv;
      this.mouseDownDistToAnchorY = y - this.mouseDownAnchor.getTop();
      this.mouseDownViewportTop = y - (this.body.getTop());

      this.mouseDownViewportLeft = x;
      this.mouseDownPageLeftPct = (x - el.getX()) / el.getWidth();
      }

      if (this.mode == 'drag'){
        e.stopEvent();
        Ext.getBody().on('mousemove', this.onMouseMove, this);
        Ext.getDoc().on('mouseup', this.onMouseUp, this);
      }

      if (this.mode == 'select'){
        e.stopEvent();

        var x = e.getPageX();
        var y = e.getPageY();

        x=x-this.bitmap.getLeft();
        y=y-this.bitmap.getTop();

        this.mouseX = x;
        this.mouseY = y;

        if (this.selectionStartWord!=-1){
          this.clearSelection();
          }

          this.selectionStartWord=this.getWord(x,y);
          this.selectionPrevWord=this.selectionStartWord;

          Ext.getBody().on('mousemove', this.onMouseMove, this);
          Ext.getDoc().on('mouseup', this.onMouseUp, this);
      }

  },


  anchoredZoom: function(mouseDownWindowY,mouseDownZoom,mouseDownAnchorDist,mouseDownViewportTop) {

  },

  onMouseMove: function(e) {

    var x = e.getPageX();
    var y = e.getPageY();
    this.mouseX = x;
    this.mouseY = y;

    if (this.mode == 'anchorzoom') {
      //e.stopEvent();
      if (this.isMouseDown) {
        e.stopEvent();
	var tag = this.mouseDownEl.dom.tagName.toLowerCase();
	if (tag == "img") {
	  var dY = y - this.mouseDownWindowY;
	  var dZoom = dY / 100;
	  var zoomF = Math.pow(10,-dZoom);
	  this.currentZoom = this.mouseDownZoom * zoomF;

	  this.onResize(false);

	  //var blockIndex = this.columnCount
	  var newLeft = 2*this.mouseDownEl.getWidth() + this.mouseDownPageLeftPct*this.mouseDownEl.getWidth();
	  newLeft -= this.mouseDownViewportLeft;
	  //if (newLeft > 0)
	    //this.body.scrollTo('left',newLeft);

	  var newTop = Ext.Element.fly(this.mouseDownAnchor).getOffsetsTo(this.body)[1] + this.body.dom.scrollTop;
	  var dY = this.mouseDownDistToAnchorY * zoomF;
	  newTop -= this.mouseDownViewportTop;
	  newTop += dY;
	  if (this.body.dom.scrollTop == 0) {
	    this.body.scrollTo('top',newTop);
	  } else {
	    this.body.scroll('top',this.body.dom.scrollTop-newTop);
	  }
	}
      }
    }


    if (this.mode == 'drag'){
      e.stopEvent();
      if (e.within(this.body)) {
	var xDelta = x - this.mouseX;
	var yDelta = y - this.mouseY;
	this.body.dom.scrollLeft -= xDelta;
	this.body.dom.scrollTop -= yDelta;
      }
    }

    if (this.mode == 'select'){
      e.stopEvent();

      x=x-this.bitmap.getLeft();
      y=y-this.bitmap.getTop();

      Ext.getCmp('statusbar').clearStatus();
      var box=this.bitmap.getBox();
      Ext.getCmp('statusbar').setText('('+x+','+y+')'+'    ('+box.x+','+box.y+')');

      var currentWord=this.getWord(x,y);

      if (currentWord != this.selectionPrevWord) {
	this.select(this.mouseX,this.mouseY,x,y);
	this.selectionPrevWord=currentWord;
      }
    }
  },

  onMouseUp: function(e) {
    var x = e.getPageX();
    var y = e.getPageY();
    this.isMouseDown = false;

    if (this.mode == 'anchorzoom') {
      e.stopEvent();

    }

    if (this.mode == 'drag') {
      Ext.getBody().un('mousemove', this.onMouseMove, this);
      Ext.getDoc().un('mouseup', this.onMouseUp, this);
    }

    if (this.mode == 'select') {

      x=x-this.bitmap.getLeft();
      y=y-this.bitmap.getTop();

      var currentWord=this.getWord(x,y);

      if (currentWord==this.selectionStartWord && currentWord !=-1) {
	this.selectWord(currentWord);
      }

      Ext.getBody().un('mousemove', this.onMouseMove, this);
      Ext.getDoc().un('mouseup', this.onMouseUp, this);
    }

  },

  animateZoomTo: function() {
    this.zoomCfg = {duration:2,easing:"easeOutStrong"};
    this.zoomAnim = Ext.lib.Anim.motion(this.el,
      {zoomLevel:{from:1,to:2}}
	);
    this.zoomAnim.onTween.addListener(
      function(){
	this.currentZoom = this.el.getStyle("zoomLevel");
	//log(this.el.getStyle("zoomLevel"));
	this.onResize(false);
      }, this);
    this.zoomAnim.animate();
  },


  zoomToPage: function() {

  },

  zoomToWidth: function() {

  },

  loadKeyEvents: function() {
    this.keyMap = new Ext.KeyMap(document,[
      {
	key: [Ext.EventObject.LEFT,Ext.EventObject.RIGHT,Ext.EventObject.UP,Ext.EventObject.DOWN,
	      Ext.EventObject.PAGE_UP,Ext.EventObject.PAGE_DOWN],
	fn: this.keyNav,
	scope:this
      },
      {
	key: [191],
	fn:this.keySearch,
	scope:this
      },
      {
	key: [107,109],
	fn:this.keyZoom,
	ctrl:true,
	scope:this
      }
    ]);
  },

  keyNav: function(k,e) {
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
	  var pad = this.getPageWidth()*this.betweenPagePaddingFraction;
	  this.body.scroll("up",this.getPageHeight()+pad+4);
	}
      break;
      case Ext.EventObject.PAGE_DOWN:
	e.preventDefault();
	if (!this.continuous) {
	  this.pageScrollNext();
	} else {
	  var pad = this.getPageWidth()*this.betweenPagePaddingFraction;
	  this.body.scroll("down",this.getPageHeight()+pad+4);
      }
      break;

    }
  },

  keySearch: function(k,e) {
    e.preventDefault();
    log("Search!"+e);
  },

  keyZoom: function(k,e) {
    e.preventDefault();
    log("Zoom!"+e);
    switch (e.getKey()) {
    case 107: // +
      this.zoomIn();
      break;
    case 109: // -
      this.zoomOut();
    break;
    }
  },

  onMouseWheel: function(e) {
    if (e.ctrlKey) {

      // Set the current page by the mouse target.
      log(e.getTarget());
      var t = e.getTarget();
      var id = t.id;
      var index = id.lastIndexOf(".")+1;
      if (index > 0) {
	var pageIndex = id.substr(index);
	this.setCurrentPage(pageIndex);
      }

      var delta = e.getWheelDelta();
      if(delta > 0) {
	this.zoomInOut(1,false,true);
	//this.rsDelay.delay(300,this.resizeTask,this);
	e.stopEvent();
      } else if (delta < 0) {
	this.zoomInOut(-1,false,true);
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

  scrollTarget:0,
  pageScroll: function(dir) {
    // Do some checks on the original scroll target to see if we don't want to scroll at all.
    if (dir < 0 && this.scrollTarget == 0) {
      this.scrollToPage(this.scrollTarget);
      return;
    }
    if (dir > 0 && this.scrollTarget + this.columnCount - 1 >= this.pageN-1) {
      this.scrollToPage(this.scrollTarget);
      return;
    }


    this.scrollTarget += dir;
    if (this.scrollTarget < 0)
      this.scrollTarget = 0;
    if (this.scrollTarget > this.pageN-1)
      this.scrollTarget = this.pageN-1;

    var scrollTarget = this.scrollTarget;
    this.currentPage = this.scrollTarget;

    if (!this.continuous) {
      this.viewStartPage = scrollTarget;
      this.layoutPages();
      this.scrollToPage(this.scrollTarget);
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
      if (this.startPage < 0)
	this.startPage = 0;
      this.viewStartPage = this.startPage;
      this.layoutPages();
      this.scrollToPage(this.scrollTarget);
    }

    this.scrollToPage(this.scrollTarget);
  },

  setCurrentPage: function(page) {
    this.currentPage = page;
    this.scrollTarget = page;

    var pf = this.tbItems['PAGE_FIELD'];
    pf.setValue((this.currentPage+1));

    var pageImages = Ext.select("#"+this.getItemId()+" .pdf-page-img");
    pageImages.removeClass("pdf-cur-page");

    var img = this.getImage(this.currentPage);
    if (img != null) {
      //log("Setting cur pgae!");
      img.addClass("pdf-cur-page");
    }

    var pt = this.tbItems['PAGE_COUNT'];
    //log(pt);
    var totalPages = this.pageN;
    pt.setText("of "+totalPages);
  },

  scrollAnimation:null,
  scrollToPage: function(scrollTarget) {
    if (scrollTarget >= this.pageN)
      scrollTarget = this.pageN-1;
    if (scrollTarget < 0)
      scrollTarget = 0;

    //log(scrollTarget);
    var pgEl = this.getPage(scrollTarget);
//    log(scrollTarget);
    pgEl.scrollIntoView(this.body,true);
    this.setCurrentPage(scrollTarget);
    this.loadVisiblePages();
    this.updateButtons();
    //this.scrollDelay();
    //this.loadFullPage(scrollTarget);
  },

  openFile:function() {
    log("Open file!");
    var win=new Paperpile.FileChooser({
      showFilter: true,
      filterOptions:[{
		       text: 'PDF documents (.pdf)',
		       suffix: ['pdf']
		     },
		     {
		       text: 'All files',
		       suffix:['ALL']
		     }
                    ],
      callback:function(button,path){
        if (button == 'OK'){
          log(path);
          this.initPDF(path);
        }
      },
      scope:this
    });
    win.show();
  }

});

Ext.reg('pdfviewer', Paperpile.PDFviewer);

var A = Ext.lib.Anim;
Ext.override(Ext.Element, {
  scrollTo : function(left, top, animate){
    if(typeof left != 'number'){
      if(left.toLowerCase() == 'left'){
	left = top;
	top = this.dom.scrollTop;
      }else{
	left = this.dom.scrollLeft;
      }
    }
    if(!animate || !A){
      this.dom.scrollLeft = left;
      this.dom.scrollTop = top;
    }else{
      this.anim({scroll: {'to': [left, top]}}, this.preanim(arguments, 2), 'scroll');
    }
    return this;
  },

  scrollIntoView : function(container, hscroll, animate){

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
    if(h > ch || t < ct){
      ct = t;
    }else if(b > cb){
      ct = b - ch;
    }
    if(hscroll !== false){
      var cw = c.dom.clientWidth,
      cr = cl + cw;
      l = o[0] + cl,
      w = el.offsetWidth,
      r = l + w;
      if(w > cw || l < cl){
	cl = l;
      }else if(r > cr){
	cl = r - cw;
      }
    }
    return c.scrollTo(cl, ct, animate);
  },

  scrollChildIntoView : function(child, hscroll, animate){
    Ext.fly(child, '_scrollChildIntoView').scrollIntoView(this, hscroll, animate);
  }
});

Ext.menu.SliderItem = function(config){

  Ext.menu.SliderItem.superclass.constructor.call(this, new Ext.Slider(config), config);
  this.slider = this.component;
  this.addEvents();

  this.slider.on("render", function(slider){
    slider.getEl().swallowEvent("click");
    slider.container.addClass("x-menu-slider-item");
  });
};

Ext.extend(Ext.menu.SliderItem, Ext.menu.Adapter, {
});
Ext.reg('slideritem', Ext.menu.SliderItem);

Ext.menu.ButtonItem = function(config){

  Ext.menu.ButtonItem.superclass.constructor.call(this, new Ext.Button(config), config);
  this.button = this.component;
  this.addEvents();

  this.button.on("render", function(button){
    button.getEl().swallowEvent("click");
    button.container.addClass("x-menu-button-item");
  });
};

Ext.extend(Ext.menu.ButtonItem, Ext.menu.Adapter, {
});
Ext.reg('buttonitem', Ext.menu.ButtonItem);


Ext.HoverButton = function(config) {
  Ext.HoverButton.superclass.constructor.call(this, config);
};
Ext.extend(Ext.HoverButton, Ext.Button, {
  showSpeed:0.3,
  hideSpeed:0.3,
  hideDelay:250,
  inPosition:false,
  hideTimeout:0,
  initComponent: function() {
    Ext.HoverButton.superclass.initComponent.apply(this,arguments);

    this.on("menutriggerout",function(e) {
      if (this.inPosition) {
	//log("Hide triggerout!");
	this.hideTimeout = this.hideAnim.defer(this.hideDelay,this);
      }
    },this);
    this.menu.on("mouseover",function(e) {
      clearTimeout(this.hideTimeout);
    },this);
    this.menu.on("mouseout",function(e) {
      if (this.inPosition) {
	log("Hide mouseout!");
	this.hideTimeout = this.hideAnim.defer(this.hideDelay,this);
      }
    },this);
    this.on("mouseover",function(e) {
	      log("over");
    },this);

    this.menu.getEl().setStyle("z-index",9);
    this.menu.getEl().setStyle("position","absolute");
  },

  hideAnim:function() {
    this.menu.getEl().alignTo(this.el,"bl",[0,0],{
				duration:this.hideSpeed,
				scope:this,
				callback:function() {
				  this.menu.hide();
				  this.inPosition=false;
				}
    });
  },

  showAnim: function() {
    this.menu.show(this.el,"bl");
    this.menu.getEl().alignTo(this.el,"tl-bl?",[0,0],{
				duration:this.showSpeed,
				scope:this,
				callback:function() {
				  this.inPosition=true;
//				  this.menu.resumeEvents();
				}
			      }
			     );
//    this.menu.suspendEvents();
    this.inPosition = false;
  },

  onClick: function(e) {
//    log("Click!");
    this.showMenu();
    this.inPosition = true;
  },

  onMouseDown:function(e) {
//    log("Down!");
    this.showMenu();
    this.inPosition = true;
  },

  onMouseOver: function(e) {
    if (!this.menu.isVisible()) {
      this.showAnim();
    }
    e.stopEvent();
    Ext.HoverButton.superclass.onMouseOver.call(this,e,arguments);
  }
});