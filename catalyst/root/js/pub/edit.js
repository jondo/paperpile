Paperpile.Forms.PubEdit = Ext.extend(Paperpile.Forms, {
	  
    initComponent: function() {

        this.pub_fields=Paperpile.main.globalSettings.pub_fields;
        this.pub_types=Paperpile.main.globalSettings.pub_types;

        var _type_store=[];
        for (var type in this.pub_types){
            _type_store.push([type,this.pub_types[type].name]);
        }

    	Ext.apply(this, {
            itemId:'pub_edit',
            defaultType:'textfield',
            labelAlign:'right',
            defaults:{
                width:320
            },
            frame:true,
            border:0,
            items:[
                {xtype:'combo',
                 itemId:'pubtype',
                 editable:false,
                 forceSelection:true,
                 triggerAction: 'all',
                 //name:'pubtype',
                 disableKeyFilter: true,
                 fieldLabel:'Type',
                 mode: 'local',
                 minListWidth:320,
                 store: _type_store,
                 hiddenName: 'pubtype',
                 listeners: {
                     select: {
                         fn: function(combo,record,indec){
                             this.setFields(record.data.value);
                         },
                         scope:this,
                     }
                 }
                },
                {name:'title',
                 xtype:'textarea',
                 height:'70',
                },
                {name:'authors',
                 xtype:'textarea',
                 height:'70',
                },
                {name:'booktitle'},
                {name:'series'},
                {name:'editors'},
                {name:'journal'},
                {name:'chapter'},
                {name:'edition'},
                {name:'volume',
                 width:100
                },

                {name:'issue',
                 width:100
                },
                {name:'pages',
                 width:100},
                {name:'publisher'},
                {name:'school'},
                {name:'city'},
                {name:'address'},
                {name:'year',
                 width:100
                },
                {name:'month',
                 width:100
                },
                {name:'day',
                 width:100
                },
                {name:'issn',
                 width:100
                },
                {name:'isbn',
                 width:100
                },
                {name:'pmid',
                 width:100
                },
                {name:'doi'},
                {name:'url'},
                {name:'abstract',
                 xtype:'textarea',
                 height:'100',
                },
            ],

            bbar:[{xtype:'tbfill'},
                  new Ext.Button({
                      id: 'edit_save_button',
                      text: 'Save',
                      cls: 'x-btn-text-icon save',
                      listeners: {
                          click:  {fn: this.save, scope: this}
                      },
                  }),
                  new Ext.Button({
                      id: 'edit_cancel_button',
                      text: 'Cancel',
                      cls: 'x-btn-text-icon cancel',
                      listeners: {
                          click:  {fn: this.cancel, scope: this}
                      },
                  }),
                 ],
		});

        for (var i=0; i<this.items.length; i++){
            var label=this.pub_fields[this.items[i].name];
            if (label){
                this.items[i].fieldLabel=label;
            }
        }

        Paperpile.Forms.PubEdit.superclass.initComponent.call(this);
        
        this.setValues(this.data);

        this.on('afterlayout',
                function(){
                    this.setFields('ARTICLE');
                });
              
	  },
    
    setValues : function(values){
        for (var i = 0, items = this.items.items, len = items.length; i < len; i++) {
            var field = items[i];
            var v = values[field.id] || values[field.hiddenName || field.name];
            if (typeof v !== 'undefined') {
                field.setValue(v)
                if(this.trackResetOnLoad){
                    field.originalValue = field.getValue();
                }
            }
        }
    },

    setFields : function(pubtype){

        /* first hide everything */
        for (var i=0; i<this.items.items.length; i++){
            var el=this.items.items[i].getEl();

            if (this.items.items[i].itemId == 'pubtype'){
                continue;
            }
            el.up('div.x-form-item').setDisplayed(false);
        }

        /* then selectively show fields for current publication type */
        for (var i=0; i< this.pub_types[pubtype].fields.length;i++){
            var field=this.getForm().findField(this.pub_types[pubtype].fields[i]);
            if (field){
                el=field.getEl();
                el.up('div.x-form-item').setDisplayed(true);
            }
        }
    },
    
    save: function(){
        // Masks form instead of whole window, should set to dedicated
        // notification area later
        
        this.getForm().waitMsgTarget=true;
        
        var url;
        var params;

        // If we are given a grid_id we are updating an entry
        if (this.grid_id){
            url='/ajax/crud/update_entry';
            params={rowid:this.data._rowid,
                    sha1:this.data.sha1,
                    grid_id: this.grid_id,
                   };
        } 
        // Else we are creating a new one
        else {
            url='/ajax/crud/new_entry';
            params:{};
        }

        this.getForm().submit(
            {   url:url,
                scope:this,
                success:this.onSuccess,
                params: params,
                waitMsg:'Saving...',
            }
        );
    },

    cancel: function(){
        this.close();
    },

    onSuccess: function(form,action){
        this.close();
    },

    close: function(){
        
        var east_panel=this.findParentByType(Ext.PubView).items.get('east_panel');

        east_panel.remove('pub_edit');
        east_panel.doLayout();
        east_panel.getLayout().setActiveItem('pdf_manager');
        east_panel.showBbar();
        

    }
    

});

