Ext.define('Paperpile.pub.panel.Files', {
  extend: 'Ext.Component',
  alias: 'widget.Files',
  initComponent: function() {
    Ext.apply(this, {
      tpl: this.createTemplate(),
    });

    this.callParent(arguments);
  },

  createProgressBar: function() {
    var progress = new Ext.ProgressBar({
      renderTo: 'dl-progress-' + this.id
    });
    return progress;
  },

  updateProgress: function(pub) {
    // Todo...
    this.progress.updateProgress(0.5, "Hello world!");
  },

  setPublication: function(pub) {
    this.pub = pub;
    this.update(pub.data);
    if (this.downloadInProgress(pub)) {
      this.updateProgress(pub);
    }
  },

  downloadInProgress: function(pub) {
    return pub._search_job && pub._search_job.size;
  },

  createTemplate: function() {
    var tpl = [
      '<tpl if="this.hasAttachments(values) || this.hasPdf(values) || this.isImported(values)">',
      '  <div class="pp-box pp-box-side-panel pp-box-style1">',
      this.getPdfSection(),
      this.getAttachmentsSection(),
      '  </div>',
      '</tpl>'].join("\n");

    return new Ext.XTemplate(tpl,
      this.getFunctions());
  },

  getFunctions: function() {
    return {
      hasAttachments: function(values) {
        return values._attachments_list && values._attachments_list.length > 0;
      },
      hasPdf: function(values) {
        if (values.pdf && values.pdf != '') {
          return true;
        } else {
          return false;
        }
      },
      isNotImported: function(values) {
        return !values._imported;
      },
      isImported: function(values) {
        return values._imported;
      },
      hasSearchJob: function(values) {
        if (values._search_job && values._search_job != '') {
          return true;
        } else {
          return false;
        }
      },
      hasCanceledSearch: function(values) {
        return values._search_job && values._search_job.error.match(/download canceled/);
      },
      isCancelingDownload: function(values) {
        return values._search_job && values._search_job.interrupt === "CANCEL" && values._search_job.status === 'RUNNING';
      },
      isDownloadInProgress: function(values) {
        return values._search_job && values._search_job.size;
      },
      isSearchInProgress: function(values) {
        return values._search_job && values._search_job.message;
      }
    };
  },

  getAttachmentsSection: function(data) {
    var el = [
      '    <tpl if="this.isImported(values) || this.hasAttachments(values)">',
      '      <h2>Supplementary Material</h2>',
      '    </tpl>',
      '      <tpl if="this.hasAttachments(_attachments_list)">',
      '        <ul class="pp-attachments">',
      '          <tpl for="_attachments_list">',
      '            <li class="pp-attachment-list pp-file-generic {cls}">',
      '            <a href="#" class="pp-textlink" action="open-attachment" path="{path}">{file}</a>&nbsp;&nbsp;',
      '            <a href="#" class="pp-textlink pp-second-link" action="delete-file" guid="{guid}">Delete</a></li>',
      '          </tpl>',
      '       </ul>',
      '    </tpl>',
      '    <tpl if="_imported">',
      '      <ul>',
      '        <li id="attach-file-{id}"><a href="#" class="pp-textlink pp-action pp-action-attach-file" action="attach-file">Attach File</a></li>',
      '      </ul>',
      '    </tpl>'];
    return el.join('\n');
  },

  getPdfSection: function() {
    var el = [
      '<h2>PDF</h2>',
      '<tpl if="this.hasPdf(values) === true">',
      '  <ul>',
      '    <li class="link-hover">',
      '      <a href="#" class="pp-textlink pp-action pp-action-open-pdf" action="VIEW_PDF" args="{grid_id},{guid}">View PDF</a>',
      '      <div style="display:inline-block;margin-left:2px;vertical-align:middle;">',
      '        <div class="pp-info-button pp-float-left pp-pdf-external pp-second-link" ext:qtip="View PDF in external viewer" action="open-pdf-external"></div>',
      '        <div class="pp-info-button pp-float-left pp-pdf-folder pp-second-link" ext:qtip="Open containing folder" action="open-pdf-folder"></div>',
      '      </div>',
      '    </li>',
      '    <li>',
      '      <a href="#" class="pp-textlink pp-action pp-action-delete-pdf" action="delete-pdf">Delete PDF</a>',
      '    </li>',
      '  </ul>',
      '  <tpl if="this.isNotImported(values)">',
      '    <ul>',
      '      <li id="open-pdf{id}">',
      '        <a href="#" class="pp-textlink pp-action pp-action-open-pdf" action="open-pdf">Open PDF</a>',
      '        &nbsp;&nbsp;<a href="#" class="pp-textlink pp-second-link" action="open-pdf-external">External viewer</a>',
      '      </li>',
      '    </ul>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="this.hasPdf(values) === false && this.hasSearchJob(values) === true">',
      '  <tpl if="this.hasSearchError(values)">',
      '    <div class="pp-box-error">',
      '      <p>{search_job_error}</p>',
      '      <p><a href="#" class="pp-textlink" action="report-download-error">Get this fixed</a> | <a href="#" class="pp-textlink" action="clear-download">Clear</a></p>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.hasCanceledSearch(values)">',
      '    <div class="pp-box-error">',
      '      <p>{_search_job.error}</p>',
      '      <p><a href="#" class="pp-textlink" action="clear-download">Clear</a></p>',
      '    </div>',
      '  </tpl>',
      // Canceling the download.
      '  <tpl if="this.isCancelingDownload(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running"> Canceling download...</span></div>',
      '      <div><span class="pp-inactive">Cancel</a></div>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.isDownloadInProgress(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span id ="dl-progress-' + this.id + '"></span></div>',
      '      <div><a href="#" action="cancel-download" class="pp-textlink">Cancel</a></div>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.isSearchInProgress(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running">{this.jobMessage(values)}</span></div>',
      '      <div><a href="#" action="cancel-download" class="pp-textlink">Cancel</a></div>',
      '    </div>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="this.hasPdf(values) === false && this.hasSearchJob(values) === false">',
      '  <ul>',
      '    <li id="search-pdf-{id}">',
      '      <a href="#" class="pp-textlink pp-action pp-action-search-pdf" action="search-pdf">Search & Download PDF</a>',
      '    </li>',
      '    <tpl if="this.isImported(values)">',
      '      <li id="attach-pdf-{id}">',
      '        <a href="#" class="pp-textlink pp-action pp-action-attach-pdf" action="attach-pdf">Attach PDF</a>',
      '      </li>',
      '    </tpl>',
      '  </ul>',
      '</tpl>'];
    return el.join('\n');
  }
});