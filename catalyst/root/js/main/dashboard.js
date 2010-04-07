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


Paperpile.Dashboard = Ext.extend(Ext.Panel, {

  title: 'Dashboard',
  iconCls: 'pp-icon-dashboard',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoLoad: {
        url: Paperpile.Url('/screens/dashboard'),
        callback: this.setupFields,
        scope: this
      },

    });

    Paperpile.PatternSettings.superclass.initComponent.call(this);

  },

  setupFields: function() {

    var el = Ext.get('dashboard-last-imported');

    Ext.DomHelper.overwrite(el, Paperpile.utils.prettyDate(el.dom.innerHTML));

    this.body.on('click', function(e, el, o) {

      switch (el.getAttribute('action')) {

      case 'statistics':
        Paperpile.main.tabs.newScreenTab('Statistics');
        break;
      case 'settings-patterns':
        Paperpile.main.tabs.newScreenTab('PatternSettings');
        break;
      case 'settings-general':
        Paperpile.main.tabs.newScreenTab('GeneralSettings');
        break;
      case 'duplicates':
        Paperpile.main.tabs.newPluginTab('Duplicates', {},
          "Duplicates", "pp-icon-folder", "duplicates")
        break;
      case 'catalyst':
        Paperpile.main.tabs.newScreenTab('CatalystLog', 'catalyst-log');
        break;
      case 'updates':
        Paperpile.main.checkForUpdates(false);
        break;
      }
    },
    this, {
      delegate: 'a'
    });

  },
});