Ext.define('Paperpile.pub.EditWindow', {
  extend: 'Ext.Window',
  alias: 'widget.pubedit',
  initComponent: function() {

    var me = this;
    var isNew = this.isNew;
    this.form = this.createForm();

    Ext.apply(this, {
      title: isNew ? 'Add new reference' : 'Edit reference',
      modal: true,
      shadow: false,
      layout: 'fit',
      width: 800,
      height: 600,
      resizable: false,
      closable: true,
      items: [this.form]
    });

    this.callParent(arguments);
  },

  createForm: function() {
    var me = this;
    return new Paperpile.pub.EditForm({
      isNew: isNew,
      callback: function(status, data) {
        Paperpile.log(status);
        Paperpile.log(data);
        me.close();
      },
    })
  }
});