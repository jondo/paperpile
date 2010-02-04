Paperpile.LabelWidget = Ext.extend(Object, {

    constructor: function(config) {
        Ext.apply(this, config);
    },

    renderData: function(data) {
        this.data = data;
        this.renderTags();
    },

    // private!
    renderTags: function() {
        var data = this.data;
        if (!data || !data._imported) return;

        var rootEl = Ext.get(this.div_id);

        rootEl.un('click', this.handleClick, this);
        rootEl.on('click', this.handleClick, this);

        var oldLabels = Ext.select("#" + this.div_id + " > *");
        oldLabels.remove();

        var store = Ext.StoreMgr.lookup('tag_store');
        var tags = data.tags.split(/\s*,\s*/);

        for (var i = 0; i < tags.length; i++) {
            var name = tags[i];
            if (name == '') continue;
            var style = '0';
            if (store.getAt(store.findExact('tag', name))) {
                style = store.getAt(store.findExact('tag', name)).get('style');
            }

            var el = {
                tag: 'div',
                cls: 'pp-tag-box pp-tag-style-' + style,
                children: [{
                    tag: 'div',
                    cls: 'pp-tag-name pp-tag-style-' + style,
                    html: name
                },
                {
                    tag: 'div',
                    cls: 'pp-tag-remove pp-tag-style-' + style,
                    html: 'x',
                    action: 'remove-tag',
                    name: name
                }]
            };

            if (i == 0) {
                Ext.DomHelper.append(rootEl, el);
            } else {
                Ext.DomHelper.append(rootEl, el);
            }
        }

        this.ADD_LABEL_MARKUP = ['<div style="display:block;float:left;">', '<img width="12px" style="padding:2px;" src="/images/icons/tag_add.png" class="pp-img-action " action="add-tag" ext:qtip="Add Label"/>', '</div>'];
        if (tags.length == 0) Ext.DomHelper.append(rootEl, el);
        else Ext.DomHelper.append(rootEl, this.ADD_LABEL_MARKUP);
    },

    handleClick: function(e) {
        e.stopEvent();
        var el = e.getTarget();
        Paperpile.log("Click!");

        switch (el.getAttribute('action')) {
        case 'remove-tag':
            this.removeTag(el);
            break;
        case 'add-tag':
            this.addTag(el);
            break;
        default:
            break;
        };
    },

    addTag: function(el) {
        var list = [];
        Ext.StoreMgr.lookup('tag_store').each(
        function(rec) {
            var tag = rec.data.tag;
            if (!this.multipleSelection) {
                if (this.data.tags.match(new RegExp("," + tag + "$"))) return; // ,XXX
                if (this.data.tags.match(new RegExp("^" + tag + "$"))) return; //  XXX
                if (this.data.tags.match(new RegExp("^" + tag + ","))) return; //  XXX,
                if (this.data.tags.match(new RegExp("," + tag + ","))) return; // ,XXX,
            }
            list.push([tag]);
        },
        this);
        var extEl = Ext.get(el);
        extEl.replaceWith(['<div id="pp-tag-control-' + this.grid_id + '"></div>']);

        var store = new Ext.data.SimpleStore({
            fields: ['tag'],
            data: list
        });

        this.comboBox = new Ext.form.ComboBox({
            id: 'tag-control-combo-' + this.grid_id,
            ctCls: 'pp-tag-control',
            store: store,
            displayField: 'tag',
            typeAhead: true,
            mode: 'local',
            triggerAction: 'all',
            selectOnFocus: true,
            forceSelection: false,
            enableKeyEvents: true,

            hideLabel: true,
            hideTrigger: false,
            renderTo: 'pp-tag-control-' + this.grid_id,
            width: 100,
            minListWidth: 100,
            listeners: {
                'specialkey': function(field, e) {
                    if (e.getKey() == e.ENTER) {
                        this.commitTag(field.getValue());
                    } else if (e.getKey() == e.ESC) {
                        this.renderTags();
                    } else if (e.getKey() == e.TAB) {
                        // TODO: Tab key should trigger an add-tag while keeping the editor open for further adding.
                    }
                },
                'select': function(combo, record, index) {
                    this.commitTag(record.get('tag'));
                },
                scope: this
            }
        });
        this.comboBox.focus();
    },

    commitTag: function(tag) {
        this.comboBox.disable();
        var tagIndex = Ext.StoreMgr.lookup('tag_store').findExact('tag', tag);

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/crud/add_tag'),
            params: {
                grid_id: this.grid_id,
                selection: Ext.getCmp(this.grid_id).getSelection(),
                tag: tag
            },
            method: 'GET',
            success: function(response) {
                var json = Ext.util.JSON.decode(response.responseText);
                var grid = Ext.getCmp(this.grid_id);

                if (tagIndex > -1) {
                    Ext.StoreMgr.lookup('tag_store').reload();
                    Paperpile.main.onUpdate(json.data);
                } else {
                    // Cause the tree's tag list to reload itself.
                    Paperpile.main.tree.getNodeById('TAGS_ROOT').reload();
                    Ext.StoreMgr.lookup('tag_store').reload({
                        callback: function() {
                            Paperpile.main.onUpdate(json.data);
                        }
                    });
                }
            },
            failure: Paperpile.main.onError,
            scope: this
        });

    },

    removeTag: function(el) {
        tag = el.getAttribute('name');

        Ext.get(el).parent().remove();

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/crud/remove_tag'),
            params: {
                grid_id: this.grid_id,
                selection: Ext.getCmp(this.grid_id).getSelection(),
                tag: tag
            },
            method: 'GET',
            success: function(response) {
                var json = Ext.util.JSON.decode(response.responseText);
                var grid = Ext.getCmp(this.grid_id);
                Ext.StoreMgr.lookup('tag_store').reload();
                Paperpile.main.onUpdate(json.data);
            },
            failure: Paperpile.main.onError,
            scope: this
        });
    }

});