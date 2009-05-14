Paperpile.PDFviewer = Ext.extend(Ext.Panel, {

    mode: 'anchorzoom',
    currentZoom: 1.0,
    currentPage:0,
    pageN:0,
    pageSizes:[],
    words:[],
    lines:[],
    selection:[],
    selectionStartWord:-1,
    selectionPrevWord:-1,
    thumbnails:[],
    delayedTask:null,

    initComponent: function() {
        Ext.apply(this, 
                  {autoScroll : true,
		   html:'<div id="content-pane" class="content-pane" style="left:0pt;top:0pt"><center class="page-pane" id="pages"></center>'
                  }
		  );
	
	Paperpile.PDFviewer.superclass.initComponent.call(this);
    },

    afterRender: function() {
        Paperpile.PDFviewer.superclass.afterRender.apply(this, arguments);
	this.body.on('scroll',this.onScroll,this);
        this.body.on('mousedown', this.onMouseDown, this);
        this.body.on('mousemove', this.onMouseMove, this);
        this.body.on('mouseup', this.onMouseUp, this);
	this.body.on('mouseover',this.onMouseOver,this);

	this.delayedTask = new Ext.util.DelayedTask();
    },

    columnCount:3,
    onResize: function(){
        Paperpile.PDFviewer.superclass.onResize.apply(this, arguments);
	for (var i=0; i < this.pageN;i++) {
	    this.resizeImage(i);
	    //var img = this.getPage(i);
	    /*if (i % this.columnCount == 0) {
		img.removeClass("pp-page-inline");
		img.addClass("pp-page-clear");
	    } else {
		img.removeClass("pp-page-clear");
		img.addClass("pp-page-inline");
		}*/
	};
	// Update the css to reflect the zoom.
	
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
                this.pageN = Ext.DomQuery.selectNumber("pageNo", doc);
                var p=Ext.DomQuery.select("page", doc);

                this.pageSizes=[];
                for (var i=0;i<this.pageN;i++){
                    var width=Ext.DomQuery.selectNumber("width", p[i]);
                    var height=Ext.DomQuery.selectNumber("width", p[i]);
                    this.pageSizes.push({width:width, height:height});
                    this.words[i]=[];
                    this.lines[i]=[];

		    // Create the per-page divs and imgs.
		    var pdfContainer=Ext.get(Ext.query('#pages'));
		    var newDiv = new Ext.Element(document.createElement('div'));
		    pdfContainer.appendChild(newDiv);
		    newDiv.set({id:"page."+i});
		    newDiv.addClass('pp-page-element');
		    newDiv.addClass('pp-page-inline');

		    var emptyDiv = new Ext.Element(document.createElement('div'));
		    emptyDiv.set({id:""});
		    newDiv.appendChild(emptyDiv);
		    var highlightDiv = new Ext.Element(document.createElement('div'));
		    emptyDiv.appendChild(highlightDiv);
		    var stickyDiv = new Ext.Element(document.createElement('div'));
		    emptyDiv.appendChild(stickyDiv);

		    var newImg = new Ext.Element(document.createElement('img'));
		    emptyDiv.appendChild(newImg);
		    newImg.addClass('pp-page-img');
		    
		    this.loadThumbnail(i,newImg);
		    this.resizeImage(i);
                }
            },
            scope:this
        });
    },

    getImgWidth: function() {
	    var zoom = this.currentZoom;
	    //if (zoom < 1.2 && zoom > 0.8)
	    //	zoom = 1;
	    return (this.getInnerWidth()-100)*zoom;
    },

    resizeImage: function(i) {
	var pgImg = this.getImage(i);
	var w = this.getImgWidth();
	pgImg.set({width:w});

	var pg = this.getPage(i);
	var pad = w/50;
	pg.setStyle("padding",pad+"px 0");
    },

    loadThumbnail: function(i,imgEl){
        var scale=200/this.pageSizes[i].width;
	scale = Math.round(scale*100)/100;
	var png = "ajax/pdf/render/"+this.file+"/"+i+"/"+scale;
	imgEl.set({src:png});
    },

    getImage: function(i){
	return Ext.get(Ext.query("img","page."+i)[0]);
    },

    getPage: function(i){
	return Ext.get("page."+i);
    },

    loadFullPage: function(i) {
	var img = this.getImage(i);
	var width = this.getImgWidth();
	//console.log(i+"  "+width+"  "+this.pageSizes[i].width);
	var scale = (width)/this.pageSizes[i].width;
        scale = Math.round(scale*100)/100;
	//console.log("Scale: "+scale);
	if (scale > 10 || scale < 0.1) {return;}

        var png="ajax/pdf/render/"+this.file+"/"+i+"/"+scale;
	var src = img.dom.src;
	if (src.indexOf(png) == -1) {
	    console.log(png);
	    var newWidth = Math.floor(this.pageSizes[i].width * scale);
	    console.log("Scale: "+scale+" orig width:"+width+" New width: "+newWidth);
	    img.set({src:png});
	    img.set({width:newWidth});
	    //Ext.DomHelper.applyStyles(img.dom,"width:"+newWidth+"px");
	    //console.log(img.dom.width);
	}
    },

    onScroll: function(el) {
	// Get the images currently in view, and update them accordingly.
	this.visiblePages = [];
	for (var i=0; i < this.pageN;i++) {
	    var pg = this.getPage(i);
	    var img = this.getImage(i);
	    if (this.isElInView(img)) {
		this.visiblePages.push(i);
		this.delayedTask.delay(200,function(index) {
			this.loadFullPage(index);
		    },this,[i]);
	    }
	}
    },

    isElInView: function(el) {
        var bot = el.getBottom();
	var top = el.getTop();
	if (bot > this.body.getTop() && top < this.body.getBottom()) {	
	    return true;
	}
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

    loadWords: function(){

        Ext.Ajax.request({
            url: '/ajax/pdf/extpdf',
            params: {
                command: 'WORDLIST',
                page:this.currentPage,
                inFile: this.file 
            },
            success: function(response){
                var doc = response.responseXML;
                var words=Ext.DomQuery.select("word", doc);

                for (var i=0;i<words.length;i++){
                    var value= Ext.DomQuery.selectValue("", words[i]);
                    var values=value.split(',');
                    var x1=values[0];
                    var y1=values[1];
                    var x2=values[2];
                    var y2=values[3];
                
                    this.words[this.currentPage].push({x1:x1,y1:y1,x2:x2,y2:y2});
                }

                this.calculateLines();

            },
            
            scope: this
        });
    },

    calculateLines: function(){

        var lines=[];
        var currWord;
        var prevWord;
        
        var prevWord=this.words[this.currentPage][0];
        var currLine=[prevWord];
        var cutoffX=5.0;
        var cutoffY=0.1;
        var distX;
        var distY;
        
        for (var i=1; i< this.words[this.currentPage].length;i++){
            currWord=this.words[this.currentPage][i];
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
                            y2:currLine[0].y2,
                           });
                currLine=[currWord];
            }
        }

        // push last line
        lines.push({x1:currLine[0].x1,
                    y1:currLine[0].y1,
                    x2:currLine[currLine.length-1].x2,
                    y2:currLine[0].y2,
                   });

        this.lines[this.currentPage]=lines;
        
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

            var top=this.pdf2px(line.y1)
            var left=this.pdf2px(line.x1);
            var width=this.pdf2px(line.x2-line.x1);
            var height=this.pdf2px(line.y2-line.y1);

            var el=Ext.get(document.createElement('div'));
            el.addClass('pp-pdf-selector');
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
        var top=this.pdf2px(word.y1)
        var left=this.pdf2px(word.x1);
        var width=this.pdf2px(word.x2-word.x1);
        var height=this.pdf2px(word.y2-word.y1);
        
        var el=Ext.get(document.createElement('div'));
        el.addClass('pp-pdf-selector');
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
	    e.stopEvent();
	    this.mouseDownWindowX = e.getPageX();
	    this.mouseDownWindowY = e.getPageY();

	    this.mouseDownZoom = this.currentZoom;
	    this.mouseDownEl = Ext.get(e.getTarget());

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
	    newDiv.setStyle("width","1px");

	    this.mouseDownAnchor = newDiv;
	    this.mouseDownDistToAnchorY = y - this.mouseDownAnchor.getY();
	    this.mouseDownViewportTop = y - (this.body.getTop());
	    console.log(this.mouseDownViewportTop);
	    
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


    onMouseMove: function(e) {

        var x = e.getPageX();
        var y = e.getPageY();
	this.mouseX = x;
	this.mouseY = y;

        if (this.mode == 'anchorzoom') {
	    e.stopEvent();
	    
	    if (this.isMouseDown) {
		// && this .mouseDownEl != null && this.mouseDownEl.tagName.toLowerCase == "img") {
		var tag = this.mouseDownEl.dom.tagName.toLowerCase();
		if (tag == "img") {
		    var dY = y - this.mouseDownWindowY;
		    var dZoom = dY / 100;
		    var zoomF = Math.pow(10,-dZoom);
		    this.currentZoom = this.mouseDownZoom * zoomF;
		    this.onResize();
		    
		    var newTop = Ext.Element.fly(this.mouseDownAnchor).getOffsetsTo(this.body)[1] + this.body.dom.scrollTop;
		    var dY = this.mouseDownDistToAnchorY * zoomF;
		    newTop -= this.mouseDownViewportTop;
		    newTop += dY;
		    //var newTop = this.mouseDownScrollF*this.body.getHeight()*zoomF;
		    this.body.scrollTo('top',newTop);
		 
		    //console.log(newTop/this.body.getHeight()/zoomF);
		    var el = this.mouseDownEl;
		    var top = Ext.Element.fly(el).getOffsetsTo(this.body)[1] + this.body.dom.scrollTop;
		    var h = el.getHeight(true);
		    var dY = this.mouseDownPercentY * h;
		    //this.body.scrollTo('top',top + dY - this.body.getHeight()/2);
		    var dX = this.mouseDownPercentX * el.getWidth(true);
		    //this.body.scrollTo('left',dX - this.body.getWidth()/2);
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

            if (currentWord != this.selectionPrevWord){
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


        if (this.mode == 'drag'){
            Ext.getBody().un('mousemove', this.onMouseMove, this);
            Ext.getDoc().un('mouseup', this.onMouseUp, this);
        }

        if (this.mode == 'select'){

            x=x-this.bitmap.getLeft();
            y=y-this.bitmap.getTop();
            
            var currentWord=this.getWord(x,y);

            if (currentWord==this.selectionStartWord && currentWord !=-1){
                this.selectWord(currentWord);
            }
                    
            Ext.getBody().un('mousemove', this.onMouseMove, this);
            Ext.getDoc().un('mouseup', this.onMouseUp, this);
        }

    }

});

Ext.reg('pdfviewer', Paperpile.PDFviewer);
