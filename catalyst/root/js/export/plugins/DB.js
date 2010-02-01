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
                      console.log(path);
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