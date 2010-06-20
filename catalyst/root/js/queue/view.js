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


Paperpile.QueuePanel = Ext.extend(Ext.Panel, {
  tabType: 'QUEUE',
  closable: true,
  title: 'Tasks',
  iconCls: 'pp-icon-queue',

  initComponent: function() {
    this.queueList = new Paperpile.QueueList({
      region: 'center',
      itemId: 'grid'
    });

    this.queueOverview = new Paperpile.QueueOverview(this, {
      region: 'east',
      width: 300,
      itemId: 'overview',
      split: false
    });

    Ext.apply(this, {
      layout: 'border',
	// Fixes a nasty bug in the grid updating. See http://www.sencha.com/forum/archive/index.php/t-96398.html
	hideMode: 'offsets',
      items: [
        this.queueList, this.queueOverview]
    });

    Paperpile.QueuePanel.superclass.initComponent.call(this);
  },

  getGrid: function() {
    return this.queueList;
  },

  getOverview: function() {
    return this.queueOverview;
  },

  onUpdate: function(data) {
      this.getOverview().onUpdate(data);
      this.getGrid().onUpdate(data);

    if (data.job_delta) {

      Paperpile.main.queueUpdateFn();
      this.getGrid().getView().holdPosition = true;
      this.getGrid().backgroundReload();
    }
  },

  clearJobs: function(sel) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/clear_jobs'),
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: function() {},
      scope: this
    });
  },

  cancelJobs: function(selection) {
    if (!selection) {
      selection = this.queueList.getSelectedIds();
    }
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/cancel_jobs'),
      method: 'GET',
      params: {
        ids: selection
      },
      success: function(response, opts) {
        this.getGrid().getStore().reload();
      },
      failure: function() {},
      scope: this
    });
  },

  retryJobs: function(selection) {
    if (!selection) {
      selection = this.queueList.getSelectedIds();
    }



    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/queue/retry_jobs'),
      method: 'GET',
      params: {
        ids: selection
      },
      success: function(response, opts) {
        Paperpile.main.queueUpdate();
        this.getGrid().getStore().reload({
          params: {
            filter: 'all'
          }});
      },
      failure: function() {},
      scope: this
    });
  }

});