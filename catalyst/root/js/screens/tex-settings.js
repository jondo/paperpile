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

Paperpile.TexSettings = Ext.extend(Ext.Panel, {

  title: 'BibTeX Settings',

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      autoLoad: {
        url: Paperpile.Url('/screens/tex_settings'),
        callback: this.setupFields,
        scope: this
      },
      bodyStyle: 'pp-settings',
      autoScroll: true,
      iconCls: 'pp-icon-tools'
    });

    Paperpile.PatternSettings.superclass.initComponent.call(this);

    this.isDirty = false;

  },

  //
  // Creates checkboxes, textfields, buttons and installs event handlers
  //
  setupFields: function() {

    var settings = Paperpile.main.globalSettings['bibtex'];

    var fields = [];

    // Create checkbox objects for main options
    for (var f in settings) {
      if (f === 'export_fields' || f === 'title_quote') continue;
      var field = new Ext.form.Checkbox({
        checked: settings[f] == '1' ? true : false,
        id: f
      });
      fields.push(field);
    }

    // Create checkbox objects for export_fields
    for (var f in settings.export_fields) {
      var field = new Ext.form.Checkbox({
        checked: settings.export_fields[f] == '1' ? true : false,
        id: 'export_fields_' + f
      });
      fields.push(field);
    }

    // Render checkboxes and install check handler
    Ext.each(fields,
      function(field) {
        field.render(field.id + '_checkbox', 0);
        field.on('check', this.onToggleCheckbox, this);
      },
      this);

    // Combine checkbox with a button to emphasize the "bibtex_mode"
    // option
    this.masterButton = new Ext.Button({
      text: "Activate BibTeX mode",
      renderTo: 'bibtex_mode_button',
      enableToggle: true,
      pressed: settings.bibtex_mode === '1' ? true : false
    });

    this.masterButton.on('toggle', function(button, pressed) {
      Ext.getCmp('bibtex_mode').setValue(pressed);
    },
    this);

    Ext.getCmp('bibtex_mode').on('check', function(box, checked) {
      this.masterButton.toggle(checked, true);
    },
    this);

    this.titleQuoteTextarea = new Ext.form.TextArea({
      value: settings.title_quote.join('\n'),
      enableKeyEvents: true,
      renderTo: 'title_quote_textarea',
      width: 280,
      height: 200,
      disabled: settings.title_quote_complete ? false : true
    });

    this.titleQuoteTextarea.on('keyup',
      function() {
        this.titleQuoteButton.enable();
      },
      this);

    this.titleQuoteButton = new Ext.Button({
      text: "Save list",
      renderTo: 'title_quote_button',
      disabled: true
    });

    Ext.getCmp('title_quote_complete').on('check', function(box, checked) {
      this.titleQuoteTextarea.setDisabled(checked);
      this.titleQuoteButton.setDisabled(checked);
    },
    this);

    this.titleQuoteButton.on('click', this.saveTitleQuoteList, this);

    var tooltips = {
      bibtex_mode: "Activate various BibTeX specific functions throughout Paperpile. You may want to deactivate this option if you're not using BibTeX",
      import_strip_tex: 'Strip LaTeX markup when importing from a BibTeX file. E.g. <tt>\\textit{B. subtilis}</tt> will be converted to <tt>B. subtilis</tt>. <br>De-activate this function to preserve the original LaTeX markup. Note: Special characters that can be represented in Unicode (e.g. in <tt>G{\\"o}del</tt>) are always converted to the corresponding Unicode character.',
      export_escape: "Escape special characters (e.g. <tt>$\\{}</tt>...) when exporting to BibTeX. De-activate this option if you wish to add LaTeX markup in Paperpile. Note: Unicode characters are always exported in LaTeX encoding.",
      pretty_print: "Nicely format BibTeX including line breaks, aligned and indented fields. De-activate this option to show a simple key-value per line.",
      double_dash: 'Convert single dashes (<tt>-</tt>) in the "pages" field to double dashes (<tt>--</tt>).',
      use_quotes: 'Activate this option to use double quotes <tt>"..."</tt> as field delimiter in BibTeX output. If de-activated curly braces <tt>{...}</tt> are used.',
      title_quote_complete: "Enclose the title in curly braces <tt>{...}</tt> forcing BibTeX to preserve exactly all uppercase/lowercase characters. De-activate this option to let BibTeX handle capitalization.",
      export_fields: "Include/Exclude optional fields in the BibTeX output.",
      title_quote: "Special title words and phrases to be enclosed in curly braces <tt>{...}</tt> to prevent that capitalization is changed by BibTeX. One word or phrase by line.",
    };

    for (var tt in tooltips) {
      new Ext.ToolTip({
        target: tt + '_tooltip',
        minWidth: 50,
        maxWidth: 300,
        html: tooltips[tt],
        anchor: 'left',
        showDelay: 0,
        hideDelay: 0
      });
    }

  },

  onToggleCheckbox: function(box, checked) {

    var value = (checked) ? "1" : "0";

    var parts = box.id.match(/(export_fields_)(.*)/);

    var currentSettings = Paperpile.main.getSetting('bibtex');

    if (parts) {
      currentSettings.export_fields[parts[2]] = value;
    } else {
      currentSettings[box.id] = value;
    }

    Paperpile.main.setSetting('bibtex', currentSettings);
    this.showUpdateNote();

  },

  saveTitleQuoteList: function(button, event) {

    var list = this.titleQuoteTextarea.getValue().split('\n');
    var currentSettings = Paperpile.main.getSetting('bibtex');

    currentSettings.title_quote = list;

    Paperpile.main.setSetting('bibtex', currentSettings);

    this.titleQuoteButton.disable();

    this.showUpdateNote();

  },

  showUpdateNote: function() {

    Paperpile.status.updateMsg({
      msg: 'Settings saved.',
      duration: 2
    });

  }

});