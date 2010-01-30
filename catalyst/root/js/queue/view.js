Paperpile.QueuePanel = Ext.extend(Ext.Panel, {
  tabType: 'QUEUE',
  closable: true,
  title: 'Tasks',
  iconCls: 'pp-icon-queue',

  initComponent: function() {
    this.queueList = new Paperpile.QueueList(this, {
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
    if (data.queue) {
      this.getOverview().onUpdate(data);
    }
    
    if (data.jobs) {
      this.getGrid().onUpdate(data);
    }

    if (data.job_delta) {
      Paperpile.main.queueUpdateFn();
      this.getGrid().getView().holdPosition = true;
      this.getGrid().getStore().reload();
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
        this.getGrid().getStore().reload();
      },
      failure: function() {},
      scope: this
    });
  }

});


