Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

Ext.onReady(function() {

    //var a = new Paperpile.Items ({renderTo:'container'});


    var a = new Ext.form.HtmlEditor({
        renderTo: 'container',
        width: 300,
        height: 100,
    });
   
    a.on('sync', 
         function(editor, html){
             console.log(html);
             return false;
         }, this);


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




