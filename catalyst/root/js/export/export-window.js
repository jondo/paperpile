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

Paperpile.SimpleExportWindow = Ext.extend(Ext.Window, {
  grid_id: null,
  source_node: null,
  selection: null,

  initComponent: function() {
    var formats = [{
      text: 'BibTeX (.bib)',
      caps: 'BIBTEX'
    },
    {
      text: 'RIS (.ris)',
      caps: 'RIS'
    },
    {
      text: 'EndNote (.txt)',
      caps: 'ENDNOTE'
    },
    {
      text: 'MODS (.xml)',
      caps: 'MODS'
    },
    {
      text: 'ISI Web of Science (.isi)',
      caps: 'ISI'
    },
    {
      text: 'Word 2007 XML (.xml)',
      caps: 'WORD2007'
    }];

    var formatItems = [];
    for (var i = 0; i < formats.length; i++) {
      var obj = formats[i];
      var text = obj.text;
      var caps = obj.caps;
      formatItems.push({
        xtype: 'subtlebutton',
        width: 150,
        height: 30,
        text: text,
        shortDescription: obj.caps,
        handler: function(button, event) {
          this.handleExport(button.shortDescription);
        },
        scope: this
      });
    }

    Ext.apply(this, {
      modal: true,
      layout: {
        type: 'vbox',
        align: 'center',
        defaultMargins: '5px',
      },
      bodyStyle: 'background-color:#FFFFFF;',
      title: 'Choose export format',
      width: 300,
      height: 340,
      buttonAlign: 'center',
      layoutConfig: {},
      items: [{
        xtype: 'label',
        text: '',
        height: 20
      }].concat(formatItems),
      bbar: [{
        xtype: 'tbfill'
      },
      {
        text: 'Cancel',
        handler: function() {
          this.close();
        },
        scope: this
      }]
    });

    Paperpile.SimpleExportWindow.superclass.initComponent.call(this);
  },

  formatToExtensions: {
    MODS: ['xml'],
    BIBTEX: ['bib', 'bibtex'],
    RIS: ['ris'],
    ENDNOTE: ['txt'],
    ISI: ['isi'],
    'WORD2007': ['xml']
  },
  formatToDescriptions: {
    MODS: 'MODS XML',
    BIBTEX: 'BibTeX',
    RIS: 'RIS',
    ENDNOTE: 'EndNote',
    ISI: 'ISI',
    'WORD2007': 'Word 2007 XML'
  },

  prependEach: function(array, prefix) {
    var newArray = [];
    for (var i = 0; i < array.length; i++) {
      newArray.push(prefix + array[i]);
    }
    return newArray;
  },

  handleExport: function(format) {
    var ext = this.formatToExtensions[format];
    var desc = this.formatToDescriptions[format];

    var includingDots = this.prependEach(ext, '.');

    var options = {
      title: 'Choose a destination file for ' + desc + ' export',
      dialogType: 'save',
      types: ext,
      typesDescription: desc + " (" + includingDots.join(', ') + ")",
      scope: this
    };
    var window = this;
    var callback = function(filenames) {
      window.close();

      if (filenames.length == 0) {
        return;
      }
      var file = filenames[0];
      if (file.indexOf('.') == -1) {
        file = file + '.' + ext[0];
      }

      Paperpile.status.showBusy('Exporting to ' + file + '...');
      Paperpile.Ajax({
        url: '/ajax/plugins/export',
        params: {
          source_node: this.source_node,
          selection: this.selection,
          grid_id: this.grid_id,
          export_name: 'Bibfile',
          export_out_format: format,
          export_out_file: file
        },
        success: function() {
          Paperpile.status.clearMsg();
        },
        scope: this
      });

    };
    Paperpile.fileDialog(callback, options);
  }
});