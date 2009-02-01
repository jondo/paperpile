PaperPile.PDFviewer = Ext.extend(Ext.Panel, {

    canvasWidth: null,
    canvasHeight: null,
    mode: 'drag',

    initComponent: function() {
    
	    var i = document.createElement('img');
        i.src = Ext.BLANK_IMAGE_URL;

        _store=new Ext.data.Store(
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
                   {autoScroll : false,
                    bbar:_pager,
                    tbar: new Ext.Toolbar(
                       {items: [_zoomer,
                    /*            { text: 'Drag',
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
                                }*/
                               ]}
                   ),
                    bitmap: i,
                    store:_store
                  }
                 );
		    PaperPile.PDFviewer.superclass.initComponent.call(this);

        _zoomer.on('change',this.onZoom,this);


	  },


    onZoom: function(zoomer,value){

        value=value/5;

        this.store.baseParams.zoom=value;
        //this.bitmap.setSize(this.bitmap.getWidth()*value,this.bitmap.getHeight()*value);
        this.store.reload({params:{start: this.getBottomToolbar().cursor}});


    },
     
    onRender: function() {

        //consider slide in effect !!
        
        PaperPile.PDFviewer.superclass.onRender.apply(this, arguments);

    },

    afterRender: function() {

        PaperPile.PDFviewer.superclass.afterRender.apply(this, arguments);

        this.body.appendChild(this.bitmap);
        this.bitmap = Ext.get(this.bitmap);
        this.bitmap.setStyle('cursor', 'move');
        this.bitmap.on('mousedown', this.onMouseDown, this);


        //Ext.getCmp('drag_button').on('toggle',this.onModeToggle,this);
        //Ext.getCmp('select_button').on('toggle',this.onModeToggle,this);
        //Ext.getCmp('sticky_button').on('toggle',this.onModeToggle,this);


    },

    initPDF: function(file){

        this.file=file,

        this.store.baseParams={viewer_id: this.id, file: this.file, limit:1, zoom:1.0};

        this.store.load({params:{start:0,
                                 canvas_width: Ext.getCmp('MAIN').canvasWidth,
                                 canvas_height: Ext.getCmp('MAIN').canvasHeight,
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
        if (this.mode == 'drag'){
            e.stopEvent();
            var x = e.getPageX();
            var y = e.getPageY();
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
