Paperpile.ExportWindow = Ext.extend(Ext.Window, {

    grid_id: null,
    source_node: null,
    selection:[],
    
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
            bbar: [ { text: 'Back',
                      itemId: 'prev_button',
                      cls: 'x-btn-text-icon prev',
                      listeners: {
                          click:  { 
                              fn: function(){
                                  this.getLayout().setActiveItem(0);
                                  this.getBottomToolbar().items.get('prev_button').hide();
                                  this.getBottomToolbar().items.get('next_button').show();
                                  this.getBottomToolbar().items.get('ok_button').hide();
                              },
                              scope:this
                          }
                      },
                      hidden: true,
                    },
                    { xtype:'tbfill'},
                    { text: 'Next',
                      itemId: 'next_button',
                      cls: 'x-btn-text-icon next',
                      listeners: {
                          click:  { 
                              fn: function(){
                                  var plugin=this.items.get('form').getForm().getValues().plugin;

                                  // Create or update plugin form for second tab depending on selection
                                  if ((!this.pluginForm) || (this.pluginForm.export_name != plugin)){
                                      this.items.remove(this.pluginForm);
                                      this.pluginForm=new Paperpile['Export'+plugin]({bodyStyle:'padding: 10px 10px 0 10px'});
                                      this.items.add(this.pluginForm);
                                  }

                                  this.getLayout().setActiveItem(1);
                                  this.getBottomToolbar().items.get('ok_button').show();
                                  this.getBottomToolbar().items.get('next_button').hide();
                                  this.getBottomToolbar().items.get('prev_button').show();
                              },
                              scope:this
                          }
                      }
                    },
                    { text: 'Export',
                      itemId: 'ok_button',
                      cls: 'x-btn-text-icon ok',
                      listeners: {
                          click:  { 
                              fn: function(){
                                  var form=this.items.get(1).getForm();
                                  form.submit({
                                      url:Paperpile.Url('/ajax/plugins/export'),
                                      params: {grid_id: this.grid_id,
                                               source_node: this.source_node,
                                               export_name: this.pluginForm.export_name,
                                               selection: this.selection
                                              },
                                      success: function(){
                                          this.close();
                                          Ext.getCmp('statusbar').clearStatus();
                                          Ext.getCmp('statusbar').setText('Exported data.');
                                      },
                                      scope:this,
                                      failure: function(){
                                          alert('nope')
                                      },
                                  })
                              },
                              scope:this
                          }
                      },
                      hidden:true
                    },
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
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'Website',
                       inputValue: 'HTML',
                       hideLabel: true,
                       disabled: true,
                      },
                      {xtype: 'radio',
                       name: 'plugin',
                       boxLabel: 'PDF',
                       inputValue: 'PDF',
                       hideLabel: true,
                       disabled: true,
                      },
                  ],
                },
            ],
        });

        
        Paperpile.ExportWindow.superclass.initComponent.call(this);

    },
        



});

