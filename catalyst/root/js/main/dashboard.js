Paperpile.Dashboard = Ext.extend(Ext.Panel, {

    title: 'Dashboard',
    iconCls: 'pp-icon-dashboard',

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoLoad:{url:'/screens/dashboard',
                      callback: this.setupFields,
                      scope:this
                     },
            
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

    },

    setupFields: function(){

        this.body.on('click', function(e, el, o){

            switch(el.getAttribute('action')){
                
            case 'statistics':

                Paperpile.main.tabs.newScreenTab('Statistics');

                break;

            case 'settings-patterns':                 
                this.searchPDF(true);
                break;
            }

        }, this, {delegate:'a'});

    },
});
