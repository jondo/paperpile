Ext.define('Paperpile.pub.EditForm', {
  extend: 'Ext.panel.Panel',
  alias: 'widget.editform',
  pubTemplates: [],
  initComponent: function() {
    this.fields = {};

    Ext.apply(this, {
      cls: 'pp-edit-panel',
      autoScroll: true,
      html: this.getInitialTable(),
      border: 0,
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

    this.on('resize', this.onResize, this);
  },

  getInitialTable: function() {
    var typeComboLine = [
      '<table id="form-table" class="pp-meta-form">',
      '  <tbody>',
      '    <tr>',
      '      <td class="label" colspan=1>Type</td>',
      '      <td class="field" id="pubtype-field" colspan=3></td>',
      '      <td colspan=2>',
      '        <div id="lookup-button"></div>',
      '        <div id="lookup-status"></div>',
      '      </td>',
      '    </tr>',
      '  </tbody>',
      '</table>'].join('\n');
    return typeComboLine;
  },

  createLookupButton: function() {
    var lookupButton = Ext.widget('button', {
      itemId: 'lookup',
      text: 'Lookup Data',
      icon: '/images/icons/reload.png',
      width: 190,
      handler: this.onLookup,
      renderTo: 'lookup-button',
      scope: this
    });
    return lookupButton;
  },

  createLookupStatus: function() {
    var status = Ext.ComponentMgr.create({
      xtype: 'component',
      hidden: true,
      renderTo: 'lookup-status',
      html: '<div id="lookup-status" class="pp-lookup-status">status</div>',
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

  },

  afterRender: function(ownerCt) {
    this.callParent(arguments);

    this.pubtypeCombo = this.createPubTypeCombo();
    this.fields['pubtype'] = this.pubtypeCombo;
    this.lookupButton = this.createLookupButton();
    this.lookupStatus = this.createLookupStatus();
    this.createToolTip();
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
    var lookup = this.lookupButton;

    var origState = !lookup.isDisabled();
    var idFields = this.getLookupEnableFields();
    var hasId = false;
    Ext.each(idFields, function(key) {
      var field = this.fields[key];
      if (field && field.getValue() != '') {
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
      this.lookupButton.disable();
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
      delegate: '.pp-tooltip-link',
      constrainPosition: true,
      floating: {
        shadow: true,
        shim: true,
        constrain: true
      },
      renderTo: Ext.getBody(),
      listeners: {
        beforeshow: {
          fn: function(tip) {
            var el = Ext.fly(tip.triggerElement);
            var field = el.getAttribute('field');
            var str = this.tooltips[field];
            tip.doLayout();
            if (str) {
              //tip.body.dom.innerHTML = str;
              tip.update(str);
            }
          },
          scope: this
        },
      }
    });
  },

  setPublication: function(pub) {
    this.pub = pub;
    this.data = pub.data;
    var pubtype = pub.get('pubtype');
    var me = this;
    var doInit = function() {
      this.renderForm(pubtype);
      this.loadData(this.data);

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

  // Takes the 'data' object from the publication record, and returns a hash
  // only containing the valid field values as defined in fields.yaml.
  getStorableData: function(allData) {
    var fields = Paperpile.Settings.get('pub_fields');
    var cleanData = {};
    for (var key in fields) {
      cleanData[key] = allData[key];
    }
    return cleanData;
  },

  getPubTypeObject: function(pubtype) {
    return this.getPubTypesStore().getById(pubtype).data;
  },

  loadData: function(data) {
    Ext.iterate(this.fields, function(key, field, fields) {
      if (data[key]) {
        field.originalValue = data[key];
        field.setValue(data[key]);
      }
    },
    this);
  },

  // Creates the table structure of the form and renders the input
  // forms to the table cells
  renderForm: function(pubType) {
    var tbodies = [];

    this.tooltips = Paperpile.Settings.get('pub_tooltips');
    this.tooltips['lookup'] = 'Find complete reference for Title and Author(s). To lookup a DOI, Pubmed ID or ArXiv ID click "Add identifier" first.';
    var pubTypeTooltips = this.getPubTypeObject(pubType).tooltips;
    Ext.apply(this.tooltips, pubTypeTooltips); // Apply the custom tooltips for this pubtype
    // Get table structure for main fields 
    Ext.each(this.renderMainFields(pubType),
    function(t) {
      tbodies.push(t);
    });

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
    this.onResize();
  },

  // This function actually creates the input objects and renders it
  // to the table cells
  createInputs: function(pubType) {
    var keys = [];
    for (field in Paperpile.Settings.get('pub_fields')) {
      keys.push(field);
    }


    for (var i = 0; i < keys.length; i++) {
      var field = keys[i];
      elField = Ext.get(field + '-field');
      elInput = Ext.get(field + '-input');

      if (!elField) {
	  Paperpile.log("No el for field "+field+"!");
        continue;
      }
      if (elInput) {
        Paperpile.log("Input already exists!");
      }
      if (field == 'pubtype') {
        continue;
      }

      var w = elField.getWidth();

      var hidden = false;
      var config = {
        id: field + '-input',
        renderTo: field + '-field',
        hideLabel: true,
        width: 100,
        name: field,
        style: {
          display: 'inline-block'
        },
        enableKeyEvents: true
      };

      switch (field) {
      case 'authors':
        Ext.apply(config, {
          xtype: 'textarea',
          grow: true,
          growMin: 30
        });
        break;
      case 'abstract':
        Ext.apply(config, {
          xtype: 'textarea',
          grow: false
        });

        var el = Ext.core.DomHelper.append(field + '-label', {
          tag: 'a',
          href: "#",
          cls: 'pp-textlink',
          id: 'abstract-toggle',
          html: 'More...'
        },
          true);
        this.abstractToggle = el;
        this.mon(this.abstractToggle, 'mousedown', function(event, target, o) {
          var f = this.fields['abstract'];
          f.grow = !f.grow;
          if (f.grow) {
            Ext.fly(target).update('Less');
            f.inputEl.setHeight(250);
          } else {
            Ext.fly(target).update('More...');
            f.inputEl.setHeight(60);
          }
        },
        this);

        break;
      case 'journal':
        Ext.apply(config, {
          xtype: 'textfield'
        });
        /*
	    // Ext combobox still kind of sucks... so we'll either re-implement with a simple
	    // ajax pop-down or leave it as text input.
        Ext.apply(config, {
          xtype: 'combo',
          displayField: 'short',
          store: this.getJournalStore(),
          typeAhead: false,
          hideTrigger: true,
          autoSelect: false,
          listConfig: {
            loadingText: '',
            getInnerTpl: function() {
              return '<div class="x-combo-list-item"><b>{short}</b><br>{long}</div>';
            }
          },
        });
	  */
        break;
      default:
        Ext.apply(config, {
          xtype: 'textfield'
        });
        break;
      };

      this.fields[field] = Ext.ComponentMgr.create(config);
      var f = this.fields[field];

      this.mon(f, 'focus', this.onFocus, this);
      this.mon(f, 'blur', this.onBlur, this);
      this.mon(f, 'change', this.onChange, this);

      // Tricky to put tooltip next to combobox; turned off
      // tooltip for journal for now
      if (field !== 'journal') {
        Ext.core.DomHelper.append(field + '-field', {
          tag: 'div',
          cls: 'pp-tooltip-link',
          id: field + '-tooltip',
          field: field,
          html: '?',
          hidden: hidden
        });
      }
    }
  },

  // Get table structure for the 'main' fields (i.e. everything except pubtype and identifiers)
  renderMainFields: function(pubType) {
    var pubTypeObj = this.getPubTypeObject(pubType);
    var pubFields = pubTypeObj.fields;
    var names = Ext.clone(Paperpile.Settings.get('pub_fields'));
    Ext.apply(names, pubTypeObj.labels);

    var identifiers = Paperpile.Settings.get('pub_identifiers');
    for (var i = 0; i < identifiers.length; i++) {
	var id = identifiers[i];
	if (this.data[id] != '') {
	    pubFields.push([identifiers[i] + ":6"]);
	}
    }
    pubFields.push(['-']);

    Paperpile.log(pubFields);

    var tbodies = [];
    var trs = [];

    // Loop over the rows in the yaml configuration
    for (var i = 0; i < pubFields.length; i++) {
      var row = pubFields[i];

      // Section boundaries are marked by a dash "-" in the yaml configuration
      if (row[0] === '-') {
        // We add an empty line as separator. Tbody elements
        // can't be styled as normal block element so we need this hack
        tbodies.push(['<tbody class="form">',
          trs.join('\n'),
          '  <tr>',
          '    <td colspan=6 class="separator"></td>',
          '  </tr>',
          '</tbody>'].join('\n'));
        trs = [];
        continue;
      }

      var html = ['<tr>'];

      // Loop over columns in the yaml configuration
      for (var j = 0; j < row.length; j++) {
        var t = row[j].split(":");
        var field = t[0];
        var colSpan = t[1];

        var displayText = names[field];

        if (!field) {
          html.push('<td>&nbsp;</td><td>&nbsp;</td>');
        } else {
          html.push([
            '<td id="' + field + '-label" class="label">',
            displayText,
            '</td>',
            '<td id="' + field + '-field" class="field"',
            ' colspan=' + (colSpan - 1) + '></td>'].join('\n'));
        }
      }

      html.push('</tr>');
      trs.push(html.join('\n'));
    }

    return tbodies;
  },

  // Gets the table structure of the identifiers
  renderIdentifiers: function(activeIdentifiers) {
    var fieldNames = Paperpile.Settings.get('pub_fields');
    var identifiers = Paperpile.Settings.get('pub_identifiers');
    var tooltips = Paperpile.Settings.get('pub_tooltips');

    var trs = [];

    for (var i = 0; i < activeIdentifiers.length; i++) {
      var field = activeIdentifiers[i];

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
      for (j = 0; j < activeIdentifiers.length; j++) {
        if (activeIdentifiers[j] === identifiers[i]) {
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
          //          'ext:qtip': tooltips[identifiers[i]],
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

  createPubTypeCombo: function() {
    var combo = Ext.widget('combo', {
      renderTo: 'pubtype-field',
      hideLabel: true,
      style: {
        display: 'inline-block'
      },
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
	  /*
        mousedown: {
	    
          // Allow clicks in the input area to toggle the combo open/closed.
          fn: function(event) {
            var target = Ext.fly(event.target);
            if (!target.is('input')) {
              // Ignore clicks on the trigger DIV.
              return;
            }
            var combo = this.pubtypeCombo;
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
	  */
        select: {
          fn: function(combo, data, index) {
            if (combo.getValue() == '') {
              return;
            }
            var pubtype = combo.getValue();
            Ext.defer(function() {
              this.data.pubtype = pubtype;
              this.renderForm(pubtype);
              this.loadData(this.data);
            },
            10,
            this);
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
    var combo = Ext.widget('textfield', Ext.apply(this.fieldDefaults, {
      name: 'journal',
      displayField: 'short',
      valueField: 'long',
      store: this.getJournalStore()
    }));
    return combo;
  },

  getJournalStore: function() {
    var existingStore = Ext.getStore('journals');
    if (existingStore) {
      return existingStore;
    }

    Ext.regModel('Journal', {
      fields: ['short', 'long'],
      idProperty: 'short'
    });
    var store = new Ext.data.Store({
      model: 'Journal',
      remoteSort: true,
      storeId: 'journals',
      proxy: {
        type: 'ajax',
        url: Paperpile.Url('/ajax/misc/journal_list'),
        reader: {
          type: 'json',
          root: 'data'
        }
      }
    });
    return store;
  },

  onResize: function() {
    Ext.get('form-table').setWidth(this.getWidth() - 100)
    Ext.get('form-table').select('tbody').setWidth(this.getWidth() - 100);

    for (var key in this.fields) {
      var field = this.fields[key];
      var td = field.getEl().up('td');
      var width = td.getWidth() - 40;
      var qmark = td.down('.pp-tooltip-link');
      if (qmark) {
        width = width - qmark.getWidth();
      }
      field.setWidth(width);
    }
  },

  onChange: function(field) {
    if (field.isDirty()) {
      var f = field.el.up('td.field');
      f.addCls("dirty");
      f.prev().addCls("dirty");
    } else {
      var f = field.el.up('td.field');
      f.removeCls("dirty");
      f.prev().removeCls("dirty");
    }
    this.onFieldChange();
  },

  onFocus: function(field) {
    var f = field.el.up('td.field');
    f.addCls("active");
    f.prev().addCls("active");
  },

  onBlur: function(field) {
    var f = field.el.up('td.field');
    f.removeCls("active");
    f.prev().removeCls("active");
    /*
    if (this.isLastField(field)) {
      var typeField = Ext.getCmp('type-input');
      typeField.focus(10);
    }
    */
  },

  // Returns true if the passed field is the last one in the form.
  isLastField: function(field) {
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

    var oldData = this.getStorableData(this.data);

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

          if (data.pubtype != oldData.pubtype) {
            this.renderForm(data.pubtype);
            this.layoutForm(data.pubtype, oldData);
          }

          this.loadData(data);

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

        this.undoData = oldData;
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
    for (var field in this.fields) {
      if (this.fields[field]) {
        this.fields[field].destroy();
      }
    }
    this.fields = {};
  },

  destroy: function() {
    this.callParent(arguments);
  },

});