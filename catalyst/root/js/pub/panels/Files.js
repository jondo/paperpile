Ext.define('Paperpile.pub.panel.Files', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.Files',
  initComponent: function() {
    Ext.apply(this, {
	});

    this.addCls('pp-panel-files');

    this.callParent(arguments);
  },

  createProgressBar: function() {
    return this.progress;
  },

  update: function(data) {
    this.callParent(arguments);

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
    // Call the PubPanel's viewRequiresUpdate method, which returns true if this 
    // pub object is marked as dirty.
    var needsUpdate = this.callParent(arguments);
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

    this.multiTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-style1">',
      '  <h2>PDF</h2>',
      '  {[Paperpile.pub.PubPanel.link("SEARCH_PDF")]}',
      '</div>');

  },

  getFunctions: function() {
    return {
      hasAttachments: function(values) {
        return values._attachments_list && values._attachments_list.length > 0;
      },
      getAttachments: function(values) {
        return values._attachments_list;
      },
      getIconForFileType: function(cls) {
        var base = '/images/icons/';
        return base + 'leaf.gif';
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
      '      <tpl if="this.hasAttachments(values)">',
      '        <ul class="pp-attachments">',
      '          <tpl for="this.getAttachments(values)">',
      '            <li class="pp-attachment-list">',
      '              {[Paperpile.pub.PubPanel.fileLink("OPEN_FILE",values.file,values.path, this.getIconForFileType(values.cls))]}',
      '              {[Paperpile.pub.PubPanel.iconButton("RENAME_FILE",values.guid)]}',
      '              {[Paperpile.pub.PubPanel.iconButton("DELETE_FILE",values.guid)]}',
      '            </li>',
      '          </tpl>',
      '       </ul>',
      '    </tpl>',
      '    <tpl if="this.isImported(values)">',
      '      <div style="margin-left: 1em;">',
      '        {[Paperpile.pub.PubPanel.link("ATTACH_FILES")]}',
      '      </div>',
      '    </tpl>'];
    return el.join('\n');
  },

  getPdfSection: function() {
    var me = this;
    var el = [
      '<h2>PDF</h2>',
      '<tpl if="this.hasPdf(values) === true">',
      '  <tpl if="this.isImported(values)">',
      '    {[Paperpile.pub.PubPanel.button("OPEN_PDF")]}',
      '    {[Paperpile.pub.PubPanel.iconButton("OPEN_PDF_EXTERNAL")]}',
      '    {[Paperpile.pub.PubPanel.iconButton("OPEN_PDF_FOLDER")]}',
      '    {[Paperpile.pub.PubPanel.iconButton("DELETE_PDF",values.pdf)]}',
      '    <div style="margin-left: 1em;">',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.isNotImported(values)">',
      '    {[Paperpile.pub.PubPanel.link("OPEN_PDF")]}',
      '    <div style="margin-left: 1em;">',
      '      {[Paperpile.pub.PubPanel.miniLink("OPEN_PDF_EXTERNAL")]}',
      '    </div>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="this.hasPdf(values) === false && this.hasSearchJob(values) === true">',
      '  <tpl if="this.hasSearchError(values) === true">',
      '    <div class="pp-box-error">',
      '      <p>{[this.getSearchError(values)]}</p>',
      '      {[Paperpile.pub.PubPanel.link("REPORT_PDF_DOWNLOAD_ERROR")]}<br/>',
      '      {[Paperpile.pub.PubPanel.link("CLEAR_PDF_JOB")]}',
      '    </div>',
      '  </tpl>',
      '  <tpl if="!this.hasSearchError(values) && this.hasCanceledSearch(values)">',
      '    <div class="pp-box-error">',
      '      <p>{_search_job.error}</p>',
      '      {[Paperpile.pub.PubPanel.link("CLEAR_PDF_JOB")]}',
      '    </div>',
      '  </tpl>',
      '  <tpl if="!this.hasSearchError(values) && this.isCancelingDownload(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running"> Canceling download...</span></div>',
      '      {[Paperpile.pub.PubPanel.link("CANCEL_PDF_JOB")]}',
      '    </div>',
      '  </tpl>',
      '  <tpl if="!this.hasSearchError(values) && this.isSearchInProgress(values) && !this.isDownloadInProgress(values)">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running">{[this.jobMessage(values)]}</span></div>',
      '      {[Paperpile.pub.PubPanel.link("CANCEL_PDF_JOB")]}',
      '    </div>',
      '  </tpl>',
      '  <tpl if="this.isDownloadInProgress(values) === true && this.hasSearchError(values) === false">',
      '    <div class="pp-download-widget">',
      '      <div class="pp-download-widget-msg"><span id="dl-progress-' + me.id + '"></span></div>',
      '      {[Paperpile.pub.PubPanel.link("CANCEL_PDF_JOB")]}',
      '    </div>',
      '  </tpl>',
      '</tpl>',
      '<tpl if="this.hasPdf(values) === false && this.hasSearchJob(values) === false">',
      '      {[Paperpile.pub.PubPanel.button("SEARCH_PDF")]}',
      '    <tpl if="this.isImported(values)">',
      '      <div style="margin-left: 1em;">',
      '        {[Paperpile.pub.PubPanel.miniLink("ATTACH_PDF")]}',
      '      </div>',
      '    </tpl>',
      '</tpl>'];
    return el.join('\n');
  }
});