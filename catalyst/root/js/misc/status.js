Paperpile.Status = Ext.extend(Ext.BoxComponent, {

    anim: false,
    scope:this,
    type: 'info',
    anchor: Ext.getBody(),
    callback: function(action){
        console.log(action);
    },

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
                                //hidden: true,
                               },
                               {tag:'td',
                                children:[
                                    { id: 'status-action2',
                                      tag: 'a',
                                      href: '#',
                                      cls: 'pp-basic pp-textlink pp-status-action',
                                    }
                                ],
                                //hidden: true,
                               },
                               {tag:'td',
                                id: 'status-busy',
                                cls: 'pp-basic',
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


        if (pars.scope){
            this.scope=pars.scope;
        }

    
        if (pars.msg){
            Ext.DomHelper.overwrite(this.msgEl, pars.msg);
        } else {
            this.msgEl.hide();
        }

        if (pars.action1){
            Ext.DomHelper.overwrite(this.action1el, pars.action1);
            this.action1el.show();
        } else {
            this.action1el.hide();
        }

        if (pars.action2){
            Ext.DomHelper.overwrite(this.action2el, pars.action2);
        } else {
            this.action2el.hide();
        }

        if (pars.busy){
            this.busyEl.addClass('pp-status-busy');
            this.busyEl.show();
        } else {
            this.busyEl.hide();
        }

        if (pars.duration) {
            (function(){this.clearMsg()}).defer(pars.duration*1000, this);
        }

        if (pars.hideOnClick){
            Ext.getBody().on('click',
                           function(e){
                               this.clearMsg();
                           }, this, {single:true});
        }

        if (pars.callback){
            this.callback=pars.callback;
        }

        this.el.alignTo(Ext.getCmp('main-toolbar').getEl(), 't-t',[0,3]);


    },

    clearMsg: function(){
        this.el.hide(this.anim);
        // back to default
        this.setType('info');
    },

    showBusy: function(msg){
        this.updateMsg({msg:msg,busy:true});
    },

    setMsg: function(msg){
        Ext.DomHelper.overwrite(this.msgEl, msg);
    },

    setType: function(type){
        this.el.replaceClass('pp-status-'+this.type,'pp-status-'+type);
        this.type=type;
    }


});