Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');


Paperpile.status = function(){
    
    Ext.Ajax.request({
        url: '/ajax/browser/status',
        params: { lookup_id: Paperpile.lookup_id,
                },
        method: 'GET',
        success: function(response){
            var json = Ext.util.JSON.decode(response.responseText);
            console.log(json);
            
        }
    })
};
                    


Ext.onReady(function() {

    Paperpile.lookup_id=Ext.get('lookup_id').dom.innerHTML;

    Paperpile.status();

    /*
    this.progressTask = {
        run: this.checkProgress,
        scope: this,
        interval: 500
    }
    Ext.TaskMgr.start(this.progressTask);

*/



});
