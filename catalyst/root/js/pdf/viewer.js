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
  continuous:false,                 // Whether or not we're laying out continuously or in single-block mode.
  startPage:0,
  maxPages:25,

  columnCount:4,                   // In both single and continuous layout, pages are grouped into page
                                   // blocks according to the columnCount value.

  // Reading state.
  currentPage:0,                   // The current "active" page being viewed
  currentZoom: 1.0,                // The current numerical zoom value.
  specialZoom:'page',              // either '' (no special zoom), 'page', or 'width'. If set, then the layout
                                   // will maintain the full-page zoom upon resizing.

  // Selection state.
  selection:[],
  selectionStartWord:-1,
  selectionPrevWord:-1,


  // Layout parameters.
  betweenPagePaddingFraction:1/50,
  imageBorderW:1,

  initComponent: function() {

    this.actions = {
      'PAGE_NEXT': new Ext.Action({
//				    text:'Next Page',
				    handler:this.pageNext,
				    scope:this,
				    cls:'x-btn-text-icon next',
				    disabled:true,
				    itemId:'next_button'
				  }),
      'PAGE_PREV': new Ext.Action({
//				    text:'Previous Page',
				    handler:this.pagePrev,
				    scope:this,
				    cls:'x-btn-text-icon prev',
				    disabled:true,
				    itemId:'pdf_prev_button'
				  }),
      'VIEW_SINGLE': new Ext.Action({
//				    text:'Single Page',
				    handler:this.viewSingle,
				    scope:this,
				    cls:'x-btn-text-icon viewSingle',
				    disabled:true,
				    itemId:'pdf_view_single'
					 }),
      'VIEW_CONTINUOUS': new Ext.Action({
//				    text:'Continuous',
				    handler:this.viewContinuous,
				    scope:this,
				    cls:'x-btn-text-icon viewContinuous',
				    disabled:true,
				    itemId:'pdf_view_continuous'
					 }),
      'LAYOUT_TWO': new Ext.Action({
//				    text:'Two-up',
				    handler:this.layoutTwoUp,
				    scope:this,
				    cls:'x-btn-text-icon layoutTwoUp',
				    disabled:true,
				    itemId:'pdf_layout_twoup'
					 }),
      'LAYOUT_FOUR': new Ext.Action({
//				    text:'Four-up',
				    handler:this.layoutFourUp,
				    scope:this,
				    cls:'x-btn-text-icon layoutFourUp',
				    disabled:true,
				    itemId:'pdf_layout_fourup'
					 }),

      'LAYOUT_ONE': new Ext.Action({
//				    text:'One-up',
				    handler:this.layoutOneUp,
				    scope:this,
				    cls:'x-btn-text-icon layoutOneUp',
				    disabled:true,
				    itemId:'pdf_layout_oneup'
					 }),

      'ZOOM_PAGE': new Ext.Action({
//				    text:'Fit to Page',
				    handler:this.zoomFitPage,
				    scope:this,
				    cls:'x-btn-text-icon zoomFitPage',
				    disabled:true,
				    itemId:'pdf_zoom_fit_page'
					 }),
      'ZOOM_WIDTH': new Ext.Action({
//	  			    text:'Fit Width',
				    handler:this.zoomFitWidth,
				    scope:this,
				    cls:'x-btn-text-icon zoomFitWidth',
				    disabled:true,
				    itemId:'pdf_zoom_fit_width'
					 }),
      'ZOOM_IN': new Ext.Action({
//				    text:'Zoom In',
				    handler:this.zoomIn,
				    scope:this,
				    cls:'x-btn-text-icon zoomIn',
				    disabled:true,
				    itemId:'pdf_zoom_in'
					 }),
      'ZOOM_OUT': new Ext.Action({
//				    text:'Zoom Out',
				    handler:this.zoomOut,
				    scope:this,
				    cls:'x-btn-text-icon zoomOut',
				    disabled:true,
				    itemId:'pdf_zoom_out'
					 }),

      'OPEN_FILE': new Ext.Action({
//				    text:'Open File',
				    handler:this.openFile,
				    scope:this,
				    cls:'x-btn-text-icon openFile',
				    disabled:true,
				    itemId:'pdf_open_file'
				  }),
      'SAVE_CHANGES': new Ext.Action({
//				    text:'Save Changes',
				    handler:this.saveChanges,
				    scope:this,
				    cls:'x-btn-text-icon saveChanges',
				    disabled:true,
				    itemId:'pdf_save_changes'
				     })
    };

 var sr = new Ext.Container({
					    layout:'fit',
					    items:[
					      {xtype:'button',
					      handler:this.prevResult,
					      scope:this,
					      text:'<'
					      },
					      {xtype:'button',
					      handler:this.nextResult,
					      scope:this,
					      text:'>'
					      }
					    ],
					    width:100,
					    height:100,
					    top:50,
					    left:50
			    });
    sr.show();

    this.tbItems = {
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
      'PAGE_COUNT': new Ext.Toolbar.TextItem({
					       id:'pageCount',
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
					       }
					       })
    };

   var loadBtn = new Ext.Button({
				  handler:this.openFile,
				  text:'Load',
				  tooltip:"Load File",
				  scope:this
				    });

    var oneBtn = new Ext.Button({
				  handler:this.layoutOneUp,
				  text:'1',
				  enableToggle:true,
				  toggleGroup:'onetwo',
				  tooltip:"One-Up Layout",
				  scope:this
				    });
    var twoBtn = new Ext.Button({
				  handler:this.layoutTwoUp,
				  text:'2',
				  enableToggle:true,
				  toggleGroup:'onetwo',
				  tooltip:"Two-Up Layout",
				  scope:this
				    });
    var fourBtn = new Ext.Button({
				  handler:this.layoutFourUp,
				  text:'4',
				  enableToggle:true,
				  toggleGroup:'onetwo',
				  tooltip:"Four-Up Layout",
				  scope:this
				    });

    var singleBtn = new Ext.Button({
				     handler:this.viewSingle,
				     text:'Single',
				     enableToggle:true,
				     toggleGroup:'flow',
				     tooltip:"Single Block",
				     scope:this
				   });
    var continBtn = new Ext.Button({
				     handler:this.viewContinuous,
				     text:'Continuous',
				     enableToggle:true,
				     toggleGroup:'flow',
				     tooltip:"Continuous",
				     scope:this
				   });

    var pgZoom = new Ext.Button({
				  handler:this.zoomPage,
				  text:'P',
				  tooltip:"Fit Page",
				  scope:this
				});
    var wZoom = new Ext.Button({
				 handler:this.zoomWidth,
				 text:'W' ,
				 tooltip:"Fit Width",
				 scope:this
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


    var bbar=[
      loadBtn,
      this.actions['PAGE_PREV'],
      this.tbItems['PAGE_FIELD'],
      this.tbItems['PAGE_COUNT'],
      this.actions['PAGE_NEXT'],
      {xtype:'tbseparator'},
      oneBtn,
      twoBtn,
      fourBtn,
      {xtype:'tbseparator'},
      singleBtn,
      continBtn,
      {xtype:'tbseparator'},
      pgZoom,
      wZoom,
      inZ,
      outZ,
      {xtype:'tbseparator'},
      this.tbItems['SEARCH_FIELD']
    ];

    var pagesId = this.prefix()+"pages";
    var root_id = this.getItemId()+"_content";

    Ext.apply(this,
      {autoScroll : true,
       enableKeyEvents: true,
       keys: {},
       bbar: bbar,
       html:'<div id="content-pane" class="content-pane" style="left:0pt;top:0pt"><center class="page-pane" id="'+pagesId+'"></center>',
       plugins: []
      });

    Paperpile.PDFviewer.superclass.initComponent.apply(this,arguments);
    Paperpile.PDFviewer.superclass.initComponent.call(this);
  },


  afterRender: function() {
    this.setKeyEvents();

    this.body.on('scroll',this.onScroll,this);
    this.body.on('mousedown', this.onMouseDown, this);
    this.body.on('mousemove', this.onMouseMove, this);
    this.body.on('mouseup', this.onMouseUp, this);
    this.body.on('mouseover',this.onMouseOver,this);

    this.delayedTask = new Ext.util.DelayedTask();

    this.updateButtons();

    Paperpile.PDFviewer.superclass.afterRender.apply(this, arguments);
  },

  onResize: function(){
    Paperpile.PDFviewer.superclass.onResize.apply(this, arguments);

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
    console.log(this.currentZoom);
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
	this.updateZoom();
	this.layoutPages();

	for (var i=0; i < this.pageN; i++) {
	  this.addBackgroundTask("initPDF thumbnails",this.loadThumbnail,[i],this,10);
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

    for (var i=0; i < columns; i++) {
      var pageIndex = this.currentPage + i;
      if (pageIndex > numPages-1) {
	break;
      }

      var newImg = Ext.get(this.prefix()+"img."+pageIndex);
      if (!this.isThumbnailLoaded(pageIndex)) {
	newImg.on("load",this.imageLoaded,this);
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

    //this.suspendEvents();
    for (var i=0; i < numBlocks; i++) {
      var children = [];
      for (var j=0; j < columns; j++) {
	var pageIndex = i*columns + j + this.viewStartPage;
	if (pageIndex > this.pageN-1)
	  break;
	children.push(this.pageTemplate(pageIndex,true));
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
	var pageIndex = i*columns+j + this.viewStartPage;
	if (pageIndex > this.pageN-1)
	  break;

	var newImg = Ext.get(this.prefix()+"img."+pageIndex);
	if (!this.isThumbnailLoaded(pageIndex)) {
	  newImg.on("load",this.imageLoaded,this);
	} else {
	  var blinder = Ext.fly(this.prefix()+"blinder."+pageIndex);
	  if (blinder != null)
	    blinder.remove();
	}

	this.addBackgroundTask("Layout Annotations",this.loadSearchAndAnnotations,[pageIndex],this,20,0,false);
      }
    }

    this.loadVisiblePages();


    //this.resumeEvents();
  },

  imageLoaded: function(e,t,o) {
    var img = Ext.fly(t);
    img.un("load");
    var id = t.id;
    var index = id.lastIndexOf(".")+1;
    if (index > 0) {
      var pageNo = id.substr(index);
      // Find the page blinder and hide it.
      var blinder = Ext.fly(this.prefix()+"blinder."+pageNo);
      if (blinder != null)
	blinder.setVisible(false);
    }
  },

  resizePages: function() {
    // Resize each page image.
    for (var i=this.startPage;i<this.startPage+this.maxPages;i++) {
      var pgImg = Ext.fly(this.prefix()+"img."+i);
      if (pgImg != null) {
	//console.log("Resizing page "+i);
	var adjW = this.getAdjustedWidth(i);
	var h = this.getAdjustedHeight(i);
	//console.log("w:"+adjW+" h:"+h);
	pgImg.set({width:adjW,height:h});
	var pgBlinder = Ext.fly(this.prefix()+"blinder."+i);
	if (pgBlinder != null) {
	  pgBlinder.setStyle({width:adjW,height:h,top:0,left:0});
	}
      }
    }

    // Load the full image of all visible pages.
    this.removeBackgroundTasksByName("Visible Pages");
    this.loadVisiblePages();

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

    // Reset the positions of all search results, stickies, annotations, etc.
    // Note: we put these actions on the bg queue, so the resizing happens first.
    this.removeBackgroundTasksByName("Resize Annotations");
    for (var i=this.startPage;i<this.startPage+this.maxPages;i++) {
      var pageIndex = i;
      var img = this.getImage(pageIndex);
      if (img == null)
	continue;

      this.addBackgroundTask("Resize Annotations",this.loadSearchAndAnnotations,[pageIndex],this,20,20,false);
    }
  },

  bgTasks:[],
  bgDelay:null,
  loadSearchAndAnnotations: function(pageIndex) {
    //console.log("  -> Loading search and Annotations for page "+pageIndex+"...");
    this.loadSearchResultsIntoPage(pageIndex);
    //console.log("  -> Done!");
  },

  addBackgroundTask: function(name,fn,paramArray,scope,delayToNext,workerDelay,addToFront) {
    if (!workerDelay) {
      workerDelay = 50;
    }
    if (!delayToNext) {
      delayToNext = 0;
    }
    if (!addToFront) {
      addToFront = false;
    }

    var bgTask = {
		   name:name,
		   fn:fn,
		   params:paramArray,
		   scope:scope,
		   delayToNext:delayToNext
		 };
    //console.log("Adding bg task: "+bgTask);
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
	console.log("Removing bg task "+i+": "+name);
	this.bgTasks.splice(i,1);
	i--;
      }
    }
  },

  backgroundWorker: function() {
    if (this.bgTasks.length > 0) {
      var bgTask = this.bgTasks.shift();
      console.log("Running background task '"+bgTask.name+"'  ["+bgTask.params+"]");
      try {
	bgTask.fn.defer(0,bgTask.scope,bgTask.params);
      } catch (err) {
	console.log("ERROR Running bgWorker:");
	console.log(err);
      }
    }

    if (this.bgTasks.length > 0) {
      this.bgDelay.delay(bgTask.delayToNext,this.backgroundWorker,this);
    } else {
      //console.log("  -> No work left to do! Stopping bgWorker...");
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
    //console.log("Real height: "+realHeight);
    return realHeight;
  },

  getRealWidth: function() {
    var realWidth = this.getInnerWidth() -2;
    //console.log("Real width: "+realWidth);
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
    //console.log("pgW: "+pgW);
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
    var needsLoading = this.loadThumbnail(pageIndex,0);
    return !needsLoading;
  },

  thumbnailSize:200,
  loadThumbnail: function(i,imgEl){
    var scale=this.thumbnailSize/this.pageSizes[i].width;
    scale = Math.round(scale*100)/100;
    var neededLoading = this.loadImage(i,scale,imgEl);
    return neededLoading;
  },

  loadImage: function(pageIndex,scale,target) {
    var url = "ajax/pdf/render"+this.file+"/"+pageIndex+"/"+scale;
    if (this.images[url] != null && this.images[url].complete) {
      //console.log("  -> No need to reload:"+url);

      if (target) {
	if (target.dom.src.indexOf(url) == -1) {
	  console.log("  -> Replacing image with pre-loaded at new size: "+url);
	  target.set({src:url});
	}
      }
      return false;
    } else {
      console.log("Loading image: "+url);

      /*if (target) {
	target.set({src:url});
	target.on("load",
	  function() {
	    this.images[url] = "loaded";
	    target.un("load");
	  },this);
      } else {*/
	var w = this.getAdjustedWidth(pageIndex,scale);
	var h = this.getAdjustedHeight(pageIndex,scale);
	var imgO = new Image(w,h);
	imgO.src = url;
	var images = this.images;
	imgO.onload = function() {
	  if (target) {
	    target.set({src:url});
	  }
	};
      //}

      this.images[url] = imgO;
      return true;
    }
  },

  loadFullPage: function(pageIndex) {
    var img = this.getImage(pageIndex);
    var scale = this.getScale(pageIndex);

    if (scale > 10 || scale < 0.1) {return false;}

    var pageNeedsLoading = this.loadImage(pageIndex,scale,img);

    /*
    var fullUrl="ajax/pdf/render"+this.file+"/"+pageIndex+"/"+scale;

    if (img.dom.src.indexOf(fullUrl) == -1) {
      if (this.images[fullUrl] != null) {
	var imgO = this.images[fullUrl];
	console.log("  -> No need to reload: "+fullUrl);
      //console.log(imgO);
      } else {
	var w = this.getAdjustedWidth(pageIndex);
	var h = this.getAdjustedHeight(pageIndex);
	var imgO = new Image(w,h);
	imgO.src = fullUrl;
	imgO.onload = function() {
	  console.log("  -> Image loaded! "+fullUrl);
	  img.set({src:fullUrl});
	  imgO.onload = null;
	};
	console.log("Loading image: "+fullUrl);
	this.images[fullUrl] = imgO;
      }
    }

    //var src = img.dom.src;
    //if (src.indexOf(png) == -1) {
    //  console.log("Loading new full img "+png);
      // If the image URL is changing as a result, let's update the <img> tag size to ensure
      // that the <img> and image sizes match up
      //var newWidth = Math.floor(this.pageSizes[pageIndex].width * scale);
      //var newHeight = newWidth * this.pageSizes[i].height / this.pageSizes[i].width;
      //img.set({src:png});
      //img.set({width:newWidth,height:newHeight});
    //}
     */
    //if (this.words[pageIndex].length == 0) {
      //this.loadWords(pageIndex);
    //}

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
    console.log("Searching for: "+searchText);

    Ext.Ajax.request({
      url: '/ajax/pdf/extpdf',
      params: {
        command: 'SEARCH',
        inFile: this.file,
	term: searchText
      },
      success: function(response){
      var doc = response.responseXML;
      //console.log("Response: "+response.responseText);

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
//    console.log(pageW/origW);
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

  onScroll: function(el) {
    this.delayedTask.delay(100,this.scrollDelay,this);;
  },

  loadNextPage:function(curPage) {
    var timeToWait = this.currentZoom * 2000;
    var pageNeedsLoading = this.loadFullPage(curPage);
    if (!pageNeedsLoading) {
      timeToWait = 100;
    }
    //this.timeoutNum = this.loadNextPage.defer(timeToWait,this,[curPage+1]);
  },

  stopPageLoading:function() {
    window.clearTimeout(this.timeoutNum);
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

    for (var i=0; i < visiblePages.length; i++) {
      var pageIndex = visiblePages[i];
      this.addBackgroundTask("Visible Pages",this.loadFullPage,[pageIndex],this,0,0,true);
    }
  },

  timeoutNum:0,
  scrollDelay: function(el) {
    var mostVisiblePage;
    var mostVisibleAmount=0;
    var visiblePages=[];
    for (var i=0; i < this.maxPages; i++) {
      var pageIndex = this.startPage + i;

      var pg = this.getPage(pageIndex);
      var img = this.getImage(pageIndex);
      if (img == null)
	continue;
      var amountInView = this.isElInView(img);
      if (amountInView > 0) {
	//console.log(amountInView);
	if (amountInView > mostVisibleAmount) {
	  mostVisibleAmount = amountInView;
	  mostVisiblePage = pageIndex;
	}
	if (amountInView > 0.05) {
	  visiblePages.push(pageIndex);
	}
      }
    }

    if (mostVisibleAmount > 0) {
      if (mostVisiblePage != this.currentPage) {
	//window.clearTimeout(this.timeoutNum);
	//this.loadNextPage(mostVisiblePage);
      }
      //this.setCurrentPage(mostVisiblePage);
    }

    for (var i=0; i < visiblePages.length; i++) {
      var pageIndex = visiblePages[i];
      //this.addBackgroundTask(this.loadFullPage,[pageIndex],this);
      this.loadFullPage(pageIndex);
    }

    //this.updateButtons();
  },

  isElInView: function(el) {
    var bot = el.getBottom()-1;
    var top = el.getTop()+1;
    if (bot > this.body.getTop() && top < this.body.getBottom()) {
      var amountInView = this.rangeOverlap(top,bot,this.body.getTop(),this.body.getBottom());
//      console.log(el.id+"  "+amountInView);
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
//	console.log("Response: "+doc);
        var words=Ext.DomQuery.select("word", doc);

        for (var i=0;i<words.length;i++){
          var value= Ext.DomQuery.selectValue("", words[i]);
	  //console.log("Word "+i+" "+value);
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
//    console.log(prevWord);
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

  zoomArray: [0.01,0.05,0.1,0.25,0.5,1,1.5,2,3,4,5,10],
  zoomInOut: function(dir) {
    var curZoom = this.currentZoom;
    this.specialZoom = '';

    var pgZ = this.getSpecialZoomLevel('page');

    var eqIndex = 0;
    var hiIndex = 0;
    for (var i=0; i < this.zoomArray.length; i++) {
      if (curZoom > this.zoomArray[i]) {
	hiIndex = i+1;
      }
      if (curZoom == this.zoomArray[i]) {
	hiIndex=i+1;
	if (dir == -1)
	  hiIndex = i;
	break;
      }
    }

    var destZoom = curZoom;
    if (dir == 1) {
      if (hiIndex >= this.zoomArray.length)
	hiIndex = this.zoomArray.length-1;
      destZoom = this.zoomArray[hiIndex];
    } else {
      if (hiIndex == 0)
	hiIndex = 1;
      destZoom = this.zoomArray[hiIndex-1];
    }

    if (destZoom < this.zoomArray[0])
      destZoom = this.zoomArray[0];
    if (destZoom > this.zoomArray[this.zoomArray.length-1])
      destZoom = this.zoomArray[this.zoomArray.length-1];

//    console.log("pg:"+pgZ);
    console.log("Cur:"+curZoom+" Dest zoom:"+destZoom);

    if (this.between(pgZ,curZoom,destZoom)) {
      destZoom = pgZ;
    }

    this.currentZoom = destZoom;
    this.updateZoom();
    this.resizePages();
    var pgEl = this.getPage(this.currentPage);
    pgEl.scrollIntoView(this.body,true);

    //this.scrollToPage(this.currentPage);
  },

  zoomIn:function() {
    this.zoomInOut(1);
  },
  zoomOut:function() {
    this.zoomInOut(-1);
  },

  updateButtons: function() {
    var pagesToStart = this.currentPage;
    var pagesToEnd = this.pageN - this.currentPage;

    for (action in this.actions) {
      this.actions[action].setDisabled(false);
    }

    this.actions['PAGE_NEXT'].setDisabled(pagesToEnd==0);
    this.actions['PAGE_PREV'].setDisabled(pagesToStart==0);


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
    //console.log(e.getTarget().tagName.toLowerCase());
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

  keyMap:null,
  setKeyEvents: function() {
    this.keyMap = new Ext.KeyMap(document);
    this.keyMap.addBinding({
      key:[Ext.EventObject.PAGE_DOWN,Ext.EventObject.RIGHT],
      fn:this.pageScrollNext,
      scope:this,
      stopEvent:true
    });

    this.keyMap.addBinding({
      key:[Ext.EventObject.PAGE_UP,Ext.EventObject.LEFT],
      fn:this.pageScrollPrev,
      scope:this,
      stopEvent:true
    });

    this.keyMap.addBinding({
      key:'z',
      fn:this.animateZoomTo,
      scope:this,
      stopEvent:true
    });
  },

  animateZoomTo: function() {
    this.zoomCfg = {duration:2,easing:"easeOutStrong"};
    this.zoomAnim = Ext.lib.Anim.motion(this.el,
      {zoomLevel:{from:1,to:2}}
	);
    this.zoomAnim.onTween.addListener(
      function(){
	this.currentZoom = this.el.getStyle("zoomLevel");
	//console.log(this.el.getStyle("zoomLevel"));
	this.onResize(false);
      }, this);
    this.zoomAnim.animate();
  },


  zoomToPage: function() {

  },

  zoomToWidth: function() {

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
      console.log("Setting cur pgae!");
      img.addClass("pdf-cur-page");
    }
    //var pt = this.tbItems['PAGE_COUNT'];
    //var totalPages = this.pageN;
    //pt.setText("of "+totalPages);
  },

  scrollAnimation:null,
  scrollToPage: function(scrollTarget) {
    if (scrollTarget >= this.pageN)
      scrollTarget = this.pageN-1;
    if (scrollTarget < 0)
      scrollTarget = 0;

    //console.log(scrollTarget);
    var pgEl = this.getPage(scrollTarget);
    console.log(scrollTarget);
    pgEl.scrollIntoView(this.body,true);
    this.setCurrentPage(scrollTarget);
    this.scrollDelay();
    //this.loadFullPage(scrollTarget);
  },

  openFile:function() {
    console.log("Open file!");
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
          console.log(path);
          this.initPDF(path);
        }
      },
      scope:this
    });
    win.show();
  }

});

// Helper class for organizing the buttons
ButtonPanel = Ext.extend(Ext.Panel, {
  layout:'table',
  defaultType: 'button',
  baseCls: 'x-plain',
  cls: 'btn-panel',
  renderTo : 'docbody',
  menu: undefined,
  split: false,

  layoutConfig: {
    columns:3
  },

  constructor: function(desc, buttons){
    // apply test configs
    for(var i = 0, b; b = buttons[i]; i++){
      b.menu = this.menu;
      b.enableToggle = this.enableToggle;
      b.split = this.split;
      b.arrowAlign = this.arrowAlign;
    }
    var items = [{
		   xtype: 'box',
		   autoEl: {tag: 'h3', html: desc, style:"padding:15px 0 3px;"},
		   colspan: 3
		 }].concat(buttons);

    ButtonPanel.superclass.constructor.call(this, {
					      items: items
					    });
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
