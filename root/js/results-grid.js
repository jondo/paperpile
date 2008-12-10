PaperPile.ResultsGrid = Ext.extend(Ext.grid.GridPanel, {

    initComponent:function() {

        var _store=new Ext.data.Store(
            {id: 'data',
             proxy: new Ext.data.HttpProxy({
                 url: '/test/list', 
                 method: 'GET'
             }),
             baseParams:{task: "LISTING"},
             reader: new Ext.data.JsonReader(),
            }); // eof _store

        var _pager=new Ext.PagingToolbar({
            pageSize: 25,
            store: _store,
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
        }); // eof _pager
    

        var renderPub=function(value, p, record){
            return String.format('<b>{0}</b><br>{1}',record.data.title,record.data.authors_flat);
        }
    
        Ext.apply(this, {
            store: _store,
            bbar: _pager,
            border:true,
            columns:[{
                header: "Publication",
                width: 400,
                renderer:renderPub
            }],
        });

        
        PaperPile.ResultsGrid.superclass.initComponent.apply(this, arguments);

    }, // eo function initComponent

    onRender: function() {
        this.store.load({params:{start:0, limit:25}});
        PaperPile.ResultsGrid.superclass.onRender.apply(this, arguments);
    }

    
}
                                   
 
);
 
Ext.reg('resultsgrid', PaperPile.ResultsGrid);
