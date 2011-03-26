Ext.define('Paperpile.app.CopyLinkHoverButtons', {
  extend: 'Ext.ux.HoverButtonGroup',
  alias: 'pp-hover-copylink',
  initComponent: function() {
    this.copy = new Ext.Component({
      html: Paperpile.pub.PubPanel.iconButton('HOVER_COPY')
    });
    this.link = new Ext.Component({
      html: Paperpile.pub.PubPanel.iconButton('HOVER_LINK')
    });

    Ext.apply(this, {
      cls: 'pp-hoverbuttons',
      items: [
	      this.link, this.copy],
      selectors: ['.pp-linkable', '.pp-copyable'],

    });

    this.copy.show();
    this.link.show();
    this.callParent(arguments);
  },

  showAtTarget: function(target) {
    var t = Ext.fly(target);
    if (t.hasCls('pp-linkable')) {
      this.link.show();
    } else {
      this.link.hide();
    }
    if (t.hasCls('pp-copyable')) {
      this.copy.show();
    } else {
      this.copy.hide();
    }

    this.callParent(arguments);
  },

});