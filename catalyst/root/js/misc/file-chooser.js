Paperpile.FileChooser = Ext.extend(Ext.Window, {

    title: "Select file",
    selectionMode:'FILE',
    showHidden:false,

    callback: function(button,path){
        console.log(button, path);
    },

    initComponent: function() {

        var label='File';

        if (this.selectionMode == 'DIR'){
            label='Directory';
        }

		Ext.apply(this, {
            layout: 'border',
            width: 500,
            height: 300,
            closeAction:'hide',
            plain: true,
            modal:true,
            items: [
                { xtype: 'panel',
                  region: 'north',
                  itemId: 'northpanel',
                  height: 40,
                  layout:'form',
                  frame:true,
                  border:false,
                  labelAlign:'right',
                  labelWidth: 50,
                  items:[
                      {xtype: 'textfield',
                       itemId: 'textfield',
                       fieldLabel: label,
                       width: 400,
                      }
                  ],
                },
                { xtype: 'panel',
                  region: 'center',
                  itemId:'centerpanel',
                  layout: 'fit',
                  items:[{xtype:'panel', itemId:'filetree', id:'DUMMY'}],
                  //items:[]
                }
            ],
            bbar: [  {xtype:'tbfill'},
                     { text: 'Select',
                      itemId: 'select',
                      cls: 'x-btn-text-icon save',
                      //disabled: true,
                      listeners: {
                          click:  { 
                              fn: function(){
                                  var ft=this.items.get('filetree');
                                  var path=ft.getPath(ft.getSelectionModel().getSelectedNode());
                                  this.callback('OK',path);
                                  this.close();
                              },
                              scope: this
                          }
                      },
                    },
                    { text: 'Cancel',
                      itemId: 'cancel',
                      cls: 'x-btn-text-icon cancel',
                      listeners: {
                          click:  { 
                              fn: function(){
                                  this.callback('CANCEL',null);
                                  this.close();
                              },
                              scope: this
                          }
                      },
                    }
                  ]
	    });
	    Paperpile.FileChooser.superclass.initComponent.call(this);

        this.showDir("ROOT", "/");

        this.textfield=this.items.get('northpanel').items.get('textfield');


    },

    onSelect: function(node){
        this.textfield.setValue(node.text);

    },



    showDir: function(root, rootText){

        var cp=this.items.get('centerpanel');
        cp.remove(cp.items.get('filetree'));
        
       
        var treepanel = new Ext.ux.FileTreePanel({
		    height:400,
            border:0,
            itemId:'filetree',
		    autoWidth:true,
		    selectionMode: this.selectionMode,
            showHidden:this.showHidden,
		    rootPath:root,
            rootText: rootText,
		    topMenu:false,
		    autoScroll:true,
		    enableProgress:false,
            url:'/ajax/files/dialogue',
	    });

        cp.add(treepanel);

        cp.doLayout();

   
    }



});


