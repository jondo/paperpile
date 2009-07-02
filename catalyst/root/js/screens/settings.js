Paperpile.GeneralSettings = Ext.extend(Ext.Panel, {

    title: 'General settings',

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoLoad:{url:Paperpile.Url('/screens/settings'),
                      callback: this.setupFields,
                      scope:this
                     },
            bodyStyle:'pp-settings',
            autoScroll: true,
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

        this.isDirty=false;

    },

    //
    // Creates textfields, buttons and installs event handlers
    //

    setupFields: function(){

        Ext.form.VTypes["nonempty"] = /^.*$/;

        Ext.get('settings-cancel-button').on('click',
                                             function(){
                                                 Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
                                             });



        this.textfields={};

        Ext.each(['proxy','proxy_user','proxy_passwd'], 
                 function(item){
                     var field=new Ext.form.TextField({value:main.globalSettings[item], 
                                                       enableKeyEvents: true,
                                                       width: 300,
                                                      });

                     field.render(item+'_textfield',0);

                     this.textfields[item]=field;

                     field.on('keypress', 
                              function(){
                                  this.isDirty=true;
                                  this.setSaveDisabled(false);
                              }, this);
                     

                 }, this
                );

        this.proxyCheckbox=new Ext.form.Checkbox({renderTo:'proxy_checkbox'});

        
        this.proxyCheckbox.on('check', 
                              function(box,checked){
                                  this.onToggleProxy(box,checked);
                                  this.isDirty=true;
                                  this.setSaveDisabled(false);
                              }, this);

       
        if (main.globalSettings['use_proxy'] == "1"){
            this.proxyCheckbox.setValue(true);
            this.onToggleProxy(this.proxyCheckbox,true);
        } else {
            this.proxyCheckbox.setValue(false);
            this.onToggleProxy(this.proxyCheckbox,false);
        }
        
        this.proxyTestButton=new Ext.Button({text:"Test your network connection", 
                                             renderTo:'proxy_test_button'});
        

        this.proxyTestButton.on('click', 
                                function(){

                                    Ext.get('proxy_test_status').removeClass(['pp-icon-tick', 'pp-icon-cross']);

                                    Paperpile.status.showBusy('Testing network connection.');

                                    var params={use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
                                                proxy: this.textfields['proxy'].getValue(),
                                                proxy_user: this.textfields['proxy_user'].getValue(),
                                                proxy_passwd: this.textfields['proxy_passwd'].getValue(),
                                               };
                                    Ext.Ajax.request({
                                        url: Paperpile.Url('/ajax/misc/test_network'),
                                        params: params,
                                        success: function(response){

                                            var error;

                                            if (response.responseText){
                                                error= Ext.util.JSON.decode(response.responseText).error;
                                            }

                                            if (error){
                                                Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
                                                Paperpile.main.onError(response);
                                            } else {
                                                Ext.get('proxy_test_status').replaceClass('pp-icon-cross','pp-icon-tick');
                                                Paperpile.status.clearMsg();
                                            }
 
                                        },
                                        failure: function(response){
                                            Ext.get('proxy_test_status').replaceClass('pp-icon-tick', 'pp-icon-cross');
                                            Paperpile.main.onError(response);
                                        }
                                    });
                                }, this);


        this.setSaveDisabled(true);
        
    },

    onToggleProxy: function(box,checked){
        this.textfields['proxy'].setDisabled(!checked);
        this.textfields['proxy_user'].setDisabled(!checked);
        this.textfields['proxy_passwd'].setDisabled(!checked);
        
        if (checked){
            Ext.select('h2,h3',true,'proxy-container').removeClass('pp-label-inactive');
        } else {
            Ext.select('h2,h3',true,'proxy-container').addClass('pp-label-inactive');
        }
    },


    setSaveDisabled: function(disabled){

        var button=Ext.get('settings-save-button');

        button.un('click',this.submit,this);

        if (disabled){
            button.replaceClass('pp-save-button','pp-save-button-disabled');
        } else {
            button.replaceClass('pp-save-button-disabled','pp-save-button');
            button.on('click', this.submit, this);
        }
    },

    submit: function(){

        var params={use_proxy: this.proxyCheckbox.getValue() ? 1 : 0,
                    proxy: this.textfields['proxy'].getValue(),
                    proxy_user: this.textfields['proxy_user'].getValue(),
                    proxy_passwd: this.textfields['proxy_passwd'].getValue(),
                   };


        Paperpile.status.showBusy('Applying changes.');

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/settings/set_settings'),
            params: params,
            success: function(response){
                Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
                main.loadSettings(
                    function(){
                        Paperpile.status.clearMsg();
                    }, this
                );
            },
            
            failure: function(response){
                
            },
            scope:this
        });


    }

});

