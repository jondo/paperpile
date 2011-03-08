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

Ext.define('Paperpile.QueueWidget', {
	extend: 'Ext.Component',
  id: 'queue-widget',
  itemId: 'queue-widget',

  initComponent: function() {

    var t = new Ext.XTemplate(
      '<div id="queue-widget-button" class="pp-queue-widget-container">',
      '  <div class="pp-queue-widget-content">',
      '    <tpl if="status==\'PAUSED\'">',
      '    <span class="pp-queue-widget-item"> Paused ({num_pending} remaining) </span>',
      '     <span class="pp-queue-widget-item"><a href="#" class="pp-textlink pp-queue-widget-action" action="queue-resume">Resume</a></span>',
      '    </tpl>',
      '    <tpl if="status==\'SUBMITTING\'">',
      '      <span class="pp-queue-widget-item"> Starting background tasks </span>',
      '    </tpl>',
      '    <tpl if="status==\'CLEARING\'">',
      '      <span class="pp-queue-widget-item"> Clear background tasks </span>',
      '    </tpl>',
      '    <tpl if="status != \'SUBMITTING\' && status !=\'CLEARING\' && status != \'PAUSED\'">',
      '      <tpl if="num_pending==1">',
      '        <span class="pp-queue-widget-item"> {num_pending} task remaining</span>',
      '      </tpl>',
      '      <tpl if="num_pending &gt;1">',
      '        <span class="pp-queue-widget-item"> {num_pending} tasks remaining</span>',
      '      </tpl>',
      '      <tpl if="!num_pending">',
      '        <span class="pp-queue-widget-item"> All tasks done. ',
      '        <tpl if="num_error">{num_error} failed.</tpl>',
      '        </span>',
      '      </tpl>',
      '     <tpl if="status != \'PAUSED\'">',
      '       <span class="pp-queue-widget-item"><a href="#" class="pp-textlink pp-queue-widget-action" action="queue-tab">Show</a></span>',
      '      </tpl>',
      '     <tpl if="!num_pending">',
      '        <span class="pp-queue-widget-item"><a href="#" class="pp-textlink pp-queue-widget-action" action="queue-clear">Clear</a></span>',
      '     </tpl>',
      '   </tpl>',
      '  </div',
      '</div>').compile();

    Ext.apply(this, {
      tpl: t,
    });

    Paperpile.QueueWidget.superclass.initComponent.call(this);

    this.on('render', function() {
      this.el.on('click', this.handleClick, this);
    },
    this);
  },

  setSubmitting: function() {
    this.onUpdate({queue:{status:'SUBMITTING'}});
  },

  onUpdate: function(data) {
    // Take the queue element from the passed data.
    var queue = data.queue;

    if (!queue) {
      // The update data contains no queue info, so don't do anything more!
      return;
    }

    // Special display states of the widget
    if (queue.status == 'SUBMITTING' || queue.status == 'CLEARING') {
      // Calling the update() method causes the template (defined above, within
      // the initComponent method) to be overwritten with data from the passed
      // object.
      this.update(queue);
      this.show();
      return;
    }

    // If only one job is in the queue and this is a pdf search, we
    // never show the widget.  In that case the user is most likely
    // watching the download and does not need extra info.
    var pdfSearchJobs = 0;
    var metadataUpdateJobs = 0;
    var allJobs = queue.num_pending + queue.num_done + queue.num_error;
    if (queue.types) {
      for (var i = 0; i < queue.types.length; i++) {
        if (queue.types[i].name === 'PDF_SEARCH') {
          var item = queue.types[i];
          pdfSearchJobs += item.num_pending;
        }
        if (queue.types[i].name === 'METADATA_UPDATE') {
          var item = queue.types[i];
          metadataUpdateJobs += item.num_pending;
          break;
        }
      }
    }

    if (queue.num_pending == 0 && queue.num_done == 0 && queue.num_error == 0) {
      this.hide();
    } else {
      this.update(queue);
      this.show();
    }
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    var action = el.getAttribute('action');

    if (action === 'queue-tab') {
      Paperpile.main.tabs.showQueueTab();
    }

    if (action === 'queue-resume') {
        Paperpile.Ajax({
          url: '/ajax/queue/pause_resume',
          params: {},
          scope: this
        });
    }

    if (action === 'queue-clear') {
      this.onUpdate({
        clearing: true
      });
      Paperpile.Ajax({
        url: '/ajax/queue/clear_jobs',
        success: function(response) {
          Paperpile.main.queueUpdateFn();
        },
        scope: this
      });
    }
  },
});