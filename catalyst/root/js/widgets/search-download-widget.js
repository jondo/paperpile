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
      this.progressBar = null;
    } else if (data._search_job) {
      if (data._search_job.error) {
        var el = [
          '<div class="pp-box-error"><p>' + data._search_job.error + '</p>',
          '<p><a href="#" class="pp-textlink" action="report-download-error">Get this fixed</a> | <a href="#" class="pp-textlink" action="clear-download">Clear</a></p>',
          '</div>'];
        Ext.DomHelper.overwrite(rootEl, el);
        this.progressBar = null;
      } else {

        if (!this.progressBar) {
          var el = [
            '<table class="pp-control-container">',
            '  <tr><td id ="dl-progress-' + this.div_id + '"></td><td><a href="#" action="cancel-download" class="pp-progress-cancel" ext:qtip="Cancel">&nbsp;</a></td></tr>',
            '</table>'];

          Ext.DomHelper.overwrite(rootEl, el);

          this.progressBar = new Ext.ProgressBar({
            text: data._search_job.msg || "",
            width: 200,
            renderTo: 'dl-progress-' + this.div_id
          });

          this.progressBar.wait({
            interval: 100,
            text: data._search_job.msg
          });
        }

        var fraction = 0;
        var downloaded = data._search_job.downloaded;
        var size = data._search_job.size;

        if (size && downloaded) {
          fraction = downloaded / size;
        }

        if (fraction) {
          if (this.progressBar.isWaiting()) {
            this.progressBar.reset();
          }
          this.progressBar.updateProgress(fraction, downloaded + " / " + size);
          this.progressBar.updateText(Ext.util.Format.fileSize(downloaded) + ' of ' + Ext.util.Format.fileSize(size));
        } else {
          var text = data._search_job.msg;
          this.progressBar.updateText(data._search_job.msg);
        }
      }
    } else {
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
      this.progressBar = null;
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