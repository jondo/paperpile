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

Ext.define('Paperpile.pub.FilterField', {
  extend: 'Ext.form.Trigger',
  alias: 'widget.filterfield',

  initComponent: function() {
    Ext.apply(this, {
      enableKeyEvents: true,
    });
    this.callParent(arguments);

    /*
    this.on('specialkey', function(f, e) {
      if (e.getKey() == e.ENTER) {
        this.onTrigger2Click();
      }
    },
    this);
    */
    var task = new Ext.util.DelayedTask(this.executeSearch, this);
    this.on('keydown', function(f, e) {
      task.delay(200);
    },
    this);

  },

  hideTrigger: true,

  onTriggerClick: function() {
    this.executeSearch();
  },

  executeSearch: function() {
    Paperpile.log("Searching");
    var v = this.getRawValue();

    // Reload everthing when empty
    if (v.length == 0) {
      //      this.store.getProxy().extraParams['plugin_query'] = this.build_query('');
      this.store.getProxy().extraParams['plugin_query'] = this.build_query('');
      this.store.load({
	      start: 0,
		  filters: undefined
	  });
      return;
    }

    // Don't trigger search with less than 3 characters for efficiency
    // reasons
    if (v.length < 3) {
      return;
    }

    var o = {
      start: 0,
      task: 'NEW'
    };
    //    this.store.baseParams = this.store.baseParams || {};
      this.store.baseParams = this.store.baseParams || {};
    this.store.getProxy().extraParams['plugin_query'] = this.build_query(v);
    this.store.getProxy().extraParams['task'] = 'NEW';
    this.store.load();
  },

  build_query: function(input) {
    var els = [this.base_query, input];
    var query_array = [];
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el != '') {
        query_array.push(el);
      }
    }
    return query_array.join(' ');
  }
}

);