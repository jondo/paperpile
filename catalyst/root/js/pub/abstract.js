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

Ext.define('Paperpile.PubSummary', {
  extend: 'Ext.Panel',
  alias: 'widget.pp-pubsummary',
  initComponent: function() {

    // The template for the abstract
    this.abstractMarkup = [
      '<div class="pp-basic pp-abstract">{abstract}</div>', ];

    this.abstractTemplate = new Ext.Template(this.abstractMarkup);

    Ext.apply(this, {
      bodyStyle: {
        background: '#ffffff',
        padding: '7px'
      },
      autoScroll: true,
    });

    Paperpile.PubSummary.superclass.initComponent.call(this);

  },

  getPluginPanel: function() {
    return this.ownerCt.ownerCt.ownerCt;
  },

  getGrid: function() {
    return this.getPluginPanel().getGrid();
  },

  updateDetail: function() {

    if (!this.grid) {
      this.grid = this.getGrid();
    }

    sm = this.grid.getSelectionModel();
    var numSelected = sm.getCount();
    if (this.grid.allSelected) {
      numSelected = this.grid.store.getTotalCount();
    }

    var isEmpty = false;
    if (numSelected == 1) {
      var record = sm.getSelected();
      if (record) {
        this.data = record.data;
        this.data.id = this.id;
        if (this.data.abstract === '') {
          isEmpty = true;
        } else {
          if (this.rendered) {
            this.abstractTemplate.overwrite(this.body, this.data);
          }
        }
      }
    } else {
      isEmpty = true;
    }

    if (isEmpty && this.rendered) {
      var empty = new Ext.Template('<p class="pp-basic pp-abstract pp-inactive">No abstract available.</p>');
      empty.overwrite(this.body);
    }
  },

  showEmpty: function(tpl) {
    var empty = new Ext.Template(tpl);
    var empty = new Ext.Template('<p clas="pp-basic pp-abstract pp-inactive"></p>');
    if (this.rendered) {
      empty.overwrite(this.body);
    }
  }

});