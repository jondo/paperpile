/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */

Paperpile.Clouds = Ext.extend(Ext.Panel, {

  title: 'Clouds',
  iconCls: 'pp-icon-clouds',
  field: 'authors',
  sort: 'alphabetical',

  markup: [
    '<div style="padding: 5px;">',
    '  <div class="pp-box-tabs pp-box-tabs-left">',
    '   <ul id="stats-tabs">',
    '     <li class="pp-bullet pp-box-tabs-first pp-box-tabs-active" action="show_authors">Authors</li>',
    '     <li class="pp-bullet" action="show_journals">Journals</li>',
    '     <li class="pp-bullet" action="show_tags">Labels</li>',
    '     </li>',
    '   </ul>',
    '</div>',

    '<div id="pp-cloud-checkbox">',
    '<p>Sort By:</p>',
    '<ul id="stats-options" class="pp-cloud-options">',
    '  <li ><a action="sort_alphabetical" href="#" class="pp-textlink">Alphabetical</a></li>',
    '  <li ><a action="sort_count" href="#" class="pp-textlink">Paper Count</a></li>',
    '</ul>',
    '</div>',

    '<div class="pp-box-right">',
    '  <div class="pp-box pp-box-right pp-box-style1" style="padding:20px; min-height: 200px; min-width:600px; max-width:600px;">',
    '  <div class="pp-container-centered">',
    '    <div id="container" style="display: table-cell;vertical-align: middle;">',
    '      <div id="cloud"></div>',
    '    </div>',
    '    </div>',
    '    </div>',
    '  </div>',
    '</div>'],

  initComponent: function() {
    Ext.apply(this, {
      bodyStyle: 'padding: 10px',
      closable: true,
      autoScroll: true,
    });

    this.field = Paperpile.main.globalSettings['cloud_field'] || 'authors';
    this.sort = Paperpile.main.globalSettings['cloud_sorting'] || 'alphabetical';
    this.tpl = new Ext.XTemplate(this.markup);

    Paperpile.Clouds.superclass.initComponent.call(this);
  },

  afterRender: function() {
    Paperpile.Clouds.superclass.afterRender.call(this);

    this.countTip = new Ext.ToolTip({
      //      maxWidth: 500,
      //      showDelay: 0,
      //      hideDelay: 0,
      target: this.getEl(),
      delegate: '.pp-cloud-item',
      renderTo: document.body,
      listeners: {
        beforeshow: {
          fn: function updateTipBody(tip) {
            var el = tip.triggerElement;
            var count = el.getAttribute("count");
            tip.body.dom.innerHTML = "Paper Count: <b>" + count + "</b>";
          },
          scope: this
        }
      }
    });

    this.updateClouds();

    this.tpl.overwrite(this.body, {
      id: this.id
    },
      true);

    Ext.get('cloud').on('click', function(e, el, o) {
      var key = el.getAttribute('key');
      var iconCls = '';
      var title = '';
      if (!key) return;

      var pars = {
        plugin_mode: 'FULLTEXT'
      };
      pars.plugin_title = key;
      title = key;

      if (this.field == 'authors') {
        pars.plugin_query = 'author:' + '"' + key + '"';
      }
      if (this.field == 'journals') {
        pars.plugin_query = 'journal:' + '"' + key + '"';
      }
      if (this.field == 'tags') {
        // A little customized for tags. This stuff copied from tree.jsn
        pars.plugin_query = 'labelid:' + Paperpile.utils.encodeTag(key);
        var style_num = el.getAttribute('style_number');
        iconCls = 'pp-tag-style-tab pp-tag-style-' + style_num;
      }

      pars.plugin_base_query = pars.plugin_query;
      Paperpile.main.tabs.newPluginTab('DB', pars, title, iconCls, key);
    },
    this);

    var fn = function(e, el, o) {
      var action = el.getAttribute('action');
      if (!action) return;

      if (action.indexOf('sort') > -1) {
        this.sort = action.split('_')[1];
      } else if (action.indexOf('show') > -1) {
        this.field = action.split('_')[1];
      }

      this.updateClouds();
      this.updateSettings();
    };
    Ext.get('stats-tabs').on('click', fn, this);
    Ext.get('stats-options').on('click', fn, this);
  },

  updateSettings: function() {
    var params = {
      cloud_sorting: this.sort,
      cloud_field: this.field
    };
    Paperpile.main.setSettings(params);
  },

  updateClouds: function() {

    Paperpile.Ajax({
      url: '/ajax/charts/clouds',
      params: {
        field: this.field,
        sorting: this.sort
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        Ext.select('#stats-tabs li', true).removeClass('pp-box-tabs-active');
        Ext.select('[action=show_' + this.field + ']').addClass('pp-box-tabs-active');

        var sortOptions = Ext.select('.pp-cloud-options li');
        sortOptions.removeClass('pp-cloud-options-active');
        sortOptions.each(function(el, c, index) {
          var anchor = el.down('a');
          if (anchor.getAttribute('action') == 'sort_' + this.sort) {
            el.addClass('pp-cloud-options-active');
          }
        },
        this);

        Ext.DomHelper.overwrite('cloud', '');
        Ext.DomHelper.insertHtml('afterBegin', Ext.get('cloud').dom, json.html);
      },
      scope: this
    });
  }

});