Retriever = function(){
	this.xml = new CSL.System.Xml.E4X();
    this._cache = new Object();
};

Retriever.prototype.retrieveItem = function(id){
	return this._cache[id];
};

Retriever.prototype.retrieveItems = function(ids){
	var ret = [];
	for each (var id in ids){
		ret.push(this.retrieveItem(id));
	}
	return ret;
};

Retriever.prototype.getLang = function(lang){
	return locales[lang];
};

Retriever.prototype.loadData = function(data){
	for each (var entry in data){
		this._cache[entry.id] = entry;
	}
}

Retriever.prototype.makeXml = function(str){
	// this is where this should happen
	str = str.replace(/\s*<\?[^>]*\?>\s*\n/g, "");
	default xml namespace = "http://purl.org/net/xbiblio/csl"; with({});
	var ret = new XML(str);
	return ret;
};

Retriever.prototype.setLocaleXml = function(arg,lang){
	if ("undefined" == typeof this.locale_terms){
		this.locale_terms = new Object();
	}
	if ("undefined" == typeof arg){
		var myxml = new XML( this.getLang("en") );
		lang = "en";
	} else if ("string" == typeof arg){
		var myxml = new XML( this.getLang(arg) );
		lang = arg;
	} else if ("xml" != typeof arg){
		throw "Argument to setLocaleXml must nil, a lang string, or an XML object";
	} else if ("string" != typeof lang) {
		throw "Error in setLocaleXml: Must provide lang string with XML locale object";
	} else {
		var myxml = arg;
	}
	default xml namespace = "http://purl.org/net/xbiblio/csl"; with({});
	var xml = new Namespace("http://www.w3.org/XML/1998/namespace");
	var locale = new XML();
	for each (var blob in myxml..locale){
		if (blob.@xml::lang == lang){
			locale = blob;
			break;
		}
	}
	for each (var term in locale.term){
		var termname = term.@name.toString();
		default xml namespace = "http://purl.org/net/xbiblio/csl"; with({});
		if ("undefined" == typeof this.locale_terms[termname]){
			this.locale_terms[termname] = new Object();
		};
		var form = "long";
		if (term.@form.toString()){
			form = term.@form.toString();
		}
		if (term.multiple.length()){
			this.locale_terms[termname][form] = new Array();
			this.locale_terms[term.@name.toString()][form][0] = term.single.toString();
			this.locale_terms[term.@name.toString()][form][1] = term.multiple.toString();
		} else {
			this.locale_terms[term.@name.toString()][form] = term.toString();
		}
	}
};

var sys = new Retriever();
