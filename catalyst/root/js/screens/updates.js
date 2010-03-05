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


Paperpile.Updates = Ext.extend(Ext.Panel, {

  title: 'Updates',

  markupPatch: [
    '<div class="pp-box pp-box-top pp-box-style1" style="width:400px;">',
    '<tpl for="updates">',
    '<h2>Update {name}</h2>',
    '<p>{msg}</p>',
    '<ul class="pp-update-log">',
    '<tpl for="log">',
    '<li>{.}</li>',
    '</tpl>',
    '</ul>',
    '</tpl>',
    '<center><div id="download-button"></div></center>',
    '<p>&nbsp;</p>',
    '</div>', ],

  // Add details how to install updates for different operating systems
  markupNoPatch: [
    '<div class="pp-box pp-box-top pp-box-style1" style="width:400px;">',
    '<p>&nbsp;</p>',
    '<p>Version {latestVersion} of Paperpile is available for download</p>',
    '<center><div id="download-button"></div></center>',
    '<p>&nbsp;</p>',
    '</div>', ],

  initComponent: function() {
    Ext.apply(this, {
      closable: true,
      bodyStyle: 'pp-settings',
      autoScroll: true,
      iconCls: 'pp-icon-update',
    });

    Paperpile.Updates.superclass.initComponent.call(this);

  },

  afterRender: function() {
    Paperpile.Updates.superclass.afterRender.apply(this, arguments);

    var template;
    var buttonText = '';
    var action;

    if (Paperpile.updateInfo.patch_available) {
      template = new Ext.XTemplate(this.markupPatch).compile();
      buttonText = 'Install updates (' + Ext.util.Format.fileSize(Paperpile.updateInfo.download_size) + ')';
      action = this.performUpgrade;
    } else {
      template = new Ext.XTemplate(this.markupNoPatch).compile();
      buttonText = 'Get update';
      action = this.redirect;
    }

    Paperpile.updateInfo.numUpdates = Paperpile.updateInfo.updates.length;
    Paperpile.updateInfo.latestVersion = Paperpile.updateInfo.updates[0].string;

    template.overwrite(this.body, Paperpile.updateInfo, true);

    var b = new Ext.Button({
      renderTo: 'download-button',
      text: buttonText,
    });

    b.on('click', action, this);

  },

  performUpgrade: function() {

    Ext.Msg.progress("Downloading updates");

    var platform = Paperpile.utils.get_platform();
    var path = Titanium.App.getHome() + '/catalyst';

    var args = [path + "/perl5/" + platform + "/bin/perl", path + '/script/updater.pl', '--update'];

    var upgrader = Titanium.Process.createProcess({
      args: args,
    });

    upgrader.setEnvironment("PERL5LIB", "");

    var downloadSize = Paperpile.updateInfo.download_size;
    var downloadSizeString = Ext.util.Format.fileSize(downloadSize);

    var error = false;

    upgrader.setOnReadLine(function(line) {

      log = Ext.util.JSON.decode(line);

      if (log.error) {

        error = true;

        Paperpile.status.updateMsg({
          type: 'error',
          msg: 'Automatic update failed',
          action1: 'Details',
          callback: function(action) {
            if (action === 'ACTION1') {
              Ext.MessageBox.buttonText.ok = "Send error report";
              Ext.Msg.show({
                title: 'Error',
                msg: log.error,
                animEl: 'elId',
                icon: Ext.MessageBox.ERROR,
                buttons: Ext.Msg.OKCANCEL,
                fn: function(btn) {
                  if (btn === 'ok') {
                    Paperpile.main.reportError('CRASH',log.error);
                  }
                  Ext.MessageBox.buttonText.ok = "Ok";
                },
              });
            }
          },
          hideOnClick: true,
        });
      }

      if (log.status === 'DOWNLOAD') {
        var p = Ext.util.Format.fileSize(log.downloaded) + " of " + downloadSizeString;
        Ext.Msg.updateProgress(log.downloaded / downloadSize, p);
      }

      if (log.status === 'EXTRACT') {
        Ext.Msg.wait("", "Extracting updates", {
          interval: 100
        });
      }

      if (log.status === 'PATCH') {
        Ext.Msg.wait("", "Applying changes", {
          interval: 100
        });
      }

    });

    upgrader.setOnExit(function() {

      if (error) {
        Ext.Msg.hide();
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
        return;
      }

      var msg = 'Paperpile is now up-to-date.';

      if (Paperpile.updateInfo.restart) {
        Ext.MessageBox.buttonText.ok = "Restart now";
        msg = 'The updates were successfully installed. Please restart Paperpile to finish the update process.';
      }

      Ext.Msg.show({
        title: 'Update successful',
        msg: msg,
        animEl: 'elId',
        icon: Ext.MessageBox.INFO,
        buttons: Ext.Msg.OK,
        minWidth: 200,
        maxWidth: 400,
        fn: function(btn) {
          if (btn === 'ok') {
            if (Paperpile.updateInfo.restart) {
              Titanium.App.restart();
            }
            Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
          }
          Ext.MessageBox.buttonText.ok = "Ok";
        },
      });
    });

    upgrader.launch();

  },

  redirect: function() {

    // Add code to redirect to latest version
  }
});