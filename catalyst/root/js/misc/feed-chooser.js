Paperpile.NewFeedPanel = Ext.extend(Ext.form.FormPanel, {
  initComponent: function() {
    var cb = this.callback;

    this.addButton = new Ext.Button({
      text: 'Add',
      cls: 'x-btn-text',
      handler: Ext.emptyFn
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

    this.entryField = new Ext.form.ComboBox({
      hideLabel: true,
      itemId: 'remote_feed_combo',
      store: this.remoteFeedStore,
      minChars:2,
      maxHeight: 200,
      loadingText: '',
      listEmptyText: '',
      mode: 'remote',
      displayField: 'name',
      valueField: 'url',
      forceSelection: false,
      lazyRender: true,
      tpl: ['<tpl for="."><div class="x-combo-list-item">',
        '<div style="">{name}</div>',
        '</div></tpl>'].join('')
    });

    Ext.apply(this, {
      floating: true,
      frame: true,
      defaultType: 'label',
      bodyStyle: 'font-size:9px;padding:5px;',
      header: false,
      width: 300,
      renderTo: document.body,
      style: {
        padding: '5px'
      },
      items: [{
        xtype: 'label',
        text: 'Begin typing to find a journal or paste a feed url'
      },
      {
        xtype: 'compositefield',
        hideLabel: true,
        style: {
          'margin-top': '5px',
          'margin-bottom': '5px'
        },
        items: [
          this.entryField, {
            xtype: 'button',
            text: 'Add',
            width: '35px',
            handler: this.addFeed,
            scope: this
          }]
      },
      {
        xtype: 'label',
        text: 'e.g., http://www.pnas.org/rss/current.xml or PLoS One'
      }]
    });

    Paperpile.NewFeedPanel.superclass.initComponent.call(this);

    Ext.apply(this, {
      callback: cb
    });

    this.on('show', function(panel) {
      this.entryField.focus();
    },
    this);
    this.on('hide', function(panel) {
      this.entryField.setValue('');
    },
    this);
    this.on('render', function(panel) {
      this.myAfterRender();
    },
    this, {
      single: true
    });
  },

  addFeed: function() {
    var url = this.entryField.getValue();
    if (url == '') {
      url = this.entryField.el.dom.value;
    }
    this.callback(url);
    this.onCancel();
  },

  myAfterRender: function() {
    this.keys = new Ext.KeyMap(this.getEl(), [{
      key: Ext.EventObject.ESC,
      fn: this.onCancel,
      scope: this
    },
    {
      key: Ext.EventObject.ENTER,
      fn: this.addFeed,
      scope: this
    }]);
    this.entryField.on('select', this.addFeed, this);
  },

  onCancel: function() {
    this.hide();
    this.entryField.setValue('');
  }
});