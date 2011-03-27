/* Copyright 2009-2011 Paperpile

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

Paperpile.SettingsPanel = Ext.extend(Ext.Panel, {

  initComponent: function() {
    Paperpile.SettingsPanel.superclass.initComponent.call(this);

    this.on('beforeclose', this.beforeClose, this);
  },

  getShortTitle: function() {
      // To be overridden by subclasses, to return a short version of the tab title.
      return 'Settings';
  },

  isDirty: function() {
      // To be overridden by subclasses, to return whether or not the state of this
      // settings tab has changed.
      return false;
  },

  beforeClose: function() {
    if (this.isDirty()) {
      Ext.Msg.show({
        title: 'Close '+this.getShortTitle()+' Tab',
        msg: 'You have unsaved changes. Close and discard changes?',
        icon: Ext.MessageBox.INFO,
        buttons: Ext.Msg.YESNO,
        fn: function(btn) {
          if (btn === 'yes') {
            Paperpile.main.tabs.remove(this,true);
          }
        },
        scope: this
      });
      return false;
    } else {
      return true;
    }
  }


});