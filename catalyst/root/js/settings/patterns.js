Paperpile.PatternSettings = Ext.extend(Ext.Panel, {

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoLoad:{url:'/screens/patterns',
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
                         new Ext.Button({text: item=='user_db'?'Choose file':'Choose folder',
                                         renderTo:item+'_button'});
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

        Ext.each(['key_pattern','pdf_pattern','attachment_pattern'],
                 function(f){
                     Ext.Ajax.request({
                         url: '/ajax/settings/pattern_example',
                         params: {pattern: Ext.get(f+'_textfield').first().getValue(),
                                  key: Ext.get('key_pattern_textfield').first().getValue()},
                         success: function(response){
                             var data = Ext.util.JSON.decode(response.responseText).data;
                             if (data.error){
                                 this.textfields[f].markInvalid(data.error);
                                 Ext.get(f+'_example').update('');
                             } else {
                                 Ext.get(f+'_example').update(data.string);
                             }
                         },
                         scope:this
                     });
                 }, this);
    },

    submit: function(){

        var params={};

        Ext.each(['user_db','paper_root','key_pattern','pdf_pattern','attachment_pattern'], 
                 function(item){
                     params[item]=this.textfields[item].getValue();
                 }, this);

        Ext.Ajax.request({
            url: '/ajax/settings/update_patterns',
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
                                this.wait.hide();
                            }
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

