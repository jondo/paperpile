Paperpile.CatalystLog = Ext.extend(Ext.Panel, {

    title: 'Catalyst log',
    iconCls: 'pp-icon-console',
    id: 'log-panel',

    markup: [
        '<div class="pp-catalyst-log">',
        '<pre id="catalyst-log">{content}</pre>',
        '<div id="log-last-line"></div>',
        '</div>'
    ],

    initComponent: function() {
		Ext.apply(this, {
            closable:true,
            autoScroll:true,
        });
		
        Paperpile.PatternSettings.superclass.initComponent.call(this);

        this.tpl = new Ext.XTemplate(this.markup);

    },

    afterRender: function() {
        Paperpile.Statistics.superclass.afterRender.apply(this, arguments);

        this.on('activate', 
                function(){
                    Ext.get('log-last-line').dom.scrollIntoView();
                }, this);

        this.update();

 
    },

    update: function() {

        this.tpl.overwrite(this.body, {content: Paperpile.serverLog}, true);

    }, 
    
    addLine: function(line){
        
        Ext.get('catalyst-log').insertHtml('beforeEnd',line); 
        
    }



});
