PaperPile.Tree = Ext.extend(Ext.tree.TreePanel, {
	  
    initComponent: function() {
		    Ext.apply(this, {
            dataUrl: '/ajax/tree/node',
            animate: false,
            autoScroll: true,
            root: {
                nodeType: 'async',
                text: 'Root',
                draggable:false,
                id:'root'
            }
		    });
		    PaperPile.Tree.superclass.initComponent.call(this);

        this.on("click", function(node,e){
            //var node=this.getSelectionModel().getSelectedNode();
            alert(node.text);
        });
        
	  },

});

Ext.reg('tree', PaperPile.Tree);
