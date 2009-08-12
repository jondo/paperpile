
// Stage 0 
//
// Ping the server. If we get a response, we directly go on to stage 1
// If not, we start the server and recursively call this function
// again until we get a response or give up after some time.

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

            console.log('Ping attempt '+ Paperpile.pingAttempts);

            if (IS_TITANIUM && Paperpile.pingAttempts == 0){
                var path = Titanium.App.path;
                path=path.replace(/_paperpile\.bin$/,'');
                var process = Titanium.Process.launch('bash', [path+'start_server.sh',path]);
            }

            if (Paperpile.pingAttempts < 50 ){
                Paperpile.pingAttempts++;
                (function(){Paperpile.stage0()}).defer(200);
            } else {
                Ext.Msg.show({
                    title:'Error',
                    msg: 'Could not start Paperpile server.',
                    buttons: Ext.Msg.OK,
                    icon: Ext.MessageBox.ERROR,
                });
            }
        },
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

    Paperpile.pingAttempts=0;
    Paperpile.stage0();
       
});



