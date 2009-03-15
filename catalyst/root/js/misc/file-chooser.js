PaperPile.FileChooser = Ext.extend(Ext.Window, {

    title: "Select file",
    selectionMode:'BOTH',
    showHidden:false,

    callback: function(button,path){
        console.log(button, path);
    },

    initComponent: function() {

        var treepanel = new Ext.ux.FileTreePanel({
		    height:400,
            itemId:'filetree',
		    autoWidth:true,
		    selectionMode: this.selectionMode,
            showHidden:this.showHidden,
		    rootPath:'ROOT',
            rootText: '/',
		    topMenu:false,
		    autoScroll:true,
		    enableProgress:false,
            url:'/ajax/files/dialogue',
	    });

		Ext.apply(this, {
            layout: 'fit',
            width: 500,
            height: 300,
            closeAction:'hide',
            plain: true,
            modal:true,
            items: [treepanel],
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
	    PaperPile.FileChooser.superclass.initComponent.call(this);
    }


});


