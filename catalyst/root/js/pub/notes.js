
PaperPile.PubNotes = Ext.extend(Ext.Panel, {
	markup: [
        '<div class="pp-notes">{notes}</div>',
        '<div class="pp-action-edit-notes">',
        '<a href="#" onClick="{scope}.editNotes()">Edit Notes</a>',
        '</div>',
    ],

    markupEmpty: [
        '<div class="pp-action-add-notes">',
        '<a href="#" onClick="{scope}.editNotes()">Insert notes</a>',
        '</div>',
    ],

	startingMarkup: 'Empty',
	  
    initComponent: function() {
		this.tpl = new Ext.XTemplate(this.markup);
		Ext.apply(this, {
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
            autoScroll: true,
			html: this.startingMarkup
		});
		PaperPile.PubNotes.superclass.initComponent.call(this);
	},
    
	updateDetail: function(data) {
        this.data=data;

        var tpl=new Ext.XTemplate(this.markup);

        if (data.notes==''){
            tpl=new Ext.XTemplate(this.markupEmpty);
        }

        this.data.scope='Ext.getCmp(\'pubnotes\')';
		tpl.overwrite(this.body, this.data);		
	},

    editNotes: function(){
       
        var editor=new Ext.form.HtmlEditor(
            {id:'html_editor',
             value: this.data.notes,
             itemId:'html_editor',
            }
        );

        Ext.getCmp('data_tabs').add(editor);

        Ext.getCmp('summary_tab_button').hide();
        Ext.getCmp('notes_tab_button').hide();

        Ext.getCmp('save_notes_button').show();
        Ext.getCmp('cancel_notes_button').show();

        Ext.getCmp('data_tabs').doLayout();
        Ext.getCmp('data_tabs').getLayout().setActiveItem('html_editor');

        // Does not work, don't know why
        editor.focus();
        
    },

    onSave: function(){

        var newNotes= Ext.getCmp('html_editor').getValue();

        Ext.Ajax.request({
            url: '/ajax/crud/update_notes',
            params: { sha1: this.data.sha1,
                      rowid: this.data._rowid,
                      html: newNotes,
                    },
            method: 'GET',
            success: function(){
                this.data.notes=newNotes,
                this.closeEditor();
            },
            scope: this
        });

    },


    onCancel: function(){
        this.closeEditor();
    },


    closeEditor: function(){

        Ext.getCmp('data_tabs').remove('html_editor'); 
        Ext.getCmp('summary_tab_button').show();
        Ext.getCmp('notes_tab_button').show();
        Ext.getCmp('save_notes_button').hide();
        Ext.getCmp('cancel_notes_button').hide();
        
        Ext.getCmp('data_tabs').doLayout();
        Ext.getCmp('data_tabs').getLayout().setActiveItem('pubnotes');

        this.tpl.overwrite(this.body, this.data);

    }



});

Ext.reg('pubnotes', PaperPile.PubNotes);

