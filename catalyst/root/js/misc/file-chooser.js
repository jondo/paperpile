/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU Affero General Public License as
   published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Affero General Public License for more details.  You should have
   received a copy of the GNU Affero General Public License along with
   Paperpile.  If not, see http://www.gnu.org/licenses. */

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
      Paperpile.Ajax({
        url: '/ajax/files/stats',
        params: {
          location: path
        },
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

Paperpile.fileDialog = function(callback, inputOptions) {
  // Default options. 
  var options = {
    title: 'File Dialog',
    // dialogType: 'load' or 'save'
    dialogType: 'load',
    // selectionType: 'file' or 'folder'
    selectionType: 'file',
    multiple: false,
    // types: ['txt','csv']
    types: null,
    nameFilters: null,
    typesDescription: null,
    scope: null,
    path: Paperpile.main.getSetting('user_home')
  };

  Ext.apply(options, inputOptions);

  if (callback === undefined) {
    callback = function(filenames) {};
  }

  if (options.scope) {
    callback = callback.createDelegate(options.scope);
  }

  if (IS_QT) {

    var config={};

    if (options.dialogType == 'save') {
      config['AcceptMode'] = 'AcceptSave';
    } else {
      config['AcceptMode'] = 'AcceptOpen';
    }

    if (options.selectionType == 'file') {
      config['FileMode'] = "AnyFile";
    } else {
      config['FileMode'] = "Directory";
    }

    if (options.multiple && options.selectionType=='file'){
      config['FileMode'] = "ExistingFiles";
    }

    if (options.nameFilters) {
      config['NameFilters']=options.nameFilters;
    }
    
    if (options.path) {
      config['Directory']=options.path;
    }
    
    if (options.title) {
      config['Caption']=options.title;
    }

    if (options.dontConfirmOverwrite) {
      config['DontConfirmOverwrite']=options.dontConfirmOverwrite;
    }

    if (options.lookInLabel){
      config['LookInLabel'] = options.lookInLabel;
    }

    if (options.fileNameLabel){
      config['FileNameLabel'] = options.fileNameLabel;
    }

    if (options.fileTypeLabel){
      config['FileTypeLabel'] = options.fileTypeLabel;
    }

    if (options.acceptInLabel){
      config['AcceptLabel'] = options.acceptLabel;
    }

    if (options.rejectLabel){
      config['RejectLabel'] = options.rejectLabel;
    }


    var results = QRuntime.fileDialog(config);
    
    if (!results.files) results.files=[];

    callback(results.files, results.filter, results.answer);

  } else {
    // Create an ExtJS dialog.
    var fileChooserOptions = {
      currentRoot: options.path,
      callback: function(button, path) {
        if (button == 'OK') {
          callback([path]);
        }
      },
    };

    for (var i = 0; i < options.types.length; i++) {
      var option = options.types[i];
      if (option == '*') {
        options.types[i] = '';
      }
    }

    if (options.types) {
      Ext.apply(fileChooserOptions, {
        showFilter: true,
        filterOptions: [{
          text: options.typesDescription || 'Supported files (' + options.types.join(", ") + ')',
          suffix: options.types
        },
        {
          text: 'All files',
          suffix: ""
        }],
      });
    }
    if (options.dialogType == 'save') {
      fileChooserOptions.saveMode = true;
    }
    if (options.selectionType == 'file') {
      fileChooserOptions.selectionMode = 'FILE';
    } else {
      fileChooserOptions.selectionMode = 'DIR';
    }

    win = new Paperpile.FileChooser(fileChooserOptions);
    win.show();
  }
};