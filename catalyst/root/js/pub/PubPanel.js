Ext.define('Paperpile.pub.PubPanel', {
  extend: 'Ext.Component',
  initComponent: function() {

    this.createTemplates();

    Ext.apply(this, {
	    tpl: this.singleTpl,
      hideOnSingle: false,
      hideOnMulti: false,
      hideOnEmpty: true
    });

    this.callParent(arguments);
  },

  createTemplates: function() {
    this.singleTpl = new Ext.XTemplate();
    this.multiTpl = new Ext.XTemplate();
    this.emptyTpl = new Ext.XTemplate();
  },

  setSelection: function(selection) {
    this.selection = selection;
    if (selection.length == 1) {
      if (this.hideOnSingle) {
        this.hide();
      } else {
        this.show();
        var pub = selection[0];
        this.tpl = this.singleTpl;
        this.update(pub.data);
      }
    } else if (selection.length > 1) {
      if (this.hideOnMulti) {
        this.hide();
      } else {
        this.show();
        this.tpl = this.multiTpl;
        this.update(selection);
      }
    } else {
      if (this.hideOnEmpty) {
        this.hide();
      } else {
        this.show();
        this.tpl = this.emptyTpl;
        this.update({});
      }
    }
  },

  updateFromServer: function(data) {
    if (this.viewRequiresUpdate(this.data)) {
      this.setSelection(this.selection);
    }
  },

  viewRequiresUpdate: function(data) {
    var needsUpdate = false;
    Ext.each(this.selection, function(pub) {
      if (pub.dirty) {
        needsUpdate = true;
      }
    });
    return needsUpdate;
  }

});