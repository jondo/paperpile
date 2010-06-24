/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */

Paperpile.ExportWindow = Ext.extend(Ext.Window, {

  grid_id: null,
  source_node: null,
  selection: [],

  initComponent: function() {
    Ext.apply(this, {
      layout: 'card',
      title: 'Export',
      activeItem: 0,
      width: 500,
      height: 300,
      closeAction: 'hide',
      plain: true,
      modal: true,
      bbar: [{
        text: 'Back',
        itemId: 'prev_button',
        cls: 'x-btn-text-icon prev',
        listeners: {
          click: {
            fn: function() {
              this.getLayout().setActiveItem(0);
              this.getBottomToolbar().items.get('prev_button').hide();
              this.getBottomToolbar().items.get('next_button').show();
              this.getBottomToolbar().items.get('ok_button').hide();
            },
            scope: this
          }
        },
        hidden: true,
      },
      {
        xtype: 'tbfill'
      },
      {
        text: 'Cancel',
        itemId: 'cancel_button',
        cls: 'x-btn-text-icon cancel',
        handler: function() {
          this.close()
        },
        scope: this,
      },
      {
        text: 'Next',
        itemId: 'next_button',
        cls: 'x-btn-text-icon next',
        listeners: {
          click: {
            fn: function() {
              var plugin = this.items.get('form').getForm().getValues().plugin;

              // Create or update plugin form for second tab depending on selection
              if ((!this.pluginForm) || (this.pluginForm.export_name != plugin)) {
                this.items.remove(this.pluginForm);
                this.pluginForm = new Paperpile['Export' + plugin]({
                  bodyStyle: 'padding: 10px 10px 0 10px',
                });

                this.items.add(this.pluginForm);
              }

              this.getLayout().setActiveItem(1);
              this.getBottomToolbar().items.get('ok_button').show();
              this.getBottomToolbar().items.get('cancel_button').show();
              this.getBottomToolbar().items.get('next_button').hide();
              this.getBottomToolbar().items.get('prev_button').show();
            },
            scope: this
          }
        }
      },
      {
        text: 'Export',
        itemId: 'ok_button',
        cls: 'x-btn-text-icon ok',
        listeners: {
          click: {
            fn: function() {
              var form = this.items.get(1).getForm();

              Paperpile.status.showBusy('Exporting data.')

              form.submit({
                url: Paperpile.Url('/ajax/plugins/export'),
                params: {
                  grid_id: this.grid_id,
                  source_node: this.source_node,
                  export_name: this.pluginForm.export_name,
                  selection: this.selection
                },
                success: function() {
                  Paperpile.status.clearMsg();
                  this.close();
                },
                scope: this,
                failure: function(form, action) {
                  Paperpile.main.onError(action.response);
                },
              });

            },
            scope: this
          }
        },
        hidden: true
      },
      ],
      items: [{
        xtype: 'form',
        itemId: 'form',
        layout: 'form',
        border: false,
        labelAlign: 'right',
        labelWidth: 50,
        bodyStyle: 'padding: 50px 10px 0 50px',
        items: [{
          xtype: 'radio',
          name: 'plugin',
          boxLabel: 'Bibliography file (BibTeX, EndNote...)',
          inputValue: 'Bibfile',
          hideLabel: true,
          checked: true,
        },
        {
          xtype: 'radio',
          name: 'plugin',
          boxLabel: 'Paperpile library',
          inputValue: 'DB',
          hideLabel: true,
          disabled: true,
        },
        {
          xtype: 'radio',
          name: 'plugin',
          boxLabel: 'Website',
          inputValue: 'HTML',
          hideLabel: true,
          disabled: true,
        },
        {
          xtype: 'radio',
          name: 'plugin',
          boxLabel: 'PDF',
          inputValue: 'PDF',
          hideLabel: true,
          disabled: true,
        },
        ],
      },
      ],
    });

    Paperpile.ExportWindow.superclass.initComponent.call(this);

  },

  setDisabledOk: function(disable) {
    this.getBottomToolbar().items.get('ok_button').setDisabled(disable);
  }

});

Paperpile.SimpleExportWindow = Ext.extend(Ext.Window, {
  grid_id: null,
  source_node: null,
  selection: null,

  initComponent: function() {
    var formats = [{
      text: 'BibTeX (.bib)',
      short: 'BIBTEX'
    },
    {
      text: 'RIS (.ris)',
      short: 'RIS'
    },
    {
      text: 'EndNote (.txt)',
      short: 'ENDNOTE'
    },
    {
      text: 'MODS (.xml)',
      short: 'MODS'
    },
    {
      text: 'ISI Web of Science (.isi)',
      short: 'ISI'
    },
    {
      text: 'Word 2007 XML (.xml)',
      short: 'WORD2007'
    }];

    var formatItems = [];
    for (var i = 0; i < formats.length; i++) {
      var obj = formats[i];
      var text = obj.text;
      var short = obj.short;
      formatItems.push({
        xtype: 'subtlebutton',
        width: 150,
        height: 30,
        text: text,
        shortDescription: obj.short,
        handler: function(button, event) {
          this.handleExport(button.shortDescription);
        },
        scope: this
      });
    }

    Ext.apply(this, {
      modal: true,
      layout: {
        type: 'vbox',
        align: 'center',
        defaultMargins: '5px',
      },
      bodyStyle: 'background-color:#FFFFFF;',
      title: 'Choose export format',
      width: 300,
      height: 340,
      buttonAlign: 'center',
      layoutConfig: {},
      items: [{
        xtype: 'label',
        text: '',
        height: 20
      }].concat(formatItems),
      bbar: [{
        xtype: 'tbfill'
      },
      {
        text: 'Cancel',
        itemId: 'cancel_button',
        cls: 'x-btn-text-icon cancel',
        handler: function() {
          this.close();
        },
        scope: this
      }]
    });

    Paperpile.SimpleExportWindow.superclass.initComponent.call(this);
  },

  formatToExtensions: {
    MODS: ['xml'],
    BIBTEX: ['bib', 'bibtex'],
    RIS: ['ris'],
    ENDNOTE: ['txt'],
    ISI: ['isi'],
    'WORD2007': ['xml']
  },
  formatToDescriptions: {
    MODS: 'MODS XML',
    BIBTEX: 'BibTeX',
    RIS: 'RIS',
    ENDNOTE: 'EndNote',
    ISI: 'ISI',
    'WORD2007': 'Word 2007 XML'
  },

  prependEach: function(array, prefix) {
    var newArray = [];
    for (var i = 0; i < array.length; i++) {
      newArray.push(prefix + array[i]);
    }
    return newArray;
  },

  handleExport: function(format) {
    var ext = this.formatToExtensions[format];
    var desc = this.formatToDescriptions[format];

    var includingDots = this.prependEach(ext, '.');

    var options = {
      title: 'Choose a destination file for ' + desc + ' export',
      dialogType: 'save',
      types: ext,
      typesDescription: desc + " (" + includingDots.join(', ') + ")",
      scope: this
    };
    var window = this;
    var callback = function(filenames) {
      window.close();

      if (filenames.length == 0) {
        return;
      }
      var file = filenames[0];
      if (file.indexOf('.') == -1) {
        file = file + '.' + ext[0];
      }

      Paperpile.status.showBusy('Exporting to ' + file + '...');
      Ext.Ajax.request({
        url: Paperpile.Url('/ajax/plugins/export'),
        params: {
          source_node: this.source_node,
          selection: this.selection,
          grid_id: this.grid_id,
          source_node: this.source_node,
          export_name: 'Bibfile',
          export_out_format: format,
          export_out_file: file
        },
        success: function() {
          Paperpile.status.clearMsg();
        },
        failure: Paperpile.main.onError,
        scope: this
      });

    };
    Paperpile.fileDialog(callback, options);
  }
});