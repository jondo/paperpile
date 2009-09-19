Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
var Paperpile = {};
Ext.ns('Paperpile');

Ext.getUrlParam = function(param,deflt) {
  if (deflt === undefined) deflt = '';
  var params = Ext.urlDecode(location.search.substring(1));
  if (params[param]) {
    return params[param];
  } else {
    return deflt;
  }
};

Ext.onReady(function() {

    var path = Ext.getUrlParam('file','');
    var layout = Ext.getUrlParam('layout','single');
    var columns = Ext.getUrlParam('columns','1');
    log("Layout:"+layout+" cols:"+columns);
              
    var vp=new Ext.Viewport({
        layout: 'border',
        defaults: {
            collapsible: true,
            split: true
        },
        items: [
            new Ext.Panel({
                region:'west',
                split: true,
                width: 30
            }),

            new Paperpile.PDFviewer(
                {id:'pdf_viewer',
                 region:'center',

		 // PDF Viewer initial config options.
		 search:'',     // initial search.
		 file:path,                // file to load on startup.
		 zoom:'page',            // 'width', 'page', or a numerical value.
		 columns:columns,              // Number of columns to view.
		 pageLayout:layout     // 'single' or 'continuous'
                }
            ),

            new Ext.Panel({
                region:'east',
                width: 30
            })
     ]
    });

    //vp.on('afterlayout', Ext.getCmp('pdf_viewer').onLayout, Ext.getCmp('pdf_viewer'));
    //vp.on('render', function(){alert('inhere')}, Ext.getCmp('pdf_viewer'));

    var win=new Paperpile.FileChooser({
        //currentRoot:'ROOT',
        showFilter: true,
        filterOptions:[{text: 'PDF documents (.pdf)',
                        suffix: ['pdf']
                       },
                       {text: 'All files',
                        suffix:['ALL']
                       }
                      ],
        //saveMode: true,
        //saveDefault: 'new-file.dat',
        callback:function(button,path){
            if (button == 'OK'){
                var viewer=Ext.getCmp('pdf_viewer');
                console.log(path);
                viewer.initPDF(path);
                vp.show();
            }
        }
    });

/*
     var viewer = Ext.getCmp('pdf_viewer');
    if (path !== undefined && path !== '') {
      console.log(path);
      viewer.initPDF(path);
    } else {
      win.show();
    }
*/
});