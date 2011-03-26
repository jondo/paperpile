Ext.define('Paperpile.app.PubActions', {
  statics: {
    getActions: function() {
      return {
        'HOVER_COPY': new Ext.Action({
          itemId: 'HOVER_COPY',
          icon: '/images/icons/clipboard-hover.png',
          tooltip: 'Copy text',
          handler: function() {
            var event = Paperpile.app.Actions.lastTriggerEvent;
            var target = event.getTarget('.pp-copyable');
            if (target) {
              QRuntime.setClipboard(Ext.String.trim(target.textContent));
            }
          }
        }),
        'HOVER_LINK': new Ext.Action({
          itemId: 'HOVER_COPY',
          icon: '/images/icons/link-16-hover.png',
          tooltip: 'Open link in browser',
          handler: function() {
            var event = Paperpile.app.Actions.lastTriggerEvent;
            var target = Ext.get(event.getTarget('.pp-linkable'));
            if (target) {
              var url = Ext.fly(target).getAttribute('url');
              Paperpile.utils.openURL(url);
            }
          }
        }),
        'OVERVIEW_DETAILS_TOGGLE': new Ext.Action({
          itemId: 'OVERVIEW_DETAILS_TOGGLE',
          text: 'More ...',
          handler: function() {
            var activeTab = Paperpile.main.getTabs().getActiveTab();
            if (activeTab instanceof Paperpile.pub.View) {
              var basicInfo = activeTab.overview.child('BasicInfo');
              basicInfo.toggleDetailsMode();
            }
          }
        }),
        'UNDO_COLLECTION': new Ext.Action({
          itemId: 'UNDO_COLLECTION',
          text: 'Undo',
          handler: function(status) {
            Paperpile.log(status);
            // TODO for backend: implement a generic mechanism for undo-ing the lsat
            // CRUD-based action...
            /*
            Paperpile.Ajax({
              url: '/ajax/crud/undo_collection',
              success: function(response) {
              },
              scope: this
            });
		    */
          }
        }),
        'REMOVE_LABEL': new Ext.Action({
          itemId: 'REMOVE_LABEL',
          text: 'Remove a label',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'labels', 'remove');
          }
        }),
        'MANAGE_LABELS': new Ext.Action({
          itemId: 'MANAGE_LABELS',
          text: 'Manage Labels',
          handler: function() {

          }
        }),
        'ADD_LABEL': new Ext.Action({
          itemId: 'ADD_LABEL',
          text: 'Add a label',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'labels', 'add');
          }
        }),
        'ADD_LABEL_PANEL': new Ext.Action({
          itemId: 'ADD_LABEL',
          icon: '/images/icons/label_add.png',
          text: 'Add Label',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionPicker(guid, 'labels');
          },
        }),
        'OPEN_FOLDER': new Ext.Action({
          itemId: 'OPEN_FOLDER',
          icon: '/images/icons/folder.png',
          text: 'Open this folder',
          handler: function(guid) {
            Paperpile.log("Open!");
          }
        }),
        'REMOVE_FOLDER': new Ext.Action({
          itemId: 'REMOVE_FOLDER',
          icon: '/images/icons/cancel-small-bw.png',
          text: 'Remove a folder',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'folders', 'remove');
          }
        }),
        'ADD_FOLDER': new Ext.Action({
          itemId: 'ADD_FOLDER',
          text: 'Add a folder',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'folders', 'add');
          }
        }),
        'ADD_FOLDER_PANEL': new Ext.Action({
          itemId: 'ADD_FOLDER_PANEL',
          icon: '/images/icons/folder_add.png',
          text: 'Add Folder',
          handler: function(guid) {
            var store = Ext.getStore('folders');
            store.sortHierarchical();
            Paperpile.app.PubActions.collectionPicker(guid, 'folders', {
              sortBy: 'treeOrder'
            });
          },
        }),
        'DELETE_PDF': new Ext.Action({
          itemId: 'DELETE_PDF',
          icon: '/images/icons/cancel-small-bw.png',
          text: 'Delete',
          tooltip: 'Delete the attached PDF',
          handler: function(guid) {
            Paperpile.app.PubActions.deleteFileHandler(guid, true);
          }
        }),
        'DELETE_FILE': new Ext.Action({
          itemId: 'DELETE_FILE',
          text: 'Delete',
          icon: '/images/icons/cancel-small-bw.png',
          tooltip: 'Delete the attached file',
          handler: function(guid) {
            Paperpile.app.PubActions.deleteFileHandler(guid, false);
          }
        }),
        'RENAME_FILE': new Ext.Action({
          itemId: 'RENAME_FILE',
          icon: '/images/icons/pencil.png',
          text: 'Rename',
          tooltip: 'Rename the attached file',
          handler: function(guid) {
            // TODO in backend!
          }
        }),
        'ATTACH_PDF': new Ext.Action({
          itemId: 'ATTACH_PDF',
          icon: '/images/icons/folder_page_white.png',
          text: 'Attach a PDF',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var pub = grid.getSingleSelection();

            var callback = function(filenames) {
              if (filenames.length > 0) {
                Paperpile.Ajax({
                  url: '/ajax/crud/attach_files',
                  params: {
                    guid: pub.getId(),
                    grid_id: grid.id,
                    files: filenames,
                    is_pdf: 1
                  },
                  success: function(response) {
                    Paperpile.log("Successfully attached PDF!");
                    // TODO: add a status message and an undo function.
                  },
                  scope: grid
                });

              }
            };
            var options = {
              title: 'Choose a PDF file to attach',
              selectionType: 'file',
              types: ['pdf'],
              typesDescription: 'PDF Files',
              multiple: false,
              nameFilters: ["PDF (*.pdf)"],
              scope: grid
            };
            Paperpile.app.FileDialog.createDialog(callback, options);
          }
        }),
        'OPEN_FILE': new Ext.Action({
          itemId: 'OPEN_FILE',
          text: 'Open File',
          tooltip: 'Open the attached file',
          handler: function(path) {
            Ext.defer(Paperpile.utils.openFile, 20, Paperpile.utils, [path]);
          },
        }),
        'ATTACH_FILES': new Ext.Action({
          itemId: 'ATTACH_FILES',
          icon: '/images/icons/attach.png',
          text: 'Attach file(s)',
          tooltip: 'Attach one or more files to this reference',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var pub = grid.getSingleSelection();

            var callback = function(filenames) {

              if (filenames.length > 0) {
                Paperpile.Ajax({
                  url: '/ajax/crud/attach_files',
                  params: {
                    guid: pub.getId(),
                    grid_id: grid.id,
                    files: filenames,
                    is_pdf: 0
                  },
                  success: function(response) {
                    // TODO: add a status message and an undo function.
                  },
                  scope: grid
                })
              }
            };
            var options = {
              title: 'Choose one or more files to attach',
              selectionType: 'file',
              types: ['*'],
              typesDescription: 'All Files',
              multiple: true,
              nameFilters: ["All files (*)"],
              scope: grid
            };
            Paperpile.app.FileDialog.createDialog(callback, options);
          }
        }),
        'SEARCH_PDF': new Ext.Action({
          itemId: 'SEARCH_PDF',
          icon: '/images/icons/page_white_search.png',
          text: 'Download PDF',
          tooltip: 'Search online to fetch a PDF of the article',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selection = grid.getSelectionForAjax();
            if (selection.length > 1) {
              Paperpile.main.queue.setSubmitting();
            }
            Paperpile.Ajax({
              url: '/ajax/crud/batch_download',
              params: {
                selection: selection,
                grid_id: grid.id
              },
              success: function(response) {
                // Trigger a thread to start requesting queue updates.
                Paperpile.main.queueUpdate();
              }
            });
          }
        }),
        'CANCEL_DOWNLOAD': new Ext.Action({
          itemId: 'CANCEL_DOWNLOAD',
          text: 'Cancel the current PDF download',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selected_id = grid.getSingleSelection().data._search_job.id;
            Paperpile.Ajax({
              url: '/ajax/queue/cancel_jobs',
              params: {
                ids: selected_id
              }
            });
          }
        }),
        'RETRY_DOWNLOAD': new Ext.Action({
          itemId: 'RETRY_DOWNLOAD',
          text: 'Retry the failed PDF download',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selected_id = grid.getSingleSelection().data._search_job.id;
            Paperpile.Ajax({
              url: '/ajax/queue/retry_jobs',
              params: {
                ids: selected_id
              },
              success: function(response) {
                Paperpile.main.queueJobUpdate();
              }
            });
          }
        }),
        'CLEAR_DOWNLOAD': new Ext.Action({
          itemId: 'RETRY_DOWNLOAD',
          text: 'Retry the failed PDF download',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selected_id = grid.getSingleSelection().data._search_job.id;
            Paperpile.Ajax({
              url: '/ajax/queue/remove_jobs',
              params: {
                ids: selected_id
              }
            });

          }
        }),
        'VIEW_ONLINE': new Ext.Action({
          itemId: 'VIEW_ONLINE',
          text: 'View Online',
          tooltip: 'View this reference online',
          icon: '/images/icons/world_go.png',
          handler: function() {

          },
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var pub = grid.getSingleSelection();

            var url;
            var data = pub.data;
            if (data.pmid) {
              url = 'http://www.ncbi.nlm.nih.gov/pubmed/' + data.pmid;
            } else if (data.doi) {
              url = 'http://dx.doi.org/' + data.doi;
            } else if (data.eprint) {
              url = data.eprint;
            } else if (data.arxivid) {
              url = 'http://arxiv.org/abs/' + data.arxivid;
            } else if (data.url) {
              url = data.url;
            }
            Paperpile.utils.openURL(url);
          }
        }),
        'EMAIL': new Ext.Action({
          itemId: 'EMAIL',
          text: 'E-mail Reference',
          icon: '/images/icons/email.png',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selection = grid.getSelection();
            var n = grid.getSelectionCount();

            var me = grid;

            var callback = function(string) {
              var subject = "Papers for you";
              if (n == 1) {
                subject = "Paper for you";
              }
              var body = 'I thought you might be interested in the following:';
              var attachments = [];
              string = string.replace(/%0A/g, "\n");
              // The QRuntime appears capable of sending URLs of very long lengths, at least to Thunderbird.
              // So we don't need to use as low of a cut-off threshold as before...
              if (string.length > 1024 * 50) {
                QRuntime.setClipboard(string);
                var platform = Paperpile.utils.get_platform();
                if (platform == 'osx') {
                  string = "(Hit Command-V to paste citations here)";
                } else if (platform == 'windows') {
                  string = "(Hit Ctrl-V to paste citations here)";
                } else {
                  string = "(Use the paste command to insert citations here)";
                }
              }
              var link = [
                'mailto:?',
                'subject=' + subject,
                '&body=' + body + "\n\n" + string,
                "\n\n--\nShared with Paperpile\nhttp://paperpile.com",
                attachments.join('')].join('');
              Ext.defer(Paperpile.utils.openURL, 10, this, [link]);
            };

            Paperpile.Ajax({
              url: '/ajax/plugins/export',
              params: {
                grid_id: grid.id,
                selection: grid.getSelectionForAjax(),
                export_name: 'Bibfile',
                export_out_format: 'EMAIL',
                get_string: true
              },
              success: function(response) {
                var json = Ext.decode(response.responseText);
                var string = json.data.string;
                callback.call(me, string);
              }
            });
          }
        }),

        'COPY_BIBTEX_KEY': new Ext.Action({
          itemId: 'COPY_BIBTEX_KEY',
          text: 'Copy LaTeX Citation',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.copyHandler(grid, 'Bibfile', 'BIBTEX', 'BibTeX copied');
          },
        }),
        'COPY_BIBTEX_CITATION': new Ext.Action({
          itemId: 'COPY_BIBTEX_CITATION',
          text: 'Copy BibTeX \\cite',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.copyHandler(grid, 'Bibfile', 'CITEKEYS', 'LaTeX citation{s} copied');
          },
        }),
        'COPY_FORMATTED': new Ext.Action({
          itemId: 'COPY_FORMATTED',
          text: 'Copy Citation',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.copyHandler(grid, 'Bibfile', 'CITATIONS', '{n} citation{s} copied');
          }
        }),
        'EXPORT_SELECTION': new Ext.Action({
          itemId: 'EXPORT_SELECTION',
          text: 'Export to File',
          triggerKey: 'x',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            selection = grid.getSelectionForAjax();
            Paperpile.app.PubActions.exportSelectionHandler(grid.id, selection);
          },
        }),
        'TRASH': new Ext.Action({
          itemId: 'TRASH',
          icon: '/images/icons/trash.png',
          text: 'Move to Trash',
          triggerKey: 'd',
          tooltip: 'Move selected references to Trash',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.deleteHandler('TRASH');
          },
        }),
        'DELETE': new Ext.Action({
          itemId: 'DELETE',
          text: 'Delete Reference',
          triggerKey: 'd',
          tooltip: 'Permanently delete selected references',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.deleteHandler('DELETE');
          },
        }),
        'EDIT': new Ext.Action({
          itemId: 'EDIT',
          text: 'Edit Reference',
          triggerKey: 'e',
          icon: '/images/icons/pencil.png',
          tooltip: 'Edit the selected reference',
          xtype: 'button',
          handler: function() {
            Paperpile.log("Edit me!");
          },
        }),
        'AUTO_COMPLETE': new Ext.Action({
          itemId: 'AUTO_COMPLETE',
          text: 'Auto-complete Data',
          icon: '/images/icons/reload.png',
          tooltip: 'Auto-complete citation with data from online resources.',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selectionCount = grid.getSelectionCount();

            if (selectionCount == 1) {
              grid.handleEdit(false, true);
              return;
            }

            if (selection.length > 1) {
              Ext.MessageBox.buttonText.ok = "Start Update";
              Ext.Msg.show({
                title: 'Auto-complete',
                msg: 'Data for ' + selectionCount + ' references will be matched to online resources and automatically updated. Backup copies of the old data will be copied to the Trash. Continue?',
                icon: Ext.MessageBox.INFO,
                buttons: Ext.Msg.OKCANCEL,
                fn: function(btn) {
                  if (btn === 'ok') {
                    Paperpile.main.queueWidget.setSubmitting();
                    Paperpile.Ajax({
                      url: '/ajax/crud/batch_update',
                      params: {
                        selection: selection,
                        grid_id: grid.id
                      },
                      success: function(response) {
                        // Trigger a thread to start requesting queue updates.
                        Paperpile.main.queueUpdate();
                      }
                    });
                  }
                  Ext.MessageBox.buttonText.ok = "Ok";
                },
                scope: grid
              });
            }
          }
        }),
        'LOOKUP_DETAILS': new Ext.Action({

          text: 'Lookup Details',
          handler: function() {
            Paperpile.app.PubActions.lookupDetailsHandler();
          }
        }),
        'OPEN_PDF_FOLDER': new Ext.Action({
          text: 'Show in folder',
          icon: '/images/icons/folder.png',
          itemId: 'OPEN_PDF_FOLDER',
          tooltip: 'Show in folder',
          disabledTooltip: 'No PDF attached to this reference',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var sm = grid.getSelectionModel();
            var pub = grid.getSingleSelection();
            if (pub.get('pdf')) {
              var pdf = pub.get('pdf_name');
              var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
              var parts = Paperpile.utils.splitPath(path);
              Ext.defer(Paperpile.utils.openFile, 20, Paperpile.utils, [parts.dir]);
            }
          }
        }),
        'OPEN_PDF': new Ext.Action({
          itemId: 'VIEW_PDF',
          text: 'View PDF',
          icon: '/images/icons/page_white_acrobat.png',
          triggerKey: 'v',
          tooltip: 'Open the attached PDF in Paperpile',
          disabledTooltip: 'No PDF attached to this reference',
          handler: function(grid_id, guid) {
            var grid = Paperpile.main.getCurrentGrid();
            var pub = grid.getSingleSelection();
            if (pub.get('pdf')) {
              var pdf = pub.get('pdf_name');
              var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
              Paperpile.main.tabs.newPdfTab({
                file: path,
                filename: pdf
              });
              //Paperpile.main.inc_read_counter(this.getSingleSelection().data);
            }
          },
        }),
        'OPEN_PDF_EXTERNAL': new Ext.Action({
          itemId: 'OPEN_PDF_EXTERNAL',
          text: 'Open in External Viewer',
          icon: '/images/icons/page-external.png',
          triggerKey: 'v',
          tooltip: 'Open in your default PDF reader',
          disabledTooltip: 'No PDF attached to this reference',
          handler: function(grid_id, guid) {
            var grid = Paperpile.main.getCurrentGrid();
            var sm = grid.getSelectionModel();
            var pub = grid.getSingleSelection();
            if (pub.get('pdf')) {
              var pdf = pub.get('pdf_name');
              var path = Paperpile.utils.catPath(Paperpile.main.globalSettings.paper_root, pdf);
              Ext.defer(Paperpile.utils.openFile, 20, Paperpile.utils, [path]);
            }
          },
        }),
      };
    },
    collectionPicker: function(guid, collectionType, extraOptions) {
      var panelId = collectionType + '-panel';
      var lp = Ext.getCmp(panelId);
      if (!lp) {
        extraOptions = extraOptions || {};
        var options = Ext.apply({
          id: panelId,
          collectionType: collectionType,
          height: 80,
          width: 130,
          addCheckBoxes: true,
          dontHideOnClickNodes: function() {
            return['.pp-action'];
          }
        },
        extraOptions);
        lp = Ext.createByAlias('widget.collectionpicker', options);
        lp.on('applychanges', function(lp, added, removed) {
          Paperpile.app.PubActions.collectionHandler(added.collect('guid', 'data'), collectionType, 'add');
          Paperpile.app.PubActions.collectionHandler(removed.collect('guid', 'data'), collectionType, 'remove');
          this.hide();
        },
        lp);
        lp.on('newitem', function(lp, newName) {
          Paperpile.app.PubActions.collectionHandler([], collectionType, 'new', {
            name: newName
          });
          this.hide();
        },
        lp);
      }

      var event = Paperpile.app.Actions.lastTriggerEvent;
      var target = Ext.get(event.getTarget());
      Ext.defer(function() {
        if (lp.isHidden()) {
          var grid = Paperpile.main.getCurrentGrid();
          var selection = grid.getSelection();
          var collections = grid.getSelectedCollections(collectionType);
          lp.setCheckedIds(collections.collect('guid'));

          // Collect all label GUIDs and pre-set them as checked.
          lp.show();
          lp.alignTo(event.getTarget(), 'tl-bl?');
        } else {
          lp.hide();
        }
      },
      10);
    },
    collectionHandler: function(guids, collectionType, mode, params) {
      if (guids.length == 0 && mode != 'new') {
        Paperpile.log("Nothing to " + mode + " for " + collectionType);
        return;
      }

      params = params || {};

      var dbType;
      var singular;
      if (collectionType == 'folders') {
        dbType = 'FOLDER';
        singular = 'folder';
      } else if (collectionType == 'labels') {
        dbType = 'LABEL';
        singular = 'label';
      }

      var grid = Paperpile.main.getCurrentGrid();
      var count = grid.getSelectionCount();

      var url;
      var statusTpl;
      if (mode == 'remove') {
        url = '/ajax/crud/remove_from_collection';
        if (collectionType == 'folders') {
          statusTpl = "Removing reference{sRef} from {collType}{sColl}";
        } else {
          statusTpl = "Removing {collType}{sColl} from reference{sRef}";
        }
      } else if (mode == 'add') {
        url = '/ajax/crud/move_in_collection';
        if (collectionType == 'folders') {
          statusTpl = "Adding reference{sRef} to {collType}{sColl}";
        } else {
          statusTpl = "Adding {collType}{sColl} to reference{sRef}";
        }
      } else if (mode == 'new') {
        url = '/ajax/crud/new_collection';
        statusTpl = "Creating new {singularType}";
      }

      var tplData = {
        nRef: count > 1 ? count : '',
        sRef: count > 1 ? 's' : '',
        collType: singular,
        sColl: guids.length > 1 ? 's' : '',
        nColl: guids.length > 1 ? guids.length : ''
      };
      var status = Paperpile.main.status.createNotification({
        icon: Paperpile.app.Status.busyIcon,
        text: new Ext.XTemplate(statusTpl).apply(tplData),
        delay: 1000
      });

      status.delay(4000, "Still waiting");
      status.delay(8000, "Taking forever");
      status.delay(12000, "argh!!!!!");

      Paperpile.log(collectionType);
      var store = Ext.getStore(collectionType);
      var record = store.getById(guids[0]);

      Paperpile.Ajax({
        url: url,
        params: Ext.apply(params, {
          grid_id: grid.id,
          selection: grid.getSelectionForAjax(),
          collection_guid: guids,
          type: dbType
        }),
        success: function(response) {

          var collString;
          if (guids.length > 1) {
            collString = guids.length + " " + collectionType;
          } else {
            collString = '"' + record.get('name') + '"';
          }

          var string;
          if (collectionType == 'folders') {
            var refString = (count > 1 ? 'The selected references were ' : 'The selected reference was ');
            var verbString = (mode == 'add' ? 'added to ' : 'removed from ');
            string = refString + verbString + collString;
          } else if (collectionType == 'labels') {
            var refString = (count > 1 ? ' the selected references' : 'the selected reference');
            var verbString = (mode == 'add' ? 'added to ' : 'removed from ');
            collString = collString + (guids.length > 1 ? ' were ' : ' was ');
            string = collString + verbString + refString;
          }

          status.updateStatus({
            reset: true,
            text: string,
            actions: [{
              text: 'Undo',
              action_id: 'UNDO_COLLECTION'
            }]
          });
        },
        failure: function(response) {
          // TODO.
        }
      });
    },
    deleteFileHandler: function(file_guid, isPdf) {
      var grid = Paperpile.main.getCurrentGrid();
      var pub = grid.getSingleSelection();

      Paperpile.Ajax({
        url: '/ajax/crud/delete_file',
        params: {
          'file_guid': file_guid,
          'pub_guid': pub.getId(),
          'is_pdf': isPdf ? 1 : 0,
          'grid_id': grid.id
        },
        timeout: 10000000,
        success: function(response) {
          Paperpile.log("Deleted file " + file_guid);
        }
      });
    },
    deleteHandler: function(mode, deleteAll) {
      var grid = Paperpile.main.getCurrentGrid();

      var selection = grid.getSelectionForAjax();
      if (grid.getSelectionCount() == 0) {
        Paperpile.log("Delete handler called on empty selection -- something wrong?");
        return;
      }

      // Find the lowest index of the current selection.
      var firstRecord = grid.getSelectionModel().getLowestSelected();
      var firstIndex = grid.getStore().indexOf(firstRecord);

      if (mode == 'DELETE') {
        Paperpile.status.showBusy('Deleting references from library');
      }
      if (mode == 'TRASH') {
        Paperpile.status.showBusy('Moving references to Trash');
      }
      if (mode == 'RESTORE') {
        Paperpile.status.showBusy('Restoring references');
      }

      grid.disable();

      Paperpile.Ajax({
        url: '/ajax/crud/delete_entry',
        params: {
          selection: selection,
          grid_id: grid.id,
          mode: mode
        },
        timeout: 10000000,
        success: function(response) {
          var data = Ext.decode(response.responseText);
          var num_deleted = data.num_deleted;

          grid.enable();
          grid.doAfterNextReload.push(function() {
            grid.selectRowAndSetCursor(firstIndex);
          });
          if (mode == 'TRASH') {
            var msg = num_deleted + ' references moved to Trash';
            if (num_deleted == 1) {
              msg = "1 reference moved to Trash";
            }

            Paperpile.log("Trashed!");
          } else {}
        },
        failure: function() {
          // TODO: better error message.
          Paperpile.log("Error deleting!");
          grid.enable();
        },
        scope: grid
      });
    },
    copyHandler: function(grid, module, format, msg) {
      var isMultiple = grid.getSelectionCount() > 1;
      var s = '';
      var n = '';
      if (isMultiple) {
        s = 's';
        n = grid.getSelectionCount();
      }
      msg = msg.replace("{n}", n);
      msg = msg.replace("{s}", s);

      var callback = function(string) {
        if (IS_QT) {
	    QRuntime.setClipboard(string);
	    Paperpile.log("Copied "+string);
        }
      };
      Paperpile.Ajax({
        url: '/ajax/plugins/export',
        params: {
          grid_id: grid.id,
          selection: grid.getSelectionForAjax(),
          export_name: module,
          export_out_format: format,
          get_string: true
        },
        success: function(response) {
          var json = Ext.decode(response.responseText);
          var string = json.data.string;
          callback.call(grid, string);
        }
      });
    },
    lookupDetailsHandler: function() {
      // Get the Grid by ID.
      var grid = Paperpile.main.getCurrentGrid();
      // Get the currently-selected pub.
      var pub = grid.getPub(guid);
      var data = pub.data;
      if (data._needs_details_lookup) {
        var guid = data.guid;

        var cancelFn = function() {
          clearTimeout(grid.timeoutWarn);
          clearTimeout(grid.timeoutAbort);

          Ext.Ajax.abort(grid.lookupDetailsTransaction);
          Paperpile.Ajax({
            url: '/ajax/misc/cancel_request',
            params: {
              cancel_handle: grid.id + '_lookup',
              kill: 1
            }
          });

        };

        Paperpile.status.updateMsg({
          busy: true,
          msg: 'Looking up bibliographic data',
          action1: 'Cancel',
          callback: function() {
            Ext.Ajax.abort(grid.lookupDetailsTransaction);
            cancelFn.call();
            Paperpile.status.clearMsg();
            grid.getSelectionModel().un('beforerowselect', blockingFunction, grid);
            grid.isLocked = false;
          },
          scope: grid
        });

        // Warn after 10 sec
        grid.timeoutWarn = (function() {
          Paperpile.status.setMsg('This is taking longer than usual. Still looking up data.');
        }).defer(10000, grid);

        // Abort after 20 sec
        grid.timeoutAbort = (function() {
          Ext.Ajax.abort(grid.lookupDetailsTransaction);
          grid.cancelLookupDetails();
          Paperpile.status.clearMsg();
          Paperpile.status.updateMsg({
            msg: 'Data lookup failed. There may be problems with your network or ' + grid.plugin_name + '.',
            hideOnClick: true
          });
          grid.lookupDetailsLock = false;
        }).defer(20000, grid);

        grid.lookupDetailsTransaction = Paperpile.Ajax({
          url: '/ajax/crud/complete_entry',
          params: {
            selection: sel.id,
            grid_id: grid.id,
            cancel_handle: grid.id + '_lookup'
          },
          success: function(response, options) {
            var json = Ext.util.JSON.decode(response.responseText);
            grid.lookupDetailsLock = false;

            clearTimeout(grid.timeoutWarn);
            clearTimeout(grid.timeoutAbort);

            if (json.error) {
              Paperpile.main.onError(response, options);
              return;
            }

            Paperpile.status.clearMsg();
            grid.updateButtons();
            grid.getPluginPanel().updateDetails();
          },
          failure: function(response, options) {
            grid.lookupDetailsLock = false;
            clearTimeout(grid.timeoutWarn);
            clearTimeout(grid.timeoutAbort);
          },
          scope: grid
        });
      }
    },
    exportSelectionHandler: function(gridId, selection, sourceNode) {
      var callback = function(filenames, filter) {
        if (filenames.length == 0) {
          return;
        }
        var formatsMap = {
          'BibTeX (*.bib)': 'BIBTEX',
          'RIS (*.ris)': 'RIS',
        };
        var format = formatsMap[filter];
        var file = filenames[0];

        var collection_id = null;
        var node_id = null;
        var grid_id = null;
        if (sourceNode && (sourceNode.type == 'FOLDER' || sourceNode.type == 'LABEL')) {
          collection_id = sourceNode.id;
        } else if (sourceNode) {
          node_id = sourceNode.id;
        } else if (gridId) {
          grid_id = gridId;
        } else {
          return;
        }

        Paperpile.status.showBusy('Exporting to ' + file + '...');
        Paperpile.Ajax({
          url: Paperpile.Url('/ajax/plugins/export'),
          params: {
            source_node: node_id,
            collection_id: collection_id,
            selection: selection,
            grid_id: grid_id,
            export_name: 'Bibfile',
            export_out_format: format,
            export_out_file: file
          },
          success: function() {
            Paperpile.status.clearMsg();
          },
          scope: this
        });
      };

      Paperpile.app.FileDialog.createDialog(callback, {
        'title': 'Choose file and format for export',
        'dialogType': 'save',
        'selectionType': 'file',
        'nameFilters': [
          'BibTeX (*.bib)',
          'RIS (*.ris)']
      });
    },
  }
});