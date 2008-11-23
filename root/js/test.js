Ext.BLANK_IMAGE_URL = '/ext/resources/images/default/s.gif';

var libDataStore;
var libColumnModel;
var libListingEditorGrid;
var libListingWindow;


/*
Ext.onReady(function(){

    Ext.QuickTips.init();

    LibDataStore = new Ext.data.Store({
        id: 'LibDataStore',
        proxy: new Ext.data.HttpProxy({
            url: 'list', 
            method: 'POST'
        }),
        baseParams:{task: "LISTING"}, // this parameter is passed for any HTTP request
        reader: new Ext.data.JsonReader({
            root: 'results',
            totalProperty: 'total',
            id: 'id'
        },[ 
            {name: 'authors', type: 'string', mapping: 'authors'},
            {name: 'journal', type: 'string', mapping: 'journal'},
        ]),
    });
    
    LibColumnModel = new Ext.grid.ColumnModel(
        [{
            header: 'Authors',
            dataIndex: 'authors',
            width: 60,
            editor: new Ext.form.TextField({
                allowBlank: false,
                maxLength: 20,
                maskRe: /([a-zA-Z0-9\s]+)$/
            })
        },{
            header: 'Journal',
            dataIndex: 'journal',
            width: 80,
            editor: new Ext.form.TextField({
                allowBlank: false,
                maxLength: 20,
                maskRe: /([a-zA-Z0-9\s]+)$/
          })
        }]
    );
    LibColumnModel.defaultSortable= true;
    
    LibListingEditorGrid =  new Ext.grid.EditorGridPanel({
        id: 'LibListingEditorGrid',
        store: LibDataStore,
        cm: LibColumnModel,
        enableColLock:false,
        clicksToEdit:1,
        selModel: new Ext.grid.RowSelectionModel({singleSelect:false})
    });
    
    LibListingWindow = new Ext.Window({
        id: 'LibListingWindow',
        title: 'The Lib of the USA',
        closable:true,
        width:700,
        height:350,
        plain:true,
        layout: 'fit',
        items: LibListingEditorGrid
    });
  
    LibDataStore.load();
    LibListingWindow.show();
  
});
*/

Ext.onReady(function(){

    // create the Data Store
    /*
    var store = new Ext.data.JsonStore({
        root: 'data',
        totalProperty: 'total_entries',
        idProperty: 'pubid',
        remoteSort: true,
        fields: [{name: 'pubid', type: 'string', mapping: 'pubid'},
                 {name: 'authors', type: 'string', mapping: 'authors'},
                 {name: 'journal', type: 'string', mapping: 'journal'}],
        //['id', 'authors', 'journal'],
        proxy: new Ext.data.ScriptTagProxy({
            url: 'list'
        })
    });
*/
    var store = new Ext.data.Store({
        id: 'data',
        proxy: new Ext.data.HttpProxy({
            url: 'list', 
            method: 'GET'
        }),
        baseParams:{task: "LISTING"},
        reader: new Ext.data.JsonReader({
            root: 'data',
            totalProperty: 'total_entries',
            id: 'pubid'
        },[ {name: 'pubid', type: 'string', mapping: 'pubid'},
            {name: 'authors', type: 'string', mapping: 'authors'},
            {name: 'journal', type: 'string', mapping: 'journal'},
          ]),
    });


    store.setDefaultSort('pubid', 'desc');

    var pagingBar = new Ext.PagingToolbar({
        pageSize: 25,
        store: store,
        displayInfo: true,
        displayMsg: 'Displaying papers {0} - {1} of {2}',
        emptyMsg: "No papers to display",
        
        items:[
            '-', {
                pressed: true,
                enableToggle:true,
                text: 'Show Preview',
                cls: 'x-btn-text-icon details',
                toggleHandler: function(btn, pressed){
                    var view = grid.getView();
                    view.showPreview = pressed;
                    view.refresh();
                }
            }]
    });
    
    var grid = new Ext.grid.GridPanel({
        el:'container',
        width:700,
        height:500,
        title:'ExtJS.com - Browse Forums',
        store: store,
        trackMouseOver:false,
        disableSelection:true,
        loadMask: true,

        // grid columns
        columns:[{
            id: 'id', // id assigned so we can apply custom css (e.g. .x-grid-col-topic b { color:#333 })
            header: "Sha1",
            dataIndex: 'pubid',
        },{
            header: "Authors",
            dataIndex: 'authors',
        },{
            header: "Journal",
            dataIndex: 'journal',
        }],

        // customize view config
/*        viewConfig: {
            forceFit:true,
            enableRowBody:true,
            showPreview:true,
            getRowClass : function(record, rowIndex, p, store){
                if(this.showPreview){
                    p.body = '<p>'+record.data.excerpt+'</p>';
                    return 'x-grid3-row-expanded';
                }
                return 'x-grid3-row-collapsed';
            }
        },*/

        // paging bar on the bottom
        bbar: pagingBar
    });

    // render it
    grid.render();

    // trigger the data store load
    store.load({params:{start:0, limit:25}});
});




