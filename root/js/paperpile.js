Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('PaperPile');

Ext.onReady(function() {
 
    Ext.QuickTips.init();
    
    var grid = new PaperPile.ResultsGrid();

    var tabs=new Ext.TabPanel({
        title: 'Inner Main',
        region:'center',
        xtype:'resultsgrid',
        height: 600,
        border: false,
        activeTab      : 0,
        border         : false,
        items: [{
            title: 'File',
            xtype:'resultsgrid',
            height: 600,
            border: false
        }]
    });
    
    var innerPanel = new Ext.Panel({
 				layout:'border',
        region:'center',
        margins: '2 2 2 2',
        items: [tabs,
                {region:'south',
                 height: 200,
                 border: false
                }]
    })

    var vp=new Ext.Viewport({
        layout: 'border',
        title: 'Ext Layout Browser',
        items: [{
            title: 'West Panel',
            region:'west',
            margins: '2 2 2 2',
            cmargins: '5 5 0 5',
            width: 200,
            minSize: 100,
            maxSize: 300
        },{
            title: 'East Panel',
            region:'east',
            margins: '2 2 2 2',
            cmargins: '5 5 0 5',
            width: 600,
            minSize: 100,
            maxSize: 800
        }, innerPanel],
        renderTo: Ext.getBody()
    });

    vp.show();
 
});
