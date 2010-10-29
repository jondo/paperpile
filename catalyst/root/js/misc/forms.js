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


Paperpile.Forms = Ext.extend(Ext.FormPanel, {

  initComponent: function() {
    Ext.apply(this, {
      method: 'GET',
      bodyStyle: 'padding:5px 5px 0',
      //defaultType: 'textfield',
    });
    Paperpile.Forms.superclass.initComponent.call(this);
  }
});

Paperpile.Forms.Settings = Ext.extend(Paperpile.Forms, {

  initComponent: function() {
    Ext.apply(this, {
      labelWidth: 150,
      url: Paperpile.Url('/ajax/forms/settings'),
      defaultType: 'textfield',
      items: [{
        name: 'user_db',
        fieldLabel: "Paperpile database",
      },
      {
        name: "paper_root",
        fieldLabel: "PDF folder",
        xtype: "textfield"
      },
      {
        name: "key_pattern",
        fieldLabel: "Citation key pattern",
        xtype: "textfield"
      },
      {
        name: "pdf_pattern",
        fieldLabel: "PDF file name pattern",
        xtype: "textfield"
      },
      {
        name: "attachment_pattern",
        fieldLabel: "Supplementary files directory",
        xtype: "textfield"
      },

      ],
      buttons: [{
        text: 'Save',
        handler: function() {
          this.getForm().submit({
            url: Paperpile.Url('/ajax/forms/settings'),
            params: {
              action: 'SUBMIT'
            },
            success: function() {
              Ext.getCmp('statusbar').clearStatus();
              Ext.getCmp('statusbar').setText('Saved settings.');
              this.findParentByType(Paperpile.Settings).close();
            },
            scope: this,
            failure: function() {
              alert('nope')
            },
          })
        },
        scope: this
      },
      {
        text: 'Cancel',
        handler: function() {
          this.findParentByType(Paperpile.Settings).close();
        },
        scope: this
      },
      ]
    });

    Paperpile.Forms.Settings.superclass.initComponent.call(this);

    this.load({
      url: Paperpile.Url('/ajax/forms/settings'),
      params: {
        action: 'LOAD'
      },
      success: function() {
      },
      failure: function() {
        alert('nope')
      },
    });

  }
});
