Paperpile.FileChooser = Ext.extend(Ext.Window, {

    title: "Select file",
    selectionMode:'FILE',
    showHidden:false,
    currentRoot:"ROOT",

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
                  height: 60,
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
                      },
                      {xtype:'box',
                       itemId: 'breadcrumbs',
                       autoEl: {
                           tag:'div',
                           html:'<ul class="pp-filechooser-path"><li>inhere</li></ul>'
                       },
                       width:400,
                       height:20,
                      }
                  ],
                },
                { xtype: 'panel',
                  region: 'center',
                  itemId:'centerpanel',
                  layout: 'fit',
                  items:[{xtype:'panel', itemId:'filetree', id:'DUMMY'}],
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

        this.items.get('northpanel').on('afterLayout',
                                        function(){
                                            this.showDir("");
                                        }, this,{single:true});
        
        this.textfield=this.items.get('northpanel').items.get('textfield');
        
    },

     onSelect: function(node){
        this.textfield.setValue(node.text);

    },

    showDir: function(dir){

        var cp=this.items.get('centerpanel');
        cp.remove(cp.items.get('filetree'));

        this.currentRoot=this.currentRoot+'/'+dir;

        var treepanel = new Ext.ux.FileTreePanel({
		    height:400,
            border:0,
            itemId:'filetree',
		    autoWidth:true,
		    selectionMode: this.selectionMode,
            showHidden:this.showHidden,
		    rootPath: this.currentRoot,
            rootText: dir,
		    topMenu:false,
		    autoScroll:true,
		    enableProgress:false,
            enableSort:false,
            lines:false,
            rootVisible:false,
            url:'/ajax/files/dialogue',
	    });

        cp.add(treepanel);
        cp.doLayout();

        /*

        var html="/ "+parts.join(" / ");

        var np=this.items.get('northpanel');
            parts.push('<a href="#">'+path[i]+'</a>');
        var bc=np.items.get('breadcrumbs');

 */
        bc=this.items.get('northpanel').items.get('breadcrumbs');
        parts=[{tag:'a', href:"#", html:"test2"}, {tag:'a', href:"#", html:"test2"}];
        var dh=Ext.DomHelper;

        var path=this.currentRoot;

        path=path.split('/');

        //bc.getEl().child('.pp-filechooser-path').remove();

        var ul=dh.overwrite(bc.getEl(), {tag:'ul',cls:'pp-filechooser-path'});

        var fullPath='';

        for (var i=0; i<path.length;i++){
            if (path[i]=='' || path[i]=='ROOT') continue;

            var li = dh.append(ul,{tag:'li', cls:'pp-filechooser-dir', html:path[i]});

            Ext.Element.get(li).on('click',
                                   function(){
                                       this.currentRoot=fullPath;
                                       this.showDir(path[i]);
                                   }, this);

            dh.append(ul,{tag:'li', cls:'pp-filechooser-separator', html:"/"});

            fullPath=fullPath+path[i]+'/';
            
        }



        

  
    }



});


