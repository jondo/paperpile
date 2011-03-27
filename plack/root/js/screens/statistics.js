/* Copyright 2009-2011 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU Affero General Public License as
   published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Affero General Public License for more details.  You should have
   received a copy of the GNU Affero General Public License along with
   Paperpile.  If not, see http://www.gnu.org/licenses. */


Paperpile.Statistics = Ext.extend(Ext.Panel, {

  title: 'Statistics',
  iconCls: 'pp-icon-statistics',

  markup: [
    '<div class="pp-box-tabs">',
    '<div class="pp-box pp-box-top pp-box-style1" style="height:350px; width:600px; max-width:600px; padding:20px;">',
    '<div class="pp-container-centered">',
    '<div id="container" style="display: table-cell;vertical-align: middle;">',
    '<p>Could not find flash plugin.</p>',
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

    '</div>'],

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoScroll: true,
    });

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.tpl = new Ext.XTemplate(this.markup);

  },

  afterRender: function() {
    Paperpile.Statistics.superclass.afterRender.apply(this, arguments);

    this.tpl.overwrite(this.body, {
      id: this.id
    },
    true);

    Ext.get('stats-tabs').on('click', function(e, el, o) {

      var type = el.getAttribute('action');

      if (!type) return;

      Ext.select('#stats-tabs li', true, 'stats-tab').removeClass('pp-box-tabs-active');

      Ext.get(el).parent('li').addClass('pp-box-tabs-active');

      this.showFlash(type);
    },
    this);

    this.showFlash('top_authors');

  },

  showFlash: function(type) {

    Ext.DomHelper.overwrite(Ext.get('container'), {
      tag: 'iframe',
      src: 'http://localhost:3000/screens/flash_container?type=' + type,
      width: 600,
      height: 350,
      style: "border:none;"
    });

  }

});