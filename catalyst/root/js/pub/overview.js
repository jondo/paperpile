/* Copyright 2009-2011 Paperpile

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

Ext.define('Paperpile.pub.Overview', {
  extend: 'Ext.panel.Panel',
  alias: 'widget.puboverview',
  cls: 'pp-pub-overview',
  initComponent: function() {

    var items = [{
      xtype: 'BasicInfo'
    },
    {
      xtype: 'Collections'
    },
    {
      xtype: 'OnlineResources'
    },
    {
      xtype: 'Files'
    }];

    Ext.apply(this, {
      layout: {
        type: 'auto',
        padding: '5',
      },
      items: items,
      autoScroll: true,
    });

    this.callParent(arguments);
  },
  createTemplate: function() {
    return Paperpile.pub.OverviewTemplates.single();
  },

  setSelection: function(selection) {
    this.selection = selection;
    this.items.each(function(item, index) {
      item.setSelection(selection);
    });
  },

  updateFromServer: function(data) {
    this.items.each(function(item, index) {
      item.updateFromServer(data);
    });
  },

  hideLabelControls: function() {
    var container = Ext.get('label-control-' + this.id);
    while (container.first()) {
      container.first().remove();
    }
  },

  showLabelControls: function() {
    // Skip labels for combo which are already in list (unless we have multiple selection where this
    // does not make too much sense
    var list = [];

    Ext.StoreMgr.lookup('label_store').each(function(rec) {
      var label = rec.data.label;
      if (!this.multipleSelection) {
        if (this.data.labels.match(new RegExp("," + label + "$"))) return; // ,XXX
        if (this.data.labels.match(new RegExp("^" + label + "$"))) return; //  XXX
        if (this.data.labels.match(new RegExp("^" + label + ","))) return; //  XXX,
        if (this.data.labels.match(new RegExp("," + label + ","))) return; // ,XXX,
      }
      list.push([label]);
    },
    this);

    var store = new Ext.data.SimpleStore({
      fields: ['label'],
      data: list
    });

    var combo = new Ext.form.ComboBox({
      id: 'label-control-combo-' + this.id,
      store: store,
      displayField: 'label',
      forceSelection: false,
      triggerAction: 'all',
      mode: 'local',
      enableKeyEvents: true,
      renderTo: 'label-control-' + this.id,
      width: 120,
      listWidth: 120,
      initEvents: function() {
        this.constructor.prototype.initEvents.call(this);
        Ext.apply(this.keyNav, {
          "enter": function(e) {
            this.onViewClick();
            this.delayedCheck = true;
            this.unsetDelayCheck.defer(10, this);
            scope = Ext.getCmp(this.id.replace('label-control-combo-', ''));
            scope.onAddLabel();
            this.destroy();
          },
          doRelay: function(foo, bar, hname) {
            if (hname == 'enter' || hname == 'down' || this.scope.isExpanded()) {
              return Ext.KeyNav.prototype.doRelay.apply(this, arguments);
            }
            return true;
          }
        });
      }
    });

    combo.focus();

    var button = new Ext.Button({
      id: 'label-control-ok-' + this.id,
      text: 'Add Label',
    });

    button.render(Ext.DomHelper.append('label-control-' + this.id, {
      tag: 'div',
      cls: 'pp-button-control',
    }));

    if (!this.multipleSelection) {

      var cancel = new Ext.BoxComponent({
        autoEl: {
          tag: 'div',
          cls: 'pp-textlink-control',
          children: [{
            tag: 'a',
            id: 'label-control-cancel-' + this.id,
            href: '#',
            cls: 'pp-textlink',
            html: 'Cancel'
          }]
        }
      });

      cancel.render('label-control-' + this.id);

      this.mon(Ext.get('label-control-cancel-' + this.id), 'click', function() {
        Ext.get('label-add-link-' + this.id).show();
        this.hideLabelControls();
      },
      this);
    }

    this.mon(Ext.get('label-control-ok-' + this.id), 'click', this.onAddLabel, this);

  },

  onAddLabel: function() {

    var combo = Ext.getCmp('label-control-combo-' + this.id);
    var label = combo.getValue();

    combo.setValue('');

    if (this.data.labels != '') {
      this.data.labels = this.data.labels + "," + label;
    } else {
      this.data.labels = label;
    }

    if (!this.multipleSelection) {
      this.hideLabelControls();
      Ext.get('label-add-link-' + this.id).show();
    }

    Paperpile.Ajax({
      url: '/ajax/crud/add_label',
      params: {
        grid_id: this.grid_id,
        selection: Ext.getCmp(this.grid_id).getSelection(),
        label: label
      },
      scope: this
    });

  },

  //
  // Delete file. isPDF controls whether it is *the* PDF or some
  // other attached file. In the latter case the guid of the attached
  // file has to be given.
  //
  deleteFile: function(isPDF, guid) {

    var record = this.getGrid().store.getAt(this.getGrid().store.find('guid', this.data.guid));

    Paperpile.Ajax({
      url: '/ajax/crud/delete_file',
      params: {
        file_guid: isPDF ? this.data.pdf : guid,
        pub_guid: this.data.guid,
        is_pdf: (isPDF) ? 1 : 0,
        grid_id: this.grid_id
      },
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);

        var undo_msg = '';
        if (isPDF) {
          undo_msg = 'Deleted PDF file ' + Ext.util.Format.ellipsis(record.get('pdf_name'), 25);
        } else {
          undo_msg = "Deleted one attached file";
        }

        Paperpile.status.updateMsg({
          msg: undo_msg,
          action1: 'Undo',
          callback: function(action) {
            Paperpile.Ajax({
              url: '/ajax/crud/undo_delete',
              success: function(response) {
                Paperpile.status.clearMsg();
              },
              scope: this
            });
          },
          scope: this,
          hideOnClick: true
        });
      },
      scope: this
    });

  },

  //
  // Searches for a PDF link on the publisher site
  //
  showEmpty: function(tpl) {

    var empty = new Ext.Template(tpl);
    empty.overwrite(this.body);

  },

  onDestroy: function() {

    Ext.destroy(this.searchDownloadWidget);
    Ext.destroy(this.labelWidget);

    this.callParent(arguments);

  }

});