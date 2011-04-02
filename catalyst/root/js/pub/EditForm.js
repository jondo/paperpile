Ext.define('Paperpile.pub.EditForm', {
  extend: 'Ext.form.FormPanel',
  alias: 'widget.editform',
	    pubTemplates: [],
  initComponent: function() {
    this._fcs = {};

    Ext.apply(this, {
      cls: 'pp-edit',
      autoScroll: true,
      bodyStyle: 'padding:20px;',
      bodyBorder: 0,
      dockedItems: [{
        xtype: 'toolbar',
        border: 0,
        width: 250,
        style: {
          //'background-color': 'white'
        },
        dock: 'bottom',
        items: ['->', {
          id: 'save',
          itemId: 'save',
          text: 'Save',
          icon: '/images/icons/accept.png',
          disabled: true,
          handler: this.onSave,
          scope: this
        },
        {
          itemId: 'cancel',
          text: 'Cancel',
          handler: this.onCancel,
          scope: this
        }]
      }]
    });

    this.callParent(arguments);
    //    this.getForm().on('dirtychange', this.onStateChange, this);
    this.initFields();

    this.on('resize', this.onResize, this);
  },

  createLookupButton: function() {
    this.lookupButton = Ext.widget('button', {
      itemId: 'lookup',
      text: 'Lookup Data',
      icon: '/images/icons/reload.png',
      width: 190,
      handler: this.onLookup,
      scope: this
    });
    return this.lookupButton;
  },

  createLookupStatus: function() {
    var status = Ext.ComponentMgr.create({
      xtype: 'component',
      hidden: true,
      html: '<div id="lookup-status" cls="pp-lookup-status">status</div>',
    });
    this.lookupStatus = status;
    this.lookupStatus.on('click', this.onLookupCancel, this, {
      element: 'el',
      delegate: '.pp-cancel-lookup'
    });
    return status;
  },

  onLookupCancel: function() {
    if (this.lookupRequest) {
      Ext.Ajax.abort(this.lookupRequest);
      this.enable();
      this.lookupStatus.update("Lookup canceled.");
      this.lookupRequest = undefined;
    }
  },

  onRender: function(ownerCt) {
    this.callParent(arguments);
    this.createToolTip();

    Paperpile.log(this.tpl);
  },

  onStateChange: function(form, dirty) {
    var save = this.getDockedItems()[0].getComponent('save');
    var cancel = this.getDockedItems()[0].getComponent('cancel');
    //Paperpile.log("Enabledd!");
    save.enable();
    cancel.setText('Cancel');

    if (!this.getForm().isDirty()) {
      //Paperpile.log("Disabled!");
      save.disable();
      cancel.setText('Close');
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
    return['title', 'doi', 'pmid', 'arxivid', 'linkout'];
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
    var pubtype = pub.get('pubtype');
    var me = this;
    var doInit = function() {
      me.getForm().trackResetOnLoad = true;
      //me.layoutForm(pubType, pub.data);
      this.layoutTable(pubtype, pub.data);

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
        Paperpile.log(index + "  " + widths[index]);
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
      items: items
    };
  },

  createPubTypeCombo: function() {
    var combo = Ext.widget('combo', Ext.apply(this.fieldDefaults, {
      name: 'pubtype',
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
        mousedown: {
          // Allow clicks in the input area to toggle the combo open/closed.
          fn: function(event) {
            var target = Ext.fly(event.target);
            if (!target.is('input')) {
              // Ignore clicks on the trigger DIV.
              return;
            }
            var combo = this.pubFields['pubtype'];
	    event.stopEvent();
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
            if (combo.getValue() == '') {
              return;
            }
            var pubtype = combo.getValue();
            Ext.defer(function() {
              this.data.pubtype = pubtype;
              this.layoutTable(pubtype, this.data);
            },
            10,
            this);
          },
          scope: this,
        }
      },
    }));
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
    var pubTypes = Paperpile.Settings.get('pub_types');
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

  createJournalCombo: function() {
    Ext.regModel('Journal', {
      fields: ['short', 'long'],
      idProperty: 'short'
    });
    var combo = Ext.widget('textfield', Ext.apply(this.fieldDefaults, {
      name: 'journal',
      /*
      // TODO: Once ExtJS' combobox doesn't suck, update this to become an auto-complete
      // field.
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
      */
    }));
    return combo;
  },

  initFields: function() {
    if (this.pubFields) {
      for (var key in this.pubFields) {
        var field = this.pubFields[key];
        field.destroy();
        delete this.pubFields[key];
      }
    }
    this.pubFields = {};

    var names = Paperpile.Settings.get('pub_fields');
    names['lookup'] = 'Lookup Online';
    this.pubFields = {};
    this.getForm()._fields = new Ext.util.MixedCollection();
    for (var key in names) {
      var field = this.createField(key, names[key]);
      this.pubFields[key] = field;
      if (field instanceof Ext.form.BaseField) {
	  //        this.getForm()._fields.add(field);
      }
    }
  },

  layoutTable: function(pubtype, data) {

    if (!this.pubTemplates[pubtype]) {

    var pubTypeObj = this.getPubTypesStore().getById(pubtype).data;
    var idFields = Paperpile.Settings.get('pub_identifiers');
    var names = Paperpile.Settings.get('pub_fields');
    Ext.apply(names, pubTypeObj.labels); // Apply the custom labels for this pubtype
    this.tooltips = Paperpile.Settings.get('pub_tooltips');
    this.tooltips = {};
    this.tooltips['lookup'] = 'Find complete reference for Title and Author(s). To lookup a DOI, Pubmed ID or ArXiv ID click "Add identifier" first.';
    Ext.apply(this.tooltips, pubTypeObj.tooltips); // Apply the custom tooltips for this pubtype
    var fieldLayout = Ext.clone(pubTypeObj.fields);

    fieldLayout.unshift(['pubtype:3', '.', 'lookup:2']);

    var usedFields = [];
    var rows = [];
    for (var i = 0; i < fieldLayout.length; i++) {
      var row = fieldLayout[i];
      var rowItems = [];
      var rowWidths = [];
      for (var j = 0; j < row.length; j++) {
        var cell = row[j];
        if (cell == '-') {
	  rowItems.push('');
          rowWidths.push(6);
        } else if (cell == ' ' || cell == '') {
          rowItems.push('');
          rowWidths.push(2);
        } else if (cell == '.') {
          rowItems.push('');
          rowWidths.push(1);
        } else {
          var toks = cell.split(':');
          var key = toks[0];

          usedFields.push(key);
          var div = ['<div class="pp-field-label" id="pp-'+key+'-label">',
		     '</div>',
		     '<div class="pp-field" id="pp-' + key + '">',
		     '</div>'].join('');
          if (this.tooltips[key]) {
            //            div += '<span class="pp-qmark" field="' + key + '">?</span>';
          }
          rowItems.push(div);
          rowWidths.push(toks[1]);
        }
      }
      var tr = this.createTableRow(rowItems, rowWidths);
      rows.push(tr);
    }

    var str = ['<table width="100%" border="1"><tbody>',
      rows.join("\n"),
      '</tbody></table>'].join('');

        var tpl = new Ext.XTemplate(str, {
		compiled: true,
		usedFields: usedFields,
		names: names
        });
	this.pubTemplates[pubtype] = tpl;
    } else {

    }

      this.tpl = this.pubTemplates[pubtype];
      this.tpl.overwrite(this.body, {});

      var usedFields = this.tpl.usedFields;
      var names = this.tpl.names;
    for (var i = 0; i < usedFields.length; i++) {
      var key = usedFields[i];
      var field = this.pubFields[key];
      var lblEl = this.getEl().down('#pp-'+key+'-label');
      lblEl.update(names[key]);
      var el = this.getEl().down('#pp-' + key);
      if (field.rendered) {
	          field.getEl().replace(el);
	if (field instanceof Ext.form.BaseField) {
	    //field.inputEl.dom.value = data[key];
	    	    field.originalValue = data[key];
		    field.setValue(data[key]);
	}
      } else {
        field.render(el);
      }
    }

    this.onResize();
    //this.getForm().setValues(data);
    this.onStateChange();
  },

  onResize: function() {
    for (var key in this.pubFields) {
      var field = this.pubFields[key];
      if (field.rendered && field instanceof Ext.form.BaseField) {
	  var cell = field.el.up('td');
	  Paperpile.log(cell.getWidth());
	  field.setWidth(cell.getWidth() - 80 - 25);
      }
    }
  },

  createTableRow: function(items, widths) {
    var str = '<tr>';

    for (var i = 0; i < items.length; i++) {
      var cols = widths[i];
      var width = cols / 6 * 100;
      str += '<td colspan="' + widths[i] + '" width="' + width + '%">';
      str += items[i];
      str += '</td>';
    }
    str += '</tr>';
    Paperpile.log(str);
    return str;
  },

  createField: function(key, label) {
    switch (key) {
    case 'journal':
      return this.createJournalCombo();
      break;
    case 'pubtype':
      return this.createPubTypeCombo();
      break;
    case 'lookup':
      return Ext.create('Ext.container.Container', {
        items: [
          this.createLookupButton(), this.createLookupStatus()]
      });
      break;
    default:
      var field = Ext.create('Ext.form.Text', Ext.apply(this.fieldDefaults, {
        name: key,
        hideLabel: true,
	preventMark: true,
	autoFitErrors: false
      }));
      return field;
      break;
    };
  },

  layoutForm: function(pubType, pubData) {

    var pubTypeObj = this.getPubTypesStore().getById(pubType).data;
    var idFields = Paperpile.Settings.get('pub_identifiers');
    var names = Paperpile.Settings.get('pub_fields');
    //    Ext.apply(names, pubTypeObj.labels); // Apply the custom labels for this pubtype
    //this.tooltips = Paperpile.Settings.get('pub_tooltips');
    this.tooltips = {};
    //    this.tooltips['lookup'] = 'Find complete reference for Title and Author(s). To lookup a DOI, Pubmed ID or ArXiv ID click "Add identifier" first.';
    //    Ext.apply(this.tooltips, pubTypeObj.tooltips); // Apply the custom tooltips for this pubtype
    var fieldLayout = pubTypeObj.fields;

    // Remove all field objects without destroying.
    var keepFields = {
      pubtype: true,
      lookup: true,
      journal: true
    };
    for (var key in this._fcs) {
      var layoutItem = this.getFieldContainer(key);
      var field = this.getFieldObject(key);
      if (layoutItem.ownerCt) {
        var owner = layoutItem.ownerCt;
        owner.doRemove(layoutItem, false);
      } else {
        delete this._fcs[key];
      }
    }

    // Remove all the other crap w/ destroying.
    this.removeAll(true);
    var remainingFields = Ext.clone(names);

    fieldLayout.unshift(['pubtype:3', 'space1:1', 'lookup:2']);

    var rowsToAdd = [];
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
          rowWidths.push(.5);
          cmp = this.emptyCmp();
          cmp.height = 10;
          rowItems.push(cmp);
          rowWidths.push(.5);
        } else if (cell == ' ' || cell == '') {
          rowItems.push(this.emptyCmp());
          rowWidths.push(2 / 6);
        } else if (cell == '.') {
          rowItems.push(this.emptyCmp());
          rowWidths.push(1 / 6);
        } else {
          var toks = cell.split(':');
          var key = toks[0];
          var fieldContainer = this.getFieldContainer(key);
          fieldContainer.show();
          var fieldObj = this.getFieldObject(key);
          fieldObj.show();
          //          this.setLabel(fieldObj, names[key]);
          delete remainingFields[key];

          rowItems.push(fieldContainer);
          rowWidths.push(toks[1] / 6);
        }
      }
      rowsToAdd.push(this.createRow(rowItems, rowWidths));
    }

    // Add filled-in fields for IDs that already exist
    for (var i = 0; i < idFields.length; i++) {
      var key = idFields[i];
      delete remainingFields[key];
      var fieldContainer = this.getFieldContainer(key);
      var fieldObj = this.getFieldObject(key);
      if (pubData[key]) {
        fieldContainer.show();
      } else {
        fieldContainer.hide();
      }
      //      this.setLabel(fieldObj, names[key]);
      rowsToAdd.push(this.createRow([fieldContainer], [1]));
    }

    var fields = [];
    var widths = [];
    for (var field in remainingFields) {
      var cnt = this.getFieldContainer(field);
      cnt.hide();
      fields.push(cnt);
      widths.push(0);
    }
    rowsToAdd.push(this.createRow(fields, widths));
    this.add(rowsToAdd);

    this.getForm().setValues(pubData);
    this.onStateChange();

  },

  setLabel: function(fieldObj, label) {
    if (fieldObj.rendered && fieldObj.labelEl) {
      fieldObj.labelEl.update(label + fieldObj.labelSeparator);
    } else {
      fieldObj.fieldLabel = label;
    }
  },

  addHidden: function(keys) {
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      var field = this.getFieldObject(key);
      this.add(field);
    }
  },

  getFieldObject: function(key) {
    var fieldContainer = this.getFieldContainer(key);
    if (! (fieldContainer instanceof Ext.form.BaseField) && fieldContainer.items) {
      var fieldChild = fieldContainer.items.getAt(0);
      return fieldChild;
    } else {
      //Paperpile.log("No tooltip, just the field.");
      return fieldContainer;
    }
  },

  getFieldContainer: function(key) {
    if (this._fcs[key] !== undefined) {
      return this._fcs[key];
    } else {
      Paperpile.log("Creating new " + key);
      var cfg;

      switch (key) {
      case 'journal':
        this._fcs[key] = this.createJournalCombo();
        return this._fcs[key];
        break;
      case 'pubtype':
        this._fcs[key] = this.createPubTypeCombo();
        return this._fcs[key];
        break;
      case 'lookup':
        this._fcs[key] = Ext.ComponentMgr.create({
          xtype: 'container',
          items: [
            this.createLookupButton(), this.createLookupStatus()]
        });
        return this._fcs[key];
        break;
      case 'space1':
        this._fcs[key] = Ext.ComponentMgr.create(this.emptyCmp());
        return this._fcs[key];
        break;
      case 'abstract':
        cfg = {
          xtype: 'textarea',
          grow: false,
          height: 50
        };
        break;
      case ' ':
        cfg = this.emptyCmp();
        break;
      case 'guid':
      case 'pdf':
      case 'match_job':
        cfg = {
          xtype: 'hiddenfield',
          width: 0,
          height: 0
        };
        break;
      default:
        cfg = {
          xtype: 'textfield'
        };
      };

      cfg.name = key;

      var fieldObj;
      var layoutObj;

      if (this.tooltips[key]) {
        cfg.columnWidth = '1';
        var containerConfig = {
          xtype: 'container',
          items: [
            cfg, {
              xtype: 'component',
              html: '<div class="pp-qmark" field="' + key + '">?</div>'
            }]
        };

        layoutObj = Ext.ComponentMgr.create(containerConfig);
        fieldObj = layoutObj.items.getAt(0);
      } else {
        fieldObj = Ext.ComponentMgr.create(cfg);
        layoutObj = fieldObj;
      }

      this._fcs[key] = layoutObj;
      this.mon(fieldObj, 'focus', this.onFocus, this);
      this.mon(fieldObj, 'blur', this.onBlur, this);
      this.mon(fieldObj, 'change', this.onFieldChange, this);

      return layoutObj;
    }
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

  onLookup: function() {
    this.lookupStatus.show();
    if (this.lookupStatus.rendered) {
      this.lookupStatus.el.removeCls(['pp-lookup-status-failed', 'pp-lookup-status-success']);
    }
    this.lookupStatus.update([
      '<span style="color: black !important;">',
      '<img src="/images/waiting_yellow.gif" style="vertical-align:middle; margin-right: 4px;"/>',
      'Searching online...',
      ' <a class="pp-textlink pp-cancel-lookup"',
      '  style="cursor:pointer !important; color:#0015FE !important;">',
      '  cancel',
      '</a>',
      '</span>'].join(''));

    var oldData = this.getForm().getValues();
    this.disable();
    this.lookupButton.disable();

    this.lookupRequest = Paperpile.Ajax({
      url: Paperpile.Url('/ajax/crud/lookup_entry'),
      scope: this,
      params: oldData,
      success: function(response) {
        this.enable();
        this.lookupButton.enable();
        var json = Ext.decode(response.responseText);
        var data = json.data;

        var success_plugin = json.success_plugin;
        if (success_plugin) {
          var dataDiff = [];
          for (var field in data) {
            if (data[field]) {
              if (oldData[field] != data[field] && !field.match('citekey') && !field.match('^_') && !field.match('sha1')) {
                dataDiff.push({
                  field: field,
                  oldVal: oldData[field] || '',
                  newVal: data[field]
                });
              }
            }
          }

          // A blank GUID is sent back from the server... don't let it overwrite our own.
          if (!data.guid) {
            delete data.guid;
          }

          this.getForm().trackResetOnLoad = true;
          if (data.pubtype != oldData.pubtype) {
            this.layoutForm(data.pubtype, oldData);
          }
          this.getForm().trackResetOnLoad = false;
          this.getForm().setValues(data);
          this.getForm().trackResetOnLoad = true;

          this.lookupStatus.update('Found reference on ' + success_plugin + ".");
          this.lookupStatus.removeCls('pp-lookup-status-failed');
          this.lookupStatus.addCls('pp-lookup-status-success');
          this.addWhatChangedToolTip('lookup-status', dataDiff);
        } else {
          this.lookupStatus.removeCls('pp-lookup-status-success');
          this.lookupStatus.addCls('pp-lookup-status-failed');
          var msg = json.error || 'Could not find reference online.';
          this.lookupStatus.update(msg);
        }
      },
      failure: function(response) {
        this.enable();
        this.lookupButton.enable();
        // Explicitly handle timeout (e.g. network hangs in the backend; we don't
        // have cancel for now)
        if (!response.responseText) {
          this.lookupStatus.removeCls('pp-lookup-status-success');
          this.lookupStatus.addCls('pp-lookup-status-failed');
          this.lookupStatus.update('Network error. Make sure you are online and try again later.');
        } else {
          Paperpile.main.onError(response);
        }
      },
    });
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
      if (Ext.String.trim(obj.oldVal) == '') {
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
      var linkHTML = ' <a id="what-changed" href="#">(what changed?)</a>';
      Ext.core.DomHelper.append(this.lookupStatus.getEl(), linkHTML);
      if (this.whatChangedToolTip !== undefined) {
        this.whatChangedToolTip.destroy();
      }
      this.whatChangedToolTip = new Ext.ToolTip({
        target: 'what-changed',
        minWidth: 50,
        maxWidth: 500,
        html: listHTML,
        anchor: 'top',
        showDelay: 0,
        dismissDelay: 0,
        hideDelay: 0
      });

    } else {
      Ext.core.DomHelper.append(this.lookupStatus.getEl(), " Nothing to update.");
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
    Paperpile.log("Saving...");

    var values = this.getForm().getValues();
    if (this.pub.data.match_job) {
      // Add data for a failed PDF import job (PDF has been imported
      // before but data is incomplete)
      Paperpile.log("Match job!");
      values.pdf = this.pub.data.pdf;
      values._pdf_tmp = this.pub.data._pdf_tmp;
      values.match_job = this.pub.data.match_job;
    }

    this.setLoading({
      msg: "Saving data..."
    });

    var msg = '';
    var url;

    if (!this.isNew) {
      url = Paperpile.Url('/ajax/crud/update_entry');
      msg = 'Updating database';
    } else {
      url = Paperpile.Url('/ajax/crud/new_entry');
      msg = 'Adding new entry to database';
    }

    //Paperpile.status.showBusy(msg);
    Paperpile.log(msg);

    Paperpile.Ajax({
      url: url,
      scope: this,
      params: values,
      method: 'POST',
      success: function(response) {
        this.setLoading(false);
        Paperpile.log("Success!");
        var f = Ext.bind(this.callback, this.scope, ['SAVE']);
        f();
      },
      failure: function(response) {
        this.setLoading(false);
        var json = Ext.decode(response.responseText);
        if (json.error) {
          if (json.error.type === 'DuplicateError') {
            Paperpile.log("Duplicate -- did not save!");
            /*
            Paperpile.status.updateMsg({
              msg: 'Did not save. A reference with this data already exists in your library.',
              hideOnClick: true
            });
	      */
            return;
          }
        }
        Paperpile.main.onError(response);
      },
    });
  },

  onCancel: function() {
    var f = Ext.bind(this.callback, this.scope, ['CANCEL']);
    f();
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