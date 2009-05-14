Paperpile.PDFviewer = Ext.extend(Ext.Panel, {

    mode: 'drag',
    currentZoom: 1.0,
    currentPage:0,
    pageN:0,
    pages:[],
    words:[],
    lines:[],
    selection:[],
    selectionStartWord:-1,
    selectionPrevWord:-1,

    initComponent: function() {

        var zoomer= new Paperpile.PDFzoomer;
  
        Ext.apply(this, 
                  {autoScroll : true,
                   bbar:new Ext.Toolbar(
                       { items: [
                           {  xtype:'button',
                              tooltip: 'First page',
                              itemId:'first',
                              iconCls: "x-tbar-page-first",
                              handler: function(){
                                  this.currentPage=0;
                                  this.setPage(this.currentPage);
                              },
                              scope:this,
                           },
                           {
                               xtype:'button',
                               tooltip: 'Prev page',
                               iconCls: "x-tbar-page-prev",
                               itemId:'prev',
                               handler: function(){
                                   this.currentPage--;
                                   this.setPage(this.currentPage);
                               },
                               scope: this,
                               //disabled: true,
                           },
                           //{
                           //    xtype:'textfield',
                           //    cls: "x-tbar-page-number",
                           //    disabled: true,
                           //},
                           {
                               tooltip: "Next page",
                               iconCls: "x-tbar-page-next",
                               itemId:'next',
                               handler: function(){
                                   this.currentPage++;
                                   this.setPage(this.currentPage);
                               },
                               scope: this,
                               //disabled: true,
                           },
                           {
                               tooltip: "Last page",
                               itemId:'last',
                               iconCls: "x-tbar-page-last",
                               handler: function(){
                                   this.currentPage=this.pageN-1;
                                   this.setPage(this.currentPage);
                               },
                               scope:this,
                           }
                       ]
                       }
                   ),
                   tbar: new Ext.Toolbar(
                       {items: [zoomer,
                                {xtype:'tbfill'},
                                { text: 'Drag',
                                  id: 'drag_button',
                                  enableToggle: true,
                                  toggleGroup: 'mode_buttons',
                                  allowDepress : false,
                                  pressed: true
                                },
                                { text: 'Sticky',
                                  id: 'sticky_button',
                                  enableToggle: true,
                                  toggleGroup: 'mode_buttons',
                                  allowDepress : false,
                                  pressed: false,
                                  disabled:true,
                                  
                                },
                                { text: 'Select',
                                  id: 'select_button',
                                  enableToggle: true,
                                  toggleGroup: 'mode_buttons',
                                  allowDepress : false,
                                  pressed: false
                                }
                               ]}
                   ),
                   zoomer:zoomer,
                   html:'<div id="pdf'+this.id+'" class="pp-pdf-container"></div>'
                  }
                 );

		Paperpile.PDFviewer.superclass.initComponent.call(this);

        zoomer.on('change',this.onZoom,this);
        zoomer.on('changecomplete',this.onZoomComplete,this);
        
	  },


    onZoom: function(zoomer,value){

        scale=zoomer.map[value];
        this.bitmap.setWidth(this.originalWidth*scale);

    },

    onZoomComplete: function(zoomer,value){

        this.currentZoom=zoomer.map[value];

        this.loadPage();

    },

    afterRender: function() {

        Paperpile.PDFviewer.superclass.afterRender.apply(this, arguments);
        
        this.bitmap = document.createElement('img');
        this.bitmap.src = Ext.BLANK_IMAGE_URL;
        this.pdfContainer=Ext.get(Ext.query('#pdf'+this.id))
        this.pdfContainer.appendChild(this.bitmap);
        this.bitmap = Ext.get(this.bitmap);

        this.bitmap.setStyle('cursor', 'move');
        this.bitmap.addClass('pp-pdf-bitmap');

        this.bitmap.on('mousedown', this.onMouseDown, this);

        Ext.getCmp('drag_button').on('toggle',this.onModeToggle,this);
        Ext.getCmp('select_button').on('toggle',this.onModeToggle,this);
        Ext.getCmp('sticky_button').on('toggle',this.onModeToggle,this);

    },

    onResize: function(){
        Paperpile.PDFviewer.superclass.onResize.apply(this, arguments);
        this.canvasWidth=this.getInnerWidth();
        this.canvasHeight=this.getInnerHeight();
        this.originalWidth=this.canvasWidth;
    },


    initPDF: function(file){

        this.file=file,
        this.zoomer.setValue(5);

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

                this.pages=[];

                for (var i=0;i<this.pageN;i++){
                    var width=Ext.DomQuery.selectNumber("width", p[i]);
                    var height=Ext.DomQuery.selectNumber("width", p[i]);
                    this.pages.push({width:width, height:height});
                    this.words[i]=[];
                    this.lines[i]=[];
                    
                }


                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Read info for PDF');
                this.currentPage=0;
                this.updatePager();
                this.loadPage();

            },
            scope:this
        });
    },

    nextPage: function(){
        this.currentPage=this.currentPage+1;
        this.updatePager();
        this.loadPage();
    },

    prevPage: function(){
        this.currentPage=this.currentPage-1;
        this.updatePager();
        this.loadPage();
    },

    setPage: function(i){
        this.currentPage=i;
        this.updatePager();
        this.loadPage();
    },

    updatePager: function(){

        var nextButton=this.getBottomToolbar().items.get('next');
        var prevButton=this.getBottomToolbar().items.get('prev');

        if (this.currentPage==this.pageN-1){
            nextButton.disable();
        } else {
            nextButton.enable();
        }

        if (this.currentPage==0){
            prevButton.disable();
        } else {
            prevButton.enable();
        }
        
    },
    

    loadPage: function(){
        var scale=this.canvasWidth/this.pages[this.currentPage].width*this.currentZoom;

        scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);

        var png="ajax/pdf/render/"+this.file+"/"+this.currentPage+"/"+scale;
        
        this.bitmap.set({src:png});

        if (this.words[this.currentPage].length==0){
            this.loadWords();
        }

    },

    pdf2px: function(pdfCoord){
        var scale=this.canvasWidth/this.pages[this.currentPage].width*this.currentZoom;
        scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);
        return Math.round(pdfCoord*scale);
    },

    px2pdf: function(px){
        var scale=this.canvasWidth/this.pages[this.currentPage].width*this.currentZoom;
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

    onModeToggle:function (button, pressed){
        
        if (button.id == 'sticky_button' && pressed){
            this.mode='sticky';
            this.bitmap.setStyle('cursor', 'crosshair');
        }

        if (button.id == 'select_button' && pressed){
            this.mode='select';
            this.bitmap.setStyle('cursor', 'text');
        }

        if (button.id == 'drag_button' && pressed){
            this.bitmap.setStyle('cursor', 'move');
            this.mode='drag';
        }
    },


    onMouseDown: function(e) {

        if (this.mode == 'drag'){
            e.stopEvent();
            this.mouseX = e.getPageX();
            this.mouseY = e.getPageY();
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

        if (this.mode == 'drag'){
            e.stopEvent();
            if (e.within(this.body)) {
	              var xDelta = x - this.mouseX;
	              var yDelta = y - this.mouseY;
	              this.body.dom.scrollLeft -= xDelta;
	              this.body.dom.scrollTop -= yDelta;
	          }
            this.mouseX = x;
            this.mouseY = y;
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
