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

Ext.define('Paperpile.pub.View', {
  extend: 'Ext.Panel',
  alias: 'widget.pubview',
  initComponent: function() {
    Ext.apply(this, {
      sidebarUpdateDelay: 100,
      layout: 'border',
      items: [this.createCenter(), this.createEast()],
      listeners: {
        mousedown: {
          element: 'body',
          fn: this.onMouseDown,
          scope: this
        }
      }
    });
    this.callParent(arguments);
  },

  createCenter: function() {
    var params = this.gridParams || {};
    var me = this;
    Ext.apply(params, {
      region: 'center',
      flex: 2,
      listeners: {
        scope: this,
        afterselectionchange: me.onSelect
      }
    });
    this.grid = Ext.create(this.getGridType(), params);

    this.abstract = Ext.createByAlias('widget.pubabstract', {});
    this.south = Ext.create('Ext.panel.Panel', {
      region: 'south',
      flex: 1,
      layout: 'fit',
      split: true,
      border: false,
      items: [this.abstract]
    });

    this.center = Ext.create('Ext.panel.Panel', {
      layout: 'border',
      region: 'center',
      flex: 2,
      split: true,
      border: false,
      items: [this.grid, this.south]
    });
    return this.center;
  },

  getGrid: function() {
    return this.grid;
  },

  createEast: function() {
    this.overview = Ext.createByAlias('widget.puboverview', {});

    this.east = Ext.create('Ext.panel.Panel', {
      region: 'east',
      layout: 'fit',
      flex: 1,
      split: true,
      border: false,
      items: [this.overview]
    });
    return this.east;
  },

  createSouth: function() {
    return this.south;
  },

  getGridType: function() {
    return "Paperpile.pub.Grid";
  },

  handleHideSouth: function() {
    Paperpile.log("YO");
  },

  onSelect: function(sm, selections) {
    if (this.updateSelectionTask === undefined) {
      this.updateSelectionTask = new Ext.util.DelayedTask();
    }
    this.updateSelectionTask.delay(this.sidebarUpdateDelay, this.doUpdateSelection, this, [sm, selections]);
  },

  doUpdateSelection: function(sm, selections) {
    var panels = [this.abstract, this.overview];
    var grid_id = this.grid.id;
    Ext.each(panels, function(panel) {
      panel.grid_id = grid_id;
    });

    if (selections.length == 1) {
      var pub = selections[0];
      pub.data.grid_id = grid_id;
      //      pub.set('grid_id', grid_id);
      Ext.each(panels, function(panel) {
        panel.setPublication(pub);
      });
    } else if (selections.length == 0) {
      Ext.each(panels, function(panel) {
        panel.onEmpty();
      });
    } else {
      Ext.each(panels, function(panel) {
        panel.setMulti(selections);
      });
    }
  },

  onMouseDown: function(event, target, o) {
    var el = Ext.fly(target);
    if (el.hasCls('pp-action')) {
      var id = el.getAttribute('action');
      var args = el.getAttribute('args');
      var array = undefined;
      if (args && args !== '') {
        array = args.split(',');
      }
      Paperpile.app.Actions.execute(id, array);
    }
  },

  updateFromServer: function(data) {
    this.grid.updateFromServer(data);
  }
});