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

Paperpile.LabelWidget = Ext.extend(Object, {
  data: null,
  multipleSelection: false,
  grid: null,

  constructor: function(config) {
    Ext.apply(this, config);
  },

  getGrid: function() {
    return this.grid;
  },

  renderData: function(data) {
    this.data = data;
    this.multipleSelection = false;
    this.renderLabels();
  },

  renderMultiple: function() {
    this.multipleSelection = true;
    this.renderLabels();
  },

  // private!
  renderLabels: function() {
    var data = this.data;
    if (!data || !data._imported) return;

    var rootEl = Ext.get(this.div_id);

    if (!rootEl) {
      return;
    }

    rootEl.un('click', this.handleClick, this);
    rootEl.on('click', this.handleClick, this);

    var oldLabels = Ext.select("#" + this.div_id + " > *");
    oldLabels.remove();

    if (this.comboBox) {
      this.comboBox.destroy();
    }

    var store = Ext.StoreMgr.lookup('label_store');
    var labels;
    if (this.multipleSelection) {
      // Collect all the labels from all references selected.
      var records = this.grid.getSelectionRecords();
      var label_hash = {};
      for (var i=0; i < records.length; i++) {
        var record = records[i];
        var record_labels = record.data.labels.split(/\s*,\s*/);
        for (var j = 0; j < record_labels.length; j++) {
          var label = record_labels[j];
          label_hash[label] = 1;
        }
      }
      labels = [];
      for (var k in label_hash) {
        labels.push(k);
      }
    } else {
      labels = data.labels.split(/\s*,\s*/);
    }

    for (var i = 0; i < labels.length; i++) {
      var guid = labels[i];
      if (guid == '') continue;
      var style = '0';
      if (store.getAt(store.findExact('guid', guid))) {
        style = store.getAt(store.findExact('guid', guid)).get('style');
        name = store.getAt(store.findExact('guid', guid)).get('display_name');
      }

      var el = {
        label: 'div',
        cls: 'pp-label-box pp-label-style-' + style,
        children: [{
          label: 'div',
          cls: 'pp-label-name pp-label-style-' + style,
          html: name
        },
        {
          label: 'div',
          cls: 'pp-label-remove pp-label-style-' + style,
          html: 'x',
          action: 'remove-label',
          guid: guid
        }]
      };

      if (i == 0) {
        Ext.DomHelper.append(rootEl, el);
      } else {
        Ext.DomHelper.append(rootEl, el);
      }
    }

    this.ADD_LABEL_MARKUP = [
      '<div style="display:block;float:left;">',
      '<img style="padding:2px;" src="/images/icons/label_add_small.png" class="pp-img-action " action="add-label" ext:qtip="Add Label"/>',
      '</div>'];
    if (labels.length == 0) Ext.DomHelper.append(rootEl, el);
    else Ext.DomHelper.append(rootEl, this.ADD_LABEL_MARKUP);
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    switch (el.getAttribute('action')) {
    case 'remove-label':
      this.removeLabel(el);
      break;
    case 'add-label':
      this.addLabel(el);
      break;
    default:
      break;
    };
  },

  addLabel: function(el) {
    var list = [];
    Ext.StoreMgr.lookup('label_store').each(
      function(rec) {
        var guid = rec.data.guid;
        if (!this.multipleSelection) {
          if (this.data.labels.match(new RegExp("," + guid + "$"))) return; // ,XXX
          if (this.data.labels.match(new RegExp("^" + guid + "$"))) return; //  XXX
          if (this.data.labels.match(new RegExp("^" + guid + ","))) return; //  XXX,
          if (this.data.labels.match(new RegExp("," + guid + ","))) return; // ,XXX,
        }
        list.push([rec.data.guid, rec.data.name]);
      },
      this);
    var extEl = Ext.get(el);
    extEl.replaceWith(['<div id="pp-label-control-' + this.grid.id + '"></div>']);

    var store = new Ext.data.SimpleStore({
      fields: ['guid', 'name'],
      data: list
    });

    this.comboBox = new Ext.form.ComboBox({
      id: 'label-control-combo-' + this.getGrid().id,
      ctCls: 'pp-label-control',
      store: store,
      displayField: 'name',
      valueField: 'guid',
      typeAhead: true,
      mode: 'local',
      triggerAction: 'all',
      selectOnFocus: true,
      forceSelection: false,
      enableKeyEvents: true,

      hideLabel: true,
      hideTrigger: false,
      renderTo: 'pp-label-control-' + this.getGrid().id,
      width: 100,
      minListWidth: 100,
      listeners: {
        'specialkey': function(field, e) {
          if (e.getKey() == e.ENTER) {
            var name = field.getRawValue();

            // The user entered a new label
            if (Ext.StoreMgr.lookup('label_store').findExact('name', name) === -1) {
              var guid = Paperpile.utils.generateUUID();
              Paperpile.Ajax({
                url: '/ajax/crud/new_collection',
                params: {
                  type: 'LABEL',
                  text: name,
                  node_id: guid,
                  parent_id: 'ROOT'
                },
                success: function(response) {
                  this.commitLabel(guid, true);
                },
                scope: this
              });
            }
          } else if (e.getKey() == e.ESC) {
            this.renderLabels();
          } else if (e.getKey() == e.TAB) {
            // TODO: Tab key should trigger an add-label while keeping the editor open for further adding.
          }
        },
        'blur': function(combo) {
          this.renderLabels();
        },
        'select': function(combo, record, index) {
          this.commitLabel(record.get('guid'), false);
        },
        scope: this
      }
    });
    this.comboBox.focus();
  },

  commitLabel: function(guid, isNew) {
    this.comboBox.disable();

    var lots = this.isLargeSelection();
    if (lots) {
      Paperpile.status.showBusy("Adding label to references");
    }

    Paperpile.Ajax({
      url: '/ajax/crud/move_in_collection',
      params: {
        grid_id: this.getGrid().id,
        selection: this.getGrid().getSelection(),
        guid: guid,
        type: 'LABEL'
      },
      success: function(response) {
        if (lots) {
          Paperpile.status.clearMsg();
        }
      },
      scope: this
    });

  },

  removeLabel: function(el) {
    guid = el.getAttribute('guid');

    Ext.get(el).parent().remove();

    var lots = this.isLargeSelection();
    if (lots) {
      Paperpile.status.showBusy("Removing label from references");
    }

    Paperpile.Ajax({
      url: '/ajax/crud/remove_from_collection',
      params: {
        grid_id: this.getGrid().id,
        selection: this.getGrid().getSelection(),
        collection_guid: guid,
        type: 'LABEL'
      },
      success: function(response) {
        if (lots) {
          Paperpile.status.clearMsg();
        }
      },
      scope: this
    });
  },

  isLargeSelection: function() {
    var sel = this.getGrid().getSelection();
    var count = 0;
    if (sel == 'ALL') {
      count = this.getGrid().getTotalCount();
    } else {
      count = sel.length;
    }
    if (count > 10) {
      return true;
    }
  }

});