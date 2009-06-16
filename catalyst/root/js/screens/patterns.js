Paperpile.PatternSettings = Ext.extend(Ext.Panel, {

    title: 'Location and patterns settings',

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoLoad:{url:Paperpile.Url('/screens/patterns'),
                      callback: this.setupFields,
                      scope:this
                     },
            bodyStyle:'pp-settings',
            
            bbar: [{xtype:'tbfill'},
                   { text:'Save',
                     cls: 'x-btn-text-icon save',
                     handler: this.submit,
                     scope: this
                   },
                   {text:'Cancel',
                    cls: 'x-btn-text-icon cancel',
                    handler: function(){
                        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
                    },
                    scope:this
                   },
                  ]
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

    },

    //
    // Creates textfields, buttons and installs event handlers
    //

    setupFields: function(){
        
        this.textfields={};

        Ext.each(['user_db','paper_root','key_pattern','pdf_pattern','attachment_pattern'], 
                 function(item){
                     var field=new Ext.form.TextField({value:main.globalSettings[item], 
                                                       enableKeyEvents: true,
                                                       width: 300,
                                                      });

                     field.render(item+'_textfield',0);

                     this.textfields[item]=field;

                     if (item == 'user_db' || item == 'paper_root'){
                         field.addClass('pp-textfield-with-button');
                         var b=new Ext.Button({text: item=='user_db'?'Choose file':'Choose folder',
                                               renderTo:item+'_button'});

                         b.on('click', function(){
                             var parts=Paperpile.utils.splitPath(this.textfields[item].getValue());
                             new Paperpile.FileChooser({
                                 saveMode: item == 'user_db' ? true : false,
                                 selectionMode: item == 'user_db' ? 'FILE' : 'DIR',
                                 saveDefault: item == 'user_db' ? parts.file : '',
                                 currentRoot: parts.dir,
                                 warnOnExisting:false,
                                 callback:function(button,path){
                                     if (button == 'OK'){
                                         this.textfields[item].setValue(path);
                                     }
                                 },
                                 scope:this
                             }).show();
                         },this);
                     }
                     
                     if (item == 'key_pattern' || item == 'pdf_pattern' || item == 'attachment_pattern'){

                         var task = new Ext.util.DelayedTask(this.updateFields, this);

                         field.on('keypress', function(){
                             task.delay(500); 
                         });
                     }
                     
                 }, this);
        
        this.updateFields();
        
    },

    //
    // Validates inputs and updates example fields
    //

    updateFields: function(){

        var params={};

        Ext.each(['user_db','paper_root','key_pattern','pdf_pattern','attachment_pattern'],
                 function(key){
                     params[key]=Ext.get(key+'_textfield').first().getValue();
                 }, this
                );

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/settings/pattern_example'),
            params: params,
            success: function(response){
                var data = Ext.util.JSON.decode(response.responseText).data;

                for (var f in data){                
                    if (data[f].error){
                        this.textfields[f].markInvalid(data.error);
                        Ext.get(f+'_example').update('');
                    } else {
                        Ext.get(f+'_example').update(data[f].string);
                    }
                }
            },
            scope:this
        });


    },

    submit: function(){

        var params={};

        Ext.each(['user_db','paper_root','key_pattern','pdf_pattern','attachment_pattern'], 
                 function(item){
                     params[item]=this.textfields[item].getValue();
                 }, this);

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/settings/update_patterns'),
            params: params,
            success: function(response){
                var data = Ext.util.JSON.decode(response.responseText).data;
                // Wait a second for doing this that the user has time
                // to see the progress bar instead of a unclean
                // flicker if the job is done quickly. If the job
                // takes longer this second does not do any harm
                // either.
                (function(){
                    // Close the settings dialogue
                    Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab(), true);
                    var old_user_db=main.globalSettings.user_db;
                    main.loadSettings(
                        function(){
                            // Complete reload only if database has
                            // changed. This is not necessary if the
                            // database has only be renamed but we
                            // update also in this case.
                            if (old_user_db != main.globalSettings.user_db){
                                Paperpile.main.tree.getRootNode().reload();
                                Paperpile.main.tree.expandAll();
                                
                                // Note that this as async. Tags
                                // should be loaded before results for
                                // grid appear but it is not
                                // guaranteed.
                                Ext.StoreMgr.lookup('tag_store').reload();
                                
                                Ext.each(Paperpile.main.tabs.items.items,
                                         function(item, index, length){
                                             Paperpile.main.tabs.remove(item,true);
                                         }
                                        );
                                
                                Paperpile.main.tabs.newDBtab('');
                                Paperpile.main.tabs.setActiveTab(0);
                                Paperpile.main.tabs.doLayout();
                            }
                            this.wait.hide();
                        }, this
                    );
                }).defer(1000, this);
            },
            
            failure: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                Ext.Msg.show({
                    title:'Error',
                    msg: "<p>Your settings could not be applied </p>"+json.errors[0],
                    buttons: Ext.Msg.OK,
                    animEl: 'elId',
                    icon: Ext.MessageBox.ERROR,
                    fn: function(){
                        Paperpile.main.tabs.remove(Paperpile.main.tabs.getActiveTab());
                    },
                    scope:this
                });
                main.loadSettings();
            },
            scope:this
        });

        this.wait=Ext.Msg.wait( "Applying changes","", {interval:50});

    }

});

