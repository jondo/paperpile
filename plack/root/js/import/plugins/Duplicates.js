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

Paperpile.PluginPanelDuplicates = Ext.extend(Paperpile.PluginPanel, {

  initComponent: function() {
    Ext.apply(this, {
      title: this.title,
      iconCls: 'pp-icon-duplicates'
    });
    Paperpile.PluginPanelDuplicates.superclass.initComponent.call(this);
  },

  createGrid: function(gridParams) {
    return new Paperpile.PluginGridDuplicates(gridParams);
  },

  createAboutPanel: function() {
    return undefined;
  }

});

Paperpile.PluginGridDuplicates = Ext.extend(Paperpile.PluginGridDB, {
  plugin_iconCls: 'pp-icon-duplicates',
  plugin_name: 'Duplicates',
  limit: 25,
  plugin_base_query: '',

  emptyMsg: [
    '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-welcome"',
    '<h2>Duplicate Search</h2>',
    '<p>Your library was searched and no duplicate references were found.<p>',
    '</div>'],

  initComponent: function() {
    // Need to set these store handlers before calling the superclass.initcomponent,
    // otherwise the store will have already started loading when these are added.
    this.getStore().on('beforeload',
      function() {
        this.busyStatus = Paperpile.status.showBusy('Searching duplicates');
      },
      this);
    this.getStore().on('load',
      function() {
        Paperpile.status.clearMessageNumber(this.busyStatus);
        if (this.store.getCount() == 0) {
          this.getPluginPanel().onEmpty(this.emptyMsg);
        }
      },
      this);

    Paperpile.PluginGridDuplicates.superclass.initComponent.call(this);

    this.actions['CLEAN_ALL_DUPLICATES'] = new Ext.Action({
      text: 'Clean all Duplicates',
      handler: this.cleanDuplicates,
      scope: this,
      iconCls: 'pp-icon-clean',
      itemId: 'remove_duplicates',
      tooltip: 'Automatically clean all duplicates'
    });
    this.actions['MERGE_DUPLICATES'] = new Ext.Action({
      text: 'Merge to Selected',
      handler: this.mergeDuplicates,
      scope: this,
      icon: '/images/icons/arrow_in.png',
      itemId: 'MERGE_DUPLICATES',
      tooltip: 'Keep the selected reference and merge all additional data from the other duplicates into it.'
    });

    this.on('render', this.myOnRender, this);
  },

  getEmptyTemplate: function() {
    return new Ext.XTemplate(['<div class="pp-hint-box"><p>No duplicates found. <a href="#" class="pp-textlink" action="close-tab">Close tab</a>.</p></div>']).compile();
  },

  getNoResultsTemplate: function() {
    return this.getEmptyTemplate();
  },
  getEmptyBeforeSearchTemplate: function() {
    return this.getEmptyTemplate();
  },

  initToolbarMenuItemIds: function() {
    Paperpile.PluginGridDuplicates.superclass.initToolbarMenuItemIds.call(this);
    var ids = this.toolbarMenuItemIds;
    var fillIndex = ids.indexOf('TB_FILL');

    ids.remove('NEW');
    ids.remove('DELETE');

    ids.insert(fillIndex + 1, 'DELETE'); // move the delete button to before the break.
    // We might eventually have this working, but for now it's unimplemented
    // in the backend so leave it out of the toolbar.
    //ids.insert(fillIndex + 1, 'CLEAN_ALL_DUPLICATES');
    ids.insert(fillIndex + 1, 'MERGE_DUPLICATES');
  },

  updateButtons: function() {
    Paperpile.PluginGridDuplicates.superclass.updateButtons.call(this);

    if (this.getSelectionCount() > 1 || this.getSelectionCount() == 0) {
      this.actions['MERGE_DUPLICATES'].setDisabled(true);
    } else {
      var singleSelection = this.getSingleSelectionRecord();
      if (singleSelection.get('_dup_id') === null) {
        this.actions['MERGE_DUPLICATES'].setDisabled(true);
      }
    }
  },

  afterSelectionChange: function(sm) {
    Paperpile.PluginGridDuplicates.superclass.afterSelectionChange.call(this, sm);

    this.getView().refresh();
  },

  initContextMenuItemIds: function() {
    Paperpile.PluginGridDuplicates.superclass.initContextMenuItemIds.call(this);
    var ids = this.contextMenuItemIds;

  },

  myOnRender: function() {

    this.getView().getRowClass = function(record, index, rowParams, store) {
      var singleSelection = this.grid.getSingleSelectionRecord();
      if (record.get('_dup_id') === null) {
        return 'pp-grid-dup-ok';
      }
      if (record.get('_highlight')) {
	return record.get('_highlight');
      }
      return '';
    };
  },

  mergeDuplicates: function() {

    var ref = this.getSingleSelectionRecord();

    var other_dups = this.getStore().queryBy(function(record, id) {
      if (record.data._dup_id == ref.data._dup_id && record.data.guid != ref.data.guid) {
        return true;
      } else {
        return false;
      }
    });

    var other_guids = [];
    other_dups.each(function(item, index, length) {
      other_guids = other_guids.concat(item.data.guid);
    });

    var n = other_guids.length + 1;

    Paperpile.Ajax({
      url: '/ajax/crud/merge_duplicates',
      params: {
        grid_id: this.id,
        ref_guid: ref.data.guid,
        other_guids: other_guids
      },
      success: function(response) {
        var msg = n + " duplicate references were merged.";
        Paperpile.status.updateMsg({
          msg: msg,
          hideOnClick: true
        });
        /* Not allowing undos on this for now.
 *         var undoMessage = Paperpile.status.updateMsg({
          msg: msg,
          hideOnClick: true,
          action1: 'Undo',
          callback: function(action) {
            Paperpile.status.clearMessageNumber(undoMessage);
            Paperpile.Ajax({
              url: '/ajax/crud/undo_merge_duplicates'
            });
          },
          scope: this
        });
*/
      },
      scope: this
    });
  },

  cleanDuplicates: function() {
    Paperpile.Ajax({
      url: '/ajax/misc/clean_duplicates',
      params: {
        grid_id: this.id
      },
      scope: this
    });
  }
});