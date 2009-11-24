Paperpile.LabelWidget = function(config) {
  Ext.apply(this, config);

  Paperpile.LabelWidget.superclass.constructor.call(this, {

  });

};


Ext.extend(Paperpile.LabelWidget, Ext.Container, {
  initComponent: function() {
    Paperpile.LabelWidget.superclass.initComponent.call(this);

  },

  onRender: function(ct,position) {
    Paperpile.LabelWidget.superclass.onRender.call(this,ct,position);

    this.renderTags(this.data);
    this.el.on('click',this.handleClick,this);
  },

  renderTags: function(data) {
    var store = Ext.StoreMgr.lookup('tag_store');
    var tags = data.tags.split(/\s*,\s*/);

    for (var i = 0; i< tags.length; i++){
      var name = tags[i];
      if (name == '')
	continue;
      var style = '0';
      if (store.getAt(store.find('tag',name))){
	style=store.getAt(store.find('tag',name)).get('style');
      }

      var el = {
	tag: 'div',
	cls: 'pp-tag-box pp-tag-style-'+style,
        children: [
	  {
	    tag: 'div',
	    cls: 'pp-tag-name pp-tag-style-'+style,
	    html: name
	  },
	  { tag: 'div',
            cls: 'pp-tag-remove pp-tag-style-'+style,
	    html: 'x',
	    action: 'remove-tag',
	    name: name
	  }
	]
      };

      var htmlEl = null;
      if (i==0) {
	htmlEl = Ext.DomHelper.overwrite(this.el,el);
      } else {
	htmlEl = Ext.DomHelper.append(this.el,el);
      }
    }

  },

  handleClick: function(e) {
    e.stopEvent();
    var el = e.getTarget();

    switch(el.getAttribute('action')) {
      case 'remove-tag':
	this.removeTag(el);
	break;
      default:
	break;
    };
  },

  addTag: function() {
    Ext.StoreMgr.lookup('tag_store').each(
      function(rec) {
	var tag=rec.data.tag;
        if (!this.multipleSelection){
          if (this.data.tags.match(new RegExp(","+tag+"$"))) return; // ,XXX
          if (this.data.tags.match(new RegExp("^"+tag+"$"))) return; //  XXX
          if (this.data.tags.match(new RegExp("^"+tag+","))) return; //  XXX,
          if (this.data.tags.match(new RegExp(","+tag+","))) return; // ,XXX,
        }
	list.push([tag]);
      },
      this
    );
    
    var store = new Ext.data.SimpleStore({
      fields: ['tag'],
      data: list
    });
     
    var combo = new Ext.form.ComboBox({
      id: 'tag-control-combo-'+this.id,
      store: store,
      displayField:'tag',
      forceSelection: false,
      triggerAction:'all',
      mode:'local',
      enableKeyEvents: true,
      renderTo:'tag-control-'+this.id,
      width: 120,
      listWidth: 120,
      initEvents: function() {
	this.constructor.prototype.initEvents.call(this);
	Ext.apply(this.keyNav, {
	  "enter" : function(e) {
	    this.onViewClick();
	    this.delayedCheck = true;
	    this.unsetDelayCheck.defer(10, this);
            scope=Ext.getCmp(this.id.replace('tag-control-combo-',''));
            scope.onAddTag();
            this.destroy();
          }, 
	  doRelay : function(foo, bar, hname) {
	    if(hname == 'enter' || hname == 'down' || this.scope.isExpanded()){
	      return Ext.KeyNav.prototype.doRelay.apply(this, arguments);
	    }
	    return true;
	  }
	});
      }
    });

    combo.focus();

  },

  removeTag: function(el){
    tag=el.getAttribute('name');
    
    Ext.get(el).parent().remove();

    Ext.Ajax.request({
      url: Paperpile.Url('/ajax/crud/remove_tag'),
      params: { 
        grid_id:this.grid_id,
        selection: Ext.getCmp(this.grid_id).getSelection(),
        tag: tag
      },
      method: 'GET',
      success: function(response){
        var json = Ext.util.JSON.decode(response.responseText);
        var grid=Ext.getCmp(this.grid_id);
        grid.updateData(json.data);
        grid.getView().refresh();
      },
      failure: Paperpile.main.onError,
      scope: this
    });
  }


});