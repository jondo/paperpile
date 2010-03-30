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




// Stage 0 
//
// Check if server is already running, if not start the catalyst
// server. Once we have verified that the server is running we
// continue with stage1.
Paperpile.serverLog = '';
Paperpile.isLogging = 1;

Paperpile.startupFailure = function(response) {
  var error;

  if (response.responseText) {
    error = Ext.util.JSON.decode(response.responseText).error;
    if (error) {
      error = error.msg;
    }
  }

  Ext.Msg.show({
    title: 'Error',
    msg: 'Could not start application.<br>' + error,
    buttons: Ext.Msg.OK,
    animEl: 'elId',
    icon: Ext.MessageBox.ERROR,
    fn: function(action) {
      if (IS_TITANIUM) {
        Titanium.UI.mainWindow.close();
      }
    }
  });
};

Paperpile.stage0 = function() {
  Ext.Ajax.request({
    url: Paperpile.Url('/ajax/app/heartbeat'),

    success: function(response) {
      var json = Ext.util.JSON.decode(response.responseText);
      if (json.status == 'RUNNING') {
        Paperpile.stage1();
      }
    },

    failure: function(response) {

      if (IS_TITANIUM) {

        // Determine platform we are running on
        var platform = Paperpile.utils.get_platform();

        var path = Titanium.App.getHome() + '/catalyst';

        // Set up process
        Paperpile.server = Titanium.Process.createProcess({
          args: [path + "/perl5/" + platform + "/bin/perl", path + '/script/paperpile_server.pl', '-fork']
        });

        // Make sure there is no PERL5LIB variable set in the environment
        Paperpile.server.setEnvironment("PERL5LIB", "");

        // Handler for failing start of the server
        Paperpile.server.setOnExit(function(line) {
          Ext.Msg.show({
            title: 'Error',
            msg: 'Could not start Paperpile server.',
            buttons: Ext.Msg.OK,
            icon: Ext.MessageBox.ERROR
          });
        });

        // Handler to process the STDERR output of the server
        Paperpile.server.setOnReadLine(function(line) {
          
          if (Paperpile.isLogging) {
            Paperpile.serverLog = Paperpile.serverLog + line + "\n";

            // Limit length to 100,000 characters to avoid sending
            // around huge files in error reports
            var L = Paperpile.serverLog.length;
            if (L>100000){
              Paperpile.serverLog = Paperpile.serverLog.substr(L-100000);
            }

            var panel = Ext.getCmp('log-panel');

            if (panel) {
              panel.addLine(line + "\n");
            }

            if (line.match(/powered by Catalyst 5.8/)) {
              Titanium.API.notice("Catalyst successfully started");
              // We are successful so we remove the failure
              // handler to avoid to call it on exit of the
              // application (although it does not seem to
              // be called anyway)
              Paperpile.server.setOnExit(function() {});
              Paperpile.stage1();
            }
          }
        });

        // Kill the server when the application exits
        Titanium.API.addEventListener(
          Titanium.APP_EXIT,
          function() {
            Titanium.API.notice("Killing Catalyst");
            Paperpile.server.kill();
          });

        // Finally start the actual process
        Titanium.API.notice("Starting Catalyst");
        Paperpile.server.launch();

      }
    }
  });
};

// Stage 1 
//
// Before we load the GUI elements we need basic setup tasks at the
// backend side. Once this is successfully done we move on to stage 2. 
Paperpile.stage1 = function() {

  Paperpile.status = new Paperpile.Status();

  Ext.Ajax.request({
    url: Paperpile.Url('/ajax/app/init_session'),
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

          Ext.Ajax.request({
            url: Paperpile.Url('/ajax/app/migrate_db'),
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
              if (IS_TITANIUM) {
                Titanium.UI.mainWindow.close();
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
      Paperpile.main.show();
      var tree = Ext.getCmp('treepanel');
      Paperpile.main.tree = tree;
      Paperpile.main.tabs.newDBtab('', 'MAIN');
      tree.expandAll();
      Paperpile.main.tabs.remove('welcome');
      
      var version = 'Paperpile '+Paperpile.main.globalSettings.version_name + ' <i style="color:#87AFC7;">Beta</i>';

      Ext.DomHelper.overwrite('version-tag', version );
    
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

};

Ext.onReady(function() {

  Paperpile.stage0();

});