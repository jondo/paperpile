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

Paperpile.PluginAboutPanel = Ext.extend(Ext.Panel, {

  /*
   * Use the markup and tabLabel configuration options to create a sub-class of the 
   * about panel for other plugins. See the createAboutPanel method in PubMed.js for example.
   */
  markup: [
    '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-center">',
    '<p>Put your side-panel HTML here</p>',
    '<p></p>',
    '</div>'],

  tabLabel: 'About',

  initComponent: function() {
    Ext.apply(this, {
      bodyStyle: {
        background: '#ffffff',
        padding: '7px'
      },
      autoScroll: true,
      itemId: 'about'
    });

    this.tpl = new Ext.XTemplate(this.markup).compile();

    Paperpile.PluginAboutPanel.superclass.initComponent.call(this);
  },

  update: function() {
    this.tpl.overwrite(this.body, {},
      true);
  },

  forceUpdate: function() {
    this.update();
  }

});