Paperpile.Clouds = Ext.extend(Ext.Panel, {

    title: 'Clouds',
    iconCls: 'pp-icon-clouds',

    markup: [
        '<div class="pp-box-tabs">',
        '<div class="pp-box pp-box-top pp-box-style1" style="padding:20px; min-height: 200px; max-width:600px;">',
        '<div class="pp-container-centered">',
        '<div id="container" style="display: table-cell;vertical-align: middle;">',
        '<div id="cloud"></div>',
        '</div>',
        '</div>',
        '</div>',

        '<ul id="stats-tabs">',
        '<li class="pp-box-tabs-leftmost pp-box-tabs-active">',
        '<a href="#" class="pp-textlink pp-bullet" action="authors">Authors</a>',
        '</li>',

        '<li class="pp-box-tabs-leftmost">',
        '<a href="#" class="pp-textlink pp-bullet" action="journal">Journals</a>',
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

        Ext.get('cloud').on('click', function(e, el, o){

            var key = el.getAttribute('key');
            if (!key) return;

            var pars= { plugin_mode: 'FULLTEXT'};

            if (this.field == 'authors'){
                pars.plugin_query = 'author:'+'"'+key+'"';
            }

            if (this.field == 'journal'){
                pars.plugin_query = 'journal:'+'"'+key+'"';
            }

            pars.plugin_base_query= pars.plugin_query;
           
            Paperpile.main.tabs.newPluginTab('DB', pars, key);


        }, this);

      
        Ext.get('stats-tabs').on('click', function(e, el, o){

            var action=el.getAttribute('action');
            if (!action) return;

            this.field=action;

            Ext.select('#stats-tabs li', true, 'stats-tab').removeClass('pp-box-tabs-active');

            Ext.get(el).parent('li').addClass('pp-box-tabs-active');

            this.updateClouds(action);
            
        }, this);

        this.field='authors';

        this.updateClouds(this.field);

    },

    updateClouds: function(field){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/charts/clouds'),
            params: {field: field}, 
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                Ext.DomHelper.overwrite('cloud','');
                Ext.DomHelper.insertHtml('afterBegin',Ext.get('cloud').dom, json.html);
            },
            failure: Paperpile.main.onError,
            scope:this,
        });
    }



});
