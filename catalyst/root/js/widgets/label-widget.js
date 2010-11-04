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
    this.renderTags();
  },

  renderMultiple: function() {
    this.multipleSelection = true;
    this.renderTags();
  },

  // private!
  renderTags: function() {
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

    var store = Ext.StoreMgr.lookup('tag_store');
    var tags;
    if (this.multipleSelection) {
      // Collect all the tags from all references selected.
      var records = this.grid.getSelectionModel().getSelections();
      var tag_hash = {};
      for (var i = 0; i < records.length; i++) {
        var record = records[i];
        var record_tags = record.data.tags.split(/\s*,\s*/);
        for (var j = 0; j < record_tags.length; j++) {
          var tag = record_tags[j];
          tag_hash[tag] = 1;
        }
      }
      tags = [];
      for (var k in tag_hash) {
        tags.push(k);
      }
    } else {
      tags = data.tags.split(/\s*,\s*/);
    }

    for (var i = 0; i < tags.length; i++) {
      var guid = tags[i];
      if (guid == '') continue;
      var style = '0';
      if (store.getAt(store.findExact('guid', guid))) {
        style = store.getAt(store.findExact('guid', guid)).get('style');
        name = store.getAt(store.findExact('guid', guid)).get('display_name');
      }

      var el = {
        tag: 'div',
        cls: 'pp-tag-box pp-tag-style-' + style,
        children: [{
          tag: 'div',
          cls: 'pp-tag-name pp-tag-style-' + style,
          html: name
        },
        {
          tag: 'div',
          cls: 'pp-tag-remove pp-tag-style-' + style,
          html: 'x',
          action: 'remove-tag',
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
      '<img style="padding:2px;" src="/images/icons/tag_add_small.png" class="pp-img-action " action="add-tag" ext:qtip="Add Label"/>',
      '</div>'];
    if (tags.length == 0) Ext.DomHelper.append(rootEl, el);
    else Ext.DomHelper.append(rootEl, this.ADD_LABEL_MARKUP);
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    switch (el.getAttribute('action')) {
    case 'remove-tag':
      this.removeTag(el);
      break;
    case 'add-tag':
      this.addTag(el);
      break;
    default:
      break;
    };
  },

  addTag: function(el) {
    var list = [];
    Ext.StoreMgr.lookup('tag_store').each(
      function(rec) {
        var guid = rec.data.guid;
        if (!this.multipleSelection) {
          if (this.data.tags.match(new RegExp("," + guid + "$"))) return; // ,XXX
          if (this.data.tags.match(new RegExp("^" + guid + "$"))) return; //  XXX
          if (this.data.tags.match(new RegExp("^" + guid + ","))) return; //  XXX,
          if (this.data.tags.match(new RegExp("," + guid + ","))) return; // ,XXX,
        }
        list.push([rec.data.guid, rec.data.name]);
      },
      this);
    var extEl = Ext.get(el);
    extEl.replaceWith(['<div id="pp-tag-control-' + this.grid.id + '"></div>']);

    var store = new Ext.data.SimpleStore({
      fields: ['guid', 'name'],
      data: list
    });

    this.comboBox = new Ext.form.ComboBox({
      id: 'tag-control-combo-' + this.getGrid().id,
      ctCls: 'pp-tag-control',
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
      renderTo: 'pp-tag-control-' + this.getGrid().id,
      width: 100,
      minListWidth: 100,
      listeners: {
        'specialkey': function(field, e) {
          if (e.getKey() == e.ENTER) {
            var name = field.getRawValue();

            // The user entered a new label
            if (Ext.StoreMgr.lookup('tag_store').findExact('name', name) === -1) {
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
                  this.commitTag(guid, true);
                },
                scope: this
              });
            }
          } else if (e.getKey() == e.ESC) {
            this.renderTags();
          } else if (e.getKey() == e.TAB) {
            // TODO: Tab key should trigger an add-tag while keeping the editor open for further adding.
          }
        },
        'select': function(combo, record, index) {
          this.commitTag(record.get('guid'), false);
        },
        scope: this
      }
    });
    this.comboBox.focus();
  },

  commitTag: function(guid, isNew) {
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
        var json = Ext.util.JSON.decode(response.responseText);
        Ext.StoreMgr.lookup('tag_store').reload({
          callback: function() {
            Paperpile.main.onUpdate(json.data);
          }
        });
        if (lots) {
          Paperpile.status.clearMsg();
        }
      },
      scope: this
    });

  },

  removeTag: function(el) {
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
        Ext.StoreMgr.lookup('tag_store').reload();

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