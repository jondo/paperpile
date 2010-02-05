Paperpile.PdfExtractView = function(config) {
  Ext.apply(this, config);

  Paperpile.PdfExtractView.superclass.constructor.call(this, {});
};

Ext.extend(Paperpile.PdfExtractView, Ext.Panel, {

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      layout: 'border',
      hideBorders: true,
      items: [{
        xtype: 'panel',
        region: 'center',
        split: true,
        itemId: 'center_panel',
        layout: 'border',
        items: [
          new Paperpile.PdfExtractGrid({
            itemId: 'grid',
            path: this.path
          }), {
            border: false,
            split: true,
            xtype: 'panel',
            itemId: 'pdf_preview',
            activeItem: 0,
            height: 200,
            region: 'south'
          }]
      },
      {
        region: 'east',
        itemId: 'east_panel',
        split: true,
        width: 300,
        activeItem: 0,
        layout: 'card',
        items: [
          new Paperpile.PdfExtractControl({
            region: 'center',
            itemId: 'control_panel'
          })]
      }]
    });

    Paperpile.PdfExtractView.superclass.initComponent.call(this);

    this.on('render', this.myOnRender, this);
  },

  onRowSelect: function(sm, rowIdx, r) {

  },

  myOnRender: function() {
    alert("Render!");
  }
});