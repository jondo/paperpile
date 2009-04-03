Paperpile.FileChooser = Ext.extend(Ext.Window, {

    title: "Select file",
    selectionMode: 'FILE',
    saveMode: false,
    saveDefault: 'new-file.dat',
    currentRoot: "ROOT",
    showHidden: false,

    callback: function(button,path){
        console.log(button, path);
    },

    initComponent: function() {

        var label='Location';

        if (this.selectionMode == 'DIR'){
            label='Directory';
        }

        if (this.selectionMode == 'FILE'){
            label='File';
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
                      },
                  ],
                },
                { xtype: 'panel',
                  region: 'center',
                  itemId:'centerpanel',
                  layout: 'fit',
                  tbar:[
                      {xtype:'box',
                       itemId: 'breadcrumbs',
                       autoEl: {
                           tag:'div',
                           html:'<ul class="pp-filechooser-path"><li>inhere</li></ul>'
                       },
                       width:200,
                      },
                  ],
                  items:[{xtype:'panel', itemId:'filetree', id:'DUMMY'}],
                }
            ],
            bbar: [  {xtype:'tbfill'},
                     { text: 'Select',
                       itemId: 'ok_button',
                       disabled: true,
                       cls: 'x-btn-text-icon save',
                       listeners: {
                           click:  { 
                               fn: function(){
                                   var ft=this.items.get('filetree');
                                   
                                   var path=this.getCurrentSelection();

                                   if (this.saveMode){
                                       Ext.Ajax.request({
                                           url: '/ajax/files/stats',
                                           params: { location: path},
                                           method: 'GET',
                                           success: function(response){
                                               var json = Ext.util.JSON.decode(response.responseText);
                                               if (json.stats.exists){
                                                   Ext.Msg.confirm('',path+' already exists. Overwrite?',
                                                                   function(btn){
                                                                       if (btn=='yes'){
                                                                           console.log(this.scope);
                                                                           this.callback.createDelegate(this.scope,['OK',path])();
                                                                           this.close();
                                                                       }
                                                                   }                                           
                                                                  )
                                               } else {
                                                   this.callback.createDelegate(this.scope,['OK',path])();
                                                   this.close();
                                               }
                                           },
                                           scope:this
                                       });
                                   } else {
                                       this.callback.createDelegate(this.scope,['OK',path])();
                                       this.close();
                                   }
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
                                   this.callback.createDelegate(this.scope,['CANCEL',null])();
                                   this.close();
                               },
                               scope: this
                           }
                       },
                     }
                  ]
	    });
        
        Paperpile.FileChooser.superclass.initComponent.call(this);

        if (!this.scope){
            this.scope=this;
        }

        this.items.get('northpanel').on('afterLayout',
                                        function(){
                                            this.showDir(this.currentRoot);
                                        }, this,{single:true});
        
        this.textfield=this.items.get('northpanel').items.get('textfield');

        


        
    },

    updateTextfield: function(value){
        this.textfield.setValue(value);
        if (value !=''){
            this.getBottomToolbar().items.get('ok_button').enable();
        } else {
            this.getBottomToolbar().items.get('ok_button').disable();
        }

    },

    onSelect: function(node,path){
        this.updateTextfield(node.text);
        this.saveDefault='';
        this.currentRoot=path;

    },

    getCurrentSelection: function(){

        var parts=this.currentRoot.split('/');
        var newParts=parts.slice(0,parts.length-1);
        newParts.push(this.textfield.getValue());
        return newParts.join('/');
        
    },

    showDir: function(path){

        if (this.saveMode){
            // Add selection/focus stuff here to improve usability
            this.updateTextfield(this.saveDefault);
        } else {
            this.updateTextfield('');
        }

        var cp=this.items.get('centerpanel');
        

        // Remove old tree and build new one
        cp.remove(cp.items.get('filetree'));
        
        var treepanel = new Ext.ux.FileTreePanel({
		    height:400,
            border:0,
            itemId:'filetree',
		    autoWidth:true,
		    selectionMode: this.selectionMode,
            showHidden:this.showHidden,
		    rootPath: path,
            rootText: path,
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

        bc=cp.getTopToolbar().items.get('breadcrumbs');

        var dh=Ext.DomHelper;
        var ul=dh.overwrite(bc.getEl(), {tag:'ul',cls:'pp-filechooser-path'});

        path=path.split('/');

        for (var i=0; i<path.length;i++){

            var html=path[i];
            
            if (path[i]=='ROOT') {
                html='<img src="/images/icons/drive.png" valign="center"/>';
            }

            var li = dh.append(ul,{tag:'li', cls:'pp-filechooser-dir', children:[{tag:'a', 
                                                                                  href:'#',
                                                                                  html:html,
                                                                                 }]});
            
            var link=path.slice(0,i+1).join('/');
            
            Ext.Element.get(li).on('click',
                                   function(e, el, options){
                                       this.showDir(options.link);
                                   }, this, {link: link });
            
            dh.append(ul,{tag:'li', cls:'pp-filechooser-separator', html:"/"});
        }
    }
});





