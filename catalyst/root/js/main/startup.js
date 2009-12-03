// Stage 0 
//
// Check if server is already running, if not start the catalyst
// server. Once we have verified that the server is running we
// continue with stage1.

Paperpile.serverLog='';

Paperpile.stage0 = function(){
    Ext.Ajax.request({
        url: Paperpile.Url('/ajax/app/heartbeat'),

        success: function(response){
            var json = Ext.util.JSON.decode(response.responseText);
            if (json.status == 'RUNNING'){
                Paperpile.stage1();
            }
        },
                
        failure: function(response){

            if (IS_TITANIUM){

                // Determine platform we are running on
                var osname = Titanium.Platform.name;
                var ostype = Titanium.Platform.ostype;
                var platform = '';
                
                if (osname === 'Linux'){
                    if (ostype === '64bit'){
                        platform = 'linux64';
                    } else {
                        platform = 'linux32';
                    }
                }

                // Get absolute path to working directory
                var path = Titanium.App.appURLToPath('/');
                path=path.replace(/Resources$/,'');

                // Set up process
                Paperpile.server = Titanium.Process.createProcess({
                    args:[path+"catalyst/perl5/"+platform+"/bin/perl", path+'catalyst/script/paperpile_server.pl', '-fork'],
                });

                // Make sure there is no PERL5LIB variable set in the environment
                Paperpile.server.setEnvironment("PERL5LIB","");

                // Handler for failing start of the server
                Paperpile.server.setOnExit(function(line){
                    Ext.Msg.show({
                        title:'Error',
                        msg: 'Could not start Paperpile server.',
                        buttons: Ext.Msg.OK,
                        icon: Ext.MessageBox.ERROR,
                    });
                });

                // Handler to process the STDERR output of the server
                Paperpile.server.setOnReadLine(function(line){
                    Paperpile.serverLog=Paperpile.serverLog+line+"\n";

                    var panel = Ext.getCmp('log-panel');

                    if (panel){
                        panel.addLine(line+"\n");
                    }

                    if (line.match(/Paperpile powered by Catalyst/)){
                        Titanium.API.notice("Catalyst successfully started");
                        // We are successfull so we remove the failure
                        // handler to avoid to call it on exit of the
                        // application (although it does not seem to
                        // be called anyway)
                        Paperpile.server.setOnExit(function(){});
                        Paperpile.stage1();
                    }
                });

                // Kill the server when the application exits
                Titanium.API.addEventListener(
                    Titanium.APP_EXIT, 
                    function(){
                        Titanium.API.notice("Killing Catalyst");
                        Paperpile.server.kill();
                    });

                // Finally start the actual process
                Titanium.API.notice("Starting Catalyst");
                Paperpile.server.launch();
              
            }
        }
    });
}


// Stage 1 
//
// Before we load the GUI elements we need basic setup tasks at the
// backend side. Once this is successfully done we move on to stage 2. 

Paperpile.stage1 = function() {

    Ext.Ajax.request({
        url: Paperpile.Url('/ajax/app/init_session'),
        success: function(response){

            var json = Ext.util.JSON.decode(response.responseText);
            
            if (json.error){
                
                Ext.Msg.show({
                    title:'Error',
                    msg: json.error.msg,
                    buttons: Ext.Msg.OK,
                    animEl: 'elId',
                    icon: Ext.MessageBox.ERROR,
                    fn: function(action){
                        if (IS_TITANIUM){
                            Titanium.UI.mainWindow.close();
                        }
                    }
                });

                if (json.error.type == 'LibraryMissingError'){
                    Paperpile.stage2();
                }
                
            } else {
                Paperpile.stage2();
            }
        }, 

        failure: function(response){
            var error;            

            if (response.responseText){
                error= Ext.util.JSON.decode(response.responseText).error;
                if (error){
                    error=error.msg;
                }
            }
            
            Ext.Msg.show({
                title:'Error',
                msg: 'Could not start application.<br>'+error,
                buttons: Ext.Msg.OK,
                animEl: 'elId',
                icon: Ext.MessageBox.ERROR,
                fn: function(action){
                    if (IS_TITANIUM){
                        Titanium.UI.mainWindow.close();
                    }
                }
            });
        }
    });
};

// Stage 2 
//
// Load the rest of the GUI

Paperpile.stage2=function(){

    Ext.QuickTips.init();
    Paperpile.main=new Paperpile.Viewport;

    Paperpile.main.on('afterrender',
                      function(){
                          alert("layout finished");
                      },this, {single:true});

    Paperpile.main.loadSettings(
        function(){
            Paperpile.main.show();
            var tree=Ext.getCmp('treepanel');
            Paperpile.main.tree=tree;
            Paperpile.status=new Paperpile.Status();
            Paperpile.main.tabs.newDBtab('','MAIN');
            tree.expandAll();
            Paperpile.main.tabs.remove('welcome');
            Ext.get('splash').remove();
        }, this);
    
    Ext.get('dashboard-button').on('click', function(){ 
        Paperpile.main.tabs.newScreenTab('Dashboard','dashboard');
    });

    // If offline the uservoice JS has not been loaded, so test for it
    if (window.UserVoice){
        UserVoice.Popin.setup({ 
            key: 'paperpile',
            host: 'paperpile.uservoice.com', 
            forum: 'general', 
            lang: 'en'
        });
    }
    
}


Ext.onReady(function() {

    Paperpile.stage0();
       
});

