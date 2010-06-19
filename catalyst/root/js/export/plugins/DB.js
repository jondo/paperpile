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


Paperpile.ExportDB = Ext.extend(Ext.FormPanel, {

  initComponent: function() {
    Ext.apply(this, {
      export_name: 'DB',
      defaultType: 'textfield',
      layout: "column",
      border: false,
      items: [{
        columnWidth: 0.7,
        layout: 'form',
        itemId: 'path',
        border: false,
        xtype: 'panel',
        items: [{
          xtype: 'textfield',
          itemId: 'textfield',
          anchor: "100%",
          hideLabel: true,
          name: 'export_out_file',
          value: Paperpile.main.globalSettings.user_home + '/export.ppl',
        }]
      },
      {
        columnWidth: 0.3,
        layout: 'form',
        border: false,
        xtype: 'panel',
        itemId: 'path_button',
        items: [{
          xtype: 'button',
          text: 'Choose file',
          itemId: 'button',
          listeners: {
            click: {
              fn: function() {
                var parts = Paperpile.utils.splitPath(this.items.get('path').items.get('textfield').getValue());
                var win = new Paperpile.FileChooser({
                  saveMode: true,
                  saveDefault: parts.file,
                  currentRoot: parts.dir,
                  warnOnExisting: false,
                  callback: function(button, path) {
                    if (button == 'OK') {
                      this.items.get('path').items.get('textfield').setValue(path);
                    }
                  },
                  scope: this
                });

                win.show();

              },
              scope: this
            }
          },
        },
        ]
      },
      {
        columnWidth: 1.0,
        layout: 'form',
        border: false,
        itemId: 'options',
        xtype: 'panel',
        labelWidth: 200,
        items: [{
          xtype: 'checkbox',
          fieldLabel: '',
          boxLabel: 'Include PDFs',
          hideLabel: true,
          name: 'export_include_pdfs',
          itemId: 'export_include_pdfs',
          disabled: true,
        },
        {
          xtype: 'checkbox',
          fieldLabel: '',
          boxLabel: 'Include attachments',
          hideLabel: true,
          name: 'export_include_attachments',
          itemId: 'export_include_attachments',
          disabled: true,
        },
        ]
      },
      ]
    });

    Paperpile.ExportDB.superclass.initComponent.call(this);

    //this.on('afterlayout', function(){this.setOptionFields(this.currentType)});
  },

  setOptionFields: function(type) {

    for (var field in this.optionFields) {
      var item = this.items.get('options').items.get(field);
      if (this.optionFields[field].indexOf(type) != -1) {
        item.getEl().up('div.x-form-item').setDisplayed(true);
      } else {
        item.getEl().up('div.x-form-item').setDisplayed(false);
      }
    }
  }

});

Ext.reg('export-db', Paperpile.ExportDB);
