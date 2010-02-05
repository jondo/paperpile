Ext.ux.IFrameComponent = Ext.extend(Ext.BoxComponent, {
  onRender: function(ct, position) {
    this.el = ct.createChild({
      tag: 'iframe',
      id: 'iframe-' + this.id,
      frameBorder: 0,
      src: this.url
    });
  }
});

Paperpile.Browser = Ext.extend(Ext.Panel, {

  title: 'Browser',

  initComponent: function() {
    Ext.apply(this, {
      layout: 'fit',
      items: [new Ext.ux.IFrameComponent({
        id: this.id,
        url: 'http://google.com'
      })],
      tbar: [{
        xtype: 'button',
        text: 'Back',
        handler: this.back,
        scope: this,
      },
      {
        xtype: 'button',
        text: 'Reload',
        handler: this.reload,
        scope: this,
      },
      {
        xtype: 'button',
        text: 'Forward',
        handler: this.forward,
        scope: this,
      }],
      bbar: [{
        text: 'Test'
      }],

    });
    Paperpile.Browser.superclass.initComponent.call(this);

    this.on('afterlayout',
      function() {
        this.iframe = Ext.get('iframe-' + this.id).dom;
        this.xwindow = this.iframe.contentWindow || this.iframe.contentDocument;
        this.document = this.xwindow.document;
      },
      this);
  },

  reload: function() {
    this.xwindow.history.go(0);
  },

  forward: function() {
    this.xwindow.history.go(+1);
  },

  back: function() {
    this.xwindow.history.go(-1);
  }

});