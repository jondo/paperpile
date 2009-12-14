Paperpile.MetaPanel = Ext.extend(Ext.form.FormPanel, {

    initComponent: function() {
		Ext.apply(this, {
            // The form is a table that consists of several tbody
            // elements to group specific blocks; the first tbody is
            // the selection list for the publication type
            html: {tag: 'table', 
                   cls:'pp-meta-form',
                   id:"form-table",
                   children: [
                       { tag: 'tbody',
                         children: [
                             { tag:'tr',
                               children: [
                                   {tag: 'td',
                                    cls: 'label',
                                    html: 'Type'},
                                   {tag: 'td',
                                    id: 'type-combo',
                                    cls: 'field',
                                    colspan: 5},
                               ]
                             }
                         ]
                       }
                   ]},
            autoScroll: true,
            border:false,
            bodyBorder:false,
			bodyStyle: {
				background: '#ffffff',
				padding: '7px'
			},
		});
		
        Paperpile.MetaPanel.superclass.initComponent.call(this);
        
        this.on('afterrender',
                function(){
                    this.initForm(this.data.get('pubtype'));
                } 
               );
	},

    initForm: function(pubType){

        var pubTypes=Paperpile.main.globalSettings.pub_types;

        //var list=['ARTICLE','BOOK','INCOLLECTION','INBOOK',
        //          'PROCEEDINGS', 'INPROCEEDINGS', 
        //          'MASTERSTHESIS', 'PHDTHESIS',
        //          'MANUAL', 'UNPUBLISHED','MISC'];

        var list=['ARTICLE','INCOLLECTION'];
        
        var t=[];
        for (var i=0;i<list.length;i++){
            t.push([list[i],pubTypes[list[i]].name]);
        }

        var cb = new Ext.form.ComboBox({
            renderTo:'type-combo',
            editable:false,
            displayField:'displayText',
            valueField:'name',
            forceSelection:true,
            triggerAction: 'all',
            disableKeyFilter: true,
            mode: 'local',
            hiddenName: 'pubtype',
            value: pubType,
            renderTo:'type-combo',
            store: new Ext.data.ArrayStore({
                idIndex: 0,
                fields: ['name','displayText'],
                data: t
            }),
            listeners: {
                select: {
                    fn: function(combo,record,index){
                        this.renderForm(record.get('name'));
                    },
                    scope:this,
                }
            },
        });

      
        this.renderForm(pubType);

        Ext.get('form-table').on('click', this.onClick, this);



    },
    
    renderForm: function(pubType){
        
        this.activeIdentifiers=[];
        var identifiers= Paperpile.main.globalSettings.pub_identifiers;
        for (var i=0; i<identifiers.length;i++){
            if (this.data.get(identifiers[i])){
                this.activeIdentifiers.push(identifiers[i]);
            }
        }
        
        var tbodies=[];
   
        // Collect table contents
        tbodies.push(this.renderMainFields(pubType));
        tbodies.push(this.renderIdentifiers());
        
        // Remove all tbodies except the first one
        var counter=0;
        Ext.get('form-table').select('tbody').each(
            function(el){
                if (counter==0){
                    counter=1;
                    return;
                }
                el.remove();
            }
        );
        
        // Write new tbodies
        Ext.DomHelper.append('form-table', tbodies);

        this.createInputs();

        
    },

    createInputs: function(){

        for (var field in Paperpile.main.globalSettings.pub_fields){

            elField = Ext.get(field+'-field');
            elInput = Ext.get(field+'-input');

            if (!elField || elInput) {
                continue;
            }

            var w = elField.getWidth()-30;

            var hidden = false;

            if (field === 'abstract'){
                Ext.DomHelper.append(field+'-field',
                                     {tag: 'a',
                                      href:"#",
                                      cls: 'pp-textlink',
                                      id: 'abstract-toggle',
                                      html: 'Show'}
                                    );
                hidden = true;
            }

            var tf = new Ext.form.TextField(
                {   id: field+'-input',
                    width: w,
                    value: this.data.get(field),
                    hidden:hidden
                }
            );

            tf.on('focus', this.onFocus, this );
   
            tf.render(field+'-field', 0);

            Ext.DomHelper.append(field+'-field', 
                                 {tag:'div', 
                                  cls: 'tooltip-link', 
                                  children: [
                                      { tag: 'a',
                                        id: field+'-tooltip',
                                        href:"#",
                                        html: '?',
                                        hidden:hidden
                                      }
                                  ]
                                 });
            
            new Ext.ToolTip({
                target: field+'-tooltip',
                width:200,
                html: 'This tip will follow the mouse while it is over the element',
                anchor: 'left',
            });
        }
    },



    renderMainFields: function(pubType){

        var pubFields= Paperpile.main.globalSettings.pub_types[pubType].fields;
        var fieldNames= Paperpile.main.globalSettings.pub_fields;
        var trs=[];     // Collects the rows to add for each tbody

        var tbodies=[];

        // Loop over the rows in the yaml configuration
        for (var i=0; i<pubFields.length; i++){
            var row = pubFields[i];

            // Section boundaries are marked by a dash "-" in the yaml configuration
            if (row[0]==='-'){

                // We add an empty line as separator. Tbody elements
                // can't be styled as normal block element so we need this hack
                trs.push({
                    tag:'tr',
                    children: [
                        { tag: 'td',
                          colspan: '6',
                          cls: 'separator',
                        }
                    ]
                });
                
                // Push all collected rows to the list of tbodies
                tbodies.push({tag:'tbody',
                              children:trs})
                trs=[];

                continue;
            }
            
            
            var tr = {tag: 'tr',children:[]};

            // Loop over columns in the yaml configuration
            for (var j=0; j<row.length; j++){
                var t= row[j].split(":");
                var field = t[0];
                var colSpan = t[1];

                if (field == ""){
                    tr.children.push('<td>&nbsp;</td><td>&nbsp;</td>');
                } else {
                    tr.children.push({tag:'td',
                                      id: field+'-label',
                                      cls: 'label',
                                      html: fieldNames[field]},
                                     {tag:'td', 
                                      id: field+'-field',
                                      cls: 'field',
                                      colspan:colSpan - 1,
                                     }
                                    );
                }
            }

            trs.push(tr);
        }

        return(tbodies);

    },


    renderIdentifiers: function(){

        var fieldNames= Paperpile.main.globalSettings.pub_fields;
        var identifiers= Paperpile.main.globalSettings.pub_identifiers;
        
        var trs=[];

        for (var i=0; i<this.activeIdentifiers.length;i++){

            var field = this.activeIdentifiers[i];
            
            trs.push(
                {tag: 'tr',children:[
                    {tag:'td',
                     id: field+'-label',
                     cls: 'label',
                     html: fieldNames[field]},
                    {tag:'td', 
                     id: field+'-field',
                     cls: 'field',
                     colspan:3,
                    },
                    {tag:'td', 
                     colspan:2,
                    }
                ]});
        }
        
        var lis=[];

        for (var i=0; i<identifiers.length; i++){

            var active = 0;
            for (j=0; j<this.activeIdentifiers.length; j++){
                if (this.activeIdentifiers[j] === identifiers[i]){
                    active=1;
                    break;
                }
            }

            if (active) {
                continue;
            }

            lis.push({tag:'li',
                      children:[
                          { tag: 'a',
                            cls:'pp-textlink',
                            href:"#",
                            id: identifiers[i]+'-add-id',
                            html: fieldNames[identifiers[i]]
                          }
                      ]
                     }
                    );
        }

        if (lis.length > 0){
            trs.push({tag: 'tr',
                      children: [
                          { tag:'td',
                            cls:'label',
                            html: '&nbsp;'
                          },
                          {tag:'td', 
                           colspan:5,
                           children:[
                               { tag:'div',
                                 cls: 'pp-menu pp-menu-horizontal',
                                 children:[
                                     { tag: 'a',
                                       href:'#',
                                       html:'Add identifier',
                                     },
                                     { tag:'ul',
                                       children:lis,
                                     }
                                 ]
                               }
                           ]
                          }
                      ]
                     }
                    );
        }
        
        return({tag:'tbody',
                id: 'identifier-group',
                children: trs});
    },

    onFocus: function(field){
        Ext.select('table#form-table td').removeClass("active");
        field.el.parent().addClass("active");
        field.el.parent().prev().addClass("active");
    },


    onClick: function(e){

        var el = Ext.get(e.target);

        console.log(e.target);

        var m = el.id.match(/(.*)-add-id/);

        if (m){
            var field = m[1];
            Ext.get('identifier-group').remove();
            this.activeIdentifiers.push(field);
            Ext.DomHelper.append('form-table', this.renderIdentifiers());
            this.createInputs();
            Ext.get(field+'-input').focus();
            return;
        }

        m = el.id.match(/(.*)-toggle/);

        if (m){
            var field = m[1];
            Ext.getCmp(field+'-input').show();
        }

    }




});

