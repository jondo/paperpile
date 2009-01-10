PaperPile.PDFviewer = Ext.extend(Ext.Panel, {

    file: '/home/wash/play/PaperPile/t/data/nature.pdf',
    store: null,
    canvasWidth: null,
    canvasHeight: null,
    mode: 'drag',

    initComponent: function() {
    
		    _store=new Ext.data.Store(
            {id: 'data',
             proxy: new Ext.data.HttpProxy({
                 url: '/ajax/pdf/pdf_viewer', 
                 method: 'GET'
             }),
             baseParams:{viewer_id: this.id,
                         file: this.file,
                         limit:1
                        },
             reader: new Ext.data.JsonReader(),
            });

        _store.on('datachanged', this.reloadImage,this);

        var i = document.createElement('img');
        i.src = Ext.BLANK_IMAGE_URL;

        var _pager=new Ext.PagingToolbar({
            pageSize: 1,
            store: _store,
            displayInfo: false,
        });

        var _zoomer= new Ext.Slider({
            width: 200,
            value: 5,
            increment: 1,
            minValue: 0,
            maxValue: 10
        });


        Ext.apply(this, 
                  {autoScroll : false,
                   bbar: _pager,
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
                   store: _store,
                   client: i,
                  }
                 );
		    PaperPile.PDFviewer.superclass.initComponent.call(this);

        _zoomer.on('change',this.onZoom,this);


	  },


    onZoom: function(zoomer,value){

        value=value/5;
        
        this.store.reload({params:{start: this.getBottomToolbar().cursor, zoom: value}});

    },
     
    onRender: function() {

        PaperPile.PDFviewer.superclass.onRender.apply(this, arguments);

    },

    afterRender: function() {

        PaperPile.PDFviewer.superclass.afterRender.apply(this, arguments);

        Ext.getCmp('drag_button').on('toggle',this.onModeToggle,this);
        Ext.getCmp('select_button').on('toggle',this.onModeToggle,this);
        Ext.getCmp('sticky_button').on('toggle',this.onModeToggle,this);


    },

    initPDF: function(){

        this.body.appendChild(this.client);
        this.client = Ext.get(this.client);
        this.client.setStyle('cursor', 'move');

        this.client.on('mousedown', this.onMouseDown, this);

        this.store.load({params:{start:0,
                                 zoom: 1.0,
                                 canvas_width: Ext.getCmp('MAIN').canvasWidth,
                                 canvas_height: Ext.getCmp('MAIN').canvasHeight,
                                }});

    },

    onModeToggle:function (button, pressed){
        
        if (button.id == 'sticky_button' && pressed){
            this.mode='sticky';
            this.client.setStyle('cursor', 'crosshair');
        }

        if (button.id == 'select_button' && pressed){
            this.mode='select';
            this.client.setStyle('cursor', 'crosshair');
        }

        if (button.id == 'drag_button' && pressed){
            this.client.setStyle('cursor', 'move');
            this.mode='drag';

        }


    },


    reloadImage: function(store){
        var newImage=store.getAt(0).get('image');
        this.client.set({src:newImage});
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
