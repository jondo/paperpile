Paperpile.SearchDownloadWidget = Ext.extend(Object, {

  constructor: function(config) {
    Ext.apply(this,config);
  },

  renderData: function(data) {
    this.prevData = data;
    this.data = data;
    this.renderMyself();
  },

  renderMyself: function() {
    var data = this.data;

    var rootEl = Ext.get(this.div_id);
    rootEl.on('click',this.handleClick,this);

    var oldContent = Ext.select("#"+this.div_id+" > *");
    oldContent.remove();

    if (data._search_job_status == 'RUNNING') {
      // Start updating quickly if we have an in-progress search job.
      Paperpile.main.speedUpJobUpdates();
    } else {
      Paperpile.main.slowDownJobUpdates();
    }

    if (data.pdf != '') {
      var el = [
        '    <ul>',
        '      <li id="open-pdf{id}" class="pp-action pp-action-open-pdf" >',
        '      <a href="#" class="pp-textlink" action="open-pdf">Open PDF</a>',
        '      &nbsp;&nbsp;<a href="#" class="pp-textlink pp-second-link" action="open-pdf-external">External viewer</a></li>',
        '      <li id="delete-pdf-{id}" class="pp-action pp-action-delete-pdf"><a href="#" class="pp-textlink" action="delete-pdf">Delete PDF</a></li>',
        '    </ul>'
      ];
      Ext.DomHelper.overwrite(rootEl,el);
    } else if (data._search_job_error) {
      var el = [
	'<div>',
	'<span style="font-style:italic;">'+data._search_job_error+'</span>',
	' (<a href="#" class="pp-textlink" action="retry-download">retry</a>',
	' or <a href="#" class="pp-textlink" action="clear-download"> clear</a>)',
	'</div>'
      ];
      Ext.DomHelper.overwrite(rootEl,el);
    } else if (data._search_job) {
      var el = [
	'<div>',
	'  <div id="dl-progress-'+this.id+'"></div>',
	'  (<a href="#" class="pp-textlink" action="cancel-download">cancel</a>)',
	'</div>'
      ];
      Ext.DomHelper.overwrite(rootEl,el);

      this.progressBar = new Ext.ProgressBar({
	value: data._search_job_progress || 0,
	text: data._search_job_msg || "",
	renderTo:'dl-progress-'+this.id
      });
      
    } else {
      var el = [
        '<ul>',
        '  <li id="search-pdf-{id}" class="pp-menu pp-action pp-action-search-pdf">',
        '    <a href="#" class="pp-textlink" action="search-pdf">Search & Download PDF</a>',
	'  </li>',
        '  <li id="attach-pdf-{id}" class="pp-action pp-action-attach-pdf">',
	'    <a href="#" class="pp-textlink" action="attach-pdf">Attach PDF</a>',
	'  </li>',
	'</ul>'
      ];
      Ext.DomHelper.overwrite(rootEl,el);      

      // Slow down updates if we don't have an in-progress job.
      Paperpile.main.slowDownJobUpdates();
    }

  },

  handleClick: function(e) {

  }

});