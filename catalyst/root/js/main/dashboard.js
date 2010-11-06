/* Copyright 2009, 2010 Paperpile

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

Paperpile.Dashboard = Ext.extend(Ext.Panel, {

  title: 'Dashboard',
  iconCls: 'pp-icon-dashboard',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoScroll: true,
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
        Paperpile.main.tabs.newScreenTab('Statistics','statistics_tab');
        break;
      case 'settings-patterns':
        Paperpile.main.tabs.newScreenTab('PatternSettings','pattern_settings_tab');
        break;
      case 'settings-general':
        Paperpile.main.tabs.newScreenTab('GeneralSettings','general_settings_tab');
        break;
      case 'settings-tex':
        Paperpile.main.tabs.newScreenTab('TexSettings','tex_settings_tab');
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
      case 'feedback':
        Paperpile.main.userVoice();
        break;
      }
    },
    this, {
      delegate: 'a'
    });

    var settings = Paperpile.main.globalSettings['bibtex'];

    var field = new Ext.form.Checkbox({
      cls: 'pp-bibtex-checkbox-check',
      checked: settings.bibtex_mode === '1' ? true : false,
      label: '',
      checkedLabel: '<a href="#" class="pp-textlink" action="settings-tex" >Bibtex Settings</a>',
      uncheckedLabel: '<span id="bibtex-mode-text-inactive" class="pp-inactive">BibTeX mode inactivated</span>',
      hideLabel: true
    });

    var panel = new Ext.Panel({
	cls: 'pp-bibtex-checkbox',
	border: false,
	hideLabels:true,
	layout:'form',
	renderTo: 'bibtex-mode-checkbox',
	items: [field]
    });

    if (settings.bibtex_mode === '1') {
	field.wrap.child('.x-form-cb-label').update(field.checkedLabel);
    } else {
	field.wrap.child('.x-form-cb-label').update(field.uncheckedLabel);
    }

    field.on('check',
      function(box, checked) {
        var currentSettings = Paperpile.main.getSetting('bibtex');

        // If the checkbox is focused this looks strange in Webkit, so
        // we unfocus it
        box.blur();

        var value = (checked) ? "1" : "0";

        currentSettings['bibtex_mode'] = value;

        Paperpile.main.setSetting('bibtex', currentSettings);
        Paperpile.status.updateMsg({
          msg: (checked) ? 'BibTeX mode active: advanced BibTeX functions are now available' : 
            'BibTeX mode inactive: advanced BibTeX functions have been disabled',
          duration: 5
        });

    if (checked) {
	field.wrap.child('.x-form-cb-label').update(field.checkedLabel);
    } else {
	field.wrap.child('.x-form-cb-label').update(field.uncheckedLabel);
    }

      },
      this);

  },

});