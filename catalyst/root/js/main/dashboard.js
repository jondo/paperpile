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
        Paperpile.main.check_updates(false);
        break;
      }
    },
    this, {
      delegate: 'a'
    });

  },
});