Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('PaperPile');

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
            
            new PaperPile.PDFviewer(
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
    //var viewer=Ext.getCmp('pdf_viewer');
    //viewer.initPDF('/home/wash/PDFs/gesell06.pdf');
    //vp.show();

    var treepanel = new Ext.ux.FileTreePanel({
		height:400,
		autoWidth:true,
		title:'FileTreePanel',
		rootPath:'root',
        rootText: '/',
		topMenu:true,
		autoScroll:true,
		enableProgress:false,
        url:'/ajax/files/dialogue',
	});

    var win=new Ext.Window({
        layout: 'fit',
        width: 500,
        height: 300,
        closeAction:'hide',
        plain: true,
        items: [treepanel],
	});
    win.show();


})