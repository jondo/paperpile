Paperpile.SearchDownloadWidget = Ext.extend(Object, {

  constructor: function(config) {
    Ext.apply(this, config);
  },

  renderData: function(data) {
    this.data = data;
    this.renderMyself();
  },

  renderMyself: function() {
    var data = this.data;

    var rootEl = Ext.get(this.div_id);
    var oldContent = Ext.select("#" + this.div_id + " > *");

    if (data.pdf != '') {
      var el = [
        '    <ul>',
        '      <li id="open-pdf{id}" class="pp-action pp-action-open-pdf" >',
        '      <a href="#" class="pp-textlink" action="open-pdf">Open PDF</a>',
        '      &nbsp;&nbsp;<a href="#" class="pp-textlink pp-second-link" action="open-pdf-external">External viewer</a></li>',
        '      <li id="delete-pdf-{id}" class="pp-action pp-action-delete-pdf"><a href="#" class="pp-textlink" action="delete-pdf">Delete PDF</a></li>',
        '    </ul>'];
      Ext.DomHelper.overwrite(rootEl, el);
      this.progressBar=null;
    } else if (data._search_job) {
      if (data._search_job.error) {
        var el = [
          '<div class="pp-box-error">' + data._search_job.error,
          '<br><a href="#" class="pp-textlink" action="clear-download">Clear</a>',
          '</div>'];
        Ext.DomHelper.overwrite(rootEl, el);
        this.progressBar=null;
      } else  {
        
        if (!this.progressBar){
          var el = [
            '<table class="pp-control-container">',
            '  <tr><td id ="dl-progress-'+this.div_id+'"></td><td><a href="#" action="cancel-download" class="pp-progress-cancel" ext:qtip="Cancel">&nbsp;</a></td></tr>',
            '</table>'];
        
          Ext.DomHelper.overwrite(rootEl, el);

          this.progressBar = new Ext.ProgressBar({
            text: data._search_job.msg || "",
            width: 200,
            renderTo: 'dl-progress-' + this.div_id
          });

          this.progressBar.wait({interval: 100, text: data._search_job.msg});
        }

        var fraction = 0;
        var downloaded = data._search_job.downloaded;
        var size = data._search_job.size;

        if (size && downloaded) {
          fraction = downloaded / size;
        }

        if (fraction){
          if (this.progressBar.isWaiting()){
            this.progressBar.reset();
          }
          this.progressBar.updateProgress(fraction, downloaded+" / "+size);
          this.progressBar.updateText(Ext.util.Format.fileSize(downloaded)+' of '+Ext.util.Format.fileSize(size));
        } else {
          var text = data._search_job.msg;
          this.progressBar.updateText(data._search_job.msg);
        }
      }
    } else {
      var el = [
        '<ul>',
        '  <li id="search-pdf-{id}" class="pp-menu pp-action pp-action-search-pdf">',
        '    <a href="#" class="pp-textlink" action="search-pdf">Search & Download PDF</a>',
        '  </li>',
        '  <li id="attach-pdf-{id}" class="pp-action pp-action-attach-pdf">',
        '    <a href="#" class="pp-textlink" action="attach-pdf">Attach PDF</a>',
        '  </li>',
        '</ul>'];
      //oldContent.remove();
      Ext.DomHelper.overwrite(rootEl, el);
      this.progressBar=null;
    }
  },

  handleClick: function(e) {

  }

});