Ext.define('Paperpile.pub.panel.Files', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.Files',
  initComponent: function() {
    Ext.apply(this, {});

    this.callParent(arguments);
  },

  createProgressBar: function() {
    return this.progress;
  },

  update: function(data) {
    this.callParent(arguments);

    Paperpile.log(data._search_job);
    if (this.isDownloadInProgress(data)) {
      this.updateProgress(data);
    }
  },

  isDownloadInProgress: function(data) {
    var job = data._search_job;
    if (job && job.downloaded > 0 && job.status !== 'DONE' && job.interrupt !== 'CANCEL' && job.error == '') {
      return true;
    } else {
      return false;
    }
  },

  updateProgress: function(data) {
    var fraction = 0;
    var downloaded = data._search_job.downloaded;
    var size = data._search_job.size;

    if (size && downloaded) {
      fraction = downloaded / size
    }

    if (fraction) {
      var text = Ext.util.Format.fileSize(downloaded) + ' of ' + Ext.util.Format.fileSize(size)
      this.progress = new Ext.ProgressBar({
        renderTo: 'dl-progress-' + this.id,
        value: fraction,
        text: text,
        animate: false
      });
    }
  },

  viewRequiresUpdate: function(data) {
    var needsUpdate = false;
    Ext.each(this.selection, function(pub) {
      if (pub.get('_search_job')) {
        needsUpdate = true;
      }
    },
    this);
    return needsUpdate;
  },

  createTemplates: function() {
    this.callParent(arguments);

    var tpl = [
      '<tpl if="this.hasAttachments(values) || this.hasPdf(values) || this.isImported(values)">',
      '  <div class="pp-box pp-box-side-panel pp-box-style1">',
      this.getPdfSection(),
      this.getAttachmentsSection(),
      '  </div>',
      '</tpl>'].join("\n");
    this.singleTpl = new Ext.XTemplate(tpl,
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
      hasSearchError: function(values) {
        if (values._search_job && values._search_job.status == 'ERROR') {
          return true;
        } else {
          return false;
        }
      },
      getSearchError: function(values) {
	    return values._search_job.error;
      },
      hasCanceledSearch: function(values) {
        return values._search_job && values._search_job.error.match(/download canceled/);
      },
      isCancelingDownload: function(values) {
        return values._search_job && values._search_job.interrupt === "CANCEL" && values._search_job.status === 'RUNNING';
      },
      isDownloadInProgress: function(values) {
        return values._search_job && values._search_job.downloaded !== undefined;
      },
      isSearchInProgress: function(values) {
        return values._search_job && values._search_job.msg !== '';
      },
      jobMessage: function(values) {
        return values._search_job.msg;
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
      '            <a href="#" class="pp-textlink" action="OPEN_ATTACHMENT" args="{path}">{file}</a>&nbsp;&nbsp;',
      '            <a href="#" class="pp-textlink pp-second-link" action="DELETE_FILE" args="{guid}">Delete</a></li>',
      '          </tpl>',
      '       </ul>',
      '    </tpl>',
      '    <tpl if="_imported">',
      '      <ul>',
      '        <li id="attach-file-{id}"><a href="#" class="pp-textlink pp-action pp-action-attach-file" action="ATTACH_FILE">Attach File</a></li>',
      '      </ul>',
      '    </tpl>'];
    return el.join('\n');
  },

  getPdfSection: function() {
    var me = this;
    var el = [
      '<h2>PDF</h2>',
      '<tpl if="this.hasPdf(values) === true">',
      '  <ul>',
      '    <li class="link-hover">',
      '      <a href="#" class="pp-textlink pp-action pp-action-open-pdf" action="VIEW_PDF" args="{grid_id},{guid}">View PDF</a>',
      '      <div style="display:inline-block;margin-left:2px;vertical-align:middle;">',
      '        <div class="pp-info-button pp-float-left pp-pdf-external pp-second-link" ext:qtip="View PDF in external viewer" action="VIEW_PDF_EXTERNAL"></div>',
      '        <div class="pp-info-button pp-float-left pp-pdf-folder pp-second-link" ext:qtip="Open containing folder" action="OPEN_PDF_FOLDER"></div>',
      '      </div>',
      '    </li>',
      '    <li>',
      '      <a href="#" class="pp-textlink pp-action pp-action-delete-pdf" action="DELETE_PDF">Delete PDF</a>',
      '    </li>',
      '  </ul>',
      '  <tpl if="this.isNotImported(values)">',
      '    <ul>',
      '      <li id="open-pdf{id}">',
      '        <a href="#" class="pp-textlink pp-action pp-action-open-pdf" action="VIEW_PDF">Open PDF</a>',
      '        &nbsp;&nbsp;<a href="#" class="pp-textlink pp-second-link" action="VIEW_PDF_EXTERNAL">External viewer</a>',
      '      </li>',
      '    </ul>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="this.hasPdf(values) === false && this.hasSearchJob(values) === true">',
      '  <tpl if="this.hasSearchError(values) === true">',
      '    <div class="pp-box-error">',
      '      <p>{[this.getSearchError(values)]}</p>',
      '      <p><a href="#" class="pp-textlink" action="report-download-error">Get this fixed</a> | <a href="#" class="pp-textlink" action="CLEAR_PDF_DOWNLOAD">Clear</a></p>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="!this.hasSearchError(values) && this.hasCanceledSearch(values)">',
      '    <div class="pp-box-error">',
      '      <p>{_search_job.error}</p>',
      '      <p><a href="#" class="pp-textlink" action="CLEAR_PDF_DOWNLOAD">Clear</a></p>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="!this.hasSearchError(values) && this.isCancelingDownload(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running"> Canceling download...</span></div>',
      '      <div><span class="pp-inactive">Cancel</a></div>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="!this.hasSearchError(values) && this.isSearchInProgress(values) && !this.isDownloadInProgress(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running">{[this.jobMessage(values)]}</span></div>',
      '      <div><a href="#" action="CANCEL_PDF_DOWNLOAD" class="pp-textlink">Cancel</a></div>',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.isDownloadInProgress(values) === true && this.hasSearchError(values) === false">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span id="dl-progress-' + me.id + '"></span></div>',
      '      <div><a href="#" action="CANCEL_PDF_DOWNLOAD" class="pp-textlink">Cancel</a></div>',
      '    </div>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="this.hasPdf(values) === false && this.hasSearchJob(values) === false">',
      '  <ul>',
      '    <li id="search-pdf-{id}">',
      '      <a href="#" class="pp-textlink pp-action pp-action-search-pdf" action="SEARCH_PDF">Search & Download PDF</a>',
      '    </li>',
      '    <tpl if="this.isImported(values)">',
      '      <li id="attach-pdf-{id}">',
      '        <a href="#" class="pp-textlink pp-action pp-action-attach-pdf" action="ATTACH_PDF">Attach PDF</a>',
      '      </li>',
      '    </tpl>',
      '  </ul>',
      '</tpl>'];
    return el.join('\n');
  }
});