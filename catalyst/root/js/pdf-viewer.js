PaperPile.PDFviewer = Ext.extend(Ext.Panel, {

    mode: 'drag',
    currentZoom: 1.0,
    currentPage:1,
    pages:[],

    initComponent: function() {

        //var pager=new Ext.PagingToolbar({
        //    pageSize: 1,
        //    displayInfo: false,
        //});

        var zoomer= new PaperPile.PDFzoomer;
  
        Ext.apply(this, 
                  {autoScroll : false,
                   bbar:new Ext.Toolbar(
                       { items: [
                           {  xtype:'button',
                              tooltip: 'First page',
                              iconCls: "x-tbar-page-first",
                              disabled: true,
                           },
                           {
                               xtype:'button',
                               tooltip: 'Next page',
                               iconCls: "x-tbar-page-prev",
                               disabled: true,
                           },
                           {
                               xtype:'textfield',
                               cls: "x-tbar-page-number",
                               disabled: true,
                           },
                           {
                               tooltip: "Next page",
                               iconCls: "x-tbar-page-next",
                               disabled: true,
                           },
                           {
                               tooltip: "Last page",
                               iconCls: "x-tbar-page-last",
                               disabled: true,
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
                                  pressed: false
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
                   zoomer:zoomer
                  }
                 );

		PaperPile.PDFviewer.superclass.initComponent.call(this);

        //store.on('datachanged', this.reloadImage,this);
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

        PaperPile.PDFviewer.superclass.afterRender.apply(this, arguments);
        
        this.bitmap = document.createElement('img');
        this.bitmap.src = Ext.BLANK_IMAGE_URL;
        this.body.appendChild(this.bitmap);
        this.bitmap = Ext.get(this.bitmap);

        this.bitmap.setStyle('cursor', 'move');

        this.bitmap.addClass('pp-pdf-document');

        this.bitmap.on('mousedown', this.onMouseDown, this);

        //Ext.getCmp('drag_button').on('toggle',this.onModeToggle,this);
        //Ext.getCmp('select_button').on('toggle',this.onModeToggle,this);
        //Ext.getCmp('sticky_button').on('toggle',this.onModeToggle,this);

    },

    onResize: function(){
        PaperPile.PDFviewer.superclass.onResize.apply(this, arguments);
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
                this.pageNo = Ext.DomQuery.selectNumber("pageNo", doc);

                var p=Ext.DomQuery.select("page", doc);

                this.pages=[];

                for (var i=0;i<this.pageNo;i++){
                    var width=Ext.DomQuery.selectNumber("width", p[i]);
                    var height=Ext.DomQuery.selectNumber("width", p[i]);
                    this.pages.push({width:width, height:height});
                }

                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Read info for PDF');
                this.currentPage=1;
                this.loadPage();

            },
            scope:this
        });

 
        //this.store.baseParams={viewer_id: this.id, file: this.file, limit:1, zoom:1.0};

        //this.store.load({params:{start:0,
        //                         canvas_width: this.canvasWidth,
        //                         canvas_height: this.canvasHeight,
        //                        }});

    },

    loadPage: function(){
        var scale=this.canvasWidth/this.pages[this.currentPage].width*this.currentZoom;

        scale = Math.round(scale*Math.pow(10,2))/Math.pow(10,2);

        var png="ajax/pdf/render/home/wash/PDFs/gesell06.pdf/"+this.currentPage+"/"+scale;
        this.bitmap.set({src:png});
    },



    onModeToggle:function (button, pressed){
        
        if (button.id == 'sticky_button' && pressed){
            this.mode='sticky';
            this.bitmap.setStyle('cursor', 'crosshair');
        }

        if (button.id == 'select_button' && pressed){
            this.mode='select';
            this.bitmap.setStyle('cursor', 'crosshair');
        }

        if (button.id == 'drag_button' && pressed){
            this.bitmap.setStyle('cursor', 'move');
            this.mode='drag';
        }
    },


    reloadImage: function(store){
        //var newImage=store.getAt(0).get('image');
        this.bitmap.set({src:newImage});
    },

    onMouseDown: function(e) {

        if (this.mode == 'drag'){
            e.stopEvent();
            this.mouseX = e.getPageX();
            this.mouseY = e.getPageY();
            Ext.getBody().on('mousemove', this.onMouseMove, this);
            Ext.getDoc().on('mouseup', this.onMouseUp, this);
        }
    },

    onMouseMove: function(e) {

        var x = e.getPageX();
        var y = e.getPageY();

        //Ext.getCmp('statusbar').clearStatus();
        //var box=this.bitmap.getBox();
        //Ext.getCmp('statusbar').setText('('+x+','+y+')'+'    ('+box.x+','+box.y+')');

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
    },

    onMouseUp: function(e) {
     
        if (this.mode == 'drag'){
            Ext.getBody().un('mousemove', this.onMouseMove, this);
            Ext.getDoc().un('mouseup', this.onMouseUp, this);
        }
    }

});

Ext.reg('pdfviewer', PaperPile.PDFviewer);
