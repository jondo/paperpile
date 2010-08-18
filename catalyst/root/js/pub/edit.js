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

    this.inputs = {};

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
          colspan: 3
        },
        {
          tag: 'td',
          children: [{
            tag: 'div',
            children: [{
              tag: 'div',
              id: 'lookup-field',
              style: 'float:left;',
            },
            {
              tag: 'div',
              cls: 'pp-tooltip-link',
              id: 'lookup-tooltip',
              html: '?'
            },
            ],
          },
          {
            tag: 'div',
            id: 'lookup-status',
            cls: 'pp-lookup-status',
            style: "float:left;",
            hidden: true,
          }],
          colspan: 2
        },
        ]
      }],
    };

    var tableContent = [typeComboLine];

    // If we are editing the data for new PDF, we show information on
    // the PDF in the caption of the table
    //if (this.data.pdf && !this.data._imported) {
    if (this.data.match_job) {
      tableContent.unshift({
        tag: 'caption',
        cls: 'notice',
        html: '<b>Add data for</b> ' + this.data.pdf_name + '<div style="float:right;"><a href="#" id="pdf-view-button" class="pp-textlink">View PDF</a></div>',
      });
    }

    var config = {
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
      timeout: 5,
      bodyStyle: {
        background: '#ffffff',
        padding: '20px'
      },
    };

    // It is essential here to use initialConfig to make sure that
    // timeout is set in form object
    Ext.apply(this, Ext.apply(this.initialConfig, config));

    Paperpile.MetaPanel.superclass.initComponent.call(this);

    this.on('afterrender',
      function() {
        global = this.data;
        this.initForm(this.data['pubtype']);


        if (this.autoComplete){
          this.onLookup();
        }


	  // Swallow key events so the grid doesn't take em
	  // (i.e. ctrl-A, ctrl-C etc)
//        this.getEl().swallowEvent(['keypress', 'keydown']);
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

    this.inputs['pubtype'] = cb;

    cb.on('focus', this.onFocus, this);
    cb.on('blur', this.onBlur, this);

    if (Ext.get('pdf-view-button')) {
      Ext.get('pdf-view-button').on('click', function() {
        Paperpile.utils.openFile(this.data.pdf);
      },
      this);
    }

    var b = new Ext.Button({
      id: 'lookup_button',
      cls: 'x-btn-text-icon lookup',
      width: 190,
      renderTo: 'lookup-field',
      listeners: {
        click: {
          fn: this.onLookup,
          scope: this
        }
      },
    });

    this.lookupToolTip = new Ext.ToolTip({
      target: 'lookup-tooltip',
      minWidth: 50,
      maxWidth: 300,
      html: 'Get a complete reference from Title and Author(s) or look-up DOI, Pubmed ID or ArXiv ID.',
      anchor: 'left',
      showDelay: 0,
      hideDelay: 0
    });

    this.renderForm(pubType);

    this.updateLookupButton();

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
    Ext.get('form-table').select('tbody.form').each(
      function(el) {
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

      this.inputs[field] = input;

      input.on('focus', this.onFocus, this);
      input.on('blur', this.onBlur, this);

      input.render(field + '-field', 0);

      if (field === 'title') {
        input.on('keyup', function(field, e) {
          Ext.getCmp('save_button').setDisabled(field.getValue() == '');
          this.updateLookupButton();
        },
        this);
      }

      if (field === 'authors' || field === 'doi' || field === 'pmid' || field === 'arxivid') {
        input.on('keyup', function(field, e) {
          this.updateLookupButton();
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
          cls: 'form',
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
      cls: 'form',
      id: 'identifier-group',
      children: trs
    });
  },

  onFocus: function(field) {
    var f = field.el.findParent('td.field', 3, true);
    f.addClass("active");
    f.prev().addClass("active");
  },

  onBlur: function(field) {
    var f = field.el.findParent('td.field', 3, true);
    f.removeClass("active");
    f.prev().removeClass("active");
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

  // If either title and authors or an identifier (for now pmid, doi
  // and arxivid) is given the lookup button is activated. 
  updateLookupButton: function() {

    var button = Ext.getCmp('lookup_button');

    Ext.DomHelper.overwrite('lookup-status', '');

    var title = Ext.getCmp('title-input').getValue();
    var authors = Ext.getCmp('authors-input').getValue();

    var identifiers = {
      doi: null,
      pmid: null,
      arxivid: null
    };

    for (var id in identifiers) {
      var input = Ext.getCmp(id + '-input');
      if (input) {
        identifiers[id] = input.getValue();
      }
    }

    if (identifiers.pmid || identifiers.arxivid || identifiers.doi || (authors && title)) {
      this.activateLookupButton('Auto-complete Data');
      return;
    }
    /*
    if (identifiers.pmid) {
      this.activateLookupButton('Look-up in PubMed');
      return;
    }

    if (identifiers.arxivid) {
      this.activateLookupButton('Look-up in ArXiv');
      return;
    }

    if (identifiers.doi) {
      this.activateLookupButton('Look-up DOI');
      return;
    }

    if (authors && title) {
      this.activateLookupButton('Look-up online');
      return;
    }
*/
    button.setText('Auto-complete (not enough data)');
    button.disable();

  },

  // Activates lookup button with a highlight effect
  activateLookupButton: function(text) {

    var button = Ext.getCmp('lookup_button');
    if (text) {
      button.setText(text);
    }

    if (button.disabled) {
      Ext.get('lookup-field').parent('td').highlight();
      button.enable();
    }

  },

  onLookup: function() {

    Ext.get('lookup-status').show();

    Ext.get('lookup-status').removeClass(['pp-lookup-status-failed', 'pp-lookup-status-success']);
    Ext.DomHelper.overwrite('lookup-status', 'Searching online...')

    this.getForm().submit({
      url: Paperpile.Url('/ajax/crud/lookup_entry'),
      scope: this,
      params: {
        guid: this.data['guid'],
        grid_id: this.grid_id
      },
      success: this.onUpdate,

      failure: function(form, action) {
        this.updateLookupButton();
        this.setDisabledInputs(false);

        // Explicitly handle timeout (e.g. network hangs in the backend; we don't
        // have cancel for now)
        if (!action.response.responseText) {
          Ext.get('lookup-status').replaceClass('pp-lookup-status-success', 'pp-lookup-status-failed');
          Ext.DomHelper.overwrite('lookup-status', 'Network error. Make sure you are online and try again later.')
        } else {
          Paperpile.main.onError(action.response);
        }
      },
    });

    this.setDisabledInputs(true);
  },

  onUpdate: function(form, action) {
    var json = Ext.util.JSON.decode(action.response.responseText);

    var success_plugin = json.success_plugin;

    if (success_plugin) {

      var dataDiff = [];
      var newData = json.data;
      for (var field in newData) {
        if (newData[field]) {
          if (this.data[field] != newData[field] && !field.match('^_') && !field.match('sha1')) {
            dataDiff.push({
              field: field,
              oldVal: this.data[field],
              newVal: newData[field]
            });
          }
          this.data[field] = newData[field];
          if (field === 'pubtype') {
            Ext.getCmp('type-input').setValue(newData.pubtype);
          }
        }
      }

      this.renderForm(this.data['pubtype']);
      this.updateLookupButton();
      Ext.getCmp('save_button').setDisabled(this.data['title'] == '');
      Ext.DomHelper.overwrite('lookup-status', 'Found reference on ' + success_plugin + ".");
      Ext.get('lookup-status').replaceClass('pp-lookup-status-failed', 'pp-lookup-status-success');
      this.addWhatChangedToolTip('lookup-status', dataDiff);
    } else {
      Ext.get('lookup-status').replaceClass('pp-lookup-status-success', 'pp-lookup-status-failed');

      var msg = json.error || 'Could not find reference online.';

      Ext.DomHelper.overwrite('lookup-status', msg);
    }
    this.setDisabledInputs(false);
  },

  addWhatChangedToolTip: function(id, dataDiff) {
    var itemArray = [];

    for (var i = 0; i < dataDiff.length; i++) {
      var obj = dataDiff[i];
      var key = '<b>' + obj.field + '</b>';
      var str = '';
      var len = 100;
      var oldV = '' + this.midEllipse(obj.oldVal, len) + '';
      var newV = '' + this.midEllipse(obj.newVal, len) + '';
      if (obj.oldVal == '') {
        str = "Added " + key + ": " + newV + "";
      } else {
        str = "Changed " + key + ':<ul>';
        str += '<li style="margin-left:1em;color:gray;text-decoration:line-through;">' + oldV + "</li>";
        str += '<li style="margin-left:1em;">' + newV + "</li>";
        str += "</ul>";
      }
      str = '<li>' + str + '</li>';
      itemArray.push(str);
    }

    if (this.whatChangedToolTip) {
      this.whatChangedToolTip.destroy();
    }

    if (itemArray.length > 0) {
      var listHTML = '<ul style="">' + itemArray.join('') + '</ul>';
      var linkHTML = '<br/><a id="what-changed" href="#">(what changed?)</a>';
      Ext.DomHelper.append(id, linkHTML);
      this.whatChangedToolTip = new Ext.ToolTip({
        target: 'what-changed',
        minWidth: 50,
        maxWidth: 500,
        html: listHTML,
        anchor: 'left',
        showDelay: 0,
        dismissDelay: 0,
        hideDelay: 0
      });
    } else {
      Ext.DomHelper.append(id, " Nothing to update.");
    }
  },

  midEllipse: function(string, length) {
    if (string.length > length) {
      return string.substring(0, length / 2) + ' ... ' + string.substring(length - length / 2, length);
    } else {
      return string;
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
      };
      msg = 'Updating database';
    }
    // else we are creating a new one
    else {
      url = Paperpile.Url('/ajax/crud/new_entry');
      msg = 'Adding new entry to database';
      if (this.data.match_job) {
        params = {
          pdf: this.data.pdf,
          match_job: this.data.match_job
        };
      }
    }

    Paperpile.status.showBusy(msg);

    var noChangesMade = false;
    if (Paperpile.utils.areHashesEqual(this.getForm().data, this.data)) {
      noChangesMade = true;
    }

    this.getForm().submit({
      url: url,
      scope: this,
      params: params,
      success: this.onSuccess,
      failure: function(form, action) {
        var json = Ext.util.JSON.decode(action.response.responseText);
        if (json.error) {
          if (json.error.type === 'DuplicateError') {
            Paperpile.status.updateMsg({
              msg: 'Did not save. A reference with this data already exists in your library.',
              hideOnClick: true
            });
            return;
          }
        }
        Paperpile.main.onError(action.response);
      },
    });
  },

  onSuccess: function(form, action) {
    var json = Ext.util.JSON.decode(action.response.responseText);

    this.cleanUp();
    this.callback.createDelegate(this.scope, ['SAVE', json.data])();
    this.cleanUp();
  },

  onCancel: function() {
    this.cleanUp();
    this.callback.createDelegate(this.scope, ['CANCEL'])();
  },

  // Deletes all input objects which would live on after cancel or save otherwise.
  cleanUp: function() {
    for (var field in this.inputs) {
      if (this.inputs[field]) {
        this.inputs[field].destroy();
      }
    }
    this.inputs = {};
  },

  destroy: function() {
    if (this.lookupToolTip) {
      this.lookupToolTip.destroy();
    }
    if (this.whatChangedToolTip) {
      this.whatChangedToolTip.destroy();
    }
    Paperpile.MetaPanel.superclass.destroy.call(this);
  },

  setDisabledInputs: function(disabled) {


    Ext.getCmp('save_button').setDisabled(disabled);
    Ext.getCmp('cancel_button').setDisabled(disabled);

    for (var field in this.inputs) {
      if (this.inputs[field]) {

        // Explicitly change CSS because with disable() the value does
        // not get submitted
        if (disabled) {
          this.inputs[field].getEl().addClass('x-item-disabled');
        } else {
          this.inputs[field].getEl().removeClass('x-item-disabled');
        }
      }
    }
  }

});