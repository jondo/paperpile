Paperpile.PluginGridDB = function(config) {
  Ext.apply(this, config);

  Paperpile.PluginGridDB.superclass.constructor.call(this, {
    });

};

Ext.extend(Paperpile.PluginGridDB, Paperpile.PluginGrid, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'DB',
    limit: 25,

    welcomeMsg:[
        '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-welcome"',
        '<h2>Welcome to Paperpile</h2>',
        '<p>Your library is still empty. <p>',
        '<p>To get started, <p>',
        '<ul>',
        '<li>import your <a hrfef="#" class="pp-textlink" onClick="Paperpile.main.pdfExtract();">PDF collection</a></li>',
        '<li> get references from a <a href="#" class="pp-textlink" onClick="Paperpile.main.fileImport();">bibliography file</a></li>',
        '<li>start searching for papers using ',
        '<a href="#" class="pp-textlink" onClick="Paperpile.main.tabs.newPluginTab(\'PubMed\', {plugin_name: \'Pubmed\', plugin_query:\'\'});">PubMed</a> or ',
        '<a href="#" class="pp-textlink" onClick="Paperpile.main.tabs.newPluginTab(\'GoogleScholar\', {plugin_name: \'GoogleScholar\', plugin_query:\'\'});">Google Scholar</a></li>',
        '</ul>',
        '</div>',
    ],

    initComponent:function() {
        Paperpile.PluginGridDB.superclass.initComponent.call(this);
        this.limit = Paperpile.main.globalSettings['pager_limit'];

        var menu = new Ext.menu.Menu({
            defaults: {checked: false,
                       group: 'filter'+this.id,
                       checkHandler: this.toggleFilter,
                       scope:this,
                      },
            items: [ { text: 'All fields',
                       checked: true,
                       itemId: 'all_nopdf',
                     }, 
                     { text: 'All + Fulltext',
                       itemId: 'all_pdf',
                     }, 
                     '-', 
                     { text: 'Author', itemId: 'author'}, 
                     { text: 'Title',  itemId: 'title' },
                     { text: 'Journal', itemId: 'journal'},
                     { text: 'Abstract', itemId: 'abstract'},
                     { text: 'Fulltext', itemId: 'text'},
                     { text: 'Notes', itemId: 'notes'},
                     { text: 'Year', itemId: 'year'},
                   ]
        });

        this.filterField=new Ext.app.FilterField({store: this.store, 
                                                  base_query: this.plugin_base_query,
                                                  width: 200,
                                                 });
        var tbar=this.getTopToolbar();
        tbar.unshift({ xtype:'button',
                       itemId:'filter_button', 
                       text: 'Filter', 
                       tooltip: 'Choose field(s) to search',
                       menu: menu
                     }
                    );
        tbar.unshift(this.filterField);

        // If we are viewing a virtual folders we need an additional
        // button to remove an entry from a virtual folder
        this.store.baseParams['plugin_search_pdf']= 0 ;
        this.store.baseParams['limit']= this.limit ;
        this.store.on('load', 
                      function(){
                          if (this.store.getCount()==0){
                              var container= this.findParentByType(Paperpile.PubView);
                              if (container.itemId=='MAIN' && this.store.baseParams.plugin_query ==""){
                                  container.onEmpty(this.welcomeMsg);
                              }
                          }
                      }, this);
        this.store.load({params:{start:0, limit: this.limit}});

        this.store.on('load', function(){
            this.getSelectionModel().selectFirstRow();
        }, this, {
            single: true
        });

      this.on({render:{scope:this,fn:this.createSortHandles}});
      this.on({afterrender:{scope:this,fn:this.myOnRender}});

      this.actions['NEW'] = new Ext.Action({
	text: 'New Reference',
	iconCls: 'pp-icon-add',
        handler: this.newEntry,
        scope: this,
        itemId:'new_button',
        tooltip: 'Manually create a new reference for your library'
      });

    },

    myOnRender: function() {

      var tbar = this.getTopToolbar();
      var index = this.getButtonIndex(this.actions['SEARCH_TB_FILL'].itemId);
      tbar.insertButton(index+1,this.actions['NEW']);

    },

    createSortHandles: function() {
        var target=Ext.DomHelper.append(Ext.get(this.getView().getHeaderCell(1)).first(), 
                                        '<div id="pp-grid-sort-container_'+this.id+'" class="pp-grid-sort-container"></div>', true);

        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-desc"     action="created" status="desc">Date added</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="journal" status="inactive">Journal</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="year" status="inactive">Year</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="author" status="inactive">Author</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="pdf" status="inactive">PDF</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="attachments" status="inactive">Supp. material</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="notes" status="inactive">Notes</div>');

        target.on('click', this.handleSortButtons, this);
    },

    currentSortField:'',
    handleSortButtons: function(e, el, o){

        var currentClass=el.getAttribute('class');
        var field=el.getAttribute('action');
        var status=el.getAttribute('status');
      
        if (field != this.currentSortField) {
          //log(field);
          status = "inactive";
        }
        this.currentSortField = field;
      
        var classes={inactive: 'pp-grid-sort-item pp-grid-sort-inactive',
                     asc: 'pp-grid-sort-item pp-grid-sort-asc',
                     desc: 'pp-grid-sort-item pp-grid-sort-desc'};

        if (!(status == 'inactive' ||  status == 'asc'  ||   status == 'desc')) return;

        var El = Ext.get(el);

        Ext.each(El.parent().query('div'),
                 function(item){
                     var l=Ext.get(item);
                     l.removeClass('pp-grid-sort-item');
                     l.removeClass('pp-grid-sort-asc');
                     l.removeClass('pp-grid-sort-desc');
                     l.removeClass('pp-grid-sort-inactive');
                     if (item == el) return;
                     l.addClass(classes.inactive);
                 }
                );
        
         
        if (status == "inactive"){
            El.addClass(classes.desc);
            this.store.baseParams['plugin_order']=field+" DESC";
            el.setAttribute('status','desc');
        } else {
            if (status=="desc"){
                this.store.baseParams['plugin_order']=field;
                El.addClass(classes.asc);
                el.setAttribute('status','asc');
            } else {
                El.addClass(classes.desc);
                this.store.baseParams['plugin_order']=field+ " DESC";
                el.setAttribute('status','desc');
            }
        }

        if (this.filterField.getRawValue()==""){
            this.store.reload({params:{start:0, task:"NEW"}});
        } else {
            this.filterField.onTrigger2Click();
        }
    },


    toggleFilter: function(item, checked){


        var filter_button=this.getTopToolbar().items.get('filter_button');

        // Toggle 'search_pdf' option 
        if (item.itemId == 'all_pdf'){
            this.store.baseParams['plugin_search_pdf']= checked ? 1:0 ;
        }
        
        // Specific fields
        if (item.itemId != 'all_pdf' && item.itemId != 'all_nopdf'){
            if (checked){
                this.filterField.singleField=item.itemId;
                this.store.baseParams['plugin_search_pdf']= (item.itemId == 'text') ? 1:0;
            } else {
                if (this.filterField.singleField == item.itemId){
                    this.filterField.singleField="";
                }
            }
        }

        if (checked){
	  if (item.itemId == 'all_pdf' || item.itemId == 'all_nopdf') {
	    filter_button.setText('Filter');
	  } else {
            filter_button.setText(item.text);
	  }
            this.filterField.onTrigger2Click();
        }
      
    },

    shouldShowButton: function(menuItem) {
      var superShow = Paperpile.PluginGridDB.superclass.shouldShowButton.call(this,menuItem);

      if (menuItem.itemId == this.actions['DELETE'].itemId) {
	menuItem.setIconClass('pp-icon-trash');
      }

      return superShow;
    },


    shouldShowContextItem: function(menuItem,record) {
      var superShow = Paperpile.PluginGridDB.superclass.shouldShowContextItem.call(this,menuItem,record);
      
      if (menuItem.itemId == this.actions['SELECT_ALL'].itemId) {
	menuItem.setText('Select all ('+this.store.getTotalCount()+')');
      }

      if (menuItem.itemId == this.actions['DELETE'].itemId) {
	console.log(menuItem);
	menuItem.setIconClass('pp-icon-trash');
//	menuItem.ownerCt.doLayout();
	menuItem.setText('Move to Trash');
      }

      return superShow;
    }

});

Ext.reg('pp-plugin-grid-db', Paperpile.PluginGridDB);