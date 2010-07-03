Paperpile.NewFeedWindow = function(config) {
  Ext.apply(this, config);
  Paperpile.NewFeedWindow.superclass.constructor.call(this, config);
};

Ext.extend(Paperpile.NewFeedWindow, Ext.Window, {

  initComponent: function() {

    // Create the manual entry text box.
    this.manualEntryTextBox = new Ext.form.TextField({
      emptyText: 'Paste your RSS URL here.',
      itemId: 'manual_entry',
      fieldLabel: 'Load RSS feed',
      value: '',
      width: 300
    });

    // Dummy store for RSS feed 'search'...
    this.dummyFeedStore = new Ext.data.ArrayStore({
      id: 'name',
      fields: [
        'name',
        'url'],
      data: [
        ['Science', 'http://www.sciencemag.org/asdf.xml'],
        ['Nature', 'http://www.nature.com/asdf.xml']]
    });

    this.remoteFeedStore = new Ext.data.JsonStore({
      autoDestroy: true,
      storeId: 'rssFeedStore',
      url: Paperpile.Url('/ajax/misc/feed_list'),
      method: 'GET',
      root: 'feeds',
      idProperty: 'name',
      fields: [
        'name',
        'url']
    });

    this.remoteFeedCombobox = new Ext.form.ComboBox({
      fieldLabel: 'Find a Journal Feed',
      emptyText: 'Start typing to search',
      width: 300,
      itemId: 'remote_feed_combo',
      store: this.remoteFeedStore,
      loadingText: 'Searching the RSS library...',
      listEmptyText: 'No feeds found!',
      mode: 'remote',
      displayField: 'name',
      valueField: 'url',
      forceSelection: true,
      //      typeAhead: true,
      tpl: ['<tpl for="."><div class="x-combo-list-item">',
        '<div style="font-weight:bold;" ext:qtip="Feed URL: {url}">{name}</div>',
        //        '<div style="color:gray;font-style:italic;">{url}</div>',
        '</div></tpl>'].join(''),
      pageSize: 10
    });

    this.panel = new Ext.form.FormPanel({
      labelAlign: 'top',
      frame: true,
      bodyStyle: 'padding:10px 10px 0',
      cls: 'pp-feed-chooser',
      defaults: {},
      items: [
        this.manualEntryTextBox, {
          xtype: 'label',
          text: '- or -',
          height: 100,
          width: '100%'
        },
        this.remoteFeedCombobox],
      buttons: [{
        text: 'Cancel',
        itemId: 'cancel_button',
        cls: 'x-btn-text-icon cancel',
        handler: this.onCancelButton,
        scope: this
      },
      {
        text: 'Ok',
        itemId: 'ok_button',
        cls: 'x-btn-text-icon ok',
        handler: this.onOkButton,
        scope: this
      }]
    });

    Ext.apply(this, {
      title: 'New RSS Feed',
      width: 500,
      height: 250,
      plain: true,
      modal: true,
      layout: 'fit',
      items: this.panel
    });

    Paperpile.NewFeedWindow.superclass.initComponent.call(this);

    this.on('afterrender', this.myOnRender, this);
  },

  myOnRender: function() {
    this.panel.items.each(function(item, index, length) {
      item.on('focus', this.onFocus, this, [item]);
    },
    this);

    // Swallow key events so the grid doesn't take em
    // (i.e. ctrl-A, ctrl-C etc)
//    this.getEl().swallowEvent(['keypress', 'keydown']);

  },
  onFocus: function(field) {
    this.panel.getEl().select('.x-form-item').removeClass("active");
    var f = field.el.findParent('.x-form-item', 5, true);
    if (f !== undefined) {
      f.addClass("active");
    }
  },

  getFeedUrl: function() {
    if (this.manualEntryTextBox.getValue() != '') {
      return this.manualEntryTextBox.getValue();
    } else if (this.remoteFeedCombobox.getValue() != '') {
      return this.remoteFeedCombobox.getValue();
    } else return '';
  },

  onOkButton: function() {
    this.hide(); // Hide but keep UI elements (so we can get the value from the DOM).
    var url = this.getFeedUrl();
    Paperpile.main.tree.createNewFeedNode(url);

    this.close(); // Dispose of UI elements.
  },

  onCancelButton: function() {
    this.close();
  }

});