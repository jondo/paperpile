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

Ext.define('Paperpile.pub.Abstract', {
  extend: 'Ext.panel.Panel',
  alias: 'widget.pubabstract',
  cls: 'pp-pub-abstract',
  initComponent: function() {
    Ext.apply(this, {
      tpl: this.createTemplate(),
      autoScroll: true
    });

    this.callParent(arguments);
  },

  createTemplate: function() {
    return new Ext.XTemplate(
      '<div class="pp-abstract">{abstract:this.getBody}</div>', {
        getBody: function(value, all) {
          return Ext.util.Format.stripScripts(value);
        },
      });
  },

  setPublication: function(pub) {
    this.pub = pub;
    this.update(pub.data);
	},

  setMulti: function(pub) {
    delete this.pub;
    this.update({});
  }


});