Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

Ext.onReady(function() {

    var vp=new Ext.Viewport({
        layout: 'border',
        defaults: {
            collapsible: true,
            split: true,
        },
        items: [
            new Ext.Panel({
                region:'west',
                split: true,
                width: 200,
            }),
            new Ext.Panel({
                region:'north',
                height: 100,
                bbar: new Ext.StatusBar({
                    border:0,
                    id: 'statusbar',
                    defaultText: 'Default status text',
                    defaultIconCls: 'default-icon',
                    text: 'Ready',
                    iconCls: 'ready-icon',
                }),
            }),
            
            new Paperpile.PDFviewer(
                {id:'pdf_viewer',
                 itemId:'pdf_viewer',
                 region:'center'
                }
            ),

            new Ext.Panel({
                region:'east',
                width: 200,
            }),
     ]
    });

    //vp.on('afterlayout', Ext.getCmp('pdf_viewer').onLayout, Ext.getCmp('pdf_viewer'));
    //vp.on('render', function(){alert('inhere')}, Ext.getCmp('pdf_viewer'));

    win=new Paperpile.FileChooser({
        currentRoot:'ROOT/home/wash',
        showFilter: true,
        filterOptions:[{text: 'PDF documents (.pdf)',
                        suffix: ['pdf'],
                       },
                       {text: 'All files',
                        suffix:['ALL'],
                       },
                      ],
        //saveMode: true,
        //saveDefault: 'new-file.dat',
        callback:function(button,path){
            if (button == 'OK'){
                var viewer=Ext.getCmp('pdf_viewer');
                //console.log(path);
                viewer.initPDF(path);
                vp.show();
            }
        }
    });

    win.show();


})