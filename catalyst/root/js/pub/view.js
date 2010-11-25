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

Paperpile.PluginPanel = Ext.extend(Ext.Panel, {
  closable: false,
  splitFraction: 2/3,

  initComponent: function() {

    // Center panel is composed of grid, abstract and notes.
    this.grid = this.createGrid(this.gridParams);
    this.centerPanel = this.createCenterPanel();

    // East panel is composed of overview and details.
    this.overviewPanel = this.createOverview();
    this.eastPanel = this.createEastPanel();

    this.centerPanel.flex = 1;
    this.eastPanel.flex = 1;

    Ext.apply(this, {
      tabType: 'PLUGIN',
      hideBorders: true,
      layout: 'hbox',
      plugins: [new Ext.ux.PanelSplit(this.centerPanel, this.updateSplitFraction,this)],
      layoutConfig: {
        align: 'stretch'
      },
      items: [
        this.centerPanel,
        this.eastPanel]
    });

    Paperpile.PluginPanel.superclass.initComponent.call(this);

    this.on('afterlayout', function() {
	this.resizeToSplitFraction();
    },
    this);

    this.mon(this.eastPanel, 'afterrender', this.afterEastRender, this);

    this.on('afterrender', function() {
      this.mon(this.el, 'click', function() {
        Paperpile.main.grabFocus();
      },
      this);
    },
    this);
  },

  updateSplitFraction: function(newFraction) {
  // REFACTOR: right now this is largely duplicated here and in paperpile.js.
      this.splitFraction = newFraction;

      // Store the new fraction setting.
      Paperpile.main.setSetting('split_fraction_grid',this.splitFraction,true);
      // Update the panel sizes.
      this.resizeToSplitFraction();
  },

  resizeToSplitFraction: function() {
  // REFACTOR: right now this is largely duplicated here and in paperpile.js.

      var fraction = this.splitFraction; // Default panel if there's no setting yet.
      var set_fraction = Paperpile.main.getSetting('split_fraction_grid');
      if (set_fraction) {
	  fraction = set_fraction;
      }

      var width = this.getWidth();
      var w1 = width * (fraction); // grid width
      var w2 = width * (1 - fraction); // sidepanel width

      // Minimum grid width.
      var min1 = 400;
      // Minimum sidepanel width.
      var min2 = 150;
      // Maximum grid width.
      var max1 = 9999;
      // Maximum sidepanel width.
      var max2 = 400;

      // Respect max sizes
      if (w1 > max1) {
        w1 = max1;
        w2 = width - max1;
      }
      if (w2 > max2) {
        w2 = max2;
        w1 = width - max2;
      }

      // Respect minimum sizes.
      if (w2 < min2) {
        w2 = min2;
        w1 = width - min2;
      }
      // Top priority -- keep grid above min size!
      if (w1 < min1) {
        w1 = min1;
        w2 = width - min1;
      }

//      this.suspendEvents(true);
      this.centerPanel.setWidth(w1);
      this.eastPanel.setWidth(w2);
      this.centerPanel.setPosition(0, 0);
      this.eastPanel.setPosition(width - w2, 0);
//      this.resumeEvents();

},

  afterEastRender: function() {
    if (this.hasAboutPanel()) {
      this.getEastPanel().getLayout().setActiveItem(this.getAboutPanel());
      this.depressButton('about_tab_button');
    } else {
      this.depressButton('overview_tab_button');
    }
  },

  saveScrollState: function() {
    this.gridState = this.getGrid().getView().getScrollState();
  },

  restoreScrollState: function() {
    if (this.gridState != null) {
      this.getGrid().getView().restoreScroll(this.gridState);
      this.gridState = null;
    }
  },

  createGrid: function() {
    return new Paperpile.PluginGrid();
  },

  createOverview: function() {
    return new Paperpile.PubOverview();
  },

  createCenterPanel: function() {
    var centerPanel = new Ext.Panel({
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
    var eastPanelItems = [this.getOverviewPanel()];
    if (this.hasAboutPanel()) {
      eastPanelItems.push(this.getAboutPanel());
    }

    var eastPanel = new Ext.Panel({
      itemId: 'east_panel',
      activeItem: 0,
      layout: 'card',
      items: [eastPanelItems],
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
      {
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
    this.eastPanel = eastPanel;
    return this.eastPanel;
  },

  getEastPanel: function() {
    return this.eastPanel;
  },

  getGrid: function() {
    return this.grid;
  },

  getOverviewPanel: function() {
    return this.overviewPanel;
  },

  getAboutPanel: function() {
    if (!this.aboutPanel) {
      this.aboutPanel = this.createAboutPanel();
    }
    return this.aboutPanel;
  },

  createAboutPanel: function() {
    return new Paperpile.PluginAboutPanel();
  },

  removeAboutPanel: function() {
    var panel = this.getAboutPanel();

    if (this.hasAboutPanel() && this.getEastPanel().items.get('about')) {
      this.getEastPanel().items.remove(panel);
      this.getEastPanel().getBottomToolbar().items.get('about_tab_button').hide();
      this.showOverview();
    }
  },

  hasAboutPanel: function() {
    return (this.getAboutPanel() !== undefined);
  },

  onEmpty: function() {},

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
      this.getGrid().backgroundReload();
    }
  },

  depressButton: function(itemId) {
    var button = this.items.get('east_panel').getBottomToolbar().items.get(itemId);
    button.toggle(true);
    this.onControlToggle(button, true, true);
  },

  onControlToggle: function(button, pressed) {
    var newActiveItem;

    if (!pressed) {
      return;
    }
    if (button.itemId == 'overview_tab_button' && pressed) {
      newActiveItem = this.getOverviewPanel();
      newActiveItem.singleSelectionDisplay = 'overview';
    } else if (button.itemId == 'details_tab_button' && pressed) {
      newActiveItem = this.getOverviewPanel();
      newActiveItem.singleSelectionDisplay = 'details';
    } else if (button.itemId == 'about_tab_button' && pressed) {
      newActiveItem = this.getAboutPanel();
    } else {
      Paperpile.log("Didn't recognize button " + button.itemId);
    }

    newActiveItem.forceUpdate();
    this.getEastPanel().getLayout().setActiveItem(newActiveItem);
  },

  updateView: function() {
    var count = this.getGrid().getStore().getCount();

    var about_button = this.getEastPanel().getBottomToolbar().get('about_tab_button');
    if (this.hasAboutPanel() && !about_button.isVisible()) {
      about_button.show();
      about_button.enable();
      about_button.setText(this.getAboutPanel().tabLabel);
    }

    if (count == 0) {
      this.onEmpty();
      this.getGrid().onEmpty();
    }

    if (count > 0) {
      // Change the active tab to 'overview'
      var activeTab = this.getEastPanel().getLayout().activeItem;
      if (activeTab == this.getAboutPanel()) {
        this.getEastPanel().getLayout().setActiveItem(this.getOverviewPanel());
        this.depressButton('overview_tab_button');
      }
    }
    this.updateDetails();
    this.updateButtons();
    this.getGrid().updateButtons();
  },

  updateDetails: function(updateImmediately) {
    if (this.updateDetailsTask === undefined) {
      this.updateDetailsTask = new Ext.util.DelayedTask(function() {
        this.updateDetailsWork();
      },
      this);
    }

    if (updateImmediately) {
      this.updateDetailsTask.cancel();
      this.updateDetailsWork();
    } else {
      this.updateDetailsTask.delay(80);
    }
  },

  updateDetailsWork: function() {
    var datatabs = this.items.get('center_panel').items.get('data_tabs');
    // Grid.
    this.getGrid().updateButtons();
    // Overview.
    this.getOverviewPanel().forceUpdate();
    // Abstract.
    datatabs.items.get('pubsummary').updateDetail();
    // Notes.
    datatabs.items.get('pubnotes').updateDetail();
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

  onDestroy: function() {
    if (this.updateDetailsTask) {
      this.updateDetailsTask.cancel();
      Ext.destroy(this.updateDetailsTask);
    }
    Ext.destroy(this.overviewPanel);

    Paperpile.PluginPanel.superclass.onDestroy.call(this);
  }
});