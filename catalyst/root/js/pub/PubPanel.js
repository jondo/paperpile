Ext.define('Paperpile.pub.PubPanel', {
  extend: 'Ext.Component',
  initComponent: function() {

    this.createTemplates();

    Ext.apply(this, {
      cls: 'pp-pubpanel',
      tpl: this.singleTpl,
      hideOnSingle: false,
      hideOnMulti: false,
      hideOnEmpty: false
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
      // Convert selection items from Publication objects to the pub.data objects.
      var newSel = [];
      Ext.each(selection, function(pub) {
        newSel.push(pub.data);
      });
      selection = newSel;

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
    var me = this;
    var grid = me.up('pubview').grid;
    if (grid.isAllSelected()) {
      return true;
    }

    var needsUpdate = false;
    Ext.each(this.selection, function(pub) {
      if (pub.dirty) {
        needsUpdate = true;
      }
    });
    return needsUpdate;
  },

  statics: {
    linkTpl: function() {
      if (!this._genericTpl) {
        this._genericTpl = new Ext.XTemplate(
          '<div',
          ' class="pp-action pp-ellipsis {cls}"',
          ' action="{action}"',
          '<tpl if="args">args="{args}"</tpl>',
          '<tpl if="tooltip">ext:qtip="{tooltip}"</tpl>',
          '>',
          '<tpl if="icon">',
          '  <img src="{icon}"/>',
          '</tpl>',
          '{text}',
          '</div>').compile();
      }
      return this._genericTpl;
    },
    buttonTpl: function() {
      if (!this._buttonTpl) {
        this._buttonTpl = new Ext.XTemplate(
          '<div',
          ' class="pp-action pp-button"',
          ' action="{action}"',
          ' role="button"',
          ' tabindex="0"',
          '  <tpl if="args"> args="{args}"</tpl>',
          '  <tpl if="tooltip"> ext:qtip="{tooltip}"</tpl>',
          '>',
          '  <tpl if="icon"><img src="{icon}"/></tpl>',
          '  {text}',
          '</div>').compile();
      }
      return this._buttonTpl;
    },
    iconButtonTpl: function() {
      if (!this._iconButtonTpl) {
        this._iconButtonTpl = new Ext.XTemplate(
          '<div',
          ' class="pp-action pp-iconbutton"',
          ' action="{action}"',
          '<tpl if="args"> args="{args}"</tpl>',
          '<tpl if="tooltip"> ext:qtip="{tooltip}"</tpl>',
          '>',
          '  <tpl if="icon"><img src="{icon}"/></tpl>',
          '</div>').compile();
      }
      return this._iconButtonTpl;
    },
    actionData: function(id, cfg) {
      var action = Paperpile.app.Actions.get(id);
      if (action) {
        if (!cfg) {
          cfg = {};
        }
        var tooltip = cfg.tooltip || action.initialConfig.tooltip || '';
        var iconCls = cfg.iconCls || action.initialConfig.iconCls || '';
        var cls = cfg.cls || action.initialConfig.cls || '';
        var icon = cfg.icon || action.initialConfig.icon || '';
        var text = cfg.text || action.initialConfig.text || id;
        var args = cfg.args || action.initialConfig.args || [];
        var data = {
          action: id,
          tooltip: tooltip,
          iconCls: iconCls,
          icon: icon,
          text: text,
          args: args,
          cls: cls
        };
        return data;
      } else {
        Paperpile.log("Can't create text link for action " + id);
        return {
          action: undefined,
          tooltip: cfg.tooltip || '',
          text: id + " NOT FOUND",
          args: cfg.args || []
        };
      }
    },
    button: function(id, args, text) {
      var str = this.buttonTpl().apply(this.actionData(id, {
        args: args,
        text: text
      }));
      return str;
    },
    iconButton: function(id, args) {
      return this.iconButtonTpl().apply(this.actionData(id, {
        args: args
      }));
    },
    link: function(id, args, text, cls) {
      return this._generic(id, {
        text: text,
        args: args,
        cls: 'pp-textlink' + (cls ? ' ' + cls : '')
      });
    },
    miniLink: function(id, args, text) {
      return this._generic(id, {
        text: text,
        args: args,
        cls: 'pp-minilink'
      });
    },
    fileLink: function(id, text, path, icon) {
      return this._generic(id, {
        text: text,
        args: path,
        cls: 'pp-filelink',
        icon: icon
      });
    },
    _generic: function(id, cfg) {
      var str = this.linkTpl().apply(this.actionData(id, cfg));
      return str;
    },
  },

});