Paperpile.NewFeedPanel = Ext.extend(Ext.form.FormPanel, {
  initComponent: function() {
    var cb = this.callback;

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
      minChars: 2,
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
      cls: 'pp-feed-chooser',
      floating: true,
      border: true,
      defaultType: 'label',
      width: 310,
      bodyStyle:'padding:10px;',
      style: {
      },
      renderTo: document.body,
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
        layoutConfig: {},
        defaults: {
          flex: 1
        },
        items: [
          this.entryField, {
            xtype: 'button',
            flex: 0,
            width: 35,
            text: 'Add',
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
      Ext.QuickTips.getQuickTip().hide();
      this.entryField.focus(false,30);
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

  show: function() {
    Paperpile.NewFeedPanel.superclass.show.call(this);
    Ext.getDoc().on("mousedown", this.onMouseDown, this);
  },

  hide: function() {
    Paperpile.NewFeedPanel.superclass.hide.call(this);
    Ext.getDoc().un("mousedown", this.onMouseDown, this);
  },

  onMouseDown: function(e) {
    if (e.getTarget(".pp-feed-chooser")) {
      return;
    } else if (e.getTarget(".pp-rss-button")) {
      return;
    } else {
      this.hide();
    }
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