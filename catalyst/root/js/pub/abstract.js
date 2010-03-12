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


Paperpile.PubSummary = Ext.extend(Ext.Panel, {

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

  updateDetail: function() {

    if (!this.grid) {
      this.grid = this.findParentByType(Paperpile.PluginPanel).items.get('center_panel').items.get('grid');
    }

    sm = this.grid.getSelectionModel();
    var numSelected = sm.getCount();
    if (this.grid.allSelected) {
      numSelected = this.grid.store.getTotalCount();
    }

    if (numSelected == 1) {
      this.data = sm.getSelected().data;
      this.data.id = this.id;
      this.abstractTemplate.overwrite(this.body, this.data);
    } else {

      var empty = new Ext.Template('');
      empty.overwrite(this.body);
    }
  },

  showEmpty: function(tpl) {
    var empty = new Ext.Template(tpl);
    empty.overwrite(this.body);
  }

});

Ext.reg('pubsummary', Paperpile.PubSummary);