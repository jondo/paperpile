Ext.BLANK_IMAGE_URL = '/ext/resources/images/default/s.gif';

var libDataStore;
var libColumnModel;
var libListingEditorGrid;
var libListingWindow;

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
            {name: 'FirstName', type: 'string', mapping: 'FirstName'},
            {name: 'LastName', type: 'string', mapping: 'LastName'},
        ]),
    });
    
    LibColumnModel = new Ext.grid.ColumnModel(
        [{
            header: 'First Name',
            dataIndex: 'FirstName',
            width: 60,
            editor: new Ext.form.TextField({
                allowBlank: false,
                maxLength: 20,
                maskRe: /([a-zA-Z0-9\s]+)$/
            })
        },{
            header: 'Last Name',
            dataIndex: 'LastName',
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



