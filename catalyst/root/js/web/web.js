document.body.appendChild(document.createElement('script')).src='http://localhost:3000/js/web/ext-core-debug.js';

//alert("inhere");

Ext.DomHelper.append(document.body, {tag: 'p', cls: 'some-class'});
Ext.select('p.some-class').update('Ext Core successfully injected');


/*

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
});

*/




