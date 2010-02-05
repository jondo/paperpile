Paperpile.QueueWidget = Ext.extend(Ext.BoxComponent, {

  id: 'queue-widget',
  itemId: 'queue-widget',

  initComponent: function() {

    var t = new Ext.XTemplate(
      '<div id="queue-widget-button" class="pp-queue-widget-container">',
      '  <div class="pp-queue-widget-content">',
      '    <tpl if="submitting">',
      '      <span class="pp-queue-widget-item"> Starting background tasks </span>',
      '    </tpl>',
      '    <tpl if="clearing">',
      '      <span class="pp-queue-widget-item"> Clear background tasks </span>',
      '    </tpl>',
      '    <tpl if="!submitting && !clearing">',
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
      '     <span class="pp-queue-widget-item"><a href="#" class="pp-textlink pp-queue-widget-action" action="queue-tab">Show</a></span>',
      '     <tpl if="!num_pending">',
      '        <span class="pp-queue-widget-item"><a href="#" class="pp-textlink pp-queue-widget-action" action="queue-clear">Clear</a></span>',
      '     </tpl>',
      '   </tpl>',
      '  </div',
      '</div>').compile();

    Ext.apply(this, {
      tpl: t,
      // Set defaults to avoid errors when initialized
      data: {
        num_pending: 0,
        num_done:0,
        num_error:0,
        submitting:false,
        clearing: false
      }
    });

    Paperpile.QueueWidget.superclass.initComponent.call(this);

    this.on('render', function() {
      this.hide();
      this.el.on('click', this.handleClick, this);
    },
    this);
  },

  onUpdate: function(data) {

    // Special display states of the widget

    if (data.submitting){
      data.clearing = false;
      this.update(data);
      this.show();
      return;
    }

    if (data.clearing){
      data.submitting = false;
      this.update(data);
      this.show();
      return;
    }

    
    // Normal display state depends on the state of the queue. 
    if (data.queue) {
      
      // Explicitely set these variables to make template happy
      data.queue.submitting=false;
      data.queue.clearing=false;

      // If only one job is in the queue and this is a pdf search, we
      // never show the widget.  In that case the user is most likely
      // watching the download and does not need extra info.
      var pdfSearchJobs = 0;
      var allJobs = data.queue.num_pending+data.queue.num_done + data.queue.num_error;
      if (data.queue.types){
        for (var i=0; i<data.queue.types.length; i++){
          if (data.queue.types[i].name === 'PDF_SEARCH'){
            var item =  data.queue.types[i];
            pdfSearchJobs+= item.num_pending+item.num_done + item.num_error;
            break;
          }
        }
      }
      if (pdfSearchJobs==1 && allJobs==1){
        this.hide();
        return;
      }

      if (data.queue.num_pending==0 && data.queue.num_done==0 && data.queue.num_error==0){
        this.hide();
      } else {
        this.show();
        this.update(data.queue);
      }
    }
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    var action = el.getAttribute('action');

    if (action === 'queue-tab'){
      Paperpile.main.tabs.showQueueTab();
    }

    if (action === 'queue-clear'){
      this.onUpdate({clearing:true});
      Ext.Ajax.request({
        url: Paperpile.Url('/ajax/queue/clear_jobs'),
        method: 'GET',
        success: function(response) {
          var json = Ext.util.JSON.decode(response.responseText);
          Paperpile.main.onUpdate(json.data);
          Paperpile.main.queueUpdateFn();
        },
        failure: Paperpile.main.onError,
        scope: this
      });
    }
  },
});