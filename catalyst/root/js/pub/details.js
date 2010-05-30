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


Paperpile.PubDetails = Ext.extend(Ext.Panel, {

  itemId: 'details',

  markup: [
    '<div id=main-container-{id}>',
    '<div class="pp-box pp-box-top pp-box-style2"',
    '  <div id="ref-actions" style="float:right;">',
    '    <img src="/images/icons/pencil.png" class="pp-img-action" action="edit-ref" ext:qtip="Edit Reference"/>',
    '  </div>',
    '<div style="height: 5px;"></div>',
    '  <dl>',
    '    <tpl if="citekey"><dt>Key: </dt><dd>{citekey}</dd></tpl>',
    '      <dt>Type: </dt><dd>{pubtype}</dd>',
    '    <tpl for="fields">',
    '      <dt>{label}:</dt><dd>{value}</dd>',
    '    </tpl>',
    '  </dl>',
    '</div>',
    '</div>'],

  initComponent: function() {
    this.tpl = new Ext.XTemplate(this.markup);
    Ext.apply(this, {
      bodyStyle: {
        background: '#ffffff',
        padding: '7px'
      },
      autoScroll: true,
    });

    Paperpile.PubDetails.superclass.initComponent.call(this);

  },

  onRender: function(ct, position) {
    Paperpile.PubDetails.superclass.onRender.call(this, ct, position);
    this.el.on('click', this.handleClick, this);
  },

  //
  // Redraws the HTML template panel with new data from the grid
  //
  // TODO: Fix to work with new data structures
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
      // Don't show details if we have only partial information that lacks pubtype
      if (this.data.pubtype) {

        //debugger;
        var currType = Paperpile.main.globalSettings.pub_types[this.data.pubtype];
        var fieldNames = Paperpile.main.globalSettings.pub_fields;

        var allFields = ['sortkey', 'title', 'booktitle', 'series', 'authors', 'editors', 'journal',
          'chapter', 'volume', 'number', 'issue', 'edition', 'pages', 'url', 'howpublished',
          'publisher', 'organization', 'school', 'address', 'year', 'month', 'day', 'eprint',
          'issn', 'isbn', 'pmid', 'lccn', 'arxivid', 'doi', 'keywords', 'note'];

        var list = [];

        for (var i = 0; i < allFields.length; i++) {
          var field = allFields[i];
          var value = this.data[field];

          var label = fieldNames[field];

          // Check if we have type specific names
          if (currType.labels) {
            if (currType.labels[field]) {
              label = currType.labels[field];
            }
          }

          // Breaks layout, needs proper fix
          if (label === 'How published') {
            label = 'How publ.';
          }

          if (!value) continue;
          list.push({
            label: label,
            value: value
          });
        }

        this.tpl.overwrite(this.body, {
          pubtype: currType.name,
          citekey: this.data.citekey,
          fields: list
        },
          true);
      }
    } else {

      var empty = new Ext.Template('');
      empty.overwrite(this.body);

    }

  },

  showEmpty: function(tpl) {
    var empty = new Ext.Template(tpl);
    empty.overwrite(this.body);
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    var action = el.getAttribute('action');

    if (action === 'edit-ref') {
      this.grid.handleEdit();
    }
  }

});

Ext.reg('pubdetails', Paperpile.PubDetails);