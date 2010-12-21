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

Paperpile.GeneralSettings = Ext.extend(Ext.Panel, {

  title: 'General settings',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      layout: 'fit',
      items: [{
        xtype: 'panel',
        height: '100%',
        bodyStyle: 'pp-settings',
        autoScroll: true,
        iconCls: 'pp-icon-tools',
        autoLoad: {
          url: Paperpile.Url('/screens/settings'),
          callback: this.setupFields,
          scope: this
        }
      }]
    });

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.isDirty = false;

  },

  onSettingChange: function() {
    this.isDirty = true;
    this.setSaveDisabled(false);
  },

  //
  // Creates textfields, buttons and installs event handlers
  //
  setupFields: function() {

    Ext.form.VTypes["nonempty"] = /^.*$/;

    Ext.get('settings-cancel-button').on('click',
      function() {
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
      });

    this.textfields = {};
    this.combos = {};
    this.checkboxes = {};

    Ext.each(['proxy', 'proxy_user', 'proxy_passwd'],
    function(item) {
      var field = new Ext.form.TextField({
        value: Paperpile.main.globalSettings[item],
        enableKeyEvents: true,
        width: 220,
      });

      field.render(item + '_textfield', 0);

      this.textfields[item] = field;

      field.on('keypress',
        function() {
          this.onSettingChange();
        },
        this);

    },
    this);

    this.combos['pager_limit'] = new Ext.form.ComboBox({
      renderTo: 'pager_limit_combo',
      editable: false,
      forceSelection: true,
      triggerAction: 'all',
      disableKeyFilter: true,
      fieldLabel: 'Type',
      mode: 'local',
      width: 100,
      store: [10, 25, 50, 75, 100],
      value: Paperpile.main.globalSettings['pager_limit'],
    });

    this.combos['sort_field'] = new Ext.form.ComboBox({
      renderTo: 'sort_field_combo',
      editable: false,
      forceSelection: true,
      triggerAction: 'all',
      disableKeyFilter: true,
      fieldLabel: 'displayText',
      mode: 'local',
      width: 100,
      store: new Ext.data.ArrayStore({
        id: 0,
        fields: [
          'id',
          'displayText'],
        data: [
          ['created DESC', 'Date added'],
          ['year DESC', 'Year'],
          ['author', 'Author'],
          ['journal', 'Journal']]
      }),
      displayField: 'displayText',
      valueField: 'id',
      value: Paperpile.main.globalSettings['sort_field'],
    });

    this.combos['pager_limit'].on('select', this.onSettingChange, this);
    this.combos['sort_field'].on('select', this.onSettingChange, this);

    this.checkboxes['check_updates'] = new Ext.form.Checkbox({
      renderTo: 'check_updates_checkbox',
      checked: Paperpile.main.globalSettings['check_updates'] == '1' ? true : false,
    });

    this.checkboxes['check_updates'].on('check',
      function() {
        this.onSettingChange();
      },
      this);

    this.proxyCheckbox = new Ext.form.Checkbox({
      renderTo: 'proxy_checkbox'
    });

    this.proxyCheckbox.on('check',
      function(box, checked) {
        this.onToggleProxy(box, checked);
        this.onSettingChange();
      },
      this);

    if (Paperpile.main.globalSettings['use_proxy'] == "1") {
      this.proxyCheckbox.setValue(true);
      this.onToggleProxy(this.proxyCheckbox, true);
    } else {
      this.proxyCheckbox.setValue(false);
      this.onToggleProxy(this.proxyCheckbox, false);
    }

    this.proxyTestButton = new Ext.Button({
      text: "Test your network connection",
      renderTo: 'proxy_test_button'
    });

    this.proxyTestButton.on('click',
      function() {

        Ext.get('proxy_test_status').removeClass(['pp-icon-tick', 'pp-icon-cross']);

        var params = {
          use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
          proxy: this.textfields['proxy'].getValue(),
          proxy_user: this.textfields['proxy_user'].getValue(),
          proxy_passwd: this.textfields['proxy_passwd'].getValue(),
          cancel_handle: 'proxy_check',
        };
        var transactionID = Paperpile.Ajax({
          url: '/ajax/misc/test_network',
          params: params,
          success: function(response, options) {
            var error;
            if (response.responseText) {
              error = Ext.util.JSON.decode(response.responseText).error;
            }

            if (error) {
              Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
              Paperpile.main.onError(response, options);
            } else {
              Ext.get('proxy_test_status').replaceClass('pp-icon-cross', 'pp-icon-tick');
              Paperpile.status.clearMsg();
              Paperpile.status.updateMsg({
                msg: 'Your network connection is working correctly.',
                hideOnClick: true
              });
            }
          },
          failure: function(response, options) {
            Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
          }
        });

        Paperpile.status.updateMsg({
          busy: true,
          msg: 'Testing network connection.',
          action1: 'Cancel',
          callback: function() {
            Ext.Ajax.abort(transactionID);
            Paperpile.status.clearMsg();
            Paperpile.Ajax({
              url: '/ajax/misc/cancel_request',
              params: {
                cancel_handle: 'proxy_check',
                kill: 1
              }
            });
          }
        });
      },
      this);

    this.pluginOrderPanel = new Paperpile.PluginOrderPanel({
      renderTo: 'plugin_order_panel',
      settingsPanel: this
    });

    new Ext.ToolTip({
      target: 'settings-proxy-address-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'The address of the proxy server you want to use to access the internet',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    new Ext.ToolTip({
      target: 'settings-proxy-user-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'Currently not supported',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    new Ext.ToolTip({
      target: 'settings-proxy-pass-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'Currently not supported',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    new Ext.ToolTip({
      target: 'settings-pager-limit-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'The maximum number of references that are shown on one page in a tab.',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    new Ext.ToolTip({
      target: 'settings-zoom-level-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'The zoom level of the user interface. Increase the value if text appears too small.',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    new Ext.ToolTip({
      target: 'settings-sort-field-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'Default sort order of references in a new tab.',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    new Ext.ToolTip({
      target: 'settings-check-updates-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'Let Paperpile automatically check for updates online. During beta phase it is highly recommended to always update to the latest available version',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    this.setSaveDisabled(true);
  },

  onToggleProxy: function(box, checked) {
    this.textfields['proxy'].setDisabled(!checked);
    this.textfields['proxy_user'].setDisabled(!checked);
    this.textfields['proxy_passwd'].setDisabled(!checked);

    if (checked) {
      Ext.select('h2,h4', true, 'proxy-container').removeClass('pp-label-inactive');
    } else {
      Ext.select('h2,h4', true, 'proxy-container').addClass('pp-label-inactive');
    }
  },

  setSaveDisabled: function(disabled) {
    var button = Ext.get('settings-save-button');
    button.un('click', this.submit, this);
    if (disabled) {
      button.replaceClass('pp-save-button', 'pp-save-button-disabled');
    } else {
      button.replaceClass('pp-save-button-disabled', 'pp-save-button');
      button.on('click', this.submit, this);
    }
  },

  submit: function() {
    var params = {
      use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
      proxy: this.textfields['proxy'].getValue(),
      proxy_user: this.textfields['proxy_user'].getValue(),
      proxy_passwd: this.textfields['proxy_passwd'].getValue(),
      pager_limit: this.combos['pager_limit'].getValue(),
      sort_field: this.combos['sort_field'].getValue(),
      check_updates: this.checkboxes['check_updates'].getValue() ? 1 : 0,
      //      zoom_level: this.combos['zoom_level'].getValue(),
      search_seq: this.pluginOrderPanel.getValue()
    };

    for (var field in params) {
      params[field] = Ext.encode(params[field]);
    }

    Paperpile.status.showBusy('Applying changes.');

    Paperpile.Ajax({
      url: '/ajax/settings/set_settings',
      params: params,
      success: function(response) {

        // Update main DB tab with new pager limit. Other DB
        // plugins will use the new setting when they are newly opened.
        var new_pager_limit = this.combos['pager_limit'].getValue();
        if (new_pager_limit != Paperpile.main.globalSettings['pager_limit']) {

          var tabs = Paperpile.main.tabs.items.items;
          for (var i = 0; i < tabs.length; i++) {
            var tab = tabs[i];

            if (tab instanceof Paperpile.PluginPanel) {
              tab.getGrid().setPageSize(new_pager_limit);
            }
          }
        }
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);

        if (this.combos['zoom_level']) {
          var new_zoom_level = this.combos['zoom_level'].getValue();
          Paperpile.main.globalSettings['zoom_level'] = new_zoom_level;
          Paperpile.main.afterLoadSettings();
        }

        Paperpile.main.loadSettings(
          function() {
            Paperpile.status.clearMsg();
          },
          this);
      },
      scope: this
    });

  }

});