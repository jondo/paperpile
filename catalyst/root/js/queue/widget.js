Paperpile.QueueWidget = Ext.extend(Ext.BoxComponent, {
    
  id: 'queue-widget',
  itemId: 'queue-widget',

    initComponent:function() {

      var t = new Ext.XTemplate(
	'<a href="#" id="queue-widget-anchor">',
	'<div id="queue-widget-button" class="pp-queue-widget pp-top-button">',
 	'    <tpl if="num_pending">',
	'      <a href="#" class="pp-basic pp-top-button-link">',
	'        <b>Queue ({num_pending})</b>',
	'      </a>',
	'    </tpl>',
	'    <tpl if="!num_pending">',
	'      <a href="#" class="pp-basic pp-top-button-link">',
	'        Queue',
	'      </a>',
	'    </tpl>',
	'</div>',
	'</a>'
      ).compile();
        
        Ext.apply(this, {
	  tpl:t,
	  data:{num_pending:0}
        });

        Paperpile.QueueWidget.superclass.initComponent.call(this);

      this.on('render', function() {
	this.el.on('click',this.test,this);
      },this);
    },
    onUpdate: function(data) {
      if (data.queue) {
	this.update(data.queue);
      }
    },

    test: function(){
      Paperpile.log("queue!");
      Paperpile.main.queueJobUpdate();
      Paperpile.main.tabs.showQueueTab();
    }

});
