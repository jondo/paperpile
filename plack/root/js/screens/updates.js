/* Copyright 2009-2011 Paperpile

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
  markupNoPatchLinux: [
    '<div class="pp-box pp-box-top pp-box-style1" style="width:600px;">',
    '<h2>Version <b>{latestVersion}</b> of Paperpile is available for download.</h2>',
    '<p>Updating is simple:</p>',
    '<ul>',
    '  <li class="pp-bullet"><b>Close</b> Paperpile</li>',
    '  <li class="pp-bullet"><b>Delete</b> your current Paperpile directory (<tt>{installationDir}</tt>)</li>',
    '  <li class="pp-bullet"><b>Download</b> the latest tbz (bzip2 compressed tar) package </li>',
    '  <li class="pp-bullet"><b>Extract</b> package to the old installation directory (or anywhere else)</li>',
    '  <li class="pp-bullet"><b>Start</b> Paperpile (your personal libary will be updated if necessary)</li>',
    '</ul>',
    '<p>&nbsp;</p>',
    '<center><div id="download-button"></div></center>',
    '<p>&nbsp;</p>',
    '<tpl for="updates">',
    '<h2>New in {name}</h2>',
    '<p>{msg}</p>',
    '<ul class="pp-update-log">',
    '<tpl for="log">',
    '<li>{.}</li>',
    '</tpl>',
    '</ul>',
    '</tpl>',
    '</div>', ],

  markupNoPatchOSX: [
    '<div class="pp-box pp-box-top pp-box-style1" style="width:600px;">',
    '<h2>Version <b>{latestVersion}</b> of Paperpile is available for download.</h2>',
    '<p>Updating is simple:</p>',
    '<ul>',
    '  <li class="pp-bullet"><b>Close</b> Paperpile</li>',
    '  <li class="pp-bullet"><b>Delete</b> the Paperpile application folder (<tt>{installationDir}</tt>)</li>',
    '  <li class="pp-bullet"><b>Download</b> the new version</li>',
    '  <li class="pp-bullet"><b>Extract</b> the package by double-clicking on it</li>',
    '  <li class="pp-bullet"><b>Move</b> Paperpile to your Application folder</li>',
    '  <li class="pp-bullet"><b>Start</b> Paperpile (your personal libary will be updated if necessary)</li>',
    '</ul>',
    '<p>&nbsp;</p>',
    '<center><div id="download-button"></div></center>',
    '<p>&nbsp;</p>',
    '<tpl for="updates">',
    '<h2>New in {name}</h2>',
    '<p>{msg}</p>',
    '<ul class="pp-update-log">',
    '<tpl for="log">',
    '<li>{.}</li>',
    '</tpl>',
    '</ul>',
    '</tpl>',
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

      if (Paperpile.utils.get_platform() === 'osx'){
        template = new Ext.XTemplate(this.markupNoPatchOSX).compile();
      } else {
        template = new Ext.XTemplate(this.markupNoPatchLinux).compile();
      }

      buttonText = 'Go to download page';
      action = function() {
        Paperpile.utils.openURL('http://paperpile.com/beta')
      };
    }

    Paperpile.updateInfo.numUpdates = Paperpile.updateInfo.updates.length;
    Paperpile.updateInfo.latestVersion = Paperpile.updateInfo.updates[0].name;

    Paperpile.updateInfo.installationDir = QRuntime.getInstallationDir();

    template.overwrite(this.body, Paperpile.updateInfo, true);

    var b = new Ext.Button({
      renderTo: 'download-button',
      text: buttonText,
    });

    b.on('click', action, this);

  },

  performUpgrade: function() {

    Ext.Msg.progress("Downloading updates");

    var downloadSize = Paperpile.updateInfo.download_size;
    var downloadSizeString = Ext.util.Format.fileSize(downloadSize);

    Paperpile.updateInfo.error = false;

    var readLineCallback = function(string) {

      log = Ext.util.JSON.decode(string);

      if (log.error) {

        Paperpile.updateInfo.error = true;

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
                    Paperpile.main.reportError('CRASH', log.error);
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
    }

    var exitCallback = function() {

      if (Paperpile.updateInfo.error) {
        Ext.Msg.hide();
        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
        return;
      }

      var msg = 'Paperpile is now up-to-date.';

      if (Paperpile.updateInfo.restart) {
        Ext.MessageBox.buttonText.ok = "Close Paperpile now";
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
              QRuntime.closeApp();
            }
            Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
          }
          Ext.MessageBox.buttonText.ok = "Ok";
        },
      });

      QRuntime.updaterReadLine.disconnect(readLineCallback);
      QRuntime.updaterExit.disconnect(exitCallback);
    }

    QRuntime.updaterReadLine.connect(readLineCallback);
    QRuntime.updaterExit.connect(exitCallback);

    QRuntime.updaterStart("update");

  }

});