Paperpile.Statistics = Ext.extend(Ext.Panel, {

    title: 'Statistics',
    iconCls: 'pp-icon-statistics',

    markup: [
        '<div class="pp-box-tabs">',
        '<div class="pp-box pp-box-top pp-box-style1" style="height:450px; width:600px; max-width:600px; padding:20px;">',
        '<div class="pp-container-centered">',
        '<div id="container" style="display: table-cell;vertical-align: middle;">',
        '<p>INHERE</p>',
        '</div>',
        '</div>',
        '</div>',

        '<ul id="stats-tabs">',
        '<li class="pp-box-tabs-leftmost pp-box-tabs-active">',
        '<a href="#" class="pp-textlink pp-bullet" action="top_authors">Top authors</a>',
        '</li>',

        '<li class="pp-box-tabs-leftmost">',
        '<a href="#" class="pp-textlink pp-bullet" action="top_journals">Top journals</a>',
        '</li>',
        
        '<li class="pp-box-tabs-leftmost">',
        '<a href="#" class="pp-textlink pp-bullet" action="pubtypes">Publication types</a>',
        '</li>',
        '</ul>',

        '</div>'
    ],

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoScroll:true,
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

        this.tpl = new Ext.XTemplate(this.markup);

    },

    afterRender: function() {
        Paperpile.Statistics.superclass.afterRender.apply(this, arguments);

        this.tpl.overwrite(this.body, {id:this.id}, true);


        Ext.get('stats-tabs').on('click', function(e, el, o){

            var action=el.getAttribute('action');

            if (!action) return;


            Ext.select('#stats-tabs li', true, 'stats-tab').removeClass('pp-box-tabs-active');

            Ext.get(el).parent('li').addClass('pp-box-tabs-active');

            console.log(action);

        });


        //swfobject.embedSWF(
        //    Paperpile.Url("/flashchart/open-flash-chart.swf"), "container", "550", "300",
        //    "9.0.0", "/expressInstall.swf",
        //    {"data-file":"/ajax/charts/test"}
        //);

        


        
    }
});
