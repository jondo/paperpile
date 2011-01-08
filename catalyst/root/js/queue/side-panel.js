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


Paperpile.QueueOverview = Ext.extend(Ext.Panel, {
  layout: 'fit',

  constructor: function(queuePanel, config) {
    this.queuePanel = queuePanel;
    Paperpile.QueueOverview.superclass.constructor.call(this, config);
  },

  initComponent: function() {
    Ext.apply(this, {
      bodyStyle: {
        background: '#ffffff',
        padding: '7px'
      },
      autoScroll: true
    });

    Paperpile.QueueOverview.superclass.initComponent.call(this);

    this.mainTemplate = new Ext.XTemplate(
      '<div id="queue-main-box"></div>',
      '<div id="queue-button-box" class="pp-box pp-box-side-panel pp-box-style2" style="padding-top:20px;">',
      '  <center><div id="queue-progress"></div></center>',
      '  <center><div id="queue-eta" class="pp-queue-eta"></div></center>',
      '  <center><div id="queue-buttons"></div></center>',
      '</div>', {
        compiled: true
      });

    this.buttonTemplate = new Ext.XTemplate(
      '<table width="240px;">',
      '  <tr>',
      '    <td style="padding:5px;"><div id="pause-button"></div></td>',
      '    <td style="padding:5px;"><div id="cleanup-button"></div></td>',
      '    <td style="padding:5px;"><div id="cancel-button"></div></td>',
      '  </tr>',
      '</table>', {
        compiled: true
      });

    this.tableTemplate = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-style1" style="padding-bottom:15px;">',
      '<h2>Tasks</h2>',
      '<table class="pp-queue-table">',
      '  <tr><td></td><td class="pp-queue-table-ok">OK</td><td class="pp-queue-table-error">Failed</td><td class="pp-queue-table-pending">Waiting</td></tr>',
      '  <tpl for="queue.types">',
      '    <tr>',
      '      <tpl if="name==\'PDF_SEARCH\'">',
      '        <td><span class="pp-queue-type-label-PDF_SEARCH">Download PDF</span></td>',
      '      </tpl>',
      '      <tpl if="name==\'PDF_IMPORT\'">',
      '        <td><span class="pp-queue-type-label-PDF_IMPORT">Import PDF</span></td>',
      '      </tpl>',
      '      <tpl if="name==\'METADATA_UPDATE\'">',
      '        <td><span class="pp-queue-type-label-METADATA_UPDATE">Auto-complete</span></td>',
      '      </tpl>',
      '      <td>{num_done}</td><td>{num_error}</td><td>{num_pending}</td>',
      '    </tr>',
      '  </tpl>',
      '</table>',
      '<p>&nbsp;</p>',
      '<center>',
      '<p>Show &nbsp;&nbsp;',
      '<a href="#" class="pp-textlink" action="show-all-jobs">All</a>&nbsp;|&nbsp;',
      '<a href="#" class="pp-textlink" action="show-done-jobs">Successful</a>&nbsp;|&nbsp;',
      '<a href="#" class="pp-textlink" action="show-error-jobs">Failed</a>',
      '</p>',
      '</center></div>', {
        compiled: true
      });

    this.emptyTable = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-style2">',
      '  <p class="pp-inactive">No Tasks to show.</p>',
      '  <p><a href="#" class="pp-textlink" action="close-tab">Close Tab</a></p>',
      '</div>', {
        compiled: true
      });

  },

  onRender: function(ct, position) {
    Paperpile.QueueOverview.superclass.onRender.call(this, ct, position);

    this.mainTemplate.overwrite(this.body);

    this.renderButtons();

    this.onUpdate(Paperpile.main.currentQueueData);

    this.el.on('click', this.handleClick, this);

  },

  renderButtons: function() {

    this.buttonTemplate.overwrite(Ext.get('queue-buttons'), {});

    this.pauseButton = new Ext.Button({
      text: 'Pause',
      tooltip: 'Pause the task queue',
      cls: 'x-btn-text-icon pause',
      handler: this.pauseQueue,
      scope: this
    });
    this.cleanupButton = new Ext.Button({
      text: 'Clear',
      tooltip: 'Clear all finished jobs from the task queue',
      cls: 'x-btn-text-icon clean',
      handler: this.cleanQueue,
      scope: this
    });
    this.cancelButton = new Ext.Button({
      text: 'Cancel All',
      tooltip: 'Cancel all running and remaining jobs in the task queue',
      cls: 'x-btn-text-icon cancel',
      handler: this.cancelAll,
      scope: this
    });
    this.queueProgress = new Ext.ProgressBar({
      cls: 'pp-basic',
      width: 230,
    });

    this.pauseButton.render('pause-button');
    this.cleanupButton.render('cleanup-button');
    this.cancelButton.render('cancel-button');
    this.queueProgress.render('queue-progress');
  },

  pauseQueue: function() {
    Paperpile.Ajax({
      url: '/ajax/queue/pause_resume',
      params: {},
      success: function(response, opts) {
        var json = Ext.util.JSON.decode(response.responseText);
        
        if (json.data.queue.status != 'PAUSED') {
          Paperpile.main.queueUpdate();
        }

      },
      scope: this
    });

  },

  cleanQueue: function() {
    this.queuePanel.clearJobs('all');
  },

  cancelAll: function() {
    this.queuePanel.cancelAllJobs();
  },

  onUpdate: function(data) {
    var queue = null;
    var types = [];

      if (!data.queue) {
	  return;
      }
      if (!this.isVisible()) {
	  return;
      }

    if (data) {
      queue = data.queue;
      types = data.queue.types
    }

    // Show overview table or emtpy message
    if (types) {
      if (types.length == 0) {
        this.emptyTable.overwrite(Ext.get('queue-main-box'), data);
        Ext.get('queue-button-box').hide();
        return;
      } else {
        this.tableTemplate.overwrite(Ext.get('queue-main-box'), data);
      }
    }

    if (queue) {

      Ext.get('queue-button-box').show();

      var num_done = parseInt(queue.num_done);
      var num_error = parseInt(queue.num_error);
      var num_pending = parseInt(queue.num_pending);
      var num_all = num_done + num_pending + num_error;
      var num_finished = num_done + num_error;
      var eta = queue.eta;

      if (queue.status == 'PAUSED') {
        this.queueProgress.updateProgress(0, 'Task are paused.');
        this.pauseButton.setText('Resume');
        this.pauseButton.setIcon('/images/icons/resume.png');
      } else {
        this.pauseButton.setText('Pause');
        this.pauseButton.setIcon('/images/icons/pause.png');
      }

      if (queue.status == 'WAITING') {
        this.queueProgress.updateProgress(1, 'Done');
        this.updateETA("All tasks finished");
        this.pauseButton.setDisabled(true);
        this.cancelButton.setDisabled(true);
      } else {
        this.pauseButton.setDisabled(false);
        this.cancelButton.setDisabled(false);
        if (queue.status != 'PAUSED') {
          this.queueProgress.show();
          this.queueProgress.updateProgress(num_finished / num_all, num_finished + ' of ' + num_all + ' tasks completed');
          if (eta != '') {
            this.updateETA('About ' + eta + ' left');
          } else {
            this.updateETA('');
          }
        }
      }
    }
  },

  updateETA: function(text) {
    Ext.DomHelper.overwrite('queue-eta', text);
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    var action = el.getAttribute('action');

    if (!action) return;

    var m = action.match(/show-(all|done|error)-jobs/);

    if (m) {
      var filter = m[1];
      this.ownerCt.getGrid().getStore().reload({
        params: {
          filter: filter
        }
      });
    }

    if (action === 'close-tab') {
      Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab());
    }
  }
});