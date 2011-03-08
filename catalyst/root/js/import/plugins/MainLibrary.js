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

Ext.define('Paperpile.PluginGridMainLibrary', {
	extend: 'Paperpile.PluginGridDB',
  initComponent: function() {

    Paperpile.PluginGridMainLibrary.superclass.initComponent.call(this);

    this.actions['NEW'] = new Ext.Action({
      text: 'Create Manually',
      iconCls: 'pp-icon-add',
      handler: function() {
        this.handleEdit(true);
      },
      scope: this,
      itemId: 'new_button',
      tooltip: 'Manually create a new reference for your library'
    });
    this.actions['FILE_IMPORT'] = new Ext.Action({
      text: "Open Bibliography File",
      iconCls: 'pp-icon-import-file',
      tooltip: 'Import references from EndNote, BibTeX <br/> and other bibliography files.',
      handler: function() {
        Paperpile.main.fileImport();
      }
    });

    this.actions['PDF_IMPORT'] = new Ext.Action({
      text: "Import PDFs",
      iconCls: 'pp-icon-import-pdf',
      tooltip: 'Import references from one or more PDFs',
      handler: function() {
        Paperpile.main.pdfExtract();
      }
    });
    this.actions['ADD_MENU'] = {
      text: 'Add to Library',
      itemId: 'ADD_MENU',
      iconCls: 'pp-icon-add',
      menu: {
        items: [
          this.actions['NEW'],
          this.actions['FILE_IMPORT'],
          this.actions['PDF_IMPORT']]
      }
    };
  },

  loadKeyboardShortcuts: function() {
    Paperpile.PluginGridMainLibrary.superclass.loadKeyboardShortcuts.call(this);

    this.keys.bindAction('ctrl-n', this.actions['NEW']);
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridMainLibrary.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;

    var index = ids.indexOf('TB_FILL');
    ids.insert(index + 1, 'ADD_MENU');
  }
});

Ext.define('Paperpile.PluginPanelMainLibrary', {
	extend: 'Paperpile.PluginPanelDB',
  createGrid: function(params) {
    return new Paperpile.PluginGridMainLibrary(params);
  },

  createAboutPanel: function() {
    return undefined;
  }
});