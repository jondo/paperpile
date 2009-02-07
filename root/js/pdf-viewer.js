PaperPile.PDFviewer = Ext.extend(Ext.Panel, {

    mode: 'drag',

    initComponent: function() {

        var _store=new Ext.data.Store(
            {id: 'data',
             proxy: new Ext.data.HttpProxy({
                 url: '/ajax/pdf/pdf_viewer', 
                 method: 'GET'
             }),
             baseParams:{},
             reader: new Ext.data.JsonReader(),
            });

        _store.on('datachanged', this.reloadImage,this);

        var _pager=new Ext.PagingToolbar({
            pageSize: 1,
            store: _store,
            displayInfo: false,
        });

        var _zoomer= new Ext.Slider({
            width: 200,
            value: 5,
            increment: 1,
            minValue: 1,
            maxValue: 10
        });

        Ext.apply(this, 
                  {autoScroll : true,
                   bbar:_pager,
                   tbar: new Ext.Toolbar(
                       {items: [_zoomer,
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
                   store:_store
                  }
                 );

		PaperPile.PDFviewer.superclass.initComponent.call(this);
        
        _zoomer.on('change',this.onZoom,this);
        
	  },


    onZoom: function(zoomer,value){

        value=value/5;
        this.store.baseParams.zoom=value;
        this.store.reload({params:{start: this.getBottomToolbar().cursor}});
        



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
        console.log(this.canvasWidth);
        console.log(this.canvasHeight);
    },


    initPDF: function(file){

        this.file=file,

        this.store.baseParams={viewer_id: this.id, file: this.file, limit:1, zoom:1.0};

        this.store.load({params:{start:0,
                                 canvas_width: this.canvasWidth,
                                 canvas_height: this.canvasHeight,
                                }});

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
        var newImage=store.getAt(0).get('image');
        console.log(this.bitmap);
        this.bitmap.set({src:newImage});

        //if (this.bitmap.getWidth() < this.body.getWidth()){
        //    console.log("Bitmap:"+this.bitmap.getWidth());
        //    console.log("Container:"+this.body.getWidth());
        //}

        console.log(this.bitmap);

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

        Ext.getCmp('statusbar').clearStatus();

        var box=this.bitmap.getBox();

        Ext.getCmp('statusbar').setText('('+x+','+y+')'+'    ('+box.x+','+box.y+')');


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
