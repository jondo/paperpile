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


Paperpile.DataTabs = Ext.extend(Ext.Panel, {

  initComponent: function() {

    Ext.apply(this, {
      itemId: 'data_tabs',
      layout: 'card',
      margins: '2 2 2 2',
      items: [{
        xtype: 'pubsummary',
        itemId: 'pubsummary',
        border: 0,
        height: 200
      },
      {
        xtype: 'pubnotes',
        itemId: 'pubnotes',
        border: 0,
        height: 200
      }],
      bbar: [{
        text: 'Abstract',
        itemId: 'summary_tab_button',
        enableToggle: true,
        toggleHandler: this.onItemToggle,
        toggleGroup: 'tab_buttons' + this.id,
        scope: this,
        allowDepress: false,
        pressed: true,
        disabled: true
      },
      {
        text: 'Notes',
        itemId: 'notes_tab_button',
        enableToggle: true,
        toggleHandler: this.onItemToggle,
        toggleGroup: 'tab_buttons' + this.id,
        scope: this,
        allowDepress: false,
        pressed: false,
        disabled: true
      },
      {
        xtype: 'tbfill'
      },
      {
        text: 'Save',
        itemId: 'save_notes_button',
        cls: 'x-btn-text-icon save',
        listeners: {
          click: {
            fn: function() {
              this.findByType(Paperpile.PubNotes)[0].onSave();
            },
            scope: this
          }
        },

        hidden: true
      },
      {
        text: 'Cancel',
        itemId: 'cancel_notes_button',
        cls: 'x-btn-text-icon cancel',
        listeners: {
          click: {
            fn: function() {
              this.findByType(Paperpile.PubNotes)[0].onCancel();
            },
            scope: this
          },
        },
        hidden: true
      },
      {
        itemId: 'collapse_button',
        // Icon is kind of a hack but I don't see an easy way to get 
        // the real collapse button in the bottom toolbar
        icon: '/images/icons/collapse.png',
        listeners: {
          click: {
            fn: function() {
              this.toggleCollapse();
            },
            scope: this
          },
        },
        height: 20
      },
      ]
    });

    Paperpile.DataTabs.superclass.initComponent.apply(this, arguments);
  },

  afterRender: function() {
    Paperpile.DataTabs.superclass.afterRender.apply(this, arguments);

    // Hack to get collapsing behaviour right. We don't want the
    // strange Exts default preview but rather install our own event
    // handler that directly restores the panel. 
    this.on('collapse', function() {

      var el = Ext.get(this.id + '-xcollapsed');
      el.addClass('pp-collapsed');
      el.removeAllListeners();
      el.on('click', this.expand, this);

    },
    this);
  },

  onItemToggle: function(button, pressed) {

    if (button.itemId == 'summary_tab_button' && pressed) {
      this.layout.setActiveItem('pubsummary');
    }

    if (button.itemId == 'notes_tab_button' && pressed) {
      this.layout.setActiveItem('pubnotes');
    }

  },

  showNotes: function() {
    this.getBottomToolbar().items.get('notes_tab_button').toggle(true);
  }

}

);

Ext.reg('datatabs', Paperpile.DataTabs);