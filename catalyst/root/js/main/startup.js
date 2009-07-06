
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

                //var path = Titanium.App.path;
                //path=path.replace(/kboot$/,'');
                //console.log(path);

                var process = Titanium.Process.launch('bash', 'start_server.sh');
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
                    icon: Ext.MessageBox.ERROR
                });

                if (json.error.type == 'LibraryMissingError'){
                    Paperpile.stage2();
                }
                
            } else {
                Paperpile.stage2();
            }
        }, 

        failure: function(response){
            Ext.Msg.show({
                title:'Error contacting Paperpile server.',
                msg: json.error.msg,
                buttons: Ext.Msg.OK,
                animEl: 'elId',
                icon: Ext.MessageBox.ERROR
            });
        }
        
    });
};

// Stage 2 
//
// Load the rest of the GUI

Paperpile.stage2=function(){

    Ext.QuickTips.init();
    main=new Paperpile.Viewport;
    main.show();

    Paperpile.main=main; 

    var tree=Ext.getCmp('treepanel');
    Paperpile.main.tree=tree;

    Paperpile.status=new Paperpile.Status();

    main.loadSettings();

    main.tabs.newDBtab('','MAIN');

    // Note: this is asynchronous, so might not be available
    // immediately (integrate this better in startup to make sure it
    // is loaded when needed)

    tree.expandAll();
    main.tabs.remove('welcome');

    Ext.get('splash').remove();

    Ext.get('dashboard-button').on('click', function(){ 
        Paperpile.main.tabs.newScreenTab('Dashboard','dashboard');
    });
}


Ext.onReady(function() {

    //Titanium.UI.mainWindow.addEventListener('close', function(){console.log("exit---------------")},false);

    if (IS_TITANIUM){
        Titanium.UI.mainWindow.addEventListener(
            function(event){
                console.log("-------------> "+event);
            }
        );
    }

    Paperpile.pingAttempts=0;
    Paperpile.stage0();
       
});



