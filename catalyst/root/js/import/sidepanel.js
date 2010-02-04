Paperpile.PluginAboutPanel = Ext.extend(Ext.Panel, {

    markup: ['<div class="pp-box pp-box-side-panel pp-box-style1">', '<p>Put your side-panel HTML here</p>', '<p></p>', '</div>'],

    tabLabel: 'About',

    initComponent: function() {
        Ext.apply(this, {
            bodyStyle: {
                background: '#ffffff',
                padding: '7px'
            },
            autoScroll: true,
            itemId: 'about'
        });

        this.tpl = new Ext.XTemplate(this.markup).compile();

        Paperpile.PluginAboutPanel.superclass.initComponent.call(this);
    },

    update: function() {

        this.tpl.overwrite(this.body, {},
        true);

    }
});