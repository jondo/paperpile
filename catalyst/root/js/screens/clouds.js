Paperpile.Clouds = Ext.extend(Ext.Panel, {

    title: 'Clouds',
    iconCls: 'pp-icon-clouds',

    field:'authors',
    sort:'alphabetical',

    markup: [
//        '<table><tr valign="top"><td width="120px">',
      '<div style="padding: 5px;">',
      '<div class="pp-box-tabs pp-box-tabs-left">',
  	  '<ul id="stats-tabs">',
            '<li class="pp-bullet pp-box-tabs-first pp-box-tabs-active" action="show_authors">Authors</li>',
            '<li class="pp-bullet" action="show_journals">Journals</li>',
            '<li class="pp-bullet" action="show_tags">Labels</li>',
            '</li>',
          '</ul>',
	'</td><td>',
      '</div>',

      '<div class="pp-box pp-box-style1" id="pp-cloud-checkbox">',
	'<p>Sort By:</p>',
	'<ul id="stats-options" class="pp-cloud-options">',
	'<li class="pp-cloud-options-active" action="sort_alphabetical">Alphabetical</li>',
	'<li action="sort_count">Paper Count</li>',
	'</ul>',
      '</div>',

      '<div class="pp-box-right">',
	'<div class="pp-box pp-box-right pp-box-style1" style="padding:20px; min-height: 200px; max-width:600px;">',
	  '<div class="pp-container-centered">',
	    '<div id="container" style="display: table-cell;vertical-align: middle;">',
	      '<div id="cloud"></div>',
	    '</div>',
	  '</div>',
	'</div>',
      '</div>',
      '</div>'
    ],

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoScroll:true,
        });

      this.field = Paperpile.main.globalSettings['cloud_field'] || 'authors';
      this.sort = Paperpile.main.globalSettings['cloud_sorting'] || 'alphabetical';
		
      Paperpile.PatternSettings.superclass.initComponent.call(this);
      this.tpl = new Ext.XTemplate(this.markup);
    },

    afterRender: function() {
        Paperpile.Statistics.superclass.afterRender.apply(this, arguments);

        this.tpl.overwrite(this.body, {id:this.id}, true);

        Ext.get('cloud').on('click', function(e, el, o){
            var key = el.getAttribute('key');
	    var iconCls = '';
	    var title = '';
            if (!key) return;

            var pars= { plugin_mode: 'FULLTEXT'};
	    pars.plugin_title = key;
            if (this.field == 'authors'){
              pars.plugin_query = 'author:'+'"'+key+'"';
            }
            if (this.field == 'journals'){
              pars.plugin_query = 'journal:'+'"'+key+'"';
            }
            if (this.field == 'tags'){
	      // A little customized for tags. This stuff copied from tree.jsn
	      pars.plugin_query = 'labelid:'+Paperpile.utils.encodeTag(key);
	      var style_num = el.getAttribute('style_number');
	      iconCls = 'pp-tag-style-tab pp-tag-style-'+style_num;
            }

            pars.plugin_base_query= pars.plugin_query;
            Paperpile.main.tabs.newPluginTab('DB', pars, title, iconCls, key);
        }, this);

	var fn = function(e, el, o){
	  var action=el.getAttribute('action');
	  console.log(action);
          if (!action) return;

	  if (action.indexOf('sort') > -1) {
	    this.sort = action.split('_')[1];
	  } else if (action.indexOf('show') > -1) {
	    this.field = action.split('_')[1];
	  }
	  this.updateClouds();
	  this.updateSettings();
        };
	Ext.get('stats-tabs').on('click',fn, this);
	Ext.get('stats-options').on('click',fn, this);

      this.updateClouds();
    },

    updateSettings: function() {
      var params = {
	cloud_sorting:this.sort,
	cloud_field:this.field
      };
      Ext.Ajax.request({
	url: Paperpile.Url('/ajax/settings/set_settings'),
	params: params,
	success: function(response){
          Paperpile.main.loadSettings(
            function(){
              Paperpile.status.clearMsg();
            }, this
          );
        },
	failure: Paperpile.main.onError,
	scope:this
      });
    },

    updateClouds: function(){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/charts/clouds'),
            params: {field: this.field,
		    sorting: this.sort},
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);

		Ext.select('#stats-tabs li', true).removeClass('pp-box-tabs-active');
		Ext.select('[action=show_'+this.field+']').addClass('pp-box-tabs-active');
		Ext.select('.pp-cloud-options li').removeClass('pp-cloud-options-active');
		Ext.select('[action=sort_'+this.sort+']').addClass('pp-cloud-options-active');

                Ext.DomHelper.overwrite('cloud','');
                Ext.DomHelper.insertHtml('afterBegin',Ext.get('cloud').dom, json.html);
            },
            failure: Paperpile.main.onError,
            scope:this,
        });
    }



});
