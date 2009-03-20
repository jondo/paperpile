/*
 * Ext JS Library 2.2
 * Copyright(c) 2006-2008, Ext JS, LLC.
 * licensing@extjs.com
 * 
 * http://extjs.com/license
 */

Ext.app.FilterField = Ext.extend(Ext.form.TwinTriggerField, {
    
    initComponent : function(){

        Ext.apply(this, {
            enableKeyEvents: true,
        });

        Ext.app.FilterField.superclass.initComponent.call(this);

        this.on('specialkey', function(f, e){
            if(e.getKey() == e.ENTER){
                this.onTrigger2Click();
            }
        }, this);

        this.on('keyup', function(f, e){
            this.onTrigger2Click();
        }, this);

    },

    validationEvent:false,
    validateOnBlur:false,
    trigger1Class:'x-form-clear-trigger',
    trigger2Class:'x-form-search-trigger',
    hideTrigger1:true,
    hideTrigger2:true,
    width:180,
    hasSearch : false,

    onTrigger1Click : function(){
        if(this.hasSearch){
            this.el.dom.value = '';
            var o = {start: 0, task:'NEW'};
            this.store.baseParams = this.store.baseParams || {};
            this.store.baseParams.plugin_query = this.build_query('');
            this.store.reload({params:o});
            this.triggers[0].hide();
            this.hasSearch = false;
        }
    },

    onTrigger2Click : function(){
        var v = this.getRawValue();
        if(v.length < 1){
            this.onTrigger1Click();
            return;
        }
        var o = {start: 0, task:'NEW'};
        this.store.baseParams = this.store.baseParams || {};
        
        this.store.baseParams['plugin_query'] = this.build_query(v);
        this.store.reload({params:o});
        this.hasSearch = true;
        this.triggers[0].show();
        

    },

    build_query: function(input){
        if (input == ''){
            if (this.base_query == ''){
                return('');
            } else {
                return(this.base_query);
            }
        } else {
            if (this.base_query == ''){
                return(input);
            } else {
                return(this.base_query+' AND '+input);
            }
        }
    }
}


);