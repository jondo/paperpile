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

Paperpile.MetaPanel = Ext.extend(Ext.form.FormPanel, {

  initComponent: function() {

    // This is the combobox of the publication type which is always
    // shown
    var typeComboLine = {
      tag: 'tbody',
      children: [{
        tag: 'tr',
        children: [{
          tag: 'td',
          cls: 'label',
          html: 'Type'
        },
        {
          tag: 'td',
          id: 'type-combo',
          cls: 'field',
          colspan: 5
        },
        ]
      }]
    };

    var tableContent =  [typeComboLine];

    
    // If we are editing the data for new PDF, we show information on
    // the PDF in the caption of the table
    //if (this.data.pdf && !this.data._imported) {
    if (this.data.match_job){
      tableContent.unshift({
        tag: 'caption',
        cls: 'notice',
        html: '<b>Add data for</b> ' + this.data.pdf + '<div style="float:right;"><a href="#" id="pdf-view-button" class="pp-textlink">View PDF</a></div>',
      });
    }
   

    Ext.apply(this, {
      // The form is a table that consists of several tbody
      // elements to group specific blocks; the first tbody is
      // the selection list for the publication type and is
      // always present
      html: [{
        tag: 'table',
        cls: 'pp-meta-form',
        id: "form-table",
        children: tableContent
      },
      ],

      bbar: [{
        xtype: 'tbfill'
      },
        new Ext.Button({
          id: 'save_button',
          text: 'Save',
          cls: 'x-btn-text-icon save',
          disabled: (this.data.title) ? false : true,
          listeners: {
            click: {
              fn: this.onSave,
              scope: this
            }
          },
        }),
        new Ext.Button({
          id: 'cancel_button',
          text: 'Cancel',
          cls: 'x-btn-text-icon cancel',
          listeners: {
            click: {
              fn: this.onCancel,
              scope: this
            }
          },
        }), ],
      autoScroll: true,
      border: false,
      bodyBorder: false,
      bodyStyle: {
        background: '#ffffff',
        padding: '20px'
      },

    });

    Paperpile.MetaPanel.superclass.initComponent.call(this);

    this.on('afterrender',
      function() {
        global = this.data;
        this.initForm(this.data['pubtype']);
      },
      this);

  },

  // Creates type selection combo box, renders the form for the
  // initial publication type and sets up event listeners
  initForm: function(pubType) {

    var pubTypes = Paperpile.main.globalSettings.pub_types;

    var list = ['ARTICLE', 'BOOK', 'INCOLLECTION', 'INBOOK',
      'PROCEEDINGS', 'INPROCEEDINGS',
      'MASTERSTHESIS', 'PHDTHESIS',
      'MANUAL', 'TECHREPORT', 'UNPUBLISHED', 'MISC'];

    var t = [];
    for (var i = 0; i < list.length; i++) {
      t.push([list[i], pubTypes[list[i]].name, pubTypes[list[i]].info]);
    }

    var cb = new Ext.form.ComboBox({
      id: 'type-input',
      renderTo: 'type-combo',
      width: 300,
      editable: false,
      displayField: 'name',
      valueField: 'id',
      forceSelection: true,
      triggerAction: 'all',
      disableKeyFilter: true,
      mode: 'local',
      hiddenName: 'pubtype',
      value: pubType,
      renderTo: 'type-combo',
      store: new Ext.data.ArrayStore({
        idIndex: 0,
        fields: ['id', 'name', 'info'],
        data: t
      }),
      tpl: new Ext.XTemplate(
        '<tpl for="."><div class="x-combo-list-item">{name}<br><span style="color:gray;">{info}</span></div></tpl>'),
      listeners: {
        select: {
          fn: function(combo, record, index) {
            this.data.pubtype = record['id'];
            this.renderForm(record['id']);
          },
          scope: this,
        }
      },
    });

    cb.on('focus', this.onFocus, this);

    if (Ext.get('pdf-view-button')) {
      Ext.get('pdf-view-button').on('click', function() {
        Paperpile.utils.openFile(this.data.pdf);
      },
      this);
    }

    this.renderForm(pubType);

    Ext.get('form-table').on('click', this.onClick, this);

  },

  // Creates the table structure of the form and renders the input
  // forms to the table cells
  renderForm: function(pubType) {

    var tbodies = [];

    // Get table structure for main fields 
    Ext.each(this.renderMainFields(pubType),
    function(t) {
      tbodies.push(t);
    });

    // Get table structure for the identifiers
    this.activeIdentifiers = [];
    var identifiers = Paperpile.main.globalSettings.pub_identifiers;
    for (var i = 0; i < identifiers.length; i++) {
      if (this.data[identifiers[i]]) {
        this.activeIdentifiers.push(identifiers[i]);
      }
    }

    tbodies.push(this.renderIdentifiers());

    // Remove all tbodies except the first one which holds the
    // pubtype selection combo; allows to redraw the form when a
    // new pubtype is selected
    var counter = 0;
    Ext.get('form-table').select('tbody').each(
      function(el) {
        if (counter == 0) {
          counter = 1;
          return;
        }
        el.remove();
      });

    // Write tbodies to the dom. Ext.DomHelper.append should take a
    // list, but this does not seem to work in Safari/Chrome. So
    // we loop over the entries and append them manually
    for (var i = 0; i < tbodies.length; i++) {
      Ext.DomHelper.append('form-table', tbodies[i]);
    }

    this.createInputs(pubType);

  },

  // This function actually creates the input objects and renders it
  // to the table cells
  createInputs: function(pubType) {

    var genericTips = Paperpile.main.globalSettings.pub_tooltips;
    var customTips = Paperpile.main.globalSettings.pub_types[pubType].tooltips;

    for (var field in Paperpile.main.globalSettings.pub_fields) {

      elField = Ext.get(field + '-field');
      elInput = Ext.get(field + '-input');

      if (!elField || elInput) {
        continue;
      }

      var w = elField.getWidth() - 30;

      var hidden = false;

      var config = {
        id: field + '-input',
        name: field,
        width: w,
        enableKeyEvents: true,
        value: this.data[field],
      };

      if (field === 'abstract') {
        Ext.DomHelper.append(field + '-field', {
          tag: 'a',
          href: "#",
          cls: 'pp-textlink',
          id: 'abstract-toggle',
          html: 'Show'
        });
        config.hidden = true;
      }

      if (field === 'journal') {

        Ext.apply(config, {
          displayField: 'short',
          valueField: 'short',
          minListWidth: w,
          store: new Ext.data.Store({
            proxy: new Ext.data.HttpProxy({
              url: Paperpile.Url('/ajax/misc/journal_list')
            }),
            reader: new Ext.data.JsonReader({
              root: 'data',
              id: 'short',
              fields: ['short', 'long'],

            },
            [{
              name: 'short',
              mapping: 'short'
            },
            {
              name: 'long',
              mapping: 'long'
            },
            ])
          }),
          tpl: new Ext.XTemplate(
            '<tpl for="."><div class="x-combo-list-item"><b>{short}</b><br>{long}</div></tpl>'),
        });
      }

      var input = null;

      if (field === 'abstract' || field === 'authors') {
        config.grow = 'true';
        input = new Ext.form.TextArea(config);
      }

      if (field === 'journal') {
        input = new Ext.form.ComboBox(config);
      }

      if (!input) {
        input = new Ext.form.TextField(config);
      }

      input.on('focus', this.onFocus, this);

      input.render(field + '-field', 0);

      if (field === 'title') {
        input.on('keyup', function(field, e) {
          Ext.getCmp('save_button').setDisabled(field.getValue() == '');
        },
        this);
      }

      // Tricky to put tooltip next to combobox; turned off
      // tooltip for journal for now
      if (field !== 'journal') {

        var displayText = genericTips[field];

        if (customTips) {
          if (customTips[field]) {
            displayText = customTips[field];
          }
        }

        Ext.DomHelper.append(field + '-field', {
          tag: 'div',
          cls: 'pp-tooltip-link',
          id: field + '-tooltip',
          html: '?',
          hidden: hidden
        });

        new Ext.ToolTip({
          target: field + '-tooltip',
          minWidth: 50,
          maxWidth: 300,
          html: displayText,
          anchor: 'left',
          showDelay: 0,
          hideDelay: 0
        });
      }
    }
  },

  // Get table structure for the 'main' fields (i.e. everything except pubtype and identifiers)
  renderMainFields: function(pubType) {

    var pubFields = Paperpile.main.globalSettings.pub_types[pubType].fields;
    var fieldNames = Paperpile.main.globalSettings.pub_fields;
    var customNames = Paperpile.main.globalSettings.pub_types[pubType].labels;

    var trs = []; // Collects the rows to add for each tbody
    var tbodies = [];

    // Loop over the rows in the yaml configuration
    for (var i = 0; i < pubFields.length; i++) {
      var row = pubFields[i];

      // Section boundaries are marked by a dash "-" in the yaml configuration
      if (row[0] === '-') {
        // We add an empty line as separator. Tbody elements
        // can't be styled as normal block element so we need this hack
        trs.push({
          tag: 'tr',
          children: [{
            tag: 'td',
            colspan: '6',
            cls: 'separator',
          }]
        });

        // Push all collected rows to the list of tbodies
        tbodies.push({
          tag: 'tbody',
          children: trs
        })
        trs = [];

        continue;
      }

      var tr = {
        tag: 'tr',
        children: []
      };

      // Loop over columns in the yaml configuration
      for (var j = 0; j < row.length; j++) {
        var t = row[j].split(":");
        var field = t[0];
        var colSpan = t[1];

        var displayText = fieldNames[field];

        if (customNames) {
          if (customNames[field]) {
            displayText = customNames[field];
          }
        }

        if (!field) {
          tr.children.push('<td>&nbsp;</td><td>&nbsp;</td>');
        } else {
          tr.children.push({
            tag: 'td',
            id: field + '-label',
            cls: 'label',
            html: displayText
          },
          {
            tag: 'td',
            id: field + '-field',
            cls: 'field',
            colspan: colSpan - 1,
          });
        }
      }

      trs.push(tr);
    }

    return (tbodies);

  },

  // Gets the table structure of the identifiers
  renderIdentifiers: function() {

    var fieldNames = Paperpile.main.globalSettings.pub_fields;
    var identifiers = Paperpile.main.globalSettings.pub_identifiers;
    var tooltips = Paperpile.main.globalSettings.pub_tooltips;

    var trs = [];

    for (var i = 0; i < this.activeIdentifiers.length; i++) {

      var field = this.activeIdentifiers[i];

      trs.push({
        tag: 'tr',
        children: [{
          tag: 'td',
          id: field + '-label',
          cls: 'label',
          html: fieldNames[field]
        },
        {
          tag: 'td',
          id: field + '-field',
          cls: 'field',
          colspan: 3,
        },
        {
          tag: 'td',
          colspan: 2,
        }]
      });
    }

    var lis = [];

    for (var i = 0; i < identifiers.length; i++) {

      var active = 0;
      for (j = 0; j < this.activeIdentifiers.length; j++) {
        if (this.activeIdentifiers[j] === identifiers[i]) {
          active = 1;
          break;
        }
      }

      if (active) {
        continue;
      }

      lis.push({
        tag: 'li',
        children: [{
          tag: 'a',
          cls: 'pp-textlink',
          href: "#",
          id: identifiers[i] + '-add-id',
          html: fieldNames[identifiers[i]],
          'ext:qtip': tooltips[identifiers[i]],
        }]
      });
    }

    if (lis.length > 0) {
      trs.push({
        tag: 'tr',
        children: [{
          tag: 'td',
          cls: 'label',
          html: '&nbsp;'
        },
        {
          tag: 'td',
          colspan: 5,
          children: [{
            tag: 'div',
            cls: 'pp-menu pp-menu-horizontal',
            children: [{
              tag: 'a',
              href: '#',
              html: 'Add identifier',
            },
            {
              tag: 'ul',
              children: lis,
            }]
          }]
        }]
      });
    }

    return ({
      tag: 'tbody',
      id: 'identifier-group',
      children: trs
    });
  },

  onFocus: function(field) {
    Ext.select('table#form-table td').removeClass("active");
    var f = field.el.findParent('td.field', 3, true);
    f.addClass("active");
    f.prev().addClass("active");
  },

  // Generic handler for click events. Depending on the id of the
  // clicked element different actions are carried out
  onClick: function(e) {

    var el = Ext.get(e.target);

    var m = el.id.match(/(.*)-add-id/);

    if (m) {
      var field = m[1];
      Ext.get('identifier-group').remove();
      this.activeIdentifiers.push(field);
      Ext.DomHelper.append('form-table', this.renderIdentifiers());
      this.createInputs(this.data.pubtype);
      Ext.get(field + '-input').focus();
      return;
    }

    m = el.id.match(/(.*)-toggle/);

    if (m) {
      var field = m[1];
      Ext.getCmp(field + '-input').show();
      Ext.get(field + '-toggle').remove();
    }

  },

  onSave: function() {

    this.getForm().waitMsgTarget = true;

    var msg = '';
    var url;
    var params;

    // If we are given a grid_id we are updating an entry
    if (this.grid_id) {
      url = Paperpile.Url('/ajax/crud/update_entry');
      params = {
        guid: this.data['guid'],
        grid_id: this.grid_id,
      };
      msg = 'Updating database';
    }
    // else we are creating a new one
    else {
      url = Paperpile.Url('/ajax/crud/new_entry');
      msg = 'Adding new entry to database';
      if (this.data.match_job) {
        params = {pdf: this.data.pdf, match_job: this.data.match_job};
      }
    }

    Paperpile.status.showBusy(msg);

    this.getForm().submit({
      url: url,
      scope: this,
      params: params,
      success: this.onSuccess,
      failure: function(form, action) {
        Paperpile.main.onError(action.response);
      },
    });
  },

  onSuccess: function(form, action) {
    var json = Ext.util.JSON.decode(action.response.responseText);
    this.callback.createDelegate(this.scope, ['SAVE', json.data])();
  },

  onCancel: function() {
    this.callback.createDelegate(this.scope, ['CANCEL'])();
  },

});