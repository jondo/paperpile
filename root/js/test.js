Ext.BLANK_IMAGE_URL = '/ext/resources/images/default/s.gif';

var libDataStore;
var libColumnModel;
var libListingEditorGrid;
var libListingWindow;


Ext.onReady(function(){

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
            '-',  {
                text: 'Add to database',
                cls: 'x-btn-text-icon add',
                handler: function(btn, pressed){
                    var id = grid.selected;
                    alert(id);
                }
            }]
    });
    
    var grid = new Ext.grid.GridPanel({
        el:'container',
        sm: new Ext.grid.RowSelectionModel({singleSelect: false}),
        stripeRows: true,
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




