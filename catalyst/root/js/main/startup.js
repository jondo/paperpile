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


Paperpile.serverLog = '';
Paperpile.isLogging = 1;
Paperpile.pingAttempts = 0;

Paperpile.startupFailure = function(response) {
  var error;

  if (response.responseText) {
    error = Ext.util.JSON.decode(response.responseText).error;
    if (error) {
      error = error.msg;
    }
  }

  var msg  = Paperpile.serverLog;
  if (msg.length > 800) {
    msg = msg.substr(msg.length - 800);
  }

  if (msg){
    msg.replace('\n','<br>');
    msg='<code>'+msg+'</code>';
  }

  Ext.Msg.show({
    title: 'Error',
    msg: 'Could not start application. Please try again and contact support@paperpile.com if the error persists.<br>' + error + '<br><br>'+msg,
    buttons: Ext.Msg.OK,
    animEl: 'elId',
    icon: Ext.MessageBox.ERROR,
    fn: function(action) {
      if (IS_QT) {
        QRuntime.closeApp();
      }
    }
  });
};

// Stage 0 
//
// Check if server is already running, if not start the catalyst
// server. Once we have verified that the server is running we
// continue with stage1.


Paperpile.stage0 = function() {

  Paperpile.pingAttempts++;

  if (IS_QT) QRuntime.log("Pinging the server (attempt #"+Paperpile.pingAttempts+')');

  Paperpile.Ajax({
    url: '/ajax/app/heartbeat',

    // Server responds
    success: function(response) {

      var json = Ext.util.JSON.decode(response.responseText);

      if (json.status == 'RUNNING') {
        
        // Server was already running before we have started it
        if (IS_QT && Paperpile.pingAttempts == 1){

          Ext.Msg.show({
            title: 'Error',
            msg: 'There is already another Paperpile instance running. Close the other instance first. If the error persists, please restart your computer and try again.',
            buttons: Ext.Msg.OK,
            animEl: 'elId',
            icon: Ext.MessageBox.ERROR,
            fn: function(action) {
              QRuntime.closeApp();
            }
          });
        } else {
          if (IS_QT) QRuntime.log("Loading frontend.");
          Paperpile.stage1();
        }
      }
    },

    failure: function(response) {

      if (IS_QT) {
    
        // Start catalyst server after the first failed ping attempt
        if (Paperpile.pingAttempts == 1){

          //Set up signals/slot connection for catalyst process

          QRuntime.catalystReady.connect(function(){
            QRuntime.log("Catalyst succesfully started.");
            Paperpile.stage0();
          });

          QRuntime.catalystExit.connect(
            function(error){

              var msg  = Paperpile.serverLog;

              if (msg.length > 800) {
                msg = msg.substr(msg.length - 800);
              }

              if (msg){
                msg.replace('\n','<br>');
                msg='<code>'+msg+'</code>';
              }

              Ext.Msg.show({
                title: 'Error',
                msg: 'Could not start Paperpile server or lost connection. Please restart Paperpile and contact support@paperpile.com if the problem persits.<br><br>'+msg,
                buttons: Ext.Msg.OK,
                icon: Ext.MessageBox.ERROR,
                fn: function(action) {
                  if (IS_QT) {
                    QRuntime.closeApp();
                  }
                }
              });
            }
          );

          QRuntime.catalystRead.connect(function(string) {
            if (Paperpile.isLogging) {
              Paperpile.serverLog = Paperpile.serverLog + string;
              var L = Paperpile.serverLog.length;
              if (L > 100000) {
                Paperpile.serverLog = Paperpile.serverLog.substr(L - 1000);
              }
              var panel = Ext.getCmp('log-panel');
              if (panel) {
                panel.addLine(string);
              }
            }
          });

          QRuntime.log("Starting Catalyst");

          QRuntime.catalystStart();
        }

        // Try pinging the server until we get a response
        if ((Paperpile.pingAttempts) > 1 && (Paperpile.pingAttempts<10)){
          Paperpile.stage0.defer(200);
        }

        // Giving up
        if (Paperpile.pingAttempts >= 10){
          if (IS_QT) QRuntime.log("Giving up.");
          Paperpile.startupFailure(response);
        }
      }
    }
  });
};

// Stage 1 
//
// Before we load the GUI elements we need basic setup tasks at the
// backend side. Once this is successfully done we move on to stage 2. 
Paperpile.stage1 = function() {

  if (!Paperpile.status) {
    Paperpile.status = new Paperpile.Status();
  }

  Paperpile.Ajax({
    url: '/ajax/app/init_session',
    success: function(response) {
      var json = Ext.util.JSON.decode(response.responseText);

      if (json.error) {
        if (json.error.type == 'DatabaseVersionError') {
          Ext.MessageBox.show({
            msg: 'Updating your library, please wait...',
            progressText: '',
            width: 300,
            wait: true,
            waitConfig: {
              interval: 200
            }
          });

          Paperpile.Ajax({
            url: '/ajax/app/migrate_db',
            success: function(response) {
              Ext.MessageBox.hide();
              Paperpile.stage1();
            },
            failure: function(response) {
              Paperpile.startupFailure(response);
            }
          });
        } else if (json.error.type == 'LibraryMissingError') {
          Paperpile.stage2();
        } else {
          Ext.Msg.show({
            title: 'Error',
            msg: json.error.msg,
            buttons: Ext.Msg.OK,
            animEl: 'elId',
            icon: Ext.MessageBox.ERROR,
            fn: function(action) {
              if (IS_QT) {
                QRuntime.closeApp();
              }
            }
          });
        }
      } else {
        Paperpile.stage2();
      }
    },
    failure: Paperpile.startupFailure
  });
};

// Stage 2 
//
// Load the rest of the GUI
Paperpile.stage2 = function() {

  Ext.QuickTips.init();

  Paperpile.main = new Paperpile.Viewport;

  Paperpile.main.loadSettings(
    function() {
      Paperpile.main.afterLoadSettings();
      //Paperpile.main.show();
      var tree = Ext.getCmp('treepanel');
      Paperpile.main.tree = tree;
      Paperpile.main.tabs.newDBtab('', 'MAIN');
      tree.expandAll();
      Paperpile.main.tabs.remove('welcome');

      var version = 'Paperpile ' + Paperpile.main.globalSettings.version_name + ' <i style="color:#87AFC7;">Beta</i>';

      Ext.DomHelper.overwrite('version-tag', version);

      Ext.get('splash').remove();
    },
    this);

  Ext.get('dashboard-button').on('click', function() {
    Paperpile.main.tabs.newScreenTab('Dashboard', 'dashboard');
  });

  // If offline the uservoice JS has not been loaded, so test for it
  if (window.UserVoice) {
    UserVoice.Popin.setup({
      key: 'paperpile',
      host: 'paperpile.uservoice.com',
      forum: 'general',
      lang: 'en'
    });
  }

  // Check in regular intervals of 10 minutes for updates.
  Paperpile.updateCheckTask = {
    run: function() {
      if (!Paperpile.status.el.isVisible()) {
        Paperpile.main.checkForUpdates(true);
      }
    },
    interval: 600000 //every 10 minutes
  };

  // Don't check immediately after start
  (function() {
    Ext.TaskMgr.start(Paperpile.updateCheckTask);
  }).defer(600000);

};

Ext.onReady(function() {

  Paperpile.stage0();

});