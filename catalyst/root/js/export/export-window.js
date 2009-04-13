Paperpile.ExportWindow = Ext.extend(Ext.Window, {
    
    initComponent: function() {
        Ext.apply(this, {
            layout: 'card',
            title: 'Export',
            activeItem:0,
            width: 500,
            height: 300,
            closeAction:'hide',
            plain: true,
            modal:true,
            bbar: [  {xtype:'tbfill'},
                     { text: 'Next',
                       itemId: 'ok_button',
                       cls: 'x-btn-text-icon next',
                       listeners: {
                           click:  { 
                               fn: function(){
                                   var plugin=this.items.get('form').getForm().getValues().plugin;
                                   var pluginForm=new Paperpile['Export'+plugin]({bodyStyle:'padding: 10px 10px 0 10px'});
                                   //bodyStyle: 'padding: 10px 10px 0 10px';
                                   this.items.add(pluginForm);
                                   this.getLayout().setActiveItem(1);
                               },
                               scope:this
                           }
                       }
                     }
                  ],
            items: [
                { xtype: 'form',
                  itemId: 'form',
                  layout:'form',
                  border:false,
                  labelAlign:'right',
                  labelWidth: 50,
                  bodyStyle:'padding: 50px 10px 0 50px',
                  items:[
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'Bibliography file (BibTeX, EndNote...)',
                       inputValue: 'Bibfile',
                       hideLabel: true,
                       checked: true,
                      },
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'Paperpile library',
                       inputValue: 'DB',
                       hideLabel: true,
                      },


                      /*
                      {xtype:'combo',
                       itemId:'file_format',
                       editable:false,
                       forceSelection:true,
                       triggerAction: 'all',
                       disableKeyFilter: true,
                       hideLabel:true,
                       mode: 'local',
                       store: [['BIBTEX','BibTeX'], 
                               ['RIS','RIS'],
                               ['ENDNOTE','EndNote'],
                               ['ENDNOTEXML', 'EndNote XML'],
                               ['MODS', 'MODS'],
                              ],
                       hiddenName: 'pubtype',
                       listeners: {
                           select: {
                               fn: function(combo,record,indec){
                                   //this.setFields(record.data.value);
                               },
                               scope:this,
                           }
                       }
                      },
                      */
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'Website',
                       inputValue: 'HTML',
                       hideLabel: true,
                      },
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'PDF',
                       inputValue: 'PDF',
                       hideLabel: true,
                      },
                  ],
                },
            ],
        });

        
        Paperpile.ExportWindow.superclass.initComponent.call(this);

    },
        



});

