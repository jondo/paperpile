/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */

Paperpile.PubOverview = Ext.extend(Ext.Panel, {

  itemId: 'overview',

  initComponent: function() {
    Ext.apply(this, {
      bodyStyle: {
        background: '#ffffff',
        padding: '7px'
      },
      autoScroll: true
    });

    Paperpile.PubOverview.superclass.initComponent.call(this);

    this.on('afterrender', this.installEvents, this);
  },

  forceUpdate: function() {
    this.onUpdate({
      updateSidePanel: 1
    });
  },

  getPluginPanel: function() {
    return this.findParentByType(Paperpile.PluginPanel);
  },

  getGrid: function() {
    return this.getPluginPanel().getGrid();
  },

  // Called when a non-user interaction causes an update of the overview panel.
  onUpdate: function(data) {
    var sm = this.getGrid().getSelectionModel();
    this.grid_id = this.getGrid().id;

    var numSelected = this.getGrid().getSelectionCount();

    if (numSelected == 1) {

      var oldData = this.oldData || {};
      var newData = sm.getSelected().data || {};

      newData.id = this.id;
      newData._pubtype_name = false;
      if (newData.pubtype) {
        var pt = Paperpile.main.globalSettings.pub_types[newData.pubtype];
        if (pt) {
          newData._pubtype_name = pt.name;
        }
      }

      this.data = newData;
      this.oldData = Ext.ux.clone(this.data);

      // Important: Check for a different GUID in order to decide whether to re-render
      // all the data again.
      if (newData.guid != oldData.guid ||
        newData._imported != oldData._imported) {
        this.updateAllInfo(newData);
        return;
      }

      var attachmentsChanged = false;
      if (newData._attachments_list.length != oldData._attachments_list.length) {
        attachmentsChanged = true;
      } else {
        for (var i = 0; i < newData._attachments_list.length; i++) {
          if (oldData._attachments_list[i].path != newData._attachments_list[i].path) {
            attachmentsChanged = true;
            break;
          }
        }
      }

      if (attachmentsChanged || newData.folders != oldData.folders) {
        this.updateAllInfo(newData);
        return;
      }

      if (data) {
        if (data.updateSidePanel) {
          this.updateAllInfo(newData);
          return;
        }
      }

      if (newData.tags != oldData.tags) {
        this.updateLabels(newData);
      }

      var jobChanged = 0;

      // Before checking fields check if _search_job got defined or undefined
      if ((oldData._search_job && !newData._search_job) || (newData._search_job && !oldData._search_job)) {
        jobChanged = 1;
      } else {
        for (var field in newData._search_job) {
          if (newData._search_job[field] != oldData._search_job[field]) {
            jobChanged = true;
            break;
          }
        }
      }
      if (newData.pdf != oldData.pdf || jobChanged) {
        this.updateSearchJob(newData);
      }

      var metaJobChanged = 0;
      if ((oldData._metadata_job && !newData._metadata_job) || (newData._metadata_job && !oldData._metadata_job)) {
        metaJobChanged = 1;
      } else {
        for (var field in newData._metadata_job) {
          if (newData._metadata_job[field] != oldData._metadata_job[field]) {
            metaJobChanged = true;
            break;
          }
        }
      }
      if (metaJobChanged) {
        this.updateAllInfo(newData);
      }

    } else {
      // Multiple articles selected.
      var d = {
        id: this.id
      };
      this.oldData = d;
      this.updateInfoMultiple(d);
    }
  },

  updateAllInfo: function(data) {
    data = this.fillInFields(data);
    this.getGrid().getSidebarTemplate().singleSelection.overwrite(this.body, data);
    this.updateEllipses(data);
    this.updateLabels(data);
    if (this.searchDownloadWidget) {
      this.searchDownloadWidget = null;
    }
    this.updateSearchJob(data);
  },

  fillInFields: function(data) {
    var list = [];
    if (data.folders) {
      // Find out which folders we're in.
      var foldersString = data.folders;
      var folders = foldersString.split(',');
      for (var i = 0; i < folders.length; i++) {
        var folder = folders[i];
        var node = Paperpile.main.tree.getNodeById(folder);
        if (node) {
          list[i] = {
            folder_name: node.text,
            folder_id: folder,
            rowid: data._rowid
          };
        }
      }
    }
    data._folders_list = list;
    return data;
  },

  updateEllipses: function(data) {
    var ellipsable_fields = ['.pp-info-doi', '.pp-info-pmid'];
    for (var i = 0; i < ellipsable_fields.length; i++) {
      var field = ellipsable_fields[i];
      var els = Ext.select("#"+this.id+" "+field);
      if (els.getCount() == 0) {
	  Paperpile.log("Can't find any "+field);
        continue;
      }
      var doiEl = els.first();
      var origText = doiEl.dom.innerHTML;
      var maxWidth = doiEl.getWidth() - (50);
      var textWidth = doiEl.getTextWidth();
      var count = 0;
      while (textWidth > maxWidth && count < 50) {
        var text = doiEl.dom.innerHTML;
        text = text.replace('...', '');
        var shorterText = text.substring(0, text.length - 1);
        doiEl.update(shorterText + '...');
	doiEl.set({'ext:qtip':origText});
        textWidth = doiEl.getTextWidth();
        count++;
      }
    }
  },

  updateLabels: function(data) {
    if (this.labelWidget == null) {
      this.labelWidget = new Paperpile.LabelWidget({
        grid: this.getGrid(),
        div_id: 'label-widget-' + this.id,
        renderTo: 'label-widget-' + this.id
      });
    }
    //    if (!Ext.get('label-widget-' + this.id)) {
    //      return;
    //    }
    this.labelWidget.renderData(data);
  },

  updateSearchJob: function(data) {
    if (this.searchDownloadWidget == null) {
      this.searchDownloadWidget = new Paperpile.SearchDownloadWidget({
        div_id: 'search-download-widget-' + this.id
      });
    }
    if (!Ext.fly('search-download-widget-' + this.id)) {
      return;
    }
    this.searchDownloadWidget.renderData(data);
  },

  updateInfoMultiple: function(data) {

    data.numSelected = this.getGrid().getSelectionCount();
    data.isBibtexMode = Paperpile.utils.isBibtexMode();
    data.totalCount = this.getGrid().getTotalCount();

    data.numImported = this.getGrid().getSelection('IMPORTED').length;
    data.allImported = this.getGrid().allImported;
    data.allSelected = this.getGrid().allSelected;

    var templateToUse = null;
    if (data.totalCount == 0) {
      templateToUse = this.getGrid().getSidebarTemplate().emptyGrid;
    } else if (data.numSelected == 0) {
      templateToUse = this.getGrid().getSidebarTemplate().noSelection;
    } else {
      templateToUse = this.getGrid().getSidebarTemplate().multipleSelection;
    }
    templateToUse.overwrite(this.body, data, true);

    if (data.numSelected > 0) {
      if (this.labelWidget == undefined) {
        this.updateLabels(data);
      }
      this.labelWidget.renderMultiple();
    }

    Ext.get('main-container-' + this.id).on('click', this.handleClick,
      this, {
        delegate: 'a'
      });
  },

  // Event handling for the HTML. Is called with 'el' as the Ext.Element of the HTML 
  // after the template was written in updateDetail
  //    
  installEvents: function() {
    var el = Ext.get('tag-add-link-' + this.id);
    this.el.on('click', this.handleClick, this);
  },

  showOverview: function() {
    var view = Paperpile.main.getActiveView();
    view.depressButton('overview_tab_button');
  },

  showDetails: function() {
    var view = Paperpile.main.getActiveView();
    view.depressButton('details_tab_button');
  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    switch (el.getAttribute('action')) {
    case 'email':
      this.getGrid().handleEmail();
      break;
    case 'doi-link':
      var url = "http://dx.doi.org/" + this.data.doi;
      Paperpile.utils.openURL(url);
      break;
    case 'doi-copy':
      Paperpile.utils.setClipboard("http://dx.doi.org/" + this.data.doi, 'DOI URL copied');
      break;

    case 'pmid-link':
      var url = 'http://www.ncbi.nlm.nih.gov/pubmed/' + this.data.pmid;
      Paperpile.utils.openURL(url);
      break;
    case 'pmid-copy':
      Paperpile.utils.setClipboard('http://www.ncbi.nlm.nih.gov/pubmed/' + this.data.pmid, 'PubMed URL copied');
      break;

    case 'eprint-link':
      var url = this.data.eprint;
      Paperpile.utils.openURL(url);
      break;
    case 'eprint-copy':
      Paperpile.utils.setClipboard(this.data.eprint, 'ePrint URL copied');
      break;

    case 'open-folder':
      var folder_id = el.getAttribute('folder_id');
      var node = Paperpile.main.tree.getNodeById(folder_id);
      Paperpile.main.tree.myOnClick(node);
      break;

    case 'delete-folder':
      var sel = this.getGrid().getSelection();
      var grid = this.getGrid();
      var folder_id = el.getAttribute('folder_id');
      Paperpile.main.deleteFromFolder(sel, grid, folder_id);
      break;

    case 'open-pdf':
      var path = this.data.pdf_name;
      if (!Paperpile.utils.isAbsolute(path)) {
        path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, path);
      }
      Paperpile.main.tabs.newPdfTab({
        file: path,
        title: this.data.pdf_name
      });
      Paperpile.main.inc_read_counter(this.data);
      break;

    case 'open-pdf-external':
      Paperpile.main.openPdfInExternalViewer(this.data.pdf_name, this.data);
      break;

    case 'attach-pdf':
      // Choose local PDF file and attach to database entry
      this.chooseFile(true);
      break;
    case 'search-pdf':
      // Search and download PDF file; if entry is already in database 
      // attach PDF directly to it
      //this.searchPDF(el.getAttribute('plugin'));
      this.getGrid().batchDownload();
      break;
    case 'cancel-download':
      this.getGrid().cancelDownload();
      break;
    case 'retry-download':
      this.getGrid().retryDownload();
      break;
    case 'clear-download':
      this.getGrid().clearDownload();
      break;
    case 'report-download-error':
      var infoString = this.data.title + '\n' + this.data._authors_display + '\n';
      infoString += this.data._citation_display + '\n' + this.data.doi + '\n' + this.data.linkout;
      Paperpile.main.reportPdfDownloadError(infoString);
      break;
    case 'import-pdf':
      // If PDF has been downloaded for an entry that is not
      // already imported, import entry and attach PDF
      var grid = this.ownerCt.ownerCt.items.get('center_panel').items.get(0);
      var pdf = this.data.pdf;
      grid.insertEntry(
        function(data) {
          this.attachFile(1, pdf);
        },
        this);
      break;

    case 'delete-pdf':
      // Delete attached PDF file from database entry
      this.deleteFile(true);
      break;

    case 'attach-file':
      // Attach an arbitrary number of files of any type to an entry in the database 
      this.chooseFile(false);
      break;

    case 'open-attachment':
      // Open attached files
      var path = el.getAttribute('path');
      Paperpile.utils.openFile(path);
      break;

    case 'delete-file':
      // Delete attached files
      this.deleteFile(false, el.getAttribute('guid'));
      break;

    case 'edit-ref':
      var grid = Paperpile.main.getActiveGrid();
      grid.handleEdit();
      break;

    case 'delete-ref':
      var grid = Paperpile.main.getActiveGrid();
      grid.handleDelete();
      break;

    case 'show-details':
      this.showDetails();
      break;

    case 'update-metadata':
      this.getGrid().updateMetadata();
      break;

    case 'batch-download':
      this.getGrid().batchDownload();
      break;

    case 'restore-ref':
      this.getGrid().deleteEntry('RESTORE');
      break;

    case 'import-ref':
      this.getGrid().insertEntry();
      break;
    case 'copy-text':
      this.getGrid().handleCopyFormatted();
      break;
    case 'copy-bibtex':
      this.getGrid().handleCopyBibtexCitation();
      break;
    case 'copy-keys':
      this.getGrid().handleCopyBibtexKey();
      break;
    }
  },

  renderTags: function() {

    if (this.searchDownloadWidget == null) {
      /*       this.searchDownloadWidget = new Paperpile.SearchDownloadWidget({
	 grid_id: this.grid_id,
	 itemId:'search-download-widget-'+this.id
       });
*/
    }
    if (!Ext.get('search-download-widget-' + this.id)) return;
    //this.searchDownloadWidget.renderData(this.data);
    return;
  },

  hideTagControls: function() {
    var container = Ext.get('tag-control-' + this.id);
    while (container.first()) {
      container.first().remove();
    }
  },

  showTagControls: function() {
    // Skip tags for combo which are already in list (unless we have multiple selection where this
    // does not make too much sense
    var list = [];

    Ext.StoreMgr.lookup('tag_store').each(function(rec) {
      var tag = rec.data.tag;
      if (!this.multipleSelection) {
        if (this.data.tags.match(new RegExp("," + tag + "$"))) return; // ,XXX
        if (this.data.tags.match(new RegExp("^" + tag + "$"))) return; //  XXX
        if (this.data.tags.match(new RegExp("^" + tag + ","))) return; //  XXX,
        if (this.data.tags.match(new RegExp("," + tag + ","))) return; // ,XXX,
      }
      list.push([tag]);
    },
    this);

    var store = new Ext.data.SimpleStore({
      fields: ['tag'],
      data: list
    });

    var combo = new Ext.form.ComboBox({
      id: 'tag-control-combo-' + this.id,
      store: store,
      displayField: 'tag',
      forceSelection: false,
      triggerAction: 'all',
      mode: 'local',
      enableKeyEvents: true,
      renderTo: 'tag-control-' + this.id,
      width: 120,
      listWidth: 120,
      initEvents: function() {
        this.constructor.prototype.initEvents.call(this);
        Ext.apply(this.keyNav, {
          "enter": function(e) {
            this.onViewClick();
            this.delayedCheck = true;
            this.unsetDelayCheck.defer(10, this);
            scope = Ext.getCmp(this.id.replace('tag-control-combo-', ''));
            scope.onAddTag();
            this.destroy();
          },
          doRelay: function(foo, bar, hname) {
            if (hname == 'enter' || hname == 'down' || this.scope.isExpanded()) {
              return Ext.KeyNav.prototype.doRelay.apply(this, arguments);
            }
            return true;
          }
        });
      }
    });

    combo.focus();

    var button = new Ext.Button({
      id: 'tag-control-ok-' + this.id,
      text: 'Add Label',
    });

    button.render(Ext.DomHelper.append('tag-control-' + this.id, {
      tag: 'div',
      cls: 'pp-button-control',
    }));

    if (!this.multipleSelection) {

      var cancel = new Ext.BoxComponent({
        autoEl: {
          tag: 'div',
          cls: 'pp-textlink-control',
          children: [{
            tag: 'a',
            id: 'tag-control-cancel-' + this.id,
            href: '#',
            cls: 'pp-textlink',
            html: 'Cancel'
          }]
        }
      });

      cancel.render('tag-control-' + this.id);

      Ext.get('tag-control-cancel-' + this.id).on('click', function() {
        Ext.get('tag-add-link-' + this.id).show();
        this.hideTagControls();
      },
      this);
    }

    Ext.get('tag-control-ok-' + this.id).on('click', this.onAddTag, this);

  },

  onAddTag: function() {

    var combo = Ext.getCmp('tag-control-combo-' + this.id);
    var tag = combo.getValue();

    combo.setValue('');

    if (this.data.tags != '') {
      this.data.tags = this.data.tags + "," + tag;
    } else {
      this.data.tags = tag;
    }

    if (!this.multipleSelection) {
      this.hideTagControls();
      Ext.get('tag-add-link-' + this.id).show();
    }

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/add_tag'),
      params: {
        grid_id: this.grid_id,
        selection: Ext.getCmp(this.grid_id).getSelection(),
        tag: tag
      },
      method: 'GET',

      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        var grid = Ext.getCmp(this.grid_id);
        grid.onUpdate(json.data);
        Ext.StoreMgr.lookup('tag_store').reload();
      },
      failure: Paperpile.main.onError,
      scope: this
    });

  },

  //
  // Choose a file from harddisk to attach. Either it is *the* PDF of the citation or a
  // supplementary file (given by isPDF).
  //
  chooseFile: function(isPDF) {
    var callback = function(filenames) {
      if (filenames.length > 0) {
        for (var i = 0; i < filenames.length; i++) {
          var file = filenames[i];
          this.attachFile(isPDF, file);
          if (isPDF) {
            return;
          }
        }
      }
    };
    var options;
    if (isPDF) {
      options = {
        title: 'Choose a PDF file to attach',
        selectionType: 'file',
        types: ['pdf'],
        multiple: false,
        typesDescription: 'PDF Files',
        scope: this
      };
    } else {
      options = {
        title: 'Choose file(s) to attach',
        selectionType: 'file',
        types: ['*'],
        multiple: true,
        typesDescription: 'All Files',
        scope: this
      };
    }
    Paperpile.fileDialog(callback, options);
  },

  //
  // Attach a file. Either it is *the* PDF of the citation or a
  // supplementary file (given by isPDF).
  //
  attachFile: function(isPDF, path) {
    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/attach_file'),
      params: {
        guid: this.data.guid,
        grid_id: this.grid_id,
        file: path,
        is_pdf: (isPDF) ? 1 : 0
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);
      },
      failure: Paperpile.main.onError,
      scope: this,
    });
  },

  //
  // Delete file. isPDF controls whether it is *the* PDF or some
  // other attached file. In the latter case the guid of the attached
  // file has to be given.
  //
  deleteFile: function(isPDF, guid) {

    var record = this.getGrid().store.getAt(this.getGrid().store.find('guid', this.data.guid));

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/delete_file'),
      params: {
        file_guid: isPDF ? this.data.pdf : guid,
        pub_guid: this.data.guid,
        is_pdf: (isPDF) ? 1 : 0,
        grid_id: this.grid_id
      },
      method: 'GET',
      success: function(response) {
        var json = Ext.util.JSON.decode(response.responseText);
        Paperpile.main.onUpdate(json.data);

        var undo_msg = '';
        if (isPDF) {
          undo_msg = 'Deleted PDF file ' + record.get('pdf_name');
        } else {
          undo_msg = "Deleted one attached file";
        }

        Paperpile.status.updateMsg({
          msg: undo_msg,
          action1: 'Undo',
          callback: function(action) {
            Ext.Ajax.request({
              url: Paperpile.Url('/ajax/crud/undo_delete'),
              method: 'GET',
              success: function(response) {
                var json = Ext.util.JSON.decode(response.responseText);
                Paperpile.main.onUpdate(json.data);
                Paperpile.status.clearMsg();
              },
              failure: Paperpile.main.onError,
              scope: this
            });
          },
          scope: this,
          hideOnClick: true
        });
      },
      failure: Paperpile.main.onError,
      scope: this,
    });

  },

  //
  // Searches for a PDF link on the publisher site
  //
  showEmpty: function(tpl) {

    var empty = new Ext.Template(tpl);
    empty.overwrite(this.body);

  }

});

Ext.reg('puboverview', Paperpile.PubOverview);