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

Paperpile.GeneralSettings = Ext.extend(Ext.Panel, {

  title: 'General settings',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoLoad: {
        url: Paperpile.Url('/screens/settings'),
        callback: this.setupFields,
        scope: this
      },
      bodyStyle: 'pp-settings',
      autoScroll: true,
      iconCls: 'pp-icon-tools'
    });

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.isDirty = false;

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
          this.isDirty = true;
          this.setSaveDisabled(false);
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
      width: 60,
      store: [10, 25, 50, 75, 100],
      value: Paperpile.main.globalSettings['pager_limit'],
    });

    this.combos['pager_limit'].on('select',
      function() {
        this.isDirty = true;
        this.setSaveDisabled(false);
      },
      this);

    this.proxyCheckbox = new Ext.form.Checkbox({
      renderTo: 'proxy_checkbox'
    });

    this.proxyCheckbox.on('check',
      function(box, checked) {
        this.onToggleProxy(box, checked);
        this.isDirty = true;
        this.setSaveDisabled(false);
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
        var transactionID = Ext.Ajax.request({
          url: Paperpile.Url('/ajax/misc/test_network'),
          params: params,
          success: function(response) {

            var error;

            if (response.responseText) {
              error = Ext.util.JSON.decode(response.responseText).error;
            }

            if (error) {
              Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
              Paperpile.main.onError(response);
            } else {
              Ext.get('proxy_test_status').replaceClass('pp-icon-cross', 'pp-icon-tick');
              Paperpile.status.clearMsg();
              Paperpile.status.updateMsg({
                msg: 'Your network connection is working correctly.',
                hideOnClick: true
              });
            }

          },
          failure: function(response) {
            Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
            Paperpile.main.onError(response);
          }
        });

        Paperpile.status.updateMsg({
          busy: true,
          msg: 'Testing network connection.',
          action1: 'Cancel',
          callback: function() {
            Ext.Ajax.abort(transactionID);
            Paperpile.status.clearMsg();
            Ext.Ajax.request({
              url: Paperpile.Url('/ajax/misc/cancel_request'),
              params: {
                cancel_handle: 'proxy_check',
                kill:1,
              },
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

    this.setSaveDisabled(true);
  },

  onToggleProxy: function(box, checked) {
    this.textfields['proxy'].setDisabled(!checked);
    this.textfields['proxy_user'].setDisabled(!checked);
    this.textfields['proxy_passwd'].setDisabled(!checked);

    if (checked) {
      Ext.select('h2,h3', true, 'proxy-container').removeClass('pp-label-inactive');
    } else {
      Ext.select('h2,h3', true, 'proxy-container').addClass('pp-label-inactive');
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
    Paperpile.log(this.pluginOrderPanel.getValue());
    var params = {
      use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
      proxy: this.textfields['proxy'].getValue(),
      proxy_user: this.textfields['proxy_user'].getValue(),
      proxy_passwd: this.textfields['proxy_passwd'].getValue(),
      pager_limit: this.combos['pager_limit'].getValue(),
      search_seq: this.pluginOrderPanel.getValue()
    };

    for (var field in params){
      params[field]=Ext.encode(params[field]);
    }

    Paperpile.status.showBusy('Applying changes.');

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/settings/set_settings'),
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

        Paperpile.main.loadSettings(
          function() {
            Paperpile.status.clearMsg();
          },
          this);
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  }

});