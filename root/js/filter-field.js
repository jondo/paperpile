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
    width:180,
    hasSearch : false,
    paramName : 'source_query',

    onTrigger1Click : function(){
        if(this.hasSearch){
            this.el.dom.value = '';
            var o = {start: 0, source_task:'NEW'};
            this.store.baseParams = this.store.baseParams || {};
            this.store.baseParams[this.paramName] = '';
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
        var o = {start: 0, source_task:'NEW'};
        this.store.baseParams = this.store.baseParams || {};
        this.store.baseParams['source_query'] = v;
        this.store.reload({params:o});
        this.hasSearch = true;
        this.triggers[0].show();
    }

});