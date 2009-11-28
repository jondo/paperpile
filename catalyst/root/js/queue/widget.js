Paperpile.QueueWidget = Ext.extend(Ext.BoxComponent, {
    
    initComponent:function() {
        
        Ext.apply(this, {
            autoEl: {
                tag: 'div',
                cls: 'pp-queue-widget',
                children : [
                    {tag: 'a',
                     href:'#',
                     cls: 'pp-basic pp-textlink pp-status-action',
                     html: 'Background tasks',
                     id: 'queue-widget-link'
                    }
                ],
            },
            id: 'queue-widget',
        });

        Paperpile.QueueWidget.superclass.initComponent.apply(this, arguments);
    },

    
    afterRender: function(){
        Paperpile.QueueWidget.superclass.afterRender.apply(this, arguments);
        
        Ext.get('queue-widget-link').on('click', this.test);


    },

    test: function(){

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/queue/fork'),
            success: function(response){
                var json = Ext.util.JSON.decode(response.responseText);
                console.log(json);
            },
            failure: Paperpile.main.onError,
            scope:this,
        });
        
    }




});
