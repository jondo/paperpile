Paperpile.PubSummary = Ext.extend(Ext.Panel, {

    initComponent: function() {

        // The template for the abstract
        this.abstractMarkup = ['<div class="pp-basic pp-abstract">{abstract}</div>', ];

        this.abstractTemplate = new Ext.Template(this.abstractMarkup);

        Ext.apply(this, {
            bodyStyle: {
                background: '#ffffff',
                padding: '7px'
            },
            autoScroll: true,
        });

        Paperpile.PubSummary.superclass.initComponent.call(this);

    },

    updateDetail: function() {

        if (!this.grid) {
            this.grid = this.findParentByType(Paperpile.PluginPanel).items.get('center_panel').items.get('grid');
        }

        sm = this.grid.getSelectionModel();
        var numSelected = sm.getCount();
        if (this.grid.allSelected) {
            numSelected = this.grid.store.getTotalCount();
        }

        if (numSelected == 1) {
            this.data = sm.getSelected().data;
            this.data.id = this.id;
            this.abstractTemplate.overwrite(this.body, this.data);
        } else {

            var empty = new Ext.Template('');
            empty.overwrite(this.body);
        }
    },

    showEmpty: function(tpl) {
        var empty = new Ext.Template(tpl);
        empty.overwrite(this.body);
    }

});

Ext.reg('pubsummary', Paperpile.PubSummary);