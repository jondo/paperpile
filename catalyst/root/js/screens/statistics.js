Paperpile.Statistics = Ext.extend(Ext.Panel, {

    title: 'Statistics',
    iconCls: 'pp-icon-statistics',

    markup: [
        '<div class="pp-chart-box pp-box-style1">',
        '<div id="container">',
        '<p>INHERE</p>',
        '</div>',
        '</div>'
    ],

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

        this.tpl = new Ext.XTemplate(this.markup);

    },

    afterRender: function() {
        Paperpile.Statistics.superclass.afterRender.apply(this, arguments);

        this.tpl.overwrite(this.body, {id:this.id}, true);

        swfobject.embedSWF(
            Paperpile.Url("/flashchart/open-flash-chart.swf"), "container", "550", "300",
            "9.0.0", "/expressInstall.swf",
            {"data-file":"/ajax/charts/test"}
        );


        
    }
});
