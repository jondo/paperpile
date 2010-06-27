Ext.lib.Ajax.isCrossDomain = function(u) {
	var match = /(?:(\w*:)\/\/)?([\w\.]*(?::\d*)?)/.exec(u);
	if (!match[1]) return false; // No protocol, not cross-domain
	return (match[1] != location.protocol) || (match[2] != location.host);
};

Ext.override(Ext.data.Connection, {

    request : function(o){
        if(this.fireEvent("beforerequest", this, o) !== false){
            var p = o.params;

            if(typeof p == "function"){
                p = p.call(o.scope||window, o);
            }
            if(typeof p == "object"){
                p = Ext.urlEncode(p);
            }
            if(this.extraParams){
                var extras = Ext.urlEncode(this.extraParams);
                p = p ? (p + '&' + extras) : extras;
            }

            var url = o.url || this.url;
            if(typeof url == 'function'){
                url = url.call(o.scope||window, o);
            }

            if(o.form){
                var form = Ext.getDom(o.form);
                url = url || form.action;

                var enctype = form.getAttribute("enctype");
                if(o.isUpload || (enctype && enctype.toLowerCase() == 'multipart/form-data')){
                    return this.doFormUpload(o, p, url);
                }
                var f = Ext.lib.Ajax.serializeForm(form);
                p = p ? (p + '&' + f) : f;
            }

            var hs = o.headers;
            if(this.defaultHeaders){
                hs = Ext.apply(hs || {}, this.defaultHeaders);
                if(!o.headers){
                    o.headers = hs;
                }
            }

            var cb = {
                success: this.handleResponse,
                failure: this.handleFailure,
                scope: this,
                argument: {options: o},
                timeout : this.timeout
            };

            var method = o.method||this.method||(p ? "POST" : "GET");

            if(method == 'GET' && (this.disableCaching && o.disableCaching !== false) || o.disableCaching === true){
                url += (url.indexOf('?') != -1 ? '&' : '?') + '_dc=' + (new Date().getTime());
            }

            if(typeof o.autoAbort == 'boolean'){ // options gets top priority
                if(o.autoAbort){
                    this.abort();
                }
            }else if(this.autoAbort !== false){
                this.abort();
            }
            if((method == 'GET' && p) || o.xmlData || o.jsonData){
                url += (url.indexOf('?') != -1 ? '&' : '?') + p;
                p = '';
            }
            if (o.scriptTag || this.scriptTag || Ext.lib.Ajax.isCrossDomain(url)) {
               this.transId = this.scriptRequest(method, url, cb, p, o);
            } else {
               this.transId = Ext.lib.Ajax.request(method, url, cb, p, o);
            }
            return this.transId;
        }else{
            Ext.callback(o.callback, o.scope, [o, null, null]);
            return null;
        }
    },
    
    scriptRequest : function(method, url, cb, data, options) {
        var transId = ++Ext.data.ScriptTagProxy.TRANS_ID;
        var trans = {
            id : transId,
            cb : options.callbackName || "stcCallback"+transId,
            scriptId : "stcScript"+transId,
            options : options
        };

        url += (url.indexOf("?") != -1 ? "&" : "?") + data + String.format("&{0}={1}", options.callbackParam || this.callbackParam || 'callback', trans.cb);

        var conn = this;
        window[trans.cb] = function(o){
            conn.handleScriptResponse(o, trans);
        };

//      Set up the timeout handler
        trans.timeoutId = this.handleScriptFailure.defer(cb.timeout, this, [trans]);

        var script = document.createElement("script");
        script.setAttribute("src", url);
        script.setAttribute("type", "text/javascript");
        script.setAttribute("id", trans.scriptId);
        document.getElementsByTagName("head")[0].appendChild(script);

        return trans;
    },

    handleScriptResponse : function(o, trans){
        this.transId = false;
        this.destroyScriptTrans(trans, true);
        var options = trans.options;
        
//      Attempt to parse a string parameter as XML.
        var doc;
        if (typeof o == 'string') {
            if (window.ActiveXObject) {
                doc = new ActiveXObject("Microsoft.XMLDOM");
                doc.async = "false";
                doc.loadXML(o);
            } else {
                doc = new DOMParser().parseFromString(o,"text/xml");
            }
        }

//      Create the bogus XHR
        response = {
            responseObject: o,
            responseText: (typeof o == "object") ? Ext.util.JSON.encode(o) : String(o),
            responseXML: doc,
            argument: options.argument
        }
        this.fireEvent("requestcomplete", this, response, options);
        Ext.callback(options.success, options.scope, [response, options]);
        Ext.callback(options.callback, options.scope, [options, true, response]);
    },
    
    handleScriptFailure: function(trans) {
        this.transId = false;
        this.destroyScriptTrans(trans, false);
        var options = trans.options;
        response = {
            argument:  options.argument,
            status: 500,
            statusText: 'Server failed to respond',
            responseText: ''
        };
        this.fireEvent("requestexception", this, response, options, {
            status: -1,
            statusText: 'communication failure'
        });
        Ext.callback(options.failure, options.scope, [response, options]);
        Ext.callback(options.callback, options.scope, [options, false, response]);
    },
    
    // private
    destroyScriptTrans : function(trans, isLoaded){
        document.getElementsByTagName("head")[0].removeChild(document.getElementById(trans.scriptId));
        clearTimeout(trans.timeoutId);
        if(isLoaded){
            window[trans.cb] = undefined;
            try{
                delete window[trans.cb];
            }catch(e){}
        }else{
            // if hasn't been loaded, wait for load to remove it to prevent script error
            window[trans.cb] = function(){
                window[trans.cb] = undefined;
                try{
                    delete window[trans.cb];
                }catch(e){}
            };
        }
    }
});
