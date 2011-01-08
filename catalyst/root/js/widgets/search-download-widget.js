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

    if (this.progressBar) {
      this.progressBar.destroy();
      this.progressBar = null;
    }

    // We already have a PDF
    if (data.pdf != '') {
      var el = [
        '    <ul>',
        '      <li id="open-pdf{id}">',
        '        <a href="#" class="pp-textlink pp-action pp-action-open-pdf" action="open-pdf">View PDF</a>',
        '        &nbsp;&nbsp;<a href="#" class="pp-textlink pp-second-link" action="open-pdf-external">External viewer</a>',
        '      </li>',
        '      <li id="delete-pdf-{id}">',
        '        <a href="#" class="pp-textlink pp-action pp-action-delete-pdf" action="delete-pdf">Delete PDF</a>',
        '      </li>',
        '    </ul>'];

      if (!data._imported) {
        el = [
          '    <ul>',
          '      <li id="open-pdf{id}">',
          '        <a href="#" class="pp-textlink pp-action pp-action-open-pdf" action="open-pdf">Open PDF</a>',
          '        &nbsp;&nbsp;<a href="#" class="pp-textlink pp-second-link" action="open-pdf-external">External viewer</a>',
          '      </li>',
          '      <li>',
          '        <a class="pp-textlink pp-action pp-action-add" href="#" action="import-ref">Import</a>',
          '     </li>',
          '    </ul>'];
      }

      Ext.DomHelper.overwrite(rootEl, el);
    } 

    // We are downloading a PDF
    else if (data._search_job) {

      // Download ended in an error
      if (data._search_job.error) {

        var el = [
          '<div class="pp-box-error"><p>' + data._search_job.error + '</p>',
          '<p><a href="#" class="pp-textlink" action="report-download-error">Get this fixed</a> | <a href="#" class="pp-textlink" action="clear-download">Clear</a></p>',
          '</div>'];

        // we don't want error reports on canceled downloads
        if (data._search_job.error.match(/download canceled/)){
          el = [
            '<div class="pp-box-error"><p>' + data._search_job.error + '</p>',
            '<p><a href="#" class="pp-textlink" action="clear-download">Clear</a></p>',
            '</div>'];
        }

        Ext.DomHelper.overwrite(rootEl, el);

      }

      // Download is still going on
      else {

        var fraction = 0;
        var downloaded = data._search_job.downloaded;
        var size = data._search_job.size;

        if (size && downloaded) {
          fraction = downloaded / size;
        }

        // Download is flagged for cancel but still running.
        if (data._search_job.interrupt === "CANCEL" && data._search_job.status === 'RUNNING') {
          var el = [
            '<div class="pp-download-widget">',
            '<div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running"> Canceling download...</span></div>',
            '<div><span class="pp-inactive">Cancel</a></div>',
            '</div>'];
          Ext.DomHelper.overwrite(rootEl, el);

        } else {


          // The actual download being performed and we have information how much we already got
          if (fraction) {
            var el = [
              '<div class="pp-download-widget">',
              '<div class="pp-download-widget-msg"><span id ="dl-progress-' + this.div_id + '"></span></div>',
              '<div><a href="#" action="cancel-download" class="pp-textlink">Cancel</a></div>',
              '</div>'];
            Ext.DomHelper.overwrite(rootEl, el);

            this.progressBar = new Ext.ProgressBar({
              text: data._search_job.msg || "",
              width: "90%",
              renderTo: 'dl-progress-' + this.div_id
            });

            this.progressBar.updateProgress(fraction, downloaded + " / " + size);
            this.progressBar.updateText(Ext.util.Format.fileSize(downloaded) + ' of ' + Ext.util.Format.fileSize(size));
          } 

          // We are still searching
          else {
            var msg = data._search_job.msg;

            var el = [
              '<div class="pp-download-widget">',
              '<div class="pp-download-widget-msg"><span class="pp-download-widget-msg-running"> ' + msg + '</span></div>',
              '<div><a href="#" action="cancel-download" class="pp-textlink">Cancel</a></div>',
              '</div>'];

            Ext.DomHelper.overwrite(rootEl, el);
          }

        }

      }
    } 
    // We don't have a PDF (and not downloading)
    else {
      var el = [
        '<ul>',
        '  <li id="search-pdf-{id}">',
        '    <a href="#" class="pp-textlink pp-action pp-action-search-pdf" action="search-pdf">Search & Download PDF</a>',
        '  </li>'];

      if (data._imported) {
        el = el.concat([
          '<li id="attach-pdf-{id}">',
          '    <a href="#" class="pp-textlink pp-action pp-action-attach-pdf" action="attach-pdf">Attach PDF</a>',
          '  </li>',
          '</ul>']);
      }

      Ext.DomHelper.overwrite(rootEl, el);
    }
  },

  handleClick: function(e) {

  },

  destroy: function() {
    if (this.progressBar) {
      this.progressBar.destroy();
    }
  }

});