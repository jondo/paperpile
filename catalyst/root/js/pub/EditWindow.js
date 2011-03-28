Ext.define('Paperpile.pub.EditWindow', {
  extend: 'Ext.Window',
  alias: 'widget.editwindow',
  // config options.
  isNew: false,
  pub: undefined,
  // end config options.
  initComponent: function() {
    var me = this;
    var isNew = this.isNew;
    this.form = this.createForm();

    Ext.apply(this, {
      title: isNew ? 'Add new reference' : 'Edit reference',
      modal: true,
      shadow: false,
      layout: 'fit',
      plain: true,
      bodyPadding: 5,
      width: 700,
      height: 500,
      minWidth: 400,
      minHeight: 300,
      resizable: true,
      closable: true,
      items: [this.form]
    });

    /*
      var window = me.ownerCt;
      window.on('show', function() {
        Ext.getCmp('title-input').focus(false, 10);
      },
      me);

    // TODO: Move this to a proper spot for handling the 'veiw pdf' button...
    if (Ext.get('pdf-view-button')) {
      this.mon(Ext.get('pdf-view-button'), 'click', function() {
        var path;

        // Set path depending on wheter PDF was already imported or not
        if (this.data.guid) {
          path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, this.data.pdf_name);
        } else {
          path = this.data._pdf_tmp;
        }
        Paperpile.utils.openFile(path);
      },
      this);
    }

    */


    this.callParent(arguments);
  },

  createForm: function() {
    var me = this;
    var form = Ext.createByAlias('widget.editform', {
      region: 'center',
      isNew: this.isNew,
      callback: function(status, data) {
        Paperpile.log(status);
        Paperpile.log(data);
        me.close();
      },
    })
    return form;
  },

  setPublication: function(pub) {
    this.pub = pub;
    this.form.setPublication(pub);
  }
});