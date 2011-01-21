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

Paperpile.PatternSettings = Ext.extend(Ext.Panel, {

  title: 'Location and Patterns Settings',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      layout: 'fit',
      items: [{
        autoLoad: {
          url: Paperpile.Url('/screens/patterns'),
          callback: this.setupFields,
          scope: this
        },
        bodyStyle: 'pp-settings',
        iconCls: 'pp-icon-tools',
        autoScroll: true
      }]
    });

    this.tooltips = {
      library_db: 'The database file that holds all your information of your Paperpile library',
      paper_root: 'The folder where your PDFs and supplementary files are stored.',
      key_pattern: 'The pattern for the reference identifier (see help box).',
      pdf_pattern: 'The pattern to name your PDFs. Can include the reference identifier <code>[key]</code> and slashes <code>/</code> to use subfolders.',
      attachment_pattern: 'The pattern for the folder where your supplementary files get stored. Can include the reference identifier <code>[key]</code> and slashes <code>/</code> to use subfolders.'
    };

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.textfields = {};
  },

  //
  // Creates textfields, buttons and installs event handlers
  //
  setupFields: function() {

    Ext.get('patterns-cancel-button').on('click',
      function() {
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
      });

    // This is the main update task, called by all change events on all fields
    // with a fairly long delay.
    if (this.updateTask === undefined) {
      this.updateTask = new Ext.util.DelayedTask(this.updateFields, this);
    }

    this.saveTooltip = new Ext.ToolTip({
      target: Ext.get('patterns-save-button'),
      minWidth: 50,
      maxWidth: 300,
      html: '',
      anchor: 'bottom',
      showDelay: 0,
      hideDelay: 0
    });

    Ext.each(this.getFields(),
    function(item) {
      var field = new Ext.form.TextField({
        value: Paperpile.main.globalSettings[item],
        width: 300,
        // Yes, we want to fire events on keyup and whatnot.
        enableKeyEvents: true,
        // Remove validation triggers and events -- we don't use the built-in validation
        // system, rather we manually call the markInvalid function from within the 
        // updateFields method.
        validationEvent: false,
        validateOnBlur: false
      });

      var f = function() {
        this.updateTask.delay(500);
      };
      field.on('keydown', f, this);
      field.on('keyup', f, this);
      field.on('change', f, this);
      field.render(item + '_textfield', 0);

      new Ext.ToolTip({
        target: item + '_tooltip',
        minWidth: 50,
        maxWidth: 300,
        html: this.tooltips[item],
        anchor: 'left',
        showDelay: 0,
        hideDelay: 0
      });

      this.textfields[item] = field;

      // Add file chooser button and callbacks for PDF and library location fields.
      if (item == 'library_db' || item == 'paper_root') {
        field.addClass('pp-textfield-with-button');
        var b = new Ext.Button({
          text: item == 'library_db' ? 'Choose file' : 'Choose folder',
          renderTo: item + '_button'
        });

        b.on('click', function() {
          var parts = Paperpile.utils.splitPath(this.textfields[item].getValue());

          var callback = function(filenames) {
            if (filenames.length > 0) {
              var folder = filenames[0];
              this.textfields[item].setValue(folder);
              this.textfields[item].onBlur();
            }
          };

          var options = {
            title: item == 'library_db' ? 'Choose Paperpile database file' : 'Choose PDF folder',
            selectionType: item == 'library_db' ? 'file' : 'folder',
            dialogType: 'save',
            nameFilters: item == 'library_db' ? ["Paperpile library file (*.ppl)", "All files (*)"] : null,
            dontConfirmOverwrite: item == 'library_db' ? true : false,
            fileNameLabel: item == 'library_db' ? "File Name" : "Folder Name",
            scope: this
          };
          Paperpile.fileDialog(callback, options);
        },
        this);
      }

    },
    this);

    // Call the update immediately to load examples into the fields.
    this.updateFields();
  },

  getFields: function() {
    return['library_db', 'paper_root', 'key_pattern', 'pdf_pattern', 'attachment_pattern'];
  },

  //
  // Makes an AJAX call to the back-end to validate inputs and update example fields.
  // Then calls the updateSaveDisabled method to set the state of the Save button.
  //
  updateFields: function() {
    var params = {};

    // Disable the save button while the form is in indeterminate state (i.e. we haven't
    // yet validated all fields)
    this.disableSave();

    // Load field values into AJAX call parameters.
    Ext.each(this.getFields(),
    function(key) {
      params[key] = this.textfields[key].getValue();
    },
    this);

    Paperpile.Ajax({
      url: '/ajax/settings/pattern_example',
      params: params,
      success: function(response) {
        var data = Ext.util.JSON.decode(response.responseText).data;
        for (var f in data) {
          if (data[f].error) {
            this.textfields[f].markInvalid(data[f].error);
            // Instead of the built-in isInvalid() method, we use a custom
            // hasError flag to store the error state of each field. Kind of a
            // hack, but it's simple and independent of the built-in validation
            // stuff
            this.textfields[f].error = data[f].error;
            Ext.get(f + '_example').update('');
          } else {
            this.textfields[f].clearInvalid();
            this.textfields[f].error = undefined;
            Ext.get(f + '_example').update(data[f].string);
          }
        }
        this.updateSaveDisabled();
      },
      scope: this
    });

  },

  disableSave: function(reason) {
    var button = Ext.fly('patterns-save-button');
    this.disabled = true;
    button.un('click', this.submit, this);
    button.replaceClass('pp-save-button', 'pp-save-button-disabled');

    if (reason) {
      this.saveTooltip.enable();
      var html = "Cannot save: " + reason;
      if (!this.saveTooltip.el) {
        this.saveTooltip.html = html;
      } else {
        this.saveTooltip.body.update(html);
      }
    }
  },

  enableSave: function() {
    var button = Ext.fly('patterns-save-button');
    this.disabled = false;
    button.replaceClass('pp-save-button-disabled', 'pp-save-button');
    button.on('click', this.submit, this);
    this.saveTooltip.disable();
  },

  updateSaveDisabled: function() {
    // Default to the disabled state.
    var shouldBeDisabled = true;
    var disableReason = 'No changes were made';

    // DIRTY: If any of the fields are dirty, enable the save button.
    Ext.each(this.getFields(), function(f) {
      var field = this.textfields[f];
      if (!field) {
        return;
      }
      if (field.isDirty()) {
        shouldBeDisabled = false;
      }
    },
    this);

    // ERRORS: If any of the fields have errors, disable the save button.
    Ext.each(this.getFields(), function(f) {
      var field = this.textfields[f];
      if (!field) {
        return;
      }
      if (field.error) {
        shouldBeDisabled = true;
        disableReason = field.error;
      }
    },
    this);

    // Update the button according to the disabled flag.
    if (shouldBeDisabled) {
      this.disableSave(disableReason);
    } else if (!shouldBeDisabled) {
      this.enableSave();
    }
  },

  submit: function() {

    if (Paperpile.main.unfinishedTasks()) {
      Ext.Msg.show({
        title: 'Unfinished tasks',
        msg: 'There are unfinished background tasks. Wait until all tasks are finished before applying your changes.',
        buttons: Ext.Msg.OK,
        animEl: 'elId',
        icon: Ext.MessageBox.INFO,
      });
      return;
    }

    var params = {};

    Ext.each(this.getFields(),
    function(item) {
      params[item] = this.textfields[item].getValue();
    },
    this);

    Paperpile.status.showBusy('Applying changes.');

    this.spot = new Ext.ux.Spotlight({
      animate: false,
    });

    this.spot.show('main-toolbar');

    Paperpile.Ajax({
      url: '/ajax/settings/update_patterns',
      params: params,
      success: function(response, options) {
        var data = Ext.util.JSON.decode(response.responseText);

        // TODO: Here we should get the hashref of patterns settings
        // from the backend as part of the response data and apply it
        // to the front-end settings store.
        this.spot.hide();
        var error = Ext.util.JSON.decode(response.responseText).error;
        if (error) {
          Paperpile.main.onError(response, options);
          return;
        }

        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
        var old_library_db = Paperpile.main.globalSettings.library_db;
        Paperpile.main.loadSettings(
          function() {
            // Complete reload only if database has changed. This is
            // not necessary if the database has only be renamed but
            // we update also in this case.
            if (old_library_db != Paperpile.main.globalSettings.library_db) {

              // Explicitly delete all open grid objects from the
              // session variable in the backend. This needs to be
              // done *before* the new grid is loaded because of
              // strange race conditions that might occur when several
              // processes read/write the session variable.
              var open_grids = [];

              var tabs = Paperpile.main.tabs.items.items;
              for (var i = 0; i < tabs.length; i++) {
                if (tabs[i].grid) {
                  open_grids.push(tabs[i].grid.id);
                }
              }

              Paperpile.Ajax({
                url: '/ajax/plugins/delete_grids',
                params: {
                  grid_ids: open_grids
                },
                success: function(response) {

                  // Also make sure that tree is reloaded before other
                  // processes start to make sure the $session->{tree}
                  // is not overwritten due to some race condition
                  Paperpile.main.getTree().getRootNode().reload(function() {

                    // Now close all tabs (this again calls
                    // 'delete_grids' which is redundant but does not do
                    // any harm)
                    Paperpile.main.tabs.removeAll();
                    Paperpile.main.tabs.newMainLibraryTab();

                    Paperpile.main.tabs.setActiveTab(0);
                    Paperpile.main.tabs.doLayout();
                    Paperpile.main.getTree().expandAll();
                    Paperpile.main.afterLoadSettings();
                    Paperpile.main.triggerLabelStoreReload();
                    Paperpile.main.triggerFolderStoreReload();

                  });
                }
              });
            } else {
              Paperpile.main.onUpdate({
                pub_delta: 1
              });
            }
            Paperpile.status.clearMsg();
          },
          this);
      },

      // Greg: this never gets called unless it is an unexpected
      // error. There is no obvious difference in the behaviour of the
      // onError function with respect of whether it is an known or
      // unexpected error. So I have no idea why.
      failure: function(response, options) {

        var json = Ext.util.JSON.decode(response.responseText);

        this.spot.hide();

        if (json.error) {
          if (json.error.type === 'PaperRootNotEmptyError') {
            Paperpile.status.updateMsg({
              msg: 'The PDF folder is not empty. To avoid conflicts with existing files please choose a new or empty folder.',
              hideOnClick: true
            });

            this.textfields['paper_root'].markInvalid('Error');
            this.textfields['paper_root'].error = 'Error';
            this.updateSaveDisabled();
            return;
          }
        }

        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab());
        Paperpile.main.loadSettings();
      },

      scope: this
    });

  },

  destroy: function() {
    Paperpile.PatternSettings.superclass.destroy.call(this);

    if (this.updateTask) {
      this.updateTask.cancel();
    }

    Ext.each(this.getFields(),
    function(item) {
      var field = this.textfields[item];
      if (field) {
        field.destroy();
      }
    },
    this);

  }

});