PaperPile.Tree = Ext.extend(Ext.tree.TreePanel, {
	  
    initComponent: function() {
		    Ext.apply(this, {

            animate: false,
            autoScroll: true,
            loader: new PaperPile.TreeLoader(
                {  url: '/ajax/tree/node',
                   requestMethod: 'GET'
                }
            ),
            root: {
                nodeType: 'async',
                text: 'Root',
                draggable:false,
                leaf:false,
                id:'root'
            }
		    });
		    PaperPile.Tree.superclass.initComponent.call(this);

        this.on("click", function(node,e){

            switch(node.type){

            case 'DB':
                Ext.getCmp('results_tabs').newDBtab(node.query);
                break;

            case 'PUBMED':
                Ext.getCmp('results_tabs').newPubMedTab(node.query);
                break;

            case 'FILE':
                Ext.getCmp('results_tabs').newFileTab(node.file);
                break;

            case 'RESET_DB':
                Ext.getCmp('MAIN').resetDB();
                break;

            case 'IMPORT_JOURNALS':
                Ext.getCmp('MAIN').importJournals();
                break;

            }





        });
	  },

});


// Extend TreeNode to allow to pass additional parameters from the server,
// Note that TreeNode is not a 'component' but only an observable, so we 
// can't override as usual but have do define (and call) an init function 
// for ourselves. 

PaperPile.AsyncTreeNode = Ext.extend(Ext.tree.AsyncTreeNode, {

    init: function(attr) {
		    Ext.apply(this, attr);
	  },

});

PaperPile.TreeNode = Ext.extend(Ext.tree.TreeNode, {

    init: function(attr) {
		    Ext.apply(this, attr);
	  },

});



// To use our custom TreeNode we also have to override TreeLoader
PaperPile.TreeLoader = Ext.extend(Ext.tree.TreeLoader, {
	  
    initComponent: function() {
		    PaperPile.TreeLoader.superclass.initComponent.call(this);
	  },


    // This function is taken from extjs-debug.js and modified
    createNode : function(attr){

        if(this.baseAttrs){
            Ext.applyIf(attr, this.baseAttrs);
        }
  
        if(this.applyLoader !== false){
            attr.loader = this;
        }

        if(typeof attr.uiProvider == 'string'){
            attr.uiProvider = this.uiProviders[attr.uiProvider] || eval(attr.uiProvider);
        }


        // Return our custom TreeNode here

        if (attr.leaf){
            var node=new PaperPile.TreeNode(attr);
            node.init(attr);
            return node;
        } else {
            var node=new PaperPile.AsyncTreeNode(attr);
            node.init(attr);
            return node;
        }

        // code in the original implementation
        
        //if(attr.nodeType){
        //    return new Ext.tree.TreePanel.nodeTypes[attr.nodeType](attr);
        //}else{
        //    return attr.leaf ?
        //        new Ext.tree.TreeNode(attr) :
        //        new Ext.tree.AsyncTreeNode(attr);
       //}
    }

});





Ext.reg('tree', PaperPile.Tree);
