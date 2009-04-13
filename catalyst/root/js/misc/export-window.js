Paperpile.ExportWindow = Ext.extend(Ext.Window, {

    initComponent: function() {
        

        Ext.apply(this, {
            layout: 'card',
            activeItem:0,
            width: 500,
            height: 300,
            closeAction:'hide',
            plain: true,
            modal:true,
            items: [
                { xtype: 'panel',
                  itemId: 'export-window-start',
                  height: 40,
                  width: 300,
                  layout:'form',
                  frame:true,
                  border:false,
                  labelAlign:'right',
                  labelWidth: 50,
                  items:[
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'Paperpile library',
                       inputValue: 'db',
                       hideLabel: true,
                      },
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'Bibliography file (BibTeX, EndNote...)',
                       inputValue: 'bibfile',
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
                       inputValue: 'db',
                       hideLabel: true,
                      },
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'PDF',
                       inputValue: 'db',
                       hideLabel: true,
                      },
                  ],
                },
            ]});

        
        Paperpile.ExportWindow.superclass.initComponent.call(this);

    },
        



});

