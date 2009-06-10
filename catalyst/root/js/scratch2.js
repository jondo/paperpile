Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

Ext.onReady(function() {

    //var a = new Paperpile.Items ({renderTo:'container'});

    var status=new Paperpile.Status();

    alert(Titanium.App.getName());


    /*
    status.updateMsg({msg: 'You have deleted 2 messages',
                      action1: 'Yes',
                      action2: 'No',
                      //type:'error',
                      //duration: 5,
                     });
*/

    status.updateMsg({msg: 'You have deleted 2 messages. this is a very long message that should be centered',
                      //duration: 5,
                      hideOnClick:true,
                     });


    //(function(){status.hideMsg()}).defer(5000, this);

    //status.showBusy('Loading');

    //(function(){status.setType('error')}).defer(5000, this);
    


    /*
    (function(){status.updateMsg({msg: 'You have deleted 2 messages',
                       busy: false,
                       duration: 1000
                                 })}).defer(5000,this);

*/

   
});


Paperpile.Status = Ext.extend(Ext.BoxComponent, {

    anim: true,
    callback: function(action){
        console.log(action);
    },
    scope:this,
    type: 'info',
    anchor: Ext.getBody(),

    initComponent: function() {
		Ext.apply(this, {
            renderTo: document.body,
            autoEl: {
                style: 'position: absolute',
                tag: 'div',
                cls: 'pp-status-line-container pp-status-'+this.type,
                children: [
                    { tag: 'table',
                      children: [
                          {tag:'tr',
                           children: [
                               {tag:'td',
                                id: 'status-msg',
                                cls: 'pp-basic pp-status-msg',
                               },
                               {tag:'td',
                                children:[
                                    { id: 'status-action1',
                                      tag: 'a',
                                      href: '#',
                                      cls: 'pp-basic pp-textlink pp-status-action',
                                    }
                                ],
                                hidden: true,
                               },
                               {tag:'td',
                                children:[
                                    { id: 'status-action2',
                                      tag: 'a',
                                      href: '#',
                                      cls: 'pp-basic pp-textlink pp-status-action',
                                    }
                                ],
                                hidden: true,
                               },
                               {tag:'td',
                                id: 'status-busy',
                                cls: 'pp-basic pp-status-spinner',
                               },
                           ]
                          }
                      ]
                    }
                ]
            }
        });
		Paperpile.Status.superclass.initComponent.call(this);
    },
    
    afterRender: function(){
        Paperpile.Status.superclass.afterRender.apply(this, arguments);
        this.el.hide();
        //this.el.anchorTo(document.body, 't-t',[0,3]);

        this.msgEl= Ext.get('status-msg');
        this.action1el= Ext.get('status-action1');
        this.action2el= Ext.get('status-action2');
        this.busyEl= Ext.get('status-busy');

        this.msgEl.setVisibilityMode(Ext.Element.DISPLAY);
        this.action1el.setVisibilityMode(Ext.Element.DISPLAY);
        this.action2el.setVisibilityMode(Ext.Element.DISPLAY);
        this.busyEl.setVisibilityMode(Ext.Element.DISPLAY);

        this.action1el.on('click',
                        function(){
                            this.callback.createDelegate(this.scope,['ACTION1'])();
                        }, this
                       );

        this.action2el.on('click',
                          function(){
                              this.callback.createDelegate(this.scope,['ACTION2'])();
                          }, this
                         );


        
    },

    updateMsg: function(pars){

        if (!this.el.isVisible()){
            this.el.show(this.anim);
        }
        
        if (pars.type){
            this.setType(pars.type);
        }
    
        if (pars.msg){
            Ext.DomHelper.overwrite(this.msgEl, pars.msg);
        } else {
            this.msgEl.hide();
        }

        if (pars.action1){
            Ext.DomHelper.overwrite(this.action1el, pars.action1);
        } else {
            this.action1el.hide();
        }

        if (pars.action2){
            Ext.DomHelper.overwrite(this.action2el, pars.action2);
        } else {
            this.action2el.hide();
        }

        if (pars.busy){
            Ext.DomHelper.overwrite(this.busyEl, '<img src="/images/icons/loading.gif">');
        } else {
            this.busyEl.hide();
        }

        if (pars.duration) {
            (function(){this.hideMsg()}).defer(pars.duration*1000, this);
        }

        if (pars.hideOnClick){
            Ext.getBody().on('click',
                           function(e){
                               this.hideMsg();
                           }, this, {single:true});
        }

        this.el.alignTo(this.anchor, 't-t',[0,3]);

    },

    hideMsg: function(){
        this.el.hide(this.anim);
        // back to default
        this.setType('info');
    },

    showBusy: function(msg){
        this.updateMsg({msg:msg,busy:true});
    },

    setText: function(text){
        Ext.DomHelper.overwrite(this.msgEl, text);
    },

    setType: function(type){
        this.el.replaceClass('pp-status-'+this.type,'pp-status-'+type);
        this.type=type;
    }


});





Paperpile.Items = Ext.extend(Ext.BoxComponent, {

    list: ['Washietl, S', 'Gruber, AR', 'Stadler, Peter F', 'Hans Huber', 'Encode Consortium'],
    
    initComponent: function() {
		Ext.apply(this, {
            autoEl: {
                tag: 'div',
                cls: 'pp-item-widget'
            }
        });
		Paperpile.Items.superclass.initComponent.call(this);

        this.activeField=null;
        

    },

    afterRender: function(){
        Paperpile.Items.superclass.afterRender.apply(this, arguments);


        for (var i=0; i<this.list.length;i++){
            var el=Ext.DomHelper.append(this.getEl(), 
                                        { id: 'item'+i, 
                                          tag: 'div', 
                                          cls: 'pp-item',
                                          children: [{tag: 'span',
                                                      html: this.list[i],
                                                      cls: 'pp-item-text',
                                                     }]
                                        }, true
                                       );

            el.setVisibilityMode(Ext.Element.DISPLAY);
        }

        this.on('mouseover', 
                function(e){
                    console.log(e.target.id);
                }
               );
        



        this.getEl().on('click',
                        function(e){
                            var target=e.getTarget('div.pp-item');

                            console.log('click');

                            if (target){

                                if (this.activeField){
                                    this.activeField.getEl().prev().show();
                                    this.activeField.destroy();
                                }

                                var text=Ext.get(target).first();

                                var index=this.getIndex(target);
                                var f=new Ext.form.TextField({cls:'pp-item-widget-textfield',
                                                              value: this.list[index],
                                                             });
                                text.setVisibilityMode(Ext.Element.DISPLAY);
                                text.hide();
                                f.render(target);
                                f.focus();
                                this.activeField=f;

                                f.on('blur',
                                     function(){
                                         //this.activeField.getEl().prev().show();
                                         //this.activeField.destroy();
                                         console.log('blur');
                                     }, this);

                            }

                        }, this
                       );
        
            
    },

    getIndex: function(target){
        target=Ext.get(target);
        var el=this.getEl().first();
        var index=0;
        while (el){
            if (el == target) return index;
            el=el.next();
            index++;
        }
    }

   


});




