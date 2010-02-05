Paperpile.FileChooser = Ext.extend(Ext.Window, {

  title: "Select file",
  selectionMode: 'FILE',
  saveMode: false,
  warnOnExisting: true,
  saveDefault: 'new-file.dat',
  currentRoot: "",
  showHidden: false,
  showFilter: false,
  filterOptions: [],
  currentFilter: 0,

  callback: function(button, path) {
    //console.log(button, path);
  },

  initComponent: function() {

    // We need this explicit marker for the root internally
    this.currentRoot = "ROOT" + this.currentRoot;

    var label = 'Location';

    if (this.selectionMode == 'DIR') {
      label = 'Directory';
    }

    if (this.selectionMode == 'FILE') {
      label = 'File';
    }

    var filterStore = [];

    if (this.filterOptions) {
      for (var i = 0; i < this.filterOptions.length; i++) {
        filterStore.push([i, this.filterOptions[i].text]);
      }
    }

    Ext.apply(this, {
      layout: 'border',
      width: 500,
      height: 300,
      closeAction: 'hide',
      plain: true,
      modal: true,
      items: [{
        xtype: 'panel',
        region: 'north',
        itemId: 'northpanel',
        height: 40,
        layout: 'form',
        frame: true,
        border: false,
        labelAlign: 'right',
        labelWidth: 50,
        items: [{
          xtype: 'textfield',
          itemId: 'textfield',
          fieldLabel: label,
          width: 400,
          enableKeyEvents: true,
        }],
      },
      {
        xtype: 'panel',
        region: 'center',
        itemId: 'centerpanel',
        layout: 'fit',
        tbar: [{
          xtype: 'box',
          itemId: 'breadcrumbs',
          autoEl: {
            tag: 'div',
            html: '<ul class="pp-filechooser-path"><li>inhere</li></ul>'
          },
          width: 400
        }],
        items: [{
          xtype: 'panel',
          itemId: 'filetree',
          id: 'DUMMY'
        }]
      }],
      bbar: [{
        xtype: 'combo',
        hidden: !this.showFilter,
        itemId: 'file_format',
        value: this.currentFilter,
        editable: false,
        forceSelection: true,
        triggerAction: 'all',
        disableKeyFilter: true,
        hideLabel: true,
        mode: 'local',
        store: filterStore,
        hiddenName: 'export_out_format',
        listeners: {
          select: {
            fn: function(combo, record, index) {
              this.currentFilter = index;
              this.showDir(this.currentRoot);
            },
            scope: this
          }
        }
      },
      {
        xtype: 'tbfill'
      },
      {
        text: 'Select',
        itemId: 'ok_button',
        disabled: true,
        cls: 'x-btn-text-icon save',
        listeners: {
          click: {
            fn: this.selectAction,
            scope: this
          }
        }
      },
      {
        text: 'Cancel',
        itemId: 'cancel',
        cls: 'x-btn-text-icon cancel',
        listeners: {
          click: {
            fn: function() {
              this.callback.createDelegate(this.scope, ['CANCEL', null])();
              this.close();
            },
            scope: this
          }
        }
      }]
    });

    Paperpile.FileChooser.superclass.initComponent.call(this);

    if (!this.scope) {
      this.scope = this;
    }

    this.items.get('northpanel').on('afterLayout',
      function() {
        this.showDir(this.currentRoot);
      },
      this, {
        single: true
      });

    this.textfield = this.items.get('northpanel').items.get('textfield');

    this.textfield.on('change',
      function(field, newValue, oldValue) {
        this.saveDefault = newValue;
      },
      this);

    this.textfield.on('keypress',
      function(field, e) {
        this.getBottomToolbar().items.get('ok_button').enable();
      },
      this);

  },

  selectAction: function() {
    var ft = this.items.get('filetree');
    var path = this.currentRoot + "/" + this.textfield.getValue();

    // ROOT only needed internally
    path = path.replace(/^ROOT/, '');

    if (this.saveMode && this.warnOnExisting) {
      Ext.Ajax.request({
        url: Paperpile.Url('/ajax/files/stats'),
        params: {
          location: path
        },
        method: 'GET',
        success: function(response) {
          var json = Ext.util.JSON.decode(response.responseText);
          if (json.stats.exists) {
            Ext.Msg.confirm('', path + ' already exists. Overwrite?',
              function(btn) {
                if (btn == 'yes') {
                  this.callback.createDelegate(this.scope, ['OK', path])();
                  this.close();
                }
              });
          } else {
            this.callback.createDelegate(this.scope, ['OK', path])();
            this.close();
          }
        },
        failure: Paperpile.main.onError,
        scope: this
      });
    } else {
      this.callback.createDelegate(this.scope, ['OK', path])();
      this.close();
    }
  },

  updateTextfield: function(value) {
    this.textfield.setValue(value);
    if (value != '') {
      this.getBottomToolbar().items.get('ok_button').enable();
    } else {
      this.getBottomToolbar().items.get('ok_button').disable();
    }

  },

  onSelect: function(node, path) {
    this.updateTextfield(node.text);
    this.saveDefault = node.text;
  },

  showDir: function(path) {

    if (this.saveMode) {
      // Add selection/focus stuff here to improve usability
      this.updateTextfield(this.saveDefault);
    } else {
      this.updateTextfield('');
    }

    this.currentRoot = path;

    var cp = this.items.get('centerpanel');

    // Remove old tree and build new one
    cp.remove(cp.items.get('filetree'));

    var filter = null;

    if (this.showFilter) {
      filter = this.filterOptions[this.currentFilter].suffix;
    }

    if (filter instanceof Array) {
      filter = filter.join(",");
    }

    var treepanel = new Ext.ux.FileTreePanel({
      height: 400,
      border: 0,
      itemId: 'filetree',
      autoWidth: true,
      selectionMode: this.selectionMode,
      showHidden: this.showHidden,
      rootPath: path,
      rootText: path,
      topMenu: false,
      autoScroll: true,
      enableProgress: false,
      enableSort: false,
      lines: false,
      rootVisible: false,
      filter: filter,
      url: Paperpile.Url('/ajax/files/dialogue')
    });

    treepanel.on("fileaction",
      function(e, el, options) {
        this.selectAction(options);
      },
      this);
    cp.add(treepanel);
    cp.doLayout();

    bc = cp.getTopToolbar().items.get('breadcrumbs');

    var dh = Ext.DomHelper;
    var ul = dh.overwrite(bc.getEl(), {
      tag: 'ul',
      cls: 'pp-filechooser-path'
    });

    path = path.split('/');

    for (var i = 0; i < path.length; i++) {

      var html = path[i];

      if (path[i] == 'ROOT') {
        html = '<img src="/images/icons/drive.png" valign="center"/>';
      }

      var li = dh.append(ul, {
        tag: 'li',
        cls: 'pp-filechooser-dir',
        children: [{
          tag: 'a',
          href: '#',
          html: html
        }]
      });

      var link = path.slice(0, i + 1).join('/');

      Ext.Element.get(li).on('click',
        function(e, el, options) {
          this.showDir(options.link);
        },
        this, {
          link: link
        });
      dh.append(ul, {
        tag: 'li',
        cls: 'pp-filechooser-separator',
        html: "/"
      });
    }
  }
});