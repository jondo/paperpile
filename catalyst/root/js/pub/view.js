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


Paperpile.PluginPanel = Ext.extend(Ext.Panel, {
  closable: false,

  initComponent: function() {

    this.grid = this.createGrid(this.gridParams);
    this.overviewPanel = this.createOverview();
    this.detailPanel = this.createDetails();

    this.centerPanel = this.createCenterPanel();
    this.eastPanel = this.createEastPanel();

    Ext.apply(this, {
      tabType: 'PLUGIN',
      layout: 'border',
      hideBorders: true,
      items: [
        this.centerPanel,
        this.eastPanel

        ]
    });

    Paperpile.PluginPanel.superclass.initComponent.call(this);

    // If grid has an "about" panel, create this panel and show it
    this.on('afterLayout',
      function() {
        if (this.grid.aboutPanel) {
          this.items.get('east_panel').items.add(this.grid.aboutPanel);
          var button = this.items.get('east_panel').getBottomToolbar().items.get('about_tab_button');
          button.show();
          button.enable();
          button.toggle(true);
          button.setText(this.grid.aboutPanel.tabLabel);
          this.grid.aboutPanel.update();
          this.items.get('east_panel').getLayout().setActiveItem('about');
        }
      },
      this, {
        single: true
      });
  },

  createGrid: function(params) {
    return new Paperpile.PluginGrid(params);
  },

  createOverview: function(params) {
    return new Paperpile.PubOverview(params);
  },

  createDetails: function(params) {
    return new Paperpile.PubDetails(params);
  },

  createCenterPanel: function() {
    var centerPanel = new Ext.Panel({
      region: 'center',
      itemId: 'center_panel',
      layout: 'border',
      items: [
        this.grid, {
          border: false,
          split: true,
          xtype: 'datatabs',
          itemId: 'data_tabs',
          activeItem: 0,
          height: 200,
          region: 'south',
          collapsible: false,
          animCollapse: false
        }]
    });
    return centerPanel;
  },

  createEastPanel: function() {
    var eastPanel = new Ext.Panel({
      region: 'east',
      itemId: 'east_panel',
      activeItem: 0,
      split: true,
      layout: 'card',
      width: 300,
      items: [
        this.overviewPanel,
        this.detailPanel],
      bbar: [{
        text: 'Overview',
        itemId: 'overview_tab_button',
        enableToggle: true,
        toggleHandler: this.onControlToggle,
        toggleGroup: 'control_tab_buttons' + this.id,
        scope: this,
        allowDepress: false,
        disabled: true,
        pressed: false
      },
      {
        text: 'Details',
        itemId: 'details_tab_button',
        enableToggle: true,
        toggleHandler: this.onControlToggle,
        toggleGroup: 'control_tab_buttons' + this.id,
        scope: this,
        allowDepress: false,
        disabled: true,
        pressed: false
      },
        '->', {
          text: 'About',
          itemId: 'about_tab_button',
          enableToggle: true,
          toggleHandler: this.onControlToggle,
          toggleGroup: 'control_tab_buttons' + this.id,
          scope: this,
          disabled: true,
          allowDepress: false,
          pressed: false,
          hidden: true
        }]
    });
    return eastPanel;
  },

  getGrid: function() {
    return this.grid;
  },

  getOverview: function() {
    return this.overviewPanel;
  },

  onUpdate: function(data) {
    if (data.pubs) {
      this.getGrid().onUpdate(data);
    }

    if (data.pub_delta) {

      if (data.pub_delta_ignore) {
        if (data.pub_delta_ignore == this.getGrid().id) {
          return;
        }
      }

      this.getGrid().getView().holdPosition = true;
      this.getGrid().getStore().reload();
    }
  },

  depressButton: function(itemId) {
    var button = this.items.get('east_panel').getBottomToolbar().items.get(itemId);
    button.toggle(true);
    this.onControlToggle(button, true);
  },

  onControlToggle: function(button, pressed) {
    if (button.itemId == 'overview_tab_button' && pressed) {
      this.items.get('east_panel').getLayout().setActiveItem('overview');
    }

    if (button.itemId == 'details_tab_button' && pressed) {
      this.items.get('east_panel').getLayout().setActiveItem('details');
    }

    if (button.itemId == 'about_tab_button' && pressed) {
      this.items.get('east_panel').getLayout().setActiveItem('about');
    }
  },

  updateDetails: function() {
    var datatabs = this.items.get('center_panel').items.get('data_tabs');
    datatabs.items.get('pubsummary').updateDetail();
    datatabs.items.get('pubnotes').updateDetail();
    this.getOverview().onUpdate();
    this.items.get('east_panel').items.get('details').updateDetail();
  },

  updateButtons: function() {
    var tb_side = this.items.get('east_panel').getBottomToolbar();
    var tb_bottom = this.items.get('center_panel').items.get('data_tabs').getBottomToolbar();

    if (this.grid.store.getCount() > 0) {
      tb_side.items.get('overview_tab_button').enable();
      tb_side.items.get('details_tab_button').enable();
      tb_bottom.items.get('summary_tab_button').enable();
      tb_bottom.items.get('notes_tab_button').enable();
    } else {
      tb_side.items.get('overview_tab_button').disable();
      tb_side.items.get('details_tab_button').disable();
      tb_bottom.items.get('summary_tab_button').disable();
      tb_bottom.items.get('notes_tab_button').disable();
    }
  },

  onEmpty: function(tpl) {
    var east_panel = this.items.get('east_panel');

    east_panel.items.get('overview').showEmpty(tpl);
    east_panel.items.get('details').showEmpty(tpl);

    var datatabs = this.items.get('center_panel').items.get('data_tabs');
    datatabs.items.get('pubsummary').showEmpty('');
    datatabs.items.get('pubnotes').showEmpty('');
  }

});