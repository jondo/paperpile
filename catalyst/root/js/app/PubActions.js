Ext.define('Paperpile.app.PubActions', {
  statics: {
    getActions: function() {
      return {
        'REMOVE_LABEL': new Ext.Action({
          itemId: 'REMOVE_LABEL',
          text: 'Remove a label',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'LABEL', 'remove');
          }
        }),
        'ADD_LABEL': new Ext.Action({
          itemId: 'ADD_LABEL',
          text: 'Add a label',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'LABEL', 'add');
          }
        }),
        'REMOVE_FOLDER': new Ext.Action({
          itemId: 'REMOVE_FOLDER',
          text: 'Remove a folder',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'FOLDER', 'remove');
          }
        }),
        'ADD_FOLDER': new Ext.Action({
          itemId: 'ADD_FOLDER',
          text: 'Add a folder',
          handler: function(guid) {
            Paperpile.app.PubActions.collectionHandler(guid, 'FOLDER', 'add');
          }
        }),
        'ATTACH_PDF': new Ext.Action({
          itemId: 'ATTACH_PDF',
          text: 'Attach a PDF to this reference',
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
        'ATTACH_FILE': new Ext.Action({
          itemId: 'ATTACH_PDF',
          text: 'Attach a PDF to this reference',
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
          text: 'Search & download the PDF',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selection = grid.getSelection();
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
        'EMAIL': new Ext.Action({
          itemId: 'EMAIL',
          text: 'E-mail References',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            var selection = grid.getSelection();
            var n = this.getSelectionCount();

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
              Paperpile.utils.openURL.defer(10, this, [link]);
            };

            Paperpile.Ajax({
              url: '/ajax/plugins/export',
              params: {
                grid_id: grid.id,
                selection: grid.getSelection(),
                export_name: 'Bibfile',
                export_out_format: 'EMAIL',
                get_string: true
              },
              success: function(response) {
                var json = Ext.decode(response.responseText);
                var string = json.data.string;
                callback.call(string);
              }
            });
          }
        }),

        'COPY_BIBTEX_KEY': new Ext.Action({
          itemId: 'COPY_BIBTEX_KEY',
          text: 'Copy LaTeX Citation',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.handleCopy(grid, 'Bibfile', 'BIBTEX', 'BibTeX copied');
          },
        }),
        'COPY_BIBTEX_CITATION': new Ext.Action({
          itemId: 'COPY_BIBTEX_CITATION',
          text: 'Copy as BibTeX',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.handleCopy(grid, 'Bibfile', 'CITEKEYS', 'LaTeX citation{s} copied');
          },
        }),
        'COPY_FORMATTED': new Ext.Action({
          itemId: 'COPY_FORMATTED',
          text: 'Copy Citation',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.handleCopy(grid, 'Bibfile', 'CITATIONS', '{n} citation{s} copied');
          }
        }),
        'EXPORT_SELECTION': new Ext.Action({
          itemId: 'EXPORT_SELECTION',
          text: 'Export selected references',
          triggerKey: 'x',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            selection = grid.getSelection();
            Paperpile.app.PubActions.exportSelectionHandler(grid.id, selection);
          },
        }),
        'TRASH': new Ext.Action({
          itemId: 'TRASH',
          text: 'Move to Trash',
          triggerKey: 'd',
          tooltip: 'Move selected references to Trash',
          iconCls: 'pp-icon-trash',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.deleteHandler('TRASH');
          },
          cls: 'x-btn-text-icon',
        }),
        'DELETE': new Ext.Action({
          itemId: 'DELETE',
          text: 'Delete Reference',
          triggerKey: 'd',
          tooltip: 'Permanently delete selected references',
          iconCls: 'pp-icon-delete',
          handler: function() {
            var grid = Paperpile.main.getCurrentGrid();
            Paperpile.app.PubActions.deleteHandler('DELETE');
          },
          cls: 'x-btn-text-icon',
        }),
        'EDIT': new Ext.Action({
          itemId: 'EDIT',
          text: 'Edit',
          triggerKey: 'e',
          icon: '/images/icons/pencil.png',
          tooltip: 'Edit the selected reference',
          xtype: 'button',
          handler: function() {
            Paperpile.log("Edit me!");
          },
          cls: 'x-btn-text-icon edit',
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
              // Need to defer this call, otherwise the context menu jumps to the upper-left side of screen...
              Paperpile.utils.openFile.defer(20, Paperpile.utils, [parts.dir]);
            }
          }
        }),
        'VIEW_PDF': new Ext.Action({
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
          iconCls: 'pp-icon-import-pdf',
          text: 'View PDF',
          triggerKey: 'v',
          disabledTooltip: 'No PDF attached to this reference'
        }),
        'TRASH': new Ext.Action({
          text: 'Move to Trash',
          iconCls: 'pp-icon-trash',
          scope: this,
          cls: 'x-btn-text-icon',
          triggerKey: 'd',
          tooltip: 'Move selected references to Trash',
          handler: function(grid_guid, selection) {
            var grid = Paperpile.main.getCurrentGrid();
            var selection = grid.getSelection();

            var firstRecord = grid.getSelectionModel().getLowestSelected();
            var firstIndex = grid.getStore().indexOf(firstRecord);

            Paperpile.Ajax({
              url: '/ajax/crud/delete_entry',
              params: {
                selection: selection,
                grid_id: grid_guid,
                mode: mode
              },
              timeout: 10000000,
              success: function(response) {
                var data = Ext.util.JSON.decode(response.responseText);
                var num_deleted = data.num_deleted;
              }
            });
          },
        })
      };
    },
    collectionHandler: function(guid, collectionType, mode) {
      var grid = Paperpile.main.getCurrentGrid();
      var count = grid.getSelectionCount();

      var url;
      if (mode == 'remove') {
        url = '/ajax/crud/remove_from_collection';
      } else if (mode == 'add') {
        url = '/ajax/crud/add_to_collection';
      }

      Paperpile.Ajax({
        url: url,
        params: {
          grid_id: grid.id,
          selection: grid.getSelection(),
          collection_guid: guid,
          type: collectionType
        },
        success: function(response) {
          var actionS = '',
          refS = '',
          collectionS = '';

          if (count == 1) refS = 'reference';
          if (count > 1) refS = 'references';

          if (collectionType = 'LABEL') collectionS = 'Label';
          if (collectionType = 'FOLDER') collectionS = 'Folder';

          if (mode == 'remove') actionS = 'removed from';
          if (mode == 'add') actionS = 'added to';

          Paperpile.log(collectionS + ' ' + actionS + ' ' + count + ' ' + refS);
        },
        failure: function(response) {
          // TODO.
        }
      });
    },
    deleteHandler: function(mode, deleteAll) {
      var grid = Paperpile.main.getCurrentGrid();

      var selection = grid.getSelection();
      if (grid.isAllSelected()) {
        selection = 'ALL';
      }
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

          // Does what it says: adds to the list of functions to call when the grid is next reloaded. This is handled in the customized 'onload' handler up at the top of the file.
          grid.enable();
          grid.doAfterNextReload.push(function() {
            grid.selectRowAndSetCursor(firstIndex);
          });
          if (mode == 'TRASH') {
            var msg = num_deleted + ' references moved to Trash';
            if (num_deleted == 1) {
              msg = "1 reference moved to Trash";
            }

            Paperpile.log("Deleted!");
            /*
            Paperpile.status.updateMsg({
              msg: msg,
              action1: 'Undo',
              callback: function(action) {
                // TODO: does not show up, don't know why:
                Paperpile.status.showBusy('Undo...');
                Paperpile.Ajax({
                  url: '/ajax/crud/undo_trash',
                  success: function(response) {
                    Paperpile.status.clearMsg();
                  },
                  scope: grid
                });
              },
              scope: grid,
              hideOnClick: true
            });
	    */
          } else {
            //            Paperpile.status.clearMsg();
          }
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
        }
      };
      Paperpile.Ajax({
        url: '/ajax/plugins/export',
        params: {
          grid_id: grid.id,
          selection: grid.getSelection(),
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

      Paperpile.fileDialog(callback, {
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