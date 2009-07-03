Paperpile.PluginGridDB = Ext.extend(Paperpile.PluginGrid, {

    plugin_base_query:'',
    plugin_iconCls: 'pp-icon-folder',
    plugin_name:'DB',

    welcomeMsg:[
        '<div class="pp-box pp-box-side-panel pp-box-style1 pp-box-welcome"',
        '<h2>Welcome to Paperpile</h2>',
        '<p>Your library is still empty. <p>',
        '<p>To get started, <p>',
        '<ul>',
        '<li>import your <a href="#" class="pp-textlink" onClick="Paperpile.main.pdfExtract();">PDF collection</a></li>',
        '<li> get references from a <a href="#" class="pp-textlink" onClick="Paperpile.main.fileImport();">bibliography file</a></li>',
        '<li>start searching for papers using ',
        '<a href="#" class="pp-textlink" onClick="Paperpile.main.tabs.newPluginTab(\'PubMed\', {plugin_name: \'Pubmed\', plugin_query:\'\'});">PubMed</a> or ',
        '<a href="#" class="pp-textlink" onClick="Paperpile.main.tabs.newPluginTab(\'GoogleScholar\', {plugin_name: \'GoogleScholar\', plugin_query:\'\'});">Google Scholar</a></li>',
        '</ul>',
        '</div>',
    ],

    initComponent:function() {

        Paperpile.PluginGridDB.superclass.initComponent.apply(this, arguments);

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
                                                  width: 250,
                                                 });
        var tbar=this.getTopToolbar();
        tbar.unshift({ xtype:'button',
                       itemId:'filter_button', 
                       text: 'Filter', 
                       tooltip: 'Choose field(s) to search',
                       menu: menu, 
                     }
                    );
        tbar.unshift(this.filterField);

        this.actions['IMPORT'].hide();
        this.actions['IMPORT_ALL'].hide();

        // If we are viewing a virtual folders we need an additional
        // button to remove an entry from a virtual folder

        if (this.plugin_base_query.match('^folder:')){


            this.actions['DELETE_FROM_FOLDER']= new Ext.Action({
                text: 'Delete from folder',
                handler: this.deleteFromFolder,
                scope: this,
            });

            var menu = new Ext.menu.Menu({
                itemId: 'deleteMenu',
                items: [
                    this.actions['DELETE_FROM_FOLDER'],
                    this.actions['DELETE']
                ]
            });

            tbar[this.getButtonIndex('Delete')]= 
                { xtype:'button',
                  text: 'Delete',
                  itemId: 'delete_button',
                  cls: 'x-btn-text-icon delete',
                  menu: menu
                };

            this.actions['DELETE'].setText('Delete from library');
            this.actions['DELETE'].setIconClass('');
        }
        
        this.store.baseParams['plugin_search_pdf']= 0 ;

        this.store.on('load', 
                      function(){
                          if (this.store.getCount()==0){
                              var container= this.findParentByType(Paperpile.PubView);
                              if (container.itemId=='MAIN'){
                                  container.onEmpty(this.welcomeMsg);
                              }
                          }
                      }, this);

    },

    onRender: function() {
        Paperpile.PluginGridDB.superclass.onRender.apply(this, arguments);
        this.store.load({params:{start:0, limit:25 }});

        this.store.on('load', function(){
            this.getSelectionModel().selectFirstRow();
        }, this, {
            single: true
        });

        Paperpile.PluginGrid.superclass.afterRender.apply(this, arguments);

        var target=Ext.DomHelper.append(Ext.get(this.getView().getHeaderCell(1)).first(), 
                                        '<div class="pp-grid-sort-container">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</div>', true);

        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-desc"     action="journal" status="desc">Date added</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="journal" status="inactive">Journal</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="year" status="inactive">Year</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="author" status="inactive">Author</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="pdf" status="inactive">PDF</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="attachments" status="inactive">Supplementary material</div>');
        Ext.DomHelper.append(target,'<div class="pp-grid-sort-item pp-grid-sort-inactive" action="attachments" status="inactive">Notes</div>');

        target.on('click', this.handleSortButtons, this);

    },

    handleSortButtons: function(e, el, o){

        var currentClass=el.getAttribute('class');
        var field=el.getAttribute('action');
        var status=el.getAttribute('status');

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
            console.log(classes.desc);
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
            filter_button.setText(item.text);
            this.filterField.onTrigger2Click();
        }
      
    },

    //
    // Delete entry from virtual folder
    //

    deleteFromFolder: function(){
        
        //var rowid=this.getSelectionModel().getSelected().get('_rowid');
        //var sha1=this.getSelectionModel().getSelected().data.sha1;
        
        var selection=this.getSelection();

        var match=this.plugin_base_query.match('folder:(.*)$');

        Ext.Ajax.request({
            url: Paperpile.Url('/ajax/crud/delete_from_folder'),
            params: { selection: selection,
                      grid_id: this.id,
                      folder_id: match[1]
                    },
            method: 'GET',
            success: function(){
                Ext.getCmp('statusbar').clearStatus();
                Ext.getCmp('statusbar').setText('Entry deleted.');
            },
            failure: Paperpile.main.onError,
        });

        for (var i=0;i<selection.length;i++){
            this.store.remove(this.store.getAt(this.store.find('sha1',selection[i])));
        }

    },




});
