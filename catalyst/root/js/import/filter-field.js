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

Ext.app.FilterField = Ext.extend(Ext.form.TwinTriggerField, {

  singleField: '',
  // Restrict query to a single field by appending it like name: knuth
  initComponent: function() {

    itemId: 'filter_field',

    Ext.apply(this, {
      enableKeyEvents: true,
    });

    Ext.app.FilterField.superclass.initComponent.call(this);

    this.on('specialkey', function(f, e) {
      if (e.getKey() == e.ENTER) {
        this.onTrigger2Click();
      }
    },
    this);

    var task = new Ext.util.DelayedTask(this.onTrigger2Click, this);
    this.on('keydown', function(f, e) {
      task.delay(200);
    },
    this);
  },

  afterRender: function() {
    Ext.app.FilterField.superclass.afterRender.call(this);

    // SwallowEvent code lifted from Editor.js -- causes
    // this field to swallow key events which would otherwise
    // be carried on to the grid (i.e. ctrl-A to select all)
    //      this.getEl().swallowEvent([
    //        'keypress', // *** Opera
    //        'keydown' // *** all other browsers
    //        ]);
  },

  validationEvent: false,
  validateOnBlur: false,
  trigger1Class: 'x-form-clear-trigger',
  trigger2Class: 'x-form-search-trigger',
  hideTrigger1: true,
  hideTrigger2: true,
  width: 180,
  hasSearch: false,

  onTrigger1Click: function() {
    if (this.hasSearch) {
      this.el.dom.value = '';
      var o = {
        start: 0,
        task: 'NEW'
      };
      this.store.baseParams = this.store.baseParams || {};
      this.store.baseParams.plugin_query = this.build_query('');
      this.store.reload({
        params: o
      });
      this.triggers[0].hide();
      this.hasSearch = false;
    }
  },

  onTrigger2Click: function() {
    var v = this.getRawValue();

    // Reload everthing when empty
    if (v.length < 1) {
      this.onTrigger1Click();
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
    this.store.baseParams = this.store.baseParams || {};

    this.store.baseParams['plugin_query'] = this.build_query(v);
    this.store.reload({
      params: o
    });
    this.hasSearch = true;
    this.triggers[0].show();

  },

  build_query: function(input) {
    if (input == '') {
      if (this.base_query == '') {
        return ('');
      } else {
        return (this.base_query);
      }
    } else {
      if (this.singleField == '') {
        return (this.base_query + " " + input);
      } else {
        var parts = input.split(/\s+/);
        for (var i = 0; i < parts.length; i++) {
          parts[i] = this.singleField + ":" + parts[i];
        }
        return (this.base_query + " " + parts.join(" "));
      }
    }
  }
}

);