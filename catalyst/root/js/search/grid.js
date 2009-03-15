Paperpile.PluginGrid = Ext.extend(Ext.grid.GridPanel, {

    plugin_query:'',
    closable:true,
    region:'center',

    initComponent:function() {

        var _store=new Ext.data.Store(
            {  proxy: new Ext.data.HttpProxy({
                url: '/ajax/grid/resultsgrid', 
                method: 'GET'
            }),
               baseParams:{grid_id: this.id,
                           plugin_file: this.plugin_file,
                           plugin_type: this.plugin_type,
                           plugin_query: this.plugin_query,
                           plugin_mode: this.plugin_mode,
                           limit:25
                          },
               reader: new Ext.data.JsonReader(),
            }); 
        
        var _pager=new Ext.PagingToolbar({
            pageSize: 25,
            store: _store,
            displayInfo: true,
            displayMsg: 'Displaying papers {0} - {1} of {2}',
            emptyMsg: "No papers to display",
        });
    
        var renderPub=function(value, p, record){

            var t = new Ext.Template(
                '<p class="pp-grid-title">{title}</p>',
                '<p class="pp-grid-authors">{authors}</p>',
                '<p class="pp-grid-citation">{citation}</p>'
            );
            return t.apply({title:record.data.title,
                            authors:record.data._authors_nice,
                            citation:record.data._citation_nice,
                           });
        }
    
        Ext.apply(this, {
            ddGroup  : 'gridDD',
            enableDragDrop   : true,
            store: _store,
            bbar: _pager,
            autoExpandColumn:'publication',
            columns:[{header: '',
                      renderer: function(value, metadata,record, rowIndex,colIndex,store){
                          if (record.data._imported){
                              return '<div class="pp-status-imported"></div>';
                          } else {
                              return '';
                          }
                      },
                      width: 36,
                     },
                     {header: '',
                      renderer: function(value, metadata,record, rowIndex,colIndex,store){
                          if (record.data.pdf){
                              return '<div class="pp-status-pdf"></div>';
                          } else {
                              return '';
                          }
                      },
                      width: 36,
                     },
                     {header: "Publication",
                      id: 'publication',
                      dataIndex: 'title',
                      renderer:renderPub,
                     }
                    ],
            
        });
        
        Paperpile.PluginGrid.superclass.initComponent.apply(this, arguments);

        
        this.on('beforedestroy', this.onDestroy,this);

    },

    afterRender: function(){

        var container= this.findParentByType(Paperpile.PubView);
        this.getSelectionModel().on('rowselect',container.onRowSelect,container);
        Paperpile.PluginGrid.superclass.afterRender.apply(this, arguments);

    },

    
    insertEntry: function(){
        
        var sha1=this.getSelectionModel().getSelected().id;
        Ext.Ajax.request({
            url: '/ajax/crud/insert_entry',
            params: { sha1: sha1,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry Inserted.');
                this.store.getById(sha1).set('_imported',1);
            },
            scope:this
        });

    },

    deleteEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().id;

        Ext.Ajax.request({
            url: '/ajax/crud/delete_entry',
            params: { rowid: rowid,
                      grid_id: this.id,
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
        });

        this.store.remove(this.store.getById(sha1));
    },

    editEntry: function(){
        
        var rowid=this.getSelectionModel().getSelected().get('_rowid');
        var sha1=this.getSelectionModel().getSelected().id;

        var form = new Paperpile.PubEdit(
            {id:'pub_edit',
             itemId:'pub_edit',
             data:this.getSelectionModel().getSelected(),
             grid_id: this.id, 
             items: [{ fieldLabel: 'Type',  name: 'dummy', id:'dummy' }],
            }
        )

        Ext.getCmp('canvas_panel').add(form);
        Ext.getCmp('canvas_panel').doLayout();
        Ext.getCmp('canvas_panel').getLayout().setActiveItem('pub_edit');

    },

    onDestroy: function(cont, comp){
        Ext.Ajax.request({
            url: '/ajax/grid/delete_grid',
            params: { grid_id: this.id,
                    },
            method: 'GET'
        });
    },
});








