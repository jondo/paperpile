Paperpile.ContextTrianglePlugin = (function() {
  return {
    init:function(treePanel) {
      treePanel.onRender = treePanel.onRender.createSequence(this.onRender);
    },

    onRender:function() {
      this.contextTriangle = Ext.DomHelper.append(this.getEl(),
	{
	  id:this.itemId+"_context_triangle",
	  tag:"div",
	  cls:"pp-tree-context-triangle",
	  action:"edit"
	},true
      );

      this.getEl().on('mouseover',function(e) {
	var hoverEl = Ext.fly(e.getTarget());
	var nodeEl = hoverEl.findParent(".x-tree-node-el",10,true);
	if (nodeEl != null) {
	  this.contextTriangle.alignTo(nodeEl,'r-r?');
	}

      },this);
    }
  };
})();

