
Paperpile.PubNotes = Ext.extend(Ext.Panel, {
	markup: [
        '<div class="pp-notes">{notes}</div>',
        '<div class="pp-action-edit-notes">',
        '<a href="#" onClick="Ext.getCmp(\'{id}\').editNotes()">Edit Notes</a>',
        '</div>',
    ],

    markupEmpty: [
        '<div class="pp-action-add-notes">',
        '<a href="#" onClick="Ext.getCmp(\'{id}\').editNotes()">Insert notes</a>',
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
		Paperpile.PubNotes.superclass.initComponent.call(this);
	},
    
	updateDetail: function(data) {
        this.data=data;

        var tpl=new Ext.XTemplate(this.markup);

        if (data.notes==''){
            tpl=new Ext.XTemplate(this.markupEmpty);
        }

        this.data.id=this.id;
		tpl.overwrite(this.body, this.data);		
	},

    editNotes: function(){
       
        this.editor=new Ext.form.HtmlEditor(
            {value: this.data.notes,
             itemId:'html_editor',
            }
        );
        
        var dataTabs=this.findParentByType(Paperpile.DataTabs);
        var bbar=dataTabs.getBottomToolbar();

        dataTabs.add(this.editor);
        

        bbar.items.get('summary_tab_button').hide();
        bbar.items.get('notes_tab_button').hide();

        bbar.items.get('save_notes_button').show();
        bbar.items.get('cancel_notes_button').show();

        dataTabs.doLayout();
        dataTabs.getLayout().setActiveItem('html_editor');

        // Does not work, don't know why
        editor.focus();
        
    },

    onSave: function(){
        
        var newNotes= this.editor.getValue();

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

        var dataTabs=this.findParentByType(Paperpile.DataTabs);
        var bbar=dataTabs.getBottomToolbar();

        dataTabs.remove('html_editor'); 
        bbar.items.get('summary_tab_button').show();
        bbar.items.get('notes_tab_button').show();
        bbar.items.get('save_notes_button').hide();
        bbar.items.get('cancel_notes_button').hide();
        
        dataTabs.doLayout();
        dataTabs.getLayout().setActiveItem('pubnotes');

        // id changes for some unknown reasons...
        this.data.id=dataTabs.items.get('pubnotes').id;

        this.tpl.overwrite(this.body, this.data);

    }



});

Ext.reg('pubnotes', Paperpile.PubNotes);

