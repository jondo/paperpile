Ext.define('Paperpile.pub.OverviewTemplates', {
  statics: {

    details: function() {
      if (this._details === undefined) {
        this._details = new Ext.XTemplate(
          '<div id="main-container-{id}">',
          '<div class="pp-box pp-box-top pp-box-side-panel pp-box-style2">',
          '  <div class="ref-actions" style="float:right;">',
          '    <img src="/images/icons/pencil.png" class="pp-img-action" action="edit-ref" ext:qtip="Edit Reference"/>',
          '  </div>',
          '  <div style="margin:-5px 0px; clear:both;"></div>',
          '    <dl>',
          '      <tpl if="citekey"><dt>Key: </dt><dd class="pp-word-wrap">{citekey}</dd></tpl>',
          '      <dt>Type: </dt><dd>{_pubtype}</dd>',
          '      <tpl for="fields">',
          '        <div class="link-hover">',
          '          <dt>{label}:</dt><dd class="pp-word-wrap pp-info-{field}">{value}</dd>',
          '        </div>',
          '      </tpl>',
          '    </dl>',
          '  </div>',

          '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style2">',
          '    <ul> ',
          '      <li><a  href="#" class="pp-textlink pp-action pp-action-clipboard" action="copy-text">Copy Citation</a> </li>',
          '      <tpl if="isBibtexMode">',
          '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-bibtex">Copy as BibTeX</a> </li>',
          '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-keys">Copy LaTeX citation</a> </li>',
          '      </tpl>',
          '    </ul>',
          '  </div>',
          '</div>');
      }
      return this._details;
    },

    multiple: function() {
      if (this._multiple === undefined) {
        this._multiple = new Ext.XTemplate(
          '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
          '  <tpl if="this.getNumSelected(selected) &gt; 0">',
          '    <p><b>{selected:this.getNumSelected}</b> references selected.</p>',
          '    <div class="pp-vspace" style="height:5px;"></div>',
          '    <ul> ',
          '    <div style="clear:both;"></div>',
          '      <li><a href="#" class="pp-action pp-textlink pp-action-update-metadata" action="update-metadata">Auto-complete Data</a></li>',
          '      <li><a href="#" class="pp-action pp-textlink pp-action-search-pdf" action="batch-download">Download PDFs</a> </li>',
          '      <li><a  href="#" class="pp-textlink pp-action pp-action-trash" action="delete-ref">Move to Trash</a> </li>',
          '    </ul>',
          '    <ul> ',
          '    <div style="clear:both;margin-top:2em;"></div>',
          '      <li><a  href="#" class="pp-textlink pp-action pp-action-clipboard" action="copy-text">Copy Citation</a> </li>',
          '      <tpl if="isBibtexMode">',
          '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-bibtex">Copy BibTeX</a> </li>',
          '        <li> <a  href="#" class="pp-textlink pp-action" action="copy-keys">Copy LaTeX Citation</a> </li>',
          '      </tpl>',
          '    </ul>',
          '    <ul>',
          '    <div style="clear:both;margin-top:2em;"></div>',
          '      <li><a  href="#" class="pp-textlink pp-action pp-action-email" action="email">E-mail References</a> </li>',
          '    </ul>',
          '    <div class="pp-vspace" style="height:5px;"></div>',
          '   <dl>',
          '     <dt style="width: 50px;">Labels: </dt>',
          '     <dd style="margin:0 0 0 50px;">',
          '       <div class="pp-label-widget"></div>',
          '     </dd>',
          '   </dl>',
          '    <div class="pp-vspace" style="height:5px;"></div>',
          '  </tpl>',
          '  </div>'
          ,{
	      getNumSelected: function(selected) {
		  return selected.length;
	      }
	  });
      }
      return this._multiple;
    },

    single: function() {
      var me = this;
      if (this._single === undefined) {
        this._single = new Ext.XTemplate(
          '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
          '<tpl if="_imported">',
          me._importedReference(),
          '</tpl>',
          '<h2>Reference Info</h2>',
          '<dl class="pp-ref-info">',
          '<tpl if="_pubtype_name">',
          '  <dt>Type: </dt><dd>{_pubtype_name}',
          '  <tpl if="howpublished">({howpublished})</tpl>',
          '</dd>',
          '</tpl>',
          '<tpl if="_imported">',
          '  <tpl if="trashed==0">',
          '    <dt>Added: </dt>',
          '  </tpl>',
          '  <tpl if="trashed==1">',
          '    <dt>Deleted: </dt>',
          '  </tpl>',
          '  <dd>{_createdPretty}</dd>',
          '</tpl>',
          '<tpl if="folders">',
          '  <dt>Folders: </dt>',
          '  <dd>',
          '    <ul class="pp-folders">',
          '    <tpl for="_folders_list">',
          '      <li class="pp-folder-list pp-folder-generic">',
          '        <a href="#" class="pp-textlink" action="open-folder" folder_id="{folder_id}" >{folder_name}</a> &nbsp;&nbsp;',
          '        <a href="#" class="pp-textlink pp-second-link" action="delete-folder" folder_id="{folder_id}" rowid="{rowid}">Remove</a>',
          '      </li>',
          '    </tpl>',
          '    </ul>',
          '  </dd>',
          '</tpl>',
          '<tpl if="_imported && !trashed">', // Don't show the labels widget if this article isn't imported.
          '  <dt>Labels: </dt>',
          '  <dd>',
          '  <div id="label-widget-{id}" class="pp-label-widget"></div>',
          '  </dd>',
          '</tpl>',
          '</dl>',
          '<tpl if="!_pubtype_name && !_imported">',
          '  <p class="pp-inactive">No data available.</p>',
          '</tpl>',
          '<tpl if="_needs_details_lookup == 1">',
          '  <ul><li>',
          '  <a class="pp-textlink pp-action pp-action-lookup" action="lookup-details">Lookup details</a>',
          '  </li></ul>',
          '</tpl>',
          '  <div style="clear:left;"></div>',
          '</div>',
          '<tpl if="trashed==0">',
          '  <div class="pp-box pp-box-side-panel pp-box-bottom pp-box-style1">',
          '  <ul>',
          '    <tpl if="doi || linkout || url || eprint || arxivid">',
          '      <li><a class="pp-textlink pp-action pp-action-go" action="view-online">View Online</a></li>',
          '    </tpl>',
          '    <tpl if="!doi && !linkout && !url && !eprint && !arxivid">',
          '      <li><a class="pp-action-inactive pp-action-go-inactive">No online link available</a></li>',
          '    </tpl>',
          '   <li><a href="#" action="email" class="pp-textlink pp-action pp-action-email">E-mail Reference</a></li>',
          '  </ul>',
          '  </div>',
          // Attachments box.
          '  <div class="pp-box pp-box-side-panel pp-box-style2 pp-box-files"',
          '    <h2>PDF</h2>',
          '    <div id="search-download-widget-{id}" class="pp-search-download-widget"></div>',
          '    <tpl if="_imported || attachments">',
          '      <h2>Supplementary Material</h2>',
          '    </tpl>',
          '      <tpl if="_attachments_list">',
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
          '    </tpl>',
          '  </div>',
          '</tpl>',
          '</div>');
      }

      return this._single;
    },

    _noSelection: function() {
      var template = [
        '<div id="main-container-{id}">',
        '  <div class="pp-box pp-box-side-panel pp-box-top pp-box-style2">',
        '    <p class="pp-inactive">No references selected.</p>',
        '  </div>',
        '</div>'];
      return[].concat(template);
    },

    _importedReference: function() {
      // Return the buttons which should show up when a reference is imported. Subclasses where
      // editing imported refs is not allowed should override this method.
      var tpl = [
        '  <div id="ref-actions" style="float:right;">',
        '  <tpl if="trashed==1">',
        '    <img src="/images/icons/arrow_rotate_anticlockwise.png" class="pp-img-action" action="restore-ref" ext:qtip="Restore Reference"/>',
        '    <img src="/images/icons/delete.png" class="pp-img-action" action="delete-ref" ext:qtip="Permanently Delete Reference"/>',
        '  </tpl>',
        '  <tpl if="trashed==0">',
        '    <img src="/images/icons/pencil.png" class="pp-img-action" action="edit-ref" ext:qtip="Edit Reference"/>',
        '    <img src="/images/icons/trash.png" class="pp-img-action" action="delete-ref" ext:qtip="Move Reference to Trash"/>',
        '  </tpl>',
        '  </div>'];
      return tpl.join('');
    },

  }

});