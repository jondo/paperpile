Ext.define('Paperpile.pub.EditForm', {
  extend: 'Ext.form.FormPanel',
  alias: 'widget.editform',
  initComponent: function() {
    this.fields = {};
    var fields = this.fields;

    fields['pubtype'] = this.createPubTypeCombo();
    fields['lookup'] = Ext.widget('button', {
      itemId: 'lookup',
      fieldLabel: 'Online Lookup',
      text: 'Lookup Data',
      icon: '/images/icons/reload.png',
      width: 190,
      handler: this.onLookup
    });

    this.firstRow = this.createRow([fields.pubtype, this.emptyCmp(), fields.lookup, this.emptyCmp()], [.5, .1, .2, .2]);

    Ext.apply(this, {
      cls: 'pp-edit',
      autoScroll: true,
      bodyStyle: 'padding:20px;',
      bodyBorder: 0,
      fieldDefaults: {
        labelWidth: 70,
        labelAlign: 'right'
      },
      dockedItems: [{
        xtype: 'toolbar',
        border: 0,
        dock: 'bottom',
        items: [{
          id: 'prev',
          text: 'Previous',
        },
        {
          id: 'next',
          text: 'Next',
        },
          '->', {
            id: 'save',
            itemId: 'save',
            text: 'Save',
            icon: '/images/icons/accept.png',
            formBind: true
          },
          {
            itemId: 'cancel',
            text: 'Cancel'
          }]
      }]
    });

    this.callParent(arguments);

    this.getForm().on('dirtychange', this.onStateChange, this);
  },

  onRender: function(ownerCt) {
    this.callParent(arguments);
    this.createToolTip();
  },

  onStateChange: function(form, dirty) {
    var save = this.getDockedItems()[0].getComponent('save');
    save.enable();

    if (!this.getForm().isDirty()) {
      save.disable();
    }

    if (!this.getForm().isValid()) {
      save.disable();
    }
  },

  onFieldChange: function() {
    // Update the lookup button: if a title or ID field exists and is non-null, allow
    // a lookup.
    var lookup = this.getFieldContainer('lookup');

    var form = this.getForm();
    var origState = !lookup.isDisabled();
    var idFields = this.getLookupEnableFields();
    var hasId = false;
    Ext.each(idFields, function(key) {
      var field = this.getFieldObject(key);
      if (field.getValue() != '') {
        hasId = true;
      }
    },
    this);

    if (hasId) {
      lookup.enable();
      if (origState == false) {
        // TODO: Show something flashy here so the user knows that they can now lookup
        // data online. Maybe pop-up a tooltip?
      }
    } else {
      this.getFieldContainer('lookup').disable();
    }
  },

  getLookupEnableFields: function() {
    return['title', 'doi', 'pmid', 'arxivid'];
  },

  createToolTip: function() {
    var me = this;
    this.toolTip = new Ext.tip.ToolTip({
      maxWidth: 200,
      showDelay: 0,
      hideDelay: 0,
      target: this.getEl(),
      delegate: '.pp-qmark',
      constrainPosition: true,
      constrain: true,
      renderTo: document.body,
      listeners: {
        beforeshow: {
          fn: function(tip) {
            var el = Ext.fly(tip.triggerElement);
            var field = el.getAttribute('field');
            var str = this.tooltips[field];
            if (str) {
		//tip.body.dom.innerHTML = str;
		tip.update(str);
            }
            //tip.doLayout();
          },
          scope: this
        },
      }
    });
  },

  onFocus: function(field) {
    field.getEl().addCls('focused');
  },

  onBlur: function(field) {
    field.getEl().removeCls('focused');
  },

  setPublication: function(pub) {
    this.pub = pub;
    this.data = pub.data;
    var pubType = pub.get('pubtype');
    var me = this;
    var doInit = function() {
      me.layoutForm(pubType, pub.data);
      me.getForm().trackResetOnLoad = true;
      me.getForm().loadRecord(pub);

      if (me.autoComplete) {
        me.onLookup();
      }

    };

    if (this.rendered) {
      doInit();
    } else {
      this.on('afterrender', doInit, this);
    }

  },

  emptyCmp: function() {
    return {
      xtype: 'component',
      html: '&nbsp;'
    };
  },

  createRow: function(items, widths) {
    Ext.each(items, function(item, index) {
      if (!widths[index] || widths[index] == 0) {
        return;
      }
      if (widths[index] <= 1) {
        Ext.apply(item, {
          columnWidth: widths[index]
        });
      } else {
        Ext.apply(item, {
          width: widths[index]
        });
      }
    });
    return {
      xtype: 'container',
      layout: 'column',
      items: items
    };
  },

  createPubTypeCombo: function() {
    var combo = Ext.widget('combo', {
      fieldLabel: 'Type',
      editable: false,
      forceSelection: true,
      triggerAction: 'all',
      disableKeyFilter: true,
      store: this.getPubTypesStore(),
      queryMode: 'local',
      itemSelector: '.x-combo-list-item',
      displayField: 'name',
      valueField: 'type',
      listConfig: {
        getInnerTpl: function(displayField) {
          return[
          '  <div class="x-combo-list-item">{name}',
          '    <br><span style="color:gray;">{info}</span>',
          '  </div>'].join('');
        }
      },
      listeners: {
        click: {
          // Allow clicks in the input area to toggle the combo open/closed.
          fn: function(event) {
            var target = Ext.fly(event.target);
            if (!target.is('input')) {
              // Ignore clicks on the trigger DIV.
              return;
            }
            var combo = this.fields['pubtype'];
            if (combo.isExpanded) {
              combo.collapse();
            } else {
              combo.expand();
            }
          },
          element: 'el',
          scope: this
        },
        select: {
          fn: function(combo, data, index) {
            this.layoutForm(combo.getValue());
          },
          scope: this,
        }
      },
    });
    return combo;
  },

  getPubTypesStore: function() {
    var existingStore = Ext.getStore('pubtypes');
    if (existingStore) {
      return existingStore;
    }

    Ext.regModel('PubType', {
      fields: ['type', 'name', 'info', 'tooltips', 'labels', 'fields'],
      idProperty: 'type'
    });
    var pubTypes = Paperpile.main.globalSettings.pub_types;
    var orderedTypes = ['ARTICLE', 'BOOK', 'INCOLLECTION', 'INBOOK',
      'PROCEEDINGS', 'INPROCEEDINGS',
      'MASTERSTHESIS', 'PHDTHESIS',
      'MANUAL', 'TECHREPORT', 'UNPUBLISHED', 'MISC'];
    var types = [];
    for (var i = 0; i < orderedTypes.length; i++) {
      var type = orderedTypes[i];
      var data = pubTypes[type];
      data['type'] = type;
      types.push(data);
    }
    var store = new Ext.data.Store({
      model: 'PubType',
      data: types,
      storeId: 'pubtypes'
    });
    return store;
  },

  onPubTypeSelect: function(cb, record) {
    Paperpile.log(record[0].data);
  },

  createJournalCombo: function() {
    Ext.regModel('Journal', {
      fields: ['short', 'long'],
      idProperty: 'short'
    });
    var combo = Ext.widget('combo', {
      displayField: 'short',
      valueField: 'long',
      store: new Ext.data.Store({
        model: 'Journal',
        proxy: {
          type: 'ajax',
          url: Paperpile.Url('/ajax/misc/journal_list'),
          reader: {
            type: 'json',
            root: 'data'
          }
        }
      }),
    })
    return combo;
  },

  // Creates type selection combo box, renders the form for the
  // initial publication type and sets up event listeners
  layoutForm: function(pubType, pubData) {
    var pubTypeObj = this.getPubTypesStore().getById(pubType).data;
    var idFields = Paperpile.main.globalSettings.pub_identifiers;
    var names = Paperpile.main.globalSettings.pub_fields;
    Ext.apply(names, pubTypeObj.labels); // Apply the custom labels for this pubtype
    this.tooltips = Paperpile.main.globalSettings.pub_tooltips;
    this.tooltips['lookup'] = 'Find complete reference for Title and Author(s). To lookup a DOI, Pubmed ID or ArXiv ID click "Add identifier" first.';
    Ext.apply(this.tooltips, pubTypeObj.tooltips); // Apply the custom tooltips for this pubtype
    var fieldLayout = pubTypeObj.fields;

    this.removeAll(false);

    // Add the pre-set first row, no matter what the pub type.
    this.add(this.firstRow);

    for (var i = 0; i < fieldLayout.length; i++) {
      var row = fieldLayout[i];

      var rowItems = [],
      rowWidths = [];
      for (var j = 0; j < row.length; j++) {
        var cell = row[j];
        if (cell == '-') {
          var cmp = this.emptyCmp();
          cmp.height = 10;
          rowItems.push(cmp);
          rowWidths.push(1);
        } else if (cell == ' ' || cell == '') {
          rowItems.push(this.emptyCmp());
          rowWidths.push(2 / 6);
        } else {
          var toks = cell.split(':');
          var key = toks[0];
          var fieldContainer = this.getFieldContainer(key);
          var fieldObj = this.getFieldObject(key);

          this.setLabel(fieldObj, names[key]);

          rowItems.push(fieldContainer);
          rowWidths.push(toks[1] / 6);
        }
      }
      this.add(this.createRow(rowItems, rowWidths));
    }

    //this.add(this.createRow([this.emptyCmp()], [1]));
    // Add filled-in fields for IDs that already exist
    for (var i = 0; i < idFields.length; i++) {
      var key = idFields[i];
      if (pubData[key]) {
        var fieldContainer = this.getFieldContainer(key);
        var fieldObj = this.getFieldObject(key);
        this.setLabel(fieldObj, names[key]);
        this.add(this.createRow([fieldContainer], [1]));
      }
    }

  },

  setLabel: function(fieldObj, label) {
    if (fieldObj.rendered) {
      fieldObj.labelEl.update(label + fieldObj.labelSeparator);
    } else {
      fieldObj.fieldLabel = label;
    }
  },

  getFieldObject: function(key) {
    var fieldContainer = this.getFieldContainer(key);
    if (! (fieldContainer instanceof Ext.form.BaseField)) {
      var fieldChild = fieldContainer.items.getAt(0);
      return fieldChild;
    } else {
      Paperpile.log("No tooltip, just the field.");
      return fieldContainer;
    }
  },

  getFieldContainer: function(key) {
    if (this.fields[key] !== undefined) {
      return this.fields[key];
    } else {
      var cfg;

      if (key == 'journal') {
        this.fields[key] = this.createJournalCombo();
        return this.fields[key];
      } else if (key == 'abstract') {
        cfg = {
          xtype: 'textarea',
          grow: false,
          height: 50
        };
      } else if (key == ' ') {
        cfg = this.emptyCmp();
      } else {
        cfg = {
          xtype: 'textfield'
        };
      }

      cfg.name = key;

      var fieldObj;
      var layoutObj;
      if (this.tooltips[key]) {
        cfg.columnWidth = '1';
        var containerConfig = {
          xtype: 'container',
          layout: 'column',
          items: [
            cfg, {
              xtype: 'component',
              html: '<div class="pp-qmark" field="' + key + '">?</div>'
            }]
        };

        layoutObj = Ext.ComponentMgr.create(containerConfig);
        fieldObj = layoutObj.items.getAt(0);
      } else {
        fieldObj = Ext.ComponentMgr.create(field);
        layoutObj = fieldObj;
      }

      this.fields[key] = layoutObj;
      this.mon(fieldObj, 'focus', this.onFocus, this);
      this.mon(fieldObj, 'blur', this.onBlur, this);
      this.mon(fieldObj, 'change', this.onFieldChange, this);

      return layoutObj;
    }
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
      Ext.core.DomHelper.append('form-table', tbodies[i]);
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
        Ext.core.DomHelper.append(field + '-field', {
          tag: 'a',
          href: "#",
          cls: 'pp-textlink',
          id: 'abstract-toggle',
          html: 'Show'
        });
        config.hidden = true;
      }

      if (field === 'journal') {

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
      input.on('change', this.onChange, this);

      input.render(field + '-field', 0);

      if (field === 'title') {
        input.on('keyup', function(field, e) {
          Ext.getCmp('save_button').setDisabled(field.getValue() == '');
          this.updateLookupButton();
        },
        this);
        input.on('change', function(field, e) {
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
        input.on('change', function(field, e) {
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

        Ext.core.DomHelper.append(field + '-field', {
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

  // Returns true if the passed field is the last one in the form.
  isLastField: function(field) {
    var lastFieldId = 'month-input';
    if (this.activeIdentifiers.length > 0) {
      lastFieldId = this.activeIdentifiers[this.activeIdentifiers.length - 1] + '-input';
    }
    if (field.id == lastFieldId) {
      return true;
    }
    return false;
  },

  onChange: function(field) {
    this.data[field.name] = field.getValue();
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
      Ext.core.DomHelper.append('form-table', this.renderIdentifiers());
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

  // Activates the lookup button if a relevant identifier is present.
  updateLookupButton: function() {

    var button = Ext.getCmp('lookup_button');

    Ext.core.DomHelper.overwrite('lookup-status', '');

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
    Ext.core.DomHelper.overwrite('lookup-status', 'Searching online...')

    this.getForm().submit({
      url: Paperpile.Url('/ajax/crud/lookup_entry'),
      scope: this,
      params: {
        guid: this.data['guid'],
      },
      success: this.onUpdate,

      failure: function(form, action) {
        this.updateLookupButton();
        this.setDisabledInputs(false);

        // Explicitly handle timeout (e.g. network hangs in the backend; we don't
        // have cancel for now)
        if (!action.response.responseText) {
          Ext.get('lookup-status').replaceClass('pp-lookup-status-success', 'pp-lookup-status-failed');
          Ext.core.DomHelper.overwrite('lookup-status', 'Network error. Make sure you are online and try again later.')
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
          if (this.data[field] != newData[field] && !field.match('citekey') && !field.match('^_') && !field.match('sha1')) {
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
      Ext.core.DomHelper.overwrite('lookup-status', 'Found reference on ' + success_plugin + ".");
      Ext.get('lookup-status').replaceClass('pp-lookup-status-failed', 'pp-lookup-status-success');
      this.addWhatChangedToolTip('lookup-status', dataDiff);
    } else {
      Ext.get('lookup-status').replaceClass('pp-lookup-status-success', 'pp-lookup-status-failed');

      var msg = json.error || 'Could not find reference online.';

      Ext.core.DomHelper.overwrite('lookup-status', msg);
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
      Ext.core.DomHelper.append(id, linkHTML);
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
      Ext.core.DomHelper.append(id, " Nothing to update.");
    }
  },

  midEllipse: function(string, length) {

    if (!string) return '';

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
    var params = {};

    if (!this.isNew) {
      url = Paperpile.Url('/ajax/crud/update_entry');
      params = {
        guid: this.data['guid'],
      };
      msg = 'Updating database';

      // Add data for a failed PDF import job (PDF has been imported
      // before but data is incomplete)
      if (this.data.match_job) {
        params.pdf = this.data.pdf;
        params.match_job = this.data.match_job;
      }
    }
    // else we are creating a new one
    else {
      url = Paperpile.Url('/ajax/crud/new_entry');
      msg = 'Adding new entry to database';

      // Add data for a failed PDF import job (job has been canceled
      // and PDF has not been imported)
      if (this.data.match_job) {
        params._pdf_tmp = this.data._pdf_tmp;
        params.match_job = this.data.match_job;
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
    var f = Ext.bind(this.callback, this.scope, ['SAVE', json.data]);
    f();
    this.cleanUp();
  },

  onCancel: function() {
    var f = Ext.bind(this.callback, this.scope, ['CANCEL']);
    f();
    this.cleanUp();
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
    this.callParent(arguments);
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