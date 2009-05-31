Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

Ext.onReady(function() {

    //var a = new Paperpile.Items ({renderTo:'container'});

    var status=new Paperpile.Status();

    status.showMsg('Imported 10 items');
    
    //(function(){status.updateMsg('New Message')}).defer(5000, this);

    //(function(){status.hideMsg()}).defer(10000, this);

  
});


Paperpile.Status = Ext.extend(Ext.BoxComponent, {

    anim: true,

    initComponent: function() {
		Ext.apply(this, {
            renderTo: document.body,
            autoEl: {
                style: 'position: absolute',
                tag: 'div',
                children: [
                    { tag: 'div',
                      id: 'status-msg',
                      cls: 'pp-basic pp-status-msg pp-status-msg-busy',
                    }
                ]
            }
        });
		Paperpile.Status.superclass.initComponent.call(this);
    },
    
    afterRender: function(){
        Paperpile.Status.superclass.afterRender.apply(this, arguments);
        this.msgEl= Ext.get('status-msg');
        this.msgEl.hide();
        this.msgEl.anchorTo(document.body, 't-t',[0,3]);
        
    },

    showMsg: function(msg,duration){

        Ext.DomHelper.overwrite(this.msgEl, msg);

        this.msgEl.show(this.anim);

        if (duration) {
            (function(){this.msgEl.hide(this.anim)}).defer(duration*1000, this);
        }
    },
    
    updateMsg: function(msg,duration){

        Ext.DomHelper.overwrite(this.msgEl, msg);

        if (duration) {
            (function(){this.msgEl.hide(this.anim)}).defer(duration*1000, this);
        }
    },

    hideMsg: function(){
        this.msgEl.hide(this.anim);
    },

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




