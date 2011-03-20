Ext.define('Paperpile.pub.PubPanel', {
  extend: 'Ext.Component',
  statics: {
    smallTextLinkTpl: function() {
      if (!this._smallTextlinkTpl) {
        this._smallTextLinkTpl = new Ext.XTemplate(
          '<a',
          ' class="pp-action pp-textlink pp-smalltextlink"',
          ' action="{action}"',
          '<tpl if="args">args="{args}"</tpl>',
          '<tpl if="tooltip">ext:qtip="{tooltip}"</tpl>',
          '>',
          '<tpl if="icon">',
          '  <img src="{icon}"/>',
          '</tpl>',
          '{text}',
          '</a>').compile();
      }
      return this._smallTextLinkTpl;
    },
    textLinkTpl: function() {
      if (!this._textlinkTpl) {
        this._textLinkTpl = new Ext.XTemplate(
          '<a',
          ' class="pp-action pp-textlink"',
          ' action="{action}"',
          '<tpl if="args">args="{args}"</tpl>',
          '<tpl if="tooltip">ext:qtip="{tooltip}"</tpl>',
          '>',
          '<tpl if="icon">',
          '  <img src="{icon}"/>',
          '</tpl>',
          '{text}',
          '</a>').compile();
      }
      return this._textLinkTpl;
    },
    hoverButtonTpl: function() {
      if (!this._hoverButtonTpl) {
        this._hoverButtonTpl = new Ext.XTemplate(
          '<a',
          ' class="pp-action pp-hoverbutton"',
          ' action="{action}"',
          '<tpl if="args">args="{args}"</tpl>',
          '<tpl if="tooltip">pp:tip="{tooltip}"</tpl>',
          '>{text}</a>').compile();
      }
      return this._textLinkTpl;
    },
    iconButtonTemplate: function() {

    },
    buttonTemplate: function() {

    },
    actionData: function(id, args, text, icon, tooltip, iconCls) {
      var action = Paperpile.app.Actions.get(id);
      if (action) {
        var cfg = {
          text: text,
          tooltip: tooltip,
          icon: icon,
          iconCls: iconCls
        };
        var tooltip = cfg.tooltip || action.initialConfig.tooltip || '';
        var iconCls = cfg.iconCls || action.initialConfig.iconCls || '';
        var icon = cfg.icon || action.initialConfig.icon || '';
        var text = cfg.text || action.initialConfig.text || id;
        var data = {
          action: id,
          tooltip: tooltip,
          iconCls: iconCls,
          icon: icon,
          text: text,
          args: args
        };
        return data;
      } else {
        Paperpile.log("Can't create text link for action " + id);
        return {
          action: undefined,
          tooltip: tooltip,
          text: id + " NOT FOUND",
          args: args
        };
      }
    },
    actionTextLink: function(id, text, tooltip, args) {
      var str = this.textLinkTpl().apply(this.actionData(id, text, tooltip, args));
      return str;
    },
    smallTextLink: function(id, text, tooltip, args) {
      var str = this.smallTextLinkTpl().apply(this.actionData(id, text, tooltip, args));
      return str;
    },
    hoverButton: function(id, text, tooltip, args) {
      var str = this.hoverButtonTpl().apply(this.actionData(id, text, tooltip, args));
      return str;
    }

  },
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