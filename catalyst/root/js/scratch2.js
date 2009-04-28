Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

Ext.onReady(function() {

    var a = new Paperpile.Items ({renderTo:'container'});

});



Paperpile.Items = Ext.extend(Ext.BoxComponent, {

    list: ['ItemA', 'ItemB', 'itemC'],
    
    initComponent: function() {
		Ext.apply(this, {
            autoEl: {
                tag: 'div',
                cls: 'pp-item-widget'
            }
        });
		Paperpile.Items.superclass.initComponent.call(this);


    },

    afterRender: function(){
        Paperpile.Items.superclass.afterRender.apply(this, arguments);


        for (var i=0; i<this.list.length;i++){
            var el=Ext.DomHelper.append(this.getEl(), 
                                        { id: 'item'+i, 
                                          tag: 'div', 
                                          cls: 'pp-item',
                                          html: this.list[i],
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
                            var target=e.getTarget('div');

                            if (target){
                                var index=this.getIndex(target);
                                var f=new Ext.form.TextField({cls:'pp-item-widget-textfield',
                                                              value: this.list[index],
                                                             });
                                f.render(this.getEl(), index);
                                Ext.get(target).hide();
                                f.focus();

                                f.on('blur', 
                                     function(field){
                                         field.getEl().next().show();
                                         field.destroy();
                                     }
                                    );


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




