CSL = new function () {
	this.START = 0;
	this.END = 1;
	this.SINGLETON = 2;
	this.SEEN = 6;
	this.SUCCESSOR = 3;
	this.SUCCESSOR_OF_SUCCESSOR = 4;
	this.SUPPRESS = 5;
	this.SINGULAR = 0;
	this.PLURAL = 1;
	this.LITERAL = true;
	this.BEFORE = 1;
	this.AFTER = 2;
	this.DESCENDING = 1;
	this.ASCENDING = 2;
	this.FINISH = 1;
	this.POSITION_FIRST = 0;
	this.POSITION_SUBSEQUENT = 1;
	this.POSITION_IBID = 2;
	this.POSITION_IBID_WITH_LOCATOR = 3;
	this.COLLAPSE_VALUES = ["citation-number","year","year-suffix"];
	this.ET_AL_NAMES = ["et-al-min","et-al-use-first"];
	this.ET_AL_NAMES = this.ET_AL_NAMES.concat( ["et-al-subsequent-min","et-al-subsequent-use-first"] );
	this.DISAMBIGUATE_OPTIONS = ["disambiguate-add-names","disambiguate-add-givenname"];
	this.DISAMBIGUATE_OPTIONS.push("disambiguate-add-year-suffix");
	this.PREFIX_PUNCTUATION = /.*[.;:]\s*$/;
	this.SUFFIX_PUNCTUATION = /^\s*[.;:,\(\)].*/;
	this.NUMBER_REGEXP = /(?:^\d+|\d+$|\d{3,})/; // avoid evaluating "F.2d" as numeric
	this.QUOTED_REGEXP = /^".+"$/;
	this.NAME_INITIAL_REGEXP = /^([A-Z\u0400-\u042f])([A-Z\u0400-\u042f])*.*$/;
	var x = new Array();
	x = x.concat(["edition","volume","number-of-volumes","number"]);
	x = x.concat(["issue","title","container-title","issued","page"]);
	x = x.concat(["locator","collection-number","original-date"]);
	x = x.concat(["reporting-date","decision-date","filing-date"]);
	x = x.concat(["revision-date"]);
	this.NUMERIC_VARIABLES = x.slice();
	this.DATE_VARIABLES = ["issued","event","accessed","container","original-date"];
	var x = new Array();
	x = x.concat(["@text-case","@font-family","@font-style","@font-variant"]);
	x = x.concat(["@font-weight","@text-decoration","@vertical-align"]);
	x = x.concat(["@display","@quotes"]);
	this.FORMAT_KEY_SEQUENCE = x.slice();
	this.SUFFIX_CHARS = "a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z";
	this.ROMAN_NUMERALS = [
		[ "", "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix" ],
		[ "", "x", "xx", "xxx", "xl", "l", "lx", "lxx", "lxxx", "xc" ],
		[ "", "c", "cc", "ccc", "cd", "d", "dc", "dcc", "dccc", "cm" ],
		[ "", "m", "mm", "mmm", "mmmm", "mmmmm"]
	];
	this.CREATORS = ["author","editor","translator","recipient","interviewer"];
	this.CREATORS = this.CREATORS.concat(["composer"]);
	this.CREATORS = this.CREATORS.concat(["original-author"]);
	this.CREATORS = this.CREATORS.concat(["container-author","collection-editor"]);
};
CSL.Engine = function(sys,style,lang) {
	this.sys = sys;
	if ("string" != typeof style){
		style = "";
	}
	this.opt = new CSL.Engine.Opt();
	this.tmp = new CSL.Engine.Tmp();
	this.build = new CSL.Engine.Build();
	this.fun = new CSL.Engine.Fun();
	this.configure = new CSL.Engine.Configure();
	this.citation = new CSL.Engine.Citation();
	this.citation_sort = new CSL.Engine.CitationSort();
	this.bibliography = new CSL.Engine.Bibliography();
	this.bibliography_sort = new CSL.Engine.BibliographySort();
	this.output = new CSL.Output.Queue(this);
	this.cslXml = this.sys.makeXml(style);
	this.sys.setLocaleXml();
	if (lang){
		this.sys.setLocaleXml(lang);
	} else {
		lang = "en";
	}
	this.sys.setLocaleXml( this.cslXml, lang );
	this.locale_terms = this.sys.locale_terms;
	this._buildTokenLists("citation");
	this._buildTokenLists("bibliography");
	this.configureTokenLists(this.citation.tokens);
	this.registry = new CSL.Factory.Registry(this);
	this.splice_delimiter = false;
	this.setOutputFormat("html");
};
CSL.Engine.prototype._buildTokenLists = function(area){
	default xml namespace = "http://purl.org/net/xbiblio/csl"; with({});
	var area_nodes = this.cslXml[area];
	if (!area_nodes.toString()){
		//print("NO AREA NODES");
		return;
	};
	var navi = new this._getNavi( this, area_nodes );
	this.build.area = area;
	this._build(navi);
};
CSL.Engine.prototype._build  = function(navi){
	if (navi.getkids()){
		this._build(navi);
	} else {
		if (navi.getbro()){
			this._build(navi);
		} else {
			while (navi.nodeList.length > 1) {
				if (navi.remember()){
					this._build(navi);
				}
			}
		}
	}
};
CSL.Engine.prototype._getNavi = function(state,myxml){
	this.sys = state.sys;
	this.state = state;
	this.nodeList = new Array();
	this.nodeList.push([0, myxml]);
	this.depth = 0;
};
CSL.Engine.prototype._getNavi.prototype.remember = function(){
	this.depth += -1;
	this.nodeList.pop();
	var node = this.nodeList[this.depth][1][(this.nodeList[this.depth][0])];
	CSL.Factory.XmlToToken.call(node,this.state,CSL.END);
	return this.getbro();
};
CSL.Engine.prototype._getNavi.prototype.getbro = function(){
	var sneakpeek = this.nodeList[this.depth][1][(this.nodeList[this.depth][0]+1)];
	if (sneakpeek){
		this.nodeList[this.depth][0] += 1;
		return true;
	} else {
		return false;
	}
};
CSL.Engine.prototype._getNavi.prototype.getkids = function(){
	var currnode = this.nodeList[this.depth][1][this.nodeList[this.depth][0]];
	var sneakpeek = this.sys.xml.children(currnode);
	if (this.sys.xml.numberofnodes(sneakpeek) == 0){
		// singleton, process immediately
		CSL.Factory.XmlToToken.call(currnode,this.state,CSL.SINGLETON);
		return false;
	} else {
		// if first node of a span, process it, then descend
		CSL.Factory.XmlToToken.call(currnode,this.state,CSL.START);
		this.depth += 1;
		this.nodeList.push([0,sneakpeek]);
		return true;
	}
};
CSL.Engine.prototype._getNavi.prototype.getNodeListValue = function(){
	return this.nodeList[this.depth][1];
};
CSL.Engine.prototype.setOutputFormat = function(mode){
	this.opt.mode = mode;
	this.fun.decorate = CSL.Factory.Mode(mode);
}
CSL.Engine.prototype.getTerm = function(term,form,plural){
	var ret = "";
	if (!this.locale_terms[term]){
		throw "Error in getTerm: term\""+term+"\" does not exist."
	}
	if (!form){
		throw "Error in getTerm: must provide a non-nil value as \"form\" argument";
	}
	var forms = [];
	if (form == "symbol"){
		forms = ["symbol","short"];
	} else if (form == "verb-short"){
		forms = ["verb-short","verb"];
	} else if (form != "long"){
		forms = [form];
	}
	forms = forms.concat(["long"]);
	for each (var f in forms){
		if (this.locale_terms[term][f]){
			if ("string" == typeof this.locale_terms[term][f]){
				ret = this.locale_terms[term][f];
			} else {
				if ("number" == typeof plural){
					ret = this.locale_terms[term][f][plural];
				} else {
					ret = this.locale_terms[term][f][0];
				}
			}
			break;
		}
	}
	return ret;
}
CSL.Engine.prototype.configureTokenLists = function(){
	for each (var area in ["citation","citation_sort","bibliography","bibliography_sort"]){
		for (var pos=(this[area].tokens.length-1); pos>-1; pos--){
			var token = this[area].tokens[pos];
			token["next"] = (pos+1);
			//print("setting: "+(pos+1)+" ("+token.name+")");
			if (token.name && CSL.Lib.Elements[token.name].configure){
				CSL.Lib.Elements[token.name].configure.call(token,this,pos);
			}
		}
	}
	this.version = CSL.Factory.version;
	return this.state;
};
CSL.Core = {};
CSL.Engine.Opt = function (){
	this.has_disambiguate = false;
	this.mode = "html";
};
CSL.Engine.Tmp = function (){
	this.names_max = new CSL.Factory.Stack();
	this.names_base = new CSL.Factory.Stack();
	this.givens_base = new CSL.Factory.Stack();
	this.value = new Array();
	this.namepart_decorations = new Object();
	this.namepart_type = false;
	this.area = "citation";
	this.can_substitute = new CSL.Factory.Stack( false, CSL.LITERAL);
	this.element_rendered_ok = false;
	this.nameset_counter = 0;
	this.term_sibling = new CSL.Factory.Stack( undefined, CSL.LITERAL);
	this.term_predecessor = false;
	this.jump = new CSL.Factory.Stack(0,CSL.LITERAL);
	this.decorations = new CSL.Factory.Stack();
	this.tokenstore_stack = new CSL.Factory.Stack();
	this.last_suffix_used = "";
	this.last_names_used = new Array();
	this.last_years_used = new Array();
	this.years_used = new Array();
	this.names_used = new Array();
	this.initialize_with = new CSL.Factory.Stack();
	this.disambig_request = false;
	this["name-as-sort-order"] = false;
	this.suppress_decorations = false;
	this.disambig_settings = new CSL.Factory.AmbigConfig();
	this.bib_sort_keys = new Array();
	this.prefix = new CSL.Factory.Stack("",CSL.LITERAL);
	this.suffix = new CSL.Factory.Stack("",CSL.LITERAL);
	this.delimiter = new CSL.Factory.Stack("",CSL.LITERAL);
};
CSL.Engine.Fun = function (){
	this.suffixator = new CSL.Util.Suffixator(CSL.SUFFIX_CHARS);
	this.romanizer = new CSL.Util.Romanizer();
	this.flipflopper = new CSL.Util.FlipFlopper();
};
CSL.Engine.Build = function (){
	this["alternate-term"] = false;
	this.in_bibliography = false;
	this.in_style = false;
	this.skip = false;
	this.postponed_macro = false;
	this.layout_flag = false;
	this.name = false;
	this.form = false;
	this.term = false;
	this.macro = new Object();
	this.macro_stack = new Array();
	this.text = false;
	this.lang = false;
	this.area = "citation";
	this.substitute_level = new CSL.Factory.Stack( 0, CSL.LITERAL);
	this.render_nesting_level = 0;
	this.render_seen = false;
};
CSL.Engine.Configure = function (){
	this.fail = new Array();
	this.succeed = new Array();
};
CSL.Engine.Citation = function (){
	this.opt = new Object();
	this.tokens = new Array();
	this.opt["et-al-min"] = 0;
	this.opt["et-al-use-first"] = 1;
	this.opt["et-al-subsequent-min"] = false;
	this.opt["et-al-subsequent-use-first"] = false;
	this.opt.collapse = new Array();
	this.opt["disambiguate-add-names"] = false;
	this.opt["disambiguate-add-givenname"] = false;
};
CSL.Engine.Bibliography = function (){
	this.opt = new Object();
	this.tokens = new Array();
	this.opt["csl-bib-body"] = new Array();
	this.opt["csl-bib-entry"] = new Array();
	this.opt["csl-bib-first"] = new Array();
	this.opt["csl-bib-other"] = new Array();
	this.opt["et-al-min"] = 0;
	this.opt["et-al-use-first"] = 1;
	this.opt["et-al-subsequent-min"] = 0;
	this.opt["et-al-subsequent-use-first"] = 1;
	this.opt.collapse = new Array();
	this.opt["disambiguate-add-names"] = false;
	this.opt["disambiguate-add-givenname"] = false;
};
CSL.Engine.BibliographySort = function (){
	this.tokens = new Array();
	this.opt = new Object();
	this.opt.sort_directions = new Array();
	this.keys = new Array();
};
CSL.Engine.CitationSort = function (){
	this.tokens = new Array();
	this.opt = new Object();
	this.opt.sort_directions = new Array();
	this.keys = new Array();
};
CSL.makeStyle = function(sys,xml,lang){
	var engine = new CSL.Engine(sys,xml,lang);
	return engine;
}
CSL.Engine.prototype.registerFlipFlops = function(flist){
	for each (ff in flist){
		this.fun.flipflopper.register(ff["start"], ff["end"], ff["func"], ff["alt"]);
	}
	return true;
}
CSL.Engine.prototype.makeCitationCluster = function(rawList){
	var inputList = [];
	for each (var item in rawList){
		var Item = this.sys.retrieveItem(item[0]);
		this.registry.insert(this,Item);
		var newitem = this.composeItem([Item,item[1]]);
		inputList.push(newitem);
	}
	if (inputList && inputList.length > 1 && this["citation_sort"].tokens.length > 0){
		var newlist = new Array();
		var keys_list = new Array();
		for each (var Item in inputList){
			var keys = this.getSortKeys(Item,"citation_sort");
			keys["cheaters_hack"] = Item;
			keys_list.push(keys);
		}
		var srt = new CSL.Factory.Registry.Comparifier(this,"citation_sort");
		keys_list.sort(srt.compareKeys);
		for each (key in keys_list){
			newlist.push(key.cheaters_hack);
		}
		//
		// XXXXX this is all one-time, one-way, slice probably isn't needed here?
		inputList = newlist;
	}
	this.tmp.last_suffix_used = "";
	this.tmp.last_names_used = new Array();
	this.tmp.last_years_used = new Array();
	var str = this._unit_of_reference.call(this,inputList);
	return str;
};
CSL.Engine.prototype.makeBibliography = function(){
	var debug = false;
	if (debug){
		for each (tok in this.bibliography.tokens){
			print("bibtok: "+tok.name);
		}
		print("---");
		for each (tok in this.citation.tokens){
			print("cittok: "+tok.name);
		}
		print("---");
		for each (tok in this.bibliography_sort.tokens){
			print("bibsorttok: "+tok.name);
		}
	}
	return this._bibliography_entries.call(this);
};
CSL.Engine.prototype.insertItems = function(inputList){
	for each (var item in inputList){
		var Item = this.sys.retrieveItem(item);
		this.registry.insert(this,Item);
	};
};
CSL.Engine.prototype.getAmbiguousCite = function(Item,disambig){
	if (disambig){
		this.tmp.disambig_request = disambig;
	} else {
		this.tmp.disambig_request = false;
	}
	this.tmp.area = "citation";
	this.tmp.suppress_decorations = true;
	this.tmp.force_subsequent = true;
	this._cite.call(this,Item);
	this.tmp.force_subsequent = false;
	var ret = this.output.string(this,this.output.queue);
	this.tmp.suppress_decorations = false;
	if (false){
		print("ok");
	}
	return ret;
}
CSL.Engine.prototype.composeItem = function(item){
	var newItem = {};
	for (var i in item[0]){
		newItem[i] = item[0][i];
	}
	for (var i in item[1]){
		newItem[i] = item[1][i];
	}
	return newItem;
};
CSL.Engine.prototype.getSortKeys = function(Item,key_type){
	if (false){
		print("KEY TYPE: "+key_type);
	}
	var area = this.tmp.area;
	var strip_prepositions = CSL.Util.Sort.strip_prepositions;
	this.tmp.area = key_type;
	this.tmp.disambig_override = true;
	this.tmp.disambig_request = false;
	this.tmp.suppress_decorations = true;
	this._cite.call(this,Item);
	this.tmp.suppress_decorations = false;
	this.tmp.disambig_override = false;
	for (var i in this[key_type].keys){
		this[key_type].keys[i] = strip_prepositions(this[key_type].keys[i]);
	}
	if (false){
		print("sort keys ("+key_type+"): "+this[key_type].keys);
	}
	this.tmp.area = area;
	return this[key_type].keys;
};
CSL.Engine.prototype.getAmbigConfig = function(){
	var config = this.tmp.disambig_request;
	if (!config){
		config = this.tmp.disambig_settings;
	}
	var ret = CSL.Factory.cloneAmbigConfig(config);
	return ret;
};
CSL.Engine.prototype.getMaxVals = function(){
	return this.tmp.names_max.mystack.slice();
};
CSL.Engine.prototype.getMinVal = function(){
	return this.tmp["et-al-min"];
};
//
// XXXXX: The handling of delimiters needs cleanup.
// Is the tmp.delimiter stack used for *anything*?
//
CSL.Engine.prototype.getSpliceDelimiter = function(last_collapsed){
	if (last_collapsed && ! this.tmp.have_collapsed && this["citation"].opt["after-collapse-delimiter"]){
		this.tmp.splice_delimiter = this["citation"].opt["after-collapse-delimiter"];
	}
	return this.tmp.splice_delimiter;
};
CSL.Engine.prototype.getModes = function(){
	var ret = new Array();
	if (this[this.tmp.area].opt["disambiguate-add-names"]){
		ret.push("names");
	}
	if (this[this.tmp.area].opt["disambiguate-add-givenname"]){
		ret.push("givens");
	}
	return ret;
};
CSL.Engine.prototype._bibliography_entries = function (){
	this.tmp.area = "bibliography";
	var input = this.sys.retrieveItems(this.registry.getSortedIds());
	this.tmp.disambig_override = true;
	this.output.addToken("bibliography_joiner","\n");
	this.output.openLevel("bibliography_joiner");
	var bib_wrapper = new CSL.Factory.Token("group",CSL.START);
	bib_wrapper.decorations = [["@bibliography","wrapper"]];
	this.output.startTag("bib_wrapper",bib_wrapper);
	for each (item in input){
		if (false){
			print("BIB: "+item.id);
		}
		var bib_entry = new CSL.Factory.Token("group",CSL.START);
		bib_entry.decorations = [["@bibliography","entry"]];
		this.output.startTag("bib_entry",bib_entry);
		this._cite.call(this,item);
		this.output.endTag(); // closes bib_entry
	}
	this.output.endTag(); // closes bib_wrapper
	this.output.closeLevel();
	this.tmp.disambig_override = false;
	return this.output.string(this,this.output.queue);
};
CSL.Engine.prototype._unit_of_reference = function (inputList){
	this.tmp.area = "citation";
	var delimiter = "";
	var result = "";
	var objects = [];
	for each (var Item in inputList){
		var last_collapsed = this.tmp.have_collapsed;
		this._cite(Item);
		//
		// This will produce a stack with one
		// layer, and exactly one or two items.
		// We merge these as we go along, to get
		// the joins right for the pairs.
		//delimiter = this.getSpliceDelimiter(last_collapsed);
		//this.tmp.delimiter.replace(delimiter);
		this.getSpliceDelimiter(last_collapsed);
		//this.tmp.delimiter.replace(delimiter);
		this.tmp.handle_ranges = true;
		var composite = this.output.string(this,this.output.queue);
		this.tmp.handle_ranges = false;
		if (objects.length && "string" == typeof composite[0]){
			composite.reverse();
			objects.push(this.tmp.splice_delimiter + composite.pop());
		} else {
		composite.reverse();
			objects.push(composite.pop());
		}
		composite.reverse();
		for each (var obj in composite){
			if ("string" == typeof obj){
				objects.push(this.tmp.splice_delimiter + obj);
				continue;
			}
			objects.push(composite.pop());
		}
	}
	result += this.output.renderBlobs(objects);
	result = this.citation.opt.layout_prefix + result + this.citation.opt.layout_suffix;
	if (!this.tmp.suppress_decorations){
		for each (var params in this.citation.opt.layout_decorations){
			result = this.fun.decorate[params[0]][params[1]](this,result);
		}
	}
	return result;
};
CSL.Engine.prototype._cite = function(Item){
	this.start(Item);
	var next = 0;
	while(next < this[this.tmp.area].tokens.length){
		next = this._render(this[this.tmp.area].tokens[next],Item);
    }
	this.end();
};
CSL.Engine.prototype._render = function(token,Item){
    var next = token.next;
	var maybenext = false;
	if (false){
		print("---> Token: "+token.name+" ("+token.tokentype+") in "+this.tmp.area+", "+this.output.current.mystack.length);
		//print("       next is: "+next+", success is: "+token.succeed+", fail is: "+token.fail);
	}
	if (token.evaluator){
	    next = token.evaluator.call(token,this,Item);
    };
	for each (var exec in token.execs){
	    maybenext = exec.call(token,this,Item);
		if (maybenext){
			next = maybenext;
		};
	};
	if (false){
		print(token.name+" ("+token.tokentype+") ---> done");
	}
	return next;
};
CSL.Engine.prototype.start = function(Item){
	this.tmp.have_collapsed = true;
	this.tmp.render_seen = false;
	if (this.tmp.disambig_request  && ! this.tmp.disambig_override){
		this.tmp.disambig_settings = this.tmp.disambig_request;
	} else if (this.registry.registry[Item.id] && ! this.tmp.disambig_override) {
		this.tmp.disambig_request = this.registry.registry[Item.id].disambig;
		this.tmp.disambig_settings = this.registry.registry[Item.id].disambig;
	} else {
		this.tmp.disambig_settings = new CSL.Factory.AmbigConfig();
	}
	this.tmp.names_used = new Array();
	this.tmp.nameset_counter = 0;
	this.tmp.years_used = new Array();
	this.tmp.splice_delimiter = this[this.tmp.area].opt.delimiter;
	this["bibliography_sort"].keys = new Array();
	this["citation_sort"].keys = new Array();
};
CSL.Engine.prototype.end = function(){
	if (this.tmp.last_suffix_used && this.tmp.last_suffix_used.match(/.*[-.,;:]$/)){
		this.tmp.splice_delimiter = " ";
	} else if (this.tmp.prefix.value() && this.tmp.prefix.value().match(/^[,,:;a-z].*/)){
		this.tmp.splice_delimiter = " ";
	} else if (this.tmp.last_suffix_used || this.tmp.prefix.value()){
			//
			// forcing the delimiter back to normal if a
			// suffix or prefix touch the join, even if
			// a year-suffix is the only output.
			//
			// XXXX: This should not be necessary.  Any cite matching
			// this condition should be forced to full form anyway.
			//
		this.tmp.splice_delimiter = state[this.tmp.area].opt.delimiter;
	}
	this.tmp.last_suffix_used = this.tmp.suffix.value();
	this.tmp.last_years_used = this.tmp.years_used.slice();
	this.tmp.last_names_used = this.tmp.names_used.slice();
	this.tmp.disambig_request = false;
};
CSL.Lib = {};
//
// XXXXX Fix initialization of given name count.
// Should this be removed from the base?  not sure.
//
CSL.Lib.Elements = {};
CSL.Lib.Elements.info = new function(){
	this.build = build;
	function build (state,target){
		if (this.tokentype == CSL.START){
			state.build.skip = "info";
		} else {
			state.build.skip = false;
		}
	};
};
CSL.Lib.Elements.macro = new function(){
	this.build = build;
	function build (state,target){
	};
};
CSL.Lib.Elements.text = new function(){
	this.build = build;
	function build (state,target){
		CSL.Util.substituteStart.call(this,state,target);
		if (this.postponed_macro){
			CSL.Factory.expandMacro.call(state,this);
		} else {
			// ...
			//
			// Do non-macro stuff
			var variable = this.variables[0];
			if ("citation-number" == variable || "year-suffix" == variable){
				//
				// citation-number and year-suffix are super special,
				// because they are rangeables, and require a completely
				// different set of formatting parameters on the output
				// queue.
				if (variable == "citation-number"){
					//this.strings.is_rangeable = true;
					if ("citation-number" == state[state.tmp.area].opt["collapse"]){
						this.range_prefix = "-";
					}
					//
					// XXXXX: where to get the delimiter for this?  The
					// layout delimiter is appropriate, where is it?
					// Is it even safe to set it at this stage of processing?
					// Guess so.
					//
					this.successor_prefix = state[state.build.area].opt.layout_delimiter;
					var func = function(state,Item){
						var id = Item["id"];
						if (!state.tmp.force_subsequent){
							var num = state.registry.registry[id].seq;
							var number = new CSL.Output.Number(num,this);
							state.output.append(number,"literal");
						}
					};
					this["execs"].push(func);
				} else if (variable == "year-suffix"){
					if (state[state.tmp.area].opt["year-suffix-range-delimiter"]){
						this.range_prefix = state[state.tmp.area].opt["year-suffix-range-delimiter"];
					}
					if (state[state.tmp.area].opt["year-suffix-delimiter"]){
						this.successor_prefix = state[state.build.area].opt["year-suffix-delimiter"];
					}
					var func = function(state,Item){
						if (state.registry.registry[Item.id] && state.registry.registry[Item.id].disambig[2]){
							//state.output.append(state.registry.registry[Item.id].disambig[2],this);
							var num = parseInt(state.registry.registry[Item.id].disambig[2], 10);
							var number = new CSL.Output.Number(num,this);
							var formatter = new CSL.Util.Suffixator(CSL.SUFFIX_CHARS);
							number.setFormatter(formatter);
							state.output.append(number,"literal");
							//
							// don't ask :)
							// obviously the variable naming scheme needs
							// a little touching up
							var firstoutput = state.tmp.term_sibling.mystack.indexOf(true) == -1;
							var specialdelimiter = state[state.tmp.area].opt["year-suffix-delimiter"];
							if (firstoutput && specialdelimiter && !state.tmp.sort_key_flag){
								state.tmp.splice_delimiter = state[state.tmp.area].opt["year-suffix-delimiter"];
							}
						}
					};
					this["execs"].push(func);
				}
			} else {
				if (state.build.term){
					var term = state.build.term;
					var form = "long";
					var plural = 0;
					if (state.build.form){
						form = state.build.form;
					}
					if (state.build.plural){
						plural = state.build.plural;
					}
					term = state.getTerm(term,form,plural);
					var printterm = function(state,Item){
						// capitalize the first letter of a term, if it is the
						// first thing rendered in a citation (or if it is
						// being rendered immediately after terminal punctuation,
						// I guess, actually).
						if (!state.tmp.term_predecessor){
							//print("Capitalize");
							term = CSL.Output.Formatters.capitalize_first(state,term);
							state.tmp.term_predecessor = true;
						};
						state.output.append(term,this);
					};
					this["execs"].push(printterm);
					state.build.term = false;
					state.build.form = false;
					state.build.plural = false;
				} else if (this.variables.length){
					var func = function(state,Item){
						state.output.append(Item[this.variables[0]],this);
					};
					this["execs"].push(func);
				} else if (this.strings.value){
					var func = function(state,Item){
						state.output.append(this.strings.value,this);
					};
					this["execs"].push(func);
				} else {
					var weird_output_function = function(state,Item){
						if (state.tmp.value.length){
							print("Weird output pattern.  Can this be revised?");
							for each (var val in state.tmp.value){
								state.output.append(val,this);
							}
							state.tmp.value = new Array();
						}
					};
					this["execs"].push(weird_output_function);
				}
			}
			target.push(this);
		};
		CSL.Util.substituteEnd.call(this,state,target);
	};
};
CSL.Lib.Elements.group = new function(){
	this.build = build;
	function build (state,target){
		if (this.tokentype == CSL.START){
			CSL.Util.substituteStart.call(this,state,target);
			if (state.build.substitute_level.value()){
				state.build.substitute_level.replace((state.build.substitute_level.value()+1));
			}
			var newoutput = function(state,Item){
				state.output.startTag("group",this);
			};
			//
			// Paranoia.  Assure that this init function is the first executed.
			var execs = new Array();
			execs.push(newoutput);
			this.execs = execs.concat(this.execs);
			var fieldcontentflag = function(state,Item){
				state.tmp.term_sibling.push( undefined, CSL.LITERAL );
			};
			this["execs"].push(fieldcontentflag);
		} else {
			var quashnonfields = function(state,Item){
				var flag = state.tmp.term_sibling.value();
				if (false == flag){
					state.output.clearlevel();
				}
				state.tmp.term_sibling.pop();
				//
				// Heals group quashing glitch with nested groups.
				//
				if (flag && state.tmp.term_sibling.mystack.length > 1){
					state.tmp.term_sibling.replace(true);
				}
			};
			this["execs"].push(quashnonfields);
			var mergeoutput = function(state,Item){
				//
				// rendering happens inside the
				// merge method, by applying decorations to
				// each token to be merged.
				state.output.endTag();
			};
			this["execs"].push(mergeoutput);
		}
		target.push(this);
		if (this.tokentype == CSL.END){
			if (state.build.substitute_level.value()){
				state.build.substitute_level.replace((state.build.substitute_level.value()-1));
			}
			CSL.Util.substituteEnd.call(this,state,target);
		}
	}
};
CSL.Lib.Elements.citation = new function(){
	this.build = build;
	function build (state,target){
		if (this.tokentype == CSL.START) {
			state.build.area_return = state.build.area;
			state.build.area = "citation";
		}
		if (this.tokentype == CSL.END) {
			state.build.area = state.build.area_return;
		}
	}
};
CSL.Lib.Elements.choose = new function(){
	this.build = build;
	this.configure = configure;
	function build (state,target){
		if (this.tokentype == CSL.START){
			var func = function(state,Item){ //open condition
				state.tmp.jump.push(undefined, CSL.LITERAL);
			};
		}
		if (this.tokentype == CSL.END){
			var func = function(state,Item){ //close condition
				state.tmp.jump.pop();
			};
		}
		this["execs"].push(func);
		target.push(this);
	}
	function configure(state,pos){
		if (this.tokentype == CSL.END){
			state.configure["fail"].push((pos));
			state.configure["succeed"].push((pos));
		} else {
			state.configure["fail"].pop();
			state.configure["succeed"].pop();
		}
	}
};
CSL.Lib.Elements["if"] = new function(){
	this.build = build;
	this.configure = configure;
	function build (state,target){
		if (this.tokentype == CSL.START){
			for each (var variable in this.variables){
				var func = function(state,Item){
					if (Item[variable]){
						return true;
					}
					return false;
				};
				this["tests"].push(func);
			};
			if (this.strings.position){
				var tryposition = this.strings.position;
				var func = function(state,Item){
					if (state.tmp.force_subsequent && tryposition < 2){
						return true;
					} else if (Item["position"] && Item["position"] >= tryposition){
						return true;
					};
					return false;
				};
				this.tests.push(func);
			}
			if (! this.evaluator){
				//
				// cut and paste of "any"
				this.evaluator = function(state,Item){
					var res = this.fail;
					state.tmp.jump.replace("fail");
					for each (var func in this.tests){
						if (func.call(this,state,Item)){
							res = this.succeed;
							state.tmp.jump.replace("succeed");
							break;
						}
					}
					return res;
				};
			};
		}
		if (this.tokentype == CSL.END){
			var closingjump = function(state,Item){
				var next = this[state.tmp.jump.value()];
				return next;
			};
			this["execs"].push(closingjump);
		};
		target.push(this);
	}
	function configure(state,pos){
		if (this.tokentype == CSL.START){
			// jump index on failure
			this["fail"] = state.configure["fail"][(state.configure["fail"].length-1)];
			this["succeed"] = this["next"];
		} else {
			// jump index on success
			this["succeed"] = state.configure["succeed"][(state.configure["succeed"].length-1)];
			this["fail"] = this["next"];
		}
	}
};
CSL.Lib.Elements["else-if"] = new function(){
	this.build = build;
	this.configure = configure;
	function build (state,target){
		if (this.tokentype == CSL.START){
			for each (var variable in this.variables){
				var func = function(state,Item){
					if (Item[variable]){
						return true;
					}
					return false;
				};
				this["tests"].push(func);
			};
			if (this.strings.position){
				var tryposition = this.strings.position;
				var func = function(state,Item){
					if (state.tmp.force_subsequent && tryposition < 2){
						return true;
					} else if (Item["position"] && Item["position"] >= tryposition){
						return true;
					};
					return false;
				};
				this.tests.push(func);
			}
			if (! this.evaluator){
				//
				// cut and paste of "any"
				this.evaluator = function(state,Item){
					var res = this.fail;
					state.tmp.jump.replace("fail");
					for each (var func in this.tests){
						if (func.call(this,state,Item)){
							res = this.succeed;
							state.tmp.jump.replace("succeed");
							break;
						}
					}
					return res;
				};
			};
		}
		if (this.tokentype == CSL.END){
			var closingjump = function(state,Item){
				var next = this[state.tmp.jump.value()];
				return next;
			};
			this["execs"].push(closingjump);
		};
		target.push(this);
	}
	function configure(state,pos){
		if (this.tokentype == CSL.START){
			// jump index on failure
			this["fail"] = state.configure["fail"][(state.configure["fail"].length-1)];
			this["succeed"] = this["next"];
			state.configure["fail"][(state.configure["fail"].length-1)] = pos;
		} else {
			// jump index on success
			this["succeed"] = state.configure["succeed"][(state.configure["succeed"].length-1)];
			this["fail"] = this["next"];
		}
	}
};
CSL.Lib.Elements["else"] = new function(){
	this.build = build;
	this.configure = configure;
	function build (state,target){
		target.push(this);
	}
	function configure(state,pos){
		if (this.tokentype == CSL.START){
			state.configure["fail"][(state.configure["fail"].length-1)] = pos;
		}
	}
};
CSL.Lib.Elements.name = new function(){
	this.build = build;
	function build(state,target){
		state.build.form = this.strings.form;
		state.build.name_flag = true;
		var func = function(state,Item){
			state.output.addToken("name",false,this);
		};
		this["execs"].push(func);
		var set_initialize_with = function(state,Item){
			state.tmp["initialize-with"] = this.strings["initialize-with"];
		};
		this["execs"].push(set_initialize_with);
		target.push(this);
	};
};
CSL.Lib.Elements["name-part"] = new function(){
	this.build = build;
	function build(state,target){
		// XXXXX problem.  can't be global.  don't want to remint
		// for every rendering.  somehow get tokens stored on
		// closing names tag static.  always safe, b/c
		// no conditional branching inside names.
		// same treatment for etal styling element.
		var set_namepart_format = function(state,Item){
			state.output.addToken(state.tmp.namepart_type,false,this);
		};
		this["execs"].push(set_namepart_format);
		target.push(this);
	};
};
CSL.Lib.Elements.label = new function(){
	this.build = build;
	function build(state,target){
		if (state.build.name_flag){
			this.strings.label_position = CSL.AFTER;
		} else {
			this.strings.label_position = CSL.BEFORE;
		}
		var set_label_info = function(state,Item){
		//	if (!this.strings.form){
		//		this.strings.form = "long";
		//	}
			state.output.addToken("label",false,this);
		};
		this["execs"].push(set_label_info);
		if (state.build.term){
			var term = state.build.term;
			var plural = 0;
			if (!this.strings.form){
				this.strings.form = "long";
			}
			var form = this.strings.form;
			//
			// XXXXX: probably wrong.  needs a test.
			//
			if (state.build.plural){
				plural = state.build.plural;
			}
			var output_label = function(state,Item){
				if ("locator" == term){
					myterm = Item["label"];
				}
				if (!myterm){
					myterm = "page";
				}
				var myterm = state.getTerm(myterm,form,plural);
				if (this.strings["include-period"]){
					myterm += ".";
				}
				state.output.append(myterm,this);
			};
			this.execs.push(output_label);
			state.build.plural = false;
			state.build.term = false;
			state.build.form = false;
		}
		target.push(this);
	};
};
CSL.Lib.Elements.substitute = new function(){
	this.build = build;
	function build(state,target){
		if (this.tokentype == CSL.START){
			var set_conditional = function(state,Item){
				if (state.tmp.value.length){
					state.tmp.can_substitute.replace(false, CSL.LITERAL);
				}
			};
			this.execs.push(set_conditional);
			target.push(this);
		}
	};
};
CSL.Lib.Elements["et-al"] = new function(){
	this.build = build;
	function build(state,target){
		var set_et_al_format = function(state,Item){
			state.output.addToken("etal",false,this);
		};
		this["execs"].push(set_et_al_format);
		target.push(this);
	};
};
CSL.Lib.Elements.layout = new function(){
	this.build = build;
	function build(state,target){
		if (this.tokentype == CSL.START){
			state.build.layout_flag = true;
			//
			// done_vars is used to prevent the repeated
			// rendering of variables
			var initialize_done_vars = function(state,Item){
				state.tmp.done_vars = new Array();
				state.tmp.no_name_rendered = true;
				state.tmp.rendered_name = false;
			};
			this.execs.push(initialize_done_vars);
			var set_opt_delimiter = function(state,Item){
				// just in case
				state.tmp.sort_key_flag = false;
				state[state.tmp.area].opt.delimiter = "";
				if (this.strings.delimiter){
					state[state.tmp.area].opt.delimiter = this.strings.delimiter;
				};
			};
			this["execs"].push(set_opt_delimiter);
			var reset_nameset_counter = function(state,Item){
				state.tmp.nameset_counter = 0;
			};
			this["execs"].push(reset_nameset_counter);
			state[state.build.area].opt.layout_prefix = this.strings.prefix;
			state[state.build.area].opt.layout_suffix = this.strings.suffix;
			state[state.build.area].opt.layout_delimiter = this.strings.delimiter;
			state[state.build.area].opt.layout_decorations = this.decorations;
			var declare_thyself = function(state,Item){
				state.tmp.term_predecessor = false;
				state.output.openLevel("empty");
			};
			this["execs"].push(declare_thyself);
			target.push(this);
			if (state.build.area == "citation"){
				var prefix_token = new CSL.Factory.Token("text",CSL.SINGLETON);
				var func = function(state,Item){
					if (Item["prefix"]){
						var sp = "";
						if (Item["prefix"].match(/.*[a-zA-Z\u0400-\u052f].*/)){
							var sp = " ";
						}
						state.output.append((Item["prefix"]+sp),this);
					};
				};
				prefix_token["execs"].push(func);
				target.push(prefix_token);
			}
		};
		if (this.tokentype == CSL.END){
			state.build.layout_flag = false;
			if (state.build.area == "citation"){
				var suffix_token = new CSL.Factory.Token("text",CSL.SINGLETON);
				var func = function(state,Item){
					if (Item["suffix"]){
						var sp = "";
						if (Item["suffix"].match(/.*[a-zA-Z\u0400-\u052f].*/)){
							var sp = " ";
						}
						state.output.append((sp+Item["suffix"]),this);
					};
				};
				suffix_token["execs"].push(func);
				target.push(suffix_token);
			}
			var mergeoutput = function(state,Item){
				if (state.tmp.area == "bibliography"){
					state.output.endTag();  // closes bib_other
				};
				state.output.closeLevel();
			};
			this["execs"].push(mergeoutput);
			target.push(this);
		}
	};
};
CSL.Lib.Elements.number = new function(){
	this.build = build;
	function build(state,target){
		CSL.Util.substituteStart.call(this,state,target);
		//
		// This should push a rangeable object to the queue.
		//
		if (this.strings.form == "roman"){
			this.formatter = state.fun.romanizer;
		}
		var push_number = function(state,Item){
			var num = parseInt(Item[this.variables[0]], 10);
			var number = new CSL.Output.Number(num,this);
			state.output.append(number,"literal");
		};
		this["execs"].push(push_number);
		target.push(this);
		CSL.Util.substituteEnd.call(this,state,target);
	};
};
CSL.Lib.Elements.date = new function(){
	this.build = build;
	function build(state,target){
		if (this.tokentype == CSL.START){
			CSL.Util.substituteStart.call(this,state,target);
			var set_value = function(state,Item){
				state.tmp.element_rendered_ok = false;
				if (this.variables.length && Item[this.variables[0]]){
					state.tmp.date_object = Item[this.variables[0]];
				}
			};
			this["execs"].push(set_value);
			var newoutput = function(state,Item){
				state.output.startTag("date",this);
			};
			this["execs"].push(newoutput);
		} else if (this.tokentype == CSL.END){
			var mergeoutput = function(state,Item){
				if (!state.tmp.element_rendered_ok || state.tmp.date_object["literal"]){
					state.output.append(state.tmp.date_object["literal"],"empty");
				}
				state.output.endTag();
			};
			this["execs"].push(mergeoutput);
		}
		target.push(this);
		if (this.tokentype == CSL.END){
			CSL.Util.substituteEnd.call(this,state,target);
		};
	};
};
CSL.Lib.Elements["date-part"] = new function(){
	this.build = build;
	function build(state,target){
		var value = "";
		if (!this.strings.form){
			this.strings.form = "long";
		}
		var render_date_part = function(state,Item){
			if (state.tmp.date_object){
				value = state.tmp.date_object[this.strings.name];
			};
			var real = !state.tmp.suppress_decorations;
			var have_collapsed = state.tmp.have_collapsed;
			var invoked = state[state.tmp.area].opt.collapse == "year-suffix";
			var precondition = state[state.tmp.area].opt["disambiguate-add-year-suffix"];
			//
			// XXXXX: need a condition for year as well?
			if (real && precondition && invoked){
				state.tmp.years_used.push(value);
				var known_year = state.tmp.last_years_used.length >= state.tmp.years_used.length;
				if (known_year && have_collapsed){
					if (state.tmp.last_years_used[(state.tmp.years_used.length-1)] == value){
						value = false;
					}
				}
			}
			if (value){
				if (this.strings.form){
					value = CSL.Util.Dates[this.strings.name][this.strings.form](state,value);
				}
				//state.output.startTag(this.strings.name,this);
				state.output.append(value,this);
				//state.output.endTag();
			};
			state.tmp.value = new Array();
		};
		this["execs"].push(render_date_part);
		target.push(this);
	};
};
CSL.Lib.Elements.option = new function(){
	this.build = build;
	function build(state,target){
		if (this.strings.name == "collapse"){
			// only one collapse value will be honoured.
			if (this.strings.value){
				state[state.tmp.area].opt.collapse = this.strings.value;
			}
		}
		if (CSL.ET_AL_NAMES.indexOf(this.strings.name) > -1){
			if (this.strings.value){
				state[state.build.area].opt[this.strings.name] = parseInt(this.strings.value, 10);
			}
		}
		if (CSL.DISAMBIGUATE_OPTIONS.indexOf(this.strings.name) > -1){
			state[state.tmp.area].opt[this.strings.name] = true;
		}
		if ("year-suffix-delimiter" == this.strings.name){
			state[state.tmp.area].opt["year-suffix-delimiter"] = this.strings.value;
		}
		if ("year-suffix-range-delimiter" == this.strings.name){
			state[state.tmp.area].opt["year-suffix-range-delimiter"] = this.strings.value;
		}
		if ("after-collapse-delimiter" == this.strings.name){
			state[state.tmp.area].opt["after-collapse-delimiter"] = this.strings.value;
		}
		if (this.strings.value == "true"){
			if ("second-field-align" == this.strings.name){
				state.bibliography.opt["csl-bib-body"].push("push-right");
				state.bibliography.opt["csl-bib-entry"].push("be-relative");
				state.bibliography.opt["csl-bib-first"].push("float-left");
			}
			if ("hanging-indent" == this.strings.name){
				state.bibliography.opt["csl-bib-body"].push("push-right");
				state.bibliography.opt["csl-bib-entry"].push("hanging-indent");
			}
		}
		target.push(this);
	};
};
CSL.Lib.Elements.bibliography = new function(){
	this.build = build;
	function build(state,target){
		if (this.tokentype == CSL.START){
			state.build.area_return = state.build.area;
			state.build.area = "bibliography";
		}
		if (this.tokentype == CSL.END){
			state.build.area = state.build.area_return;
		}
		target.push(this);
	};
};
CSL.Lib.Elements.sort = new function(){
	this.build = build;
	function build(state,target){
		if (this.tokentype == CSL.START){
			state.build.sort_flag  = true;
			state.build.area_return = state.build.area;
			state.build.area = state.build.area+"_sort";
		};
		if (this.tokentype == CSL.END){
			state.build.area = state.build.area_return;
			state.build.sort_flag  = false;
		}
	};
};
CSL.Lib.Elements.key = new function(){
	this.build = build;
	function build(state,target){
		var start_key = new CSL.Factory.Token("key",CSL.START);
		start_key.strings["et-al-min"] = this.strings["et-al-min"];
		start_key.strings["et-al-use-first"] = this.strings["et-al-use-first"];
		var initialize_done_vars = function(state,Item){
			state.tmp.done_vars = new Array();
		};
		start_key.execs.push(initialize_done_vars);
		var sort_direction = new Array();
		if (this.strings.sort_direction == CSL.DESCENDING){
			sort_direction.push(1);
			sort_direction.push(-1);
		} else {
			sort_direction.push(-1);
			sort_direction.push(1);
		}
		state[state.build.area].opt.sort_directions.push(sort_direction);
		var et_al_init = function(state,Item){
			state.tmp.sort_key_flag = true;
			if (this.strings["et-al-min"]){
				state.tmp["et-al-min"] = this.strings["et-al-min"];
			}
			if (this.strings["et-al-use-first"]){
				state.tmp["et-al-use-first"] = this.strings["et-al-use-first"];
			}
		};
		start_key["execs"].push(et_al_init);
		target.push(start_key);
		//
		// ops to initialize the key's output structures
		if (this.variables.length){
			var single_text = new CSL.Factory.Token("text",CSL.SINGLETON);
			single_text.variables = this.variables.slice();
			var output_variables = function(state,Item){
				for each(var variable in single_text.variables){
					if (variable == "citation-number"){
						state.output.append(state.registry.registry[Item["id"]].seq.toString(),"empty");
					} else if (CSL.DATE_VARIABLES.indexOf(variable) > -1) {
						state.output.append(CSL.Util.Dates.year["long"](state,Item[variable]["year"]));
						state.output.append(CSL.Util.Dates.month["numeric-leading-zeros"](state,Item[variable]["month"]));
						state.output.append(CSL.Util.Dates.day["numeric-leading-zeros"](state,Item[variable]["day"]));
					} else {
						state.output.append(Item[variable],"empty");
					}
				}
			};
			single_text["execs"].push(output_variables);
			target.push(single_text);
		} else {
			//
			// if it's not a variable, it's a macro
			var token = new CSL.Factory.Token("text",CSL.SINGLETON);
			token.postponed_macro = this.postponed_macro;
			CSL.Factory.expandMacro.call(state,token);
		}
		//
		// ops to output the key string result to an array go
		// on the closing "key" tag before it is pushed.
		// Do not close the level.
		var end_key = new CSL.Factory.Token("key",CSL.END);
		var store_key_for_use = function(state,Item){
			var keystring = state.output.string(state,state.output.queue);
			if (false){
				print("keystring: "+keystring);
			}
			state[state.tmp.area].keys.push(keystring);
			state.tmp.value = new Array();
		};
		end_key["execs"].push(store_key_for_use);
		var reset_key_params = function(state,Item){
			// state.tmp.name_quash = new Object();
			state.tmp["et-al-min"] = false;
			state.tmp["et-al-use-first"] = false;
			state.tmp.sort_key_flag = false;
		};
		end_key["execs"].push(reset_key_params);
		target.push(end_key);
	};
};
CSL.Lib.Elements.names = new function(){
	this.build = build;
	function build(state,target){
		if (this.tokentype == CSL.START || this.tokentype == CSL.SINGLETON){
			CSL.Util.substituteStart.call(this,state,target);
			state.build.substitute_level.push(1);
			var init_names = function(state,Item){
				//
				// XXXXX: could be wrong here
				if (state.tmp.value.length == 0){
					for each (var variable in this.variables){
						//
						// If the item has been marked for quashing, skip it.
						//
						// XXXXX: name_quash superceded.
						//
						// if (Item[variable] && ! state.tmp.name_quash[variable]){
						if (Item[variable]){
							state.tmp.names_max.push(Item[variable].length);
							state.tmp.value.push({"type":variable,"names":Item[variable]});
							// saving relevant names separately, for reference
							// in splice collapse and in subsequent-author-substitute
							state.tmp.names_used.push(state.tmp.value.slice());
						}
					};
				}
			};
			this["execs"].push(init_names);
		};
		if (this.tokentype == CSL.START){
			state.build.names_flag = true;
			var init_can_substitute = function(state,Item){
				state.tmp.can_substitute.push(true);
			};
			this.execs.push(init_can_substitute);
			var set_et_al_params = function(state,Item){
				state.output.startTag("names",this);
				// No value or zero means a first reference,
				// anything else is a subsequent reference.
				if (Item.position || state.tmp.force_subsequent){
						if (! state.tmp["et-al-min"]){
							if (state[state.tmp.area].opt["et-al-subsequent-min"]){
								state.tmp["et-al-min"] = state[state.tmp.area].opt["et-al-subsequent-min"];
							} else {
								state.tmp["et-al-min"] = state[state.tmp.area].opt["et-al-min"];
							}
						}
						if (! state.tmp["et-al-use-first"]){
							if (state[state.tmp.area].opt["et-al-subsequent-use-first"]){
								state.tmp["et-al-use-first"] = state[state.tmp.area].opt["et-al-subsequent-use-first"];
							} else {
								state.tmp["et-al-use-first"] = state[state.tmp.area].opt["et-al-use-first"];
							}
						}
				} else {
						if (! state.tmp["et-al-min"]){
							state.tmp["et-al-min"] = state[state.tmp.area].opt["et-al-min"];
						}
						if (! state.tmp["et-al-use-first"]){
							state.tmp["et-al-use-first"] = state[state.tmp.area].opt["et-al-use-first"];
						}
				}
			};
			this["execs"].push(set_et_al_params);
		};
		if (this.tokentype == CSL.END){
			var handle_names = function(state,Item){
				var namesets = new Array();
				var common_term = CSL.Util.Names.getCommonTerm(state,state.tmp.value);
				if (common_term){
					namesets = state.tmp.value.slice(0,1);
				} else {
					namesets = state.tmp.value;
				}
				var local_count = 0;
				var nameset = new Object();
				state.output.addToken("space"," ");
				state.output.addToken("sortsep",state.output.getToken("name").strings["sort-separator"]);
				if (!state.output.getToken("etal")){
					state.output.addToken("etal-join",", ");
					state.output.addToken("etal");
				} else {
					state.output.addToken("etal-join","");
				}
				if (!state.output.getToken("label")){
					state.output.addToken("label");
				}
				if (!state.output.getToken("etal").strings.et_al_term){
					state.output.getToken("etal").strings.et_al_term = state.getTerm("et-al","long",0);
				}
				state.output.addToken("commasep",", ");
				for each (namepart in ["secondary-key","primary-key","prefix","suffix"]){
					if (!state.output.getToken(namepart)){
						state.output.addToken(namepart);
					}
				}
				for  (var namesetIndex in namesets){
					nameset = namesets[namesetIndex];
					if (!state.tmp.suppress_decorations && (state[state.tmp.area].opt.collapse == "year" || state[state.tmp.area].opt.collapse == "year-suffix")){
						//
						// XXXX: This looks all messed up.  Apparently I'm using
						// last_names_used for two purposes -- to compare namesets
						// in a listing of nameset variables (which is what the code
						// below does), and to compare the actual name rendered
						// between cites (which is why the var gets reset before
						// _unit_of_reference is called from makeCitationCluster.
						//
						// Or so it seems on a quick look.  Might not need to touch
						// this, though; for bug #12, it will be enough to check
						// whether something has been rendered in the current cite.
						//
						// Ah, no.  This is fine, but the naming of the comparison
						// function is confusing.  This is just checking whether the
						// current name is the same as the last name rendered
						// in the last cite, and it works.  Set a toggle if the
						// test fails, so we can avoid further suppression in the
						// cite.
						//
						if (state.tmp.last_names_used.length == state.tmp.names_used.length){
							var lastones = state.tmp.last_names_used[state.tmp.nameset_counter];
							var currentones = state.tmp.names_used[state.tmp.nameset_counter];
							var compset = currentones.concat(lastones);
							if (CSL.Util.Names.getCommonTerm(state,compset)){
								continue;
							} else {
								state.tmp.have_collapsed = false;
							}
						}
					}
					if (!state.tmp.disambig_request){
						state.tmp.disambig_settings["givens"][state.tmp.nameset_counter] = new Array();
					}
					//
					// Here is where we maybe truncate the list of
					// names, to satisfy the et-al constraints.
					var display_names = nameset.names.slice();
					var sane = state.tmp["et-al-min"] >= state.tmp["et-al-use-first"];
					//
					// if there is anything on name request, we assume that
					// it was configured correctly via state.names_request
					// by the function calling the renderer.
					var discretionary_names_length = state.tmp["et-al-min"];
					//
					// if rendering for display, do not honor a disambig_request
					// to set names length below et-al-use-first
					//
					if (state.tmp.suppress_decorations){
						if (state.tmp.disambig_request){
							discretionary_names_length = state.tmp.disambig_request["names"][state.tmp.nameset_counter];
						} else if (display_names.length >= state.tmp["et-al-min"]){
							discretionary_names_length = state.tmp["et-al-use-first"];
						}
					} else {
						if (state.tmp.disambig_request && state.tmp["et-al-use-first"] < state.tmp.disambig_request["names"][state.tmp.nameset_counter]){
							discretionary_names_length = state.tmp.disambig_request["names"][state.tmp.nameset_counter];
						} else if (display_names.length >= state.tmp["et-al-min"]){
							discretionary_names_length = state.tmp["et-al-use-first"];
						}
					}
					var overlength = display_names.length > discretionary_names_length;
					var et_al = false;
					var and_term = "";
					if (sane && overlength){
						if (! state.tmp.sort_key_flag){
							et_al = state.output.getToken("etal").strings.et_al_term;
						}
						display_names = display_names.slice(0,discretionary_names_length);
					} else {
						if (state.output.getToken("name").strings["and"] && ! state.tmp.sort_key_flag && display_names.length > 1){
							and_term = state.output.getToken("name").strings["and"];
						}
					}
					state.tmp.disambig_settings["names"][state.tmp.nameset_counter] = display_names.length;
					local_count += display_names.length;
					//
					// "name" is the format for the outermost nesting of a nameset
					// "inner" is a format consisting only of a delimiter, used for
					// joining all but the last name in the set together.
					var delim = state.output.getToken("name").strings.delimiter;
					state.output.addToken("inner",delim);
					//state.tmp.tokenstore["and"] = new CSL.Factory.Token("and");
					state.output.formats.value()["name"].strings.delimiter = and_term;
					for (var i in nameset.names){
						//
						// set the display mode default for givennames if required
						if (state.tmp.disambig_request){
							//
							// fix a request for initials that makes no sense.
							// can't do this in disambig, because the availability
							// of initials is not a global parameter.
							var val = state.tmp.disambig_settings["givens"][state.tmp.nameset_counter][i];
							if (val == 1 && ! state.tmp["initialize-with"]){
								val = 2;
							}
							var param = val;
						} else {
							var param = 2;
							if (state.output.getToken("name").strings.form == "short"){
								param = 0;
							} else if ("string" == typeof state.tmp["initialize-with"]){
								param = 1;
							}
						}
						state.tmp.disambig_settings["givens"][state.tmp.nameset_counter][i] = param;
					}
					//
					// configure label if poss
					var label = false;
					if (state.output.getToken("label").strings.label_position){
						var termname;
						if (common_term){
							termname = common_term;
						} else {
							termname = nameset.type;
						}
						//
						// XXXXX: quick hack.  This should be fixed earlier.
						//
						if (!state.output.getToken("label").strings.form){
							var form = "long";
						} else {
							var form = state.output.getToken("label").strings.form;
						}
						if (nameset.names.length > 1){
							label = state.getTerm(termname,form,1);
						} else {
							label = state.getTerm(termname,form,0);
						}
					};
					//
					// Nesting levels are opened to control joins with
					// content at the end of the names block
					//
					// Gotcha.  Don't want to use startTag here, it pushes
					// a fresh format token namespace, and we lose our pointer.]
					// Use openLevel (and possibly addToken) instead.
					state.output.openLevel("empty"); // for term join
					if (label && state.output.getToken("label").strings.label_position == CSL.BEFORE){
						state.output.append(label,"label");
					}
					state.output.openLevel("etal-join"); // join for etal
					CSL.Util.Names.outputNames(state,display_names);
					if (et_al){
						state.output.append(et_al,"etal");
					}
					state.output.closeLevel(); // etal
					if (label && state.tmp.name_label_position != CSL.BEFORE){
						state.output.append(label,"label");
					}
					state.output.closeLevel(); // term
					state.tmp.nameset_counter += 1;
					if (state.tmp.area == "bibliography" && !state.tmp.suppress_decorations){
						if (state.tmp.no_name_rendered){
							state.tmp.rendered_name = state.output.string(state,state.output.current.value().blobs,false);
							if (state.tmp.rendered_name){
								// print("Name to compare (1): "+rendered_name);
								//
								// XXXXX: can't no_name_rendered and rendered_name
								// be merged?
								//
								state.tmp.no_name_rendered = false;
							};
						};
					};
				};
				if (state.output.getToken("name").strings.form == "count"){
					state.output.clearlevel();
					state.output.append(local_count.toString());
					state.tmp["et-al-min"] = false;
					state.tmp["et-al-use-first"] = false;
				}
			};
			this["execs"].push(handle_names);
		};
		//
		// Looks disabled.  Delete, I guess.
		//
		if (this.tokentype == CSL.END && state.build.form == "count" && false){
			state.build.form = false;
			var output_name_count = function(state,Item){
				var name_count = 0;
				for each (var v in this.variables){
					if(Item[v] && Item[v].length){
						name_count += Item[v].length;
					}
				}
				state.output.append(name_count.toString());
			};
			this["execs"].push(output_name_count);
		};
		if (this.tokentype == CSL.END){
			var unsets = function(state,Item){
				//
				// XXXXX: why not just use a simple var for can_substitute,
				// and set it to true when we reach the top level again?
				//
				if (!state.tmp.can_substitute.pop()){
					state.tmp.can_substitute.replace(false, CSL.LITERAL);
				}
				CSL.Util.Names.reinit(state,Item);
				state.output.endTag(); // names
				//
				// !!!!!: per-element rendering works.  hurray.
				//
				if ("string" == typeof state[state.tmp.area].opt["subsequent-author-substitute"] && !state.tmp.suppress_decorations){
					var rendered_name = state.tmp.rendered_name;
					if (state.tmp.no_name_rendered){
						rendered_name = state.output.string(state,state.output.current.value().blobs,false);
						state.tmp.no_name_rendered = false;
					};
					if (rendered_name && rendered_name == state.tmp.last_rendered_name){
						//state.output.current.value().blobs = "-----";
						///state.output.current.value().blobs = [];
						var str = new CSL.Factory.Blob(false,state[state.tmp.area].opt["subsequent-author-substitute"]);
						state.output.current.value().blobs = [str];
						//print("Name to compare (2): "+rendered_name);
					}
					state.tmp.last_rendered_name = rendered_name;
				};
			};
			this["execs"].push(unsets);
			state.build.names_flag = false;
			state.build.name_flag = false;
		}
		target.push(this);
		if (this.tokentype == CSL.END || this.tokentype == CSL.SINGLETON){
			state.build.substitute_level.pop();
			CSL.Util.substituteEnd.call(this,state,target);
		}
	}
};
CSL.Lib.Attributes = {};
CSL.Lib.Attributes["@class"] = function(state,arg){};
CSL.Lib.Attributes["@value"] = function(state,arg){
	this.strings.value = arg;
};
CSL.Lib.Attributes["@name"] = function(state,arg){
	this.strings.name = arg;
};
CSL.Lib.Attributes["@form"] = function(state,arg){
	this.strings.form = arg;
};
CSL.Lib.Attributes["@macro"] = function(state,arg){
	this.postponed_macro = arg;
};
CSL.Lib.Attributes["@term"] = function(state,arg){
	if (this.name == "et-al"){
		if (state.locale_terms[arg]){
			this.strings.et_al_term = state.getTerm(arg,"long",0);
		} else {
			this.strings.et_al_term = arg;
		}
	}
	state.build.term = arg;
};
CSL.Lib.Attributes["@xmlns"] = function(state,arg){};
CSL.Lib.Attributes["@lang"] = function(state,arg){
	if (arg){
		state.build.lang = arg;
	}
};
CSL.Lib.Attributes["@type"] = function(state,arg){
	if (this.name == "name-part") {
		//
		// Note that there will be multiple name-part items,
		// and they all need to be collected before doing anything.
		// So this must be picked up when the <name-part/>
		// element is processed, and used as a key on an
		// object holding the formatting attribute functions.
		state.tmp.namepart_type = arg;
	} else {
		var func = function(state,Item){
			if(Item.type == arg){
				return true;
			}
			return false;
		};
		this["tests"].push(func);
	}
};
CSL.Lib.Attributes["@variable"] = function(state,arg){
	this.variables = arg.split(/\s+/);
	if ("label" == this.name && this.variables[0]){
		state.build.term = this.variables[0];
	} else if (["names","date","text","number"].indexOf(this.name) > -1) {
		//
		// An oddity of variable handling is that this.variables
		// is actually ephemeral; the full list of variables is
		// held in the inner var, and pushed into this.variables
		// conditionally in order to suppress repeat renderings of
		// the same item variable.
		//
		var set_variable_names = function(state,Item){
			var variables = this.variables.slice();
			this.variables = [];
			for each (var variable in variables){
				if (state.tmp.done_vars.indexOf(variable) == -1){
					this.variables.push(variable);
					state.tmp.done_vars.push(variable);
				};
			};
		};
		this.execs.push(set_variable_names);
		var check_for_output = function(state,Item){
			var output = false;
			for each (var variable in this.variables){
				if ("object" == typeof Item[variable]){
					for (i in Item[variable]){
						output = true;
						break;
					}
				} else if ("string" == typeof Item[variable] && Item[variable]){
					output = true;
				} else if ("number" == typeof Item[variable]){
					output = true;
				}
				if (output){
					break;
				}
			}
			if (output){
				state.tmp.term_sibling.replace( true );
				state.tmp.can_substitute.replace(false, CSL.LITERAL);
			} else {
				if (undefined == state.tmp.term_sibling.value()) {
					state.tmp.term_sibling.replace( false, CSL.LITERAL );
				};
			};
			//if (output){
			//	print("Output! "+this.variables);
			//} else {
			//	print("No output! "+this.variables);
			//}
		};
		this.execs.push(check_for_output);
	} else if (["if", "else-if"].indexOf(this.name) > -1){
		var check_for_variable_value = function(state,Item){
			for each(variable in this.variables){
				if (Item[variable]){
					if ("number" == typeof Item[variable] || "string" == typeof Item[variable]){
						return true;
					} else if ("object" == typeof Item[variable]){
						if (Item[variable].length){
							return true;
						} else {
							for (i in Item[variable]){
								return true;
							}
						}
					}
				}
				return false;
			};
		};
		this.tests.push(check_for_variable_value);
	};
};
CSL.Lib.Attributes["@and"] = function(state,arg){
	if ("symbol" == arg){
		this.strings["and"] = "&";
	} else {
		var and = state.getTerm("and","long",0);
		this.strings["and"] = and;
	}
};
CSL.Lib.Attributes["@initialize-with"] = function(state,arg){
	this.strings["initialize-with"] = arg;
};
CSL.Lib.Attributes["@suffix"] = function(state,arg){
	this.strings.suffix = arg;
};
CSL.Lib.Attributes["@prefix"] = function(state,arg){
	this.strings.prefix = arg;
};
CSL.Lib.Attributes["@delimiter"] = function(state,arg){
	this.strings.delimiter = arg;
};
CSL.Lib.Attributes["@match"] = function(state,arg){
	if (this.tokentype == CSL.START){
		if ("none" == arg){
			var evaluator = function(state,Item){
				var res = this.succeed;
				state.tmp.jump.replace("succeed");
				for each (var func in this.tests){
					if (func.call(this,state,Item)){
						res = this.fail;
						state.tmp.jump.replace("fail");
						break;
					}
				}
				return res;
			};
		} else if ("any" == arg){
			var evaluator = function(state,Item){
				var res = this.fail;
				state.tmp.jump.replace("fail");
				for each (var func in this.tests){
					if (func.call(this,state,Item)){
						res = this.succeed;
						state.tmp.jump.replace("succeed");
						break;
					}
				}
				return res;
			};
		} else if ("all" == arg){
			var evaluator = function(state,Item){
				var res = this.succeed;
				state.tmp.jump.replace("succeed");
				for each (var func in this.tests){
					if (!func.call(this,state,Item)){
						res = this.fail;
						state.tmp.jump.replace("fail");
						break;
					}
				}
				return res;
			};
		} else {
			throw "Unknown match condition \""+arg+"\" in @match";
		}
		this.evaluator = evaluator;
	};
};
CSL.Lib.Attributes["@sort-separator"] = function(state,arg){
	this.strings["sort-separator"] = arg;
};
CSL.Lib.Attributes["@delimiter-precedes-last"] = function(state,arg){
	this.strings["delimiter-precedes-last"] = arg;
};
CSL.Lib.Attributes["@name-as-sort-order"] = function(state,arg){
	this.strings["name-as-sort-order"] = arg;
};
CSL.Lib.Attributes["@is-numeric"] = function(state,arg){
	var variables = arg.split(/\s+/);
	for each (var variable in variables){
		var func = function(state,Item){
			if (CSL.NUMERIC_VARIABLES.indexOf(variable) == -1){
				return false;
			}
			var val = Item[variable];
			if (typeof val == "undefined"){
				return false;
			}
			if (typeof val == "number"){
				val = val.toString();
			}
			if (typeof val != "string"){
				return false;
			}
			if (val.match(CSL.QUOTED_REGEXP)){
				return false;
			}
			if (val.match(CSL.NUMBER_REGEXP)){
				return true;
			}
			return false;
		};
		this["tests"].push(func);
	};
};
CSL.Lib.Attributes["@names-min"] = function(state,arg){
	this.strings["et-al-min"] = parseInt(arg, 10);
};
CSL.Lib.Attributes["@names-use-first"] = function(state,arg){
	this.strings["et-al-use-first"] = parseInt(arg,10);
};
CSL.Lib.Attributes["@sort"] = function(state,arg){
	if (arg == "descending"){
		this.strings.sort_direction = CSL.DESCENDING;
	}
}
CSL.Lib.Attributes["@plural"] = function(state,arg){
};
CSL.Lib.Attributes["@locator"] = function(state,arg){
};
CSL.Lib.Attributes["@include-period"] = function(state,arg){
	this.strings["include-period"] = arg;
};
CSL.Lib.Attributes["@subsequent-author-substitute"] = function(state,arg){
	state.bibliography.opt["subsequent-author-substitute"] = arg;
};
CSL.Lib.Attributes["@position"] = function(state,arg){
	if (arg == "subsequent"){
		this.strings.position = CSL.POSITION_SUBSEQUENT;
	} else if (arg == "ibid") {
		this.strings.position = CSL.POSITION_IBID;
	} else if (arg == "ibid-with-locator"){
		this.strings.position = CSL.POSITION_IBID_WITH_LOCATOR;
	};
};
CSL.Lib.Attributes["@disambiguate"] = function(state,arg){
	if (this.tokentype == CSL.START && ["if","else-if"].indexOf(this.name) > -1){
		if (arg == "true"){
			state.opt.has_disambiguate = true;
			var func = function(state,Item){
				if (state.tmp.disambig_settings["disambiguate"]){
					return true;
				}
				return false;
			};
			this["tests"].push(func);
		};
	};
};
CSL.System = {};
CSL.System.Xml = {};
CSL.System.Xml.E4X = function(){};
CSL.System.Xml.E4X.prototype.clean = function(xml){
	xml = xml.replace(/<\?[^?]+\?>/g,"");
	xml = xml.replace(/<![^>]+>/g,"");
	xml = xml.replace(/^\s+/g,"");
	xml = xml.replace(/\s+$/g,"");
	return xml;
};
CSL.System.Xml.E4X.prototype.parse = function(myxml){
	default xml namespace = "http://purl.org/net/xbiblio/csl"; with({});
	myxml = new XML( this.clean(myxml) );
	return myxml;
};
CSL.System.Xml.E4X.prototype.children = function(myxml){
	var ret = myxml.children();
	return ret;
};
CSL.System.Xml.E4X.prototype.nodename = function(myxml){
	return myxml.localName();
};
CSL.System.Xml.E4X.prototype.attributes = function(myxml){
	var ret = new Object();
	var attrs = myxml.attributes();
	for (var idx in attrs){
		var key = "@"+attrs[idx].localName();
		var value = attrs[idx].toString();
		ret[key] = value;
	}
	if (myxml.localName() == "style" || myxml.localName() == "locale"){
		var xml = new Namespace("http://www.w3.org/XML/1998/namespace");
		//print("my language: "+this.@xml::lang.toString());
		var lang = myxml.@xml::lang.toString();
		if (lang){
			ret["@lang"] = lang;
		}
	}
	return ret;
};
CSL.System.Xml.E4X.prototype.content = function(myxml){
	return myxml.toString();
};
CSL.System.Xml.E4X.prototype.numberofnodes = function(myxml){
	return myxml.length();
};
CSL.Factory = {};
CSL.Factory.version = function(){
	var msg = "\"Entropy\" citation processor (a.k.a. citeproc-js) ver.0.01";
	print(msg);
	return msg;
};
CSL.Factory.XmlToToken = function(state,tokentype){
	var name = state.sys.xml.nodename(this);
	if (state.build.skip && state.build.skip != name){
		return;
	}
	if (!name){
		var txt = state.sys.xml.content(this);
		if (txt){
			state.build.text = txt;
		}
		return;
	}
	if ( ! CSL.Lib.Elements[state.sys.xml.nodename(this)]){
		throw "Undefined node name \""+name+"\".";
	}
	var attrfuncs = new Array();
	var attributes = state.sys.xml.attributes(this);
	var decorations = CSL.Factory.setDecorations.call(this,state,attributes);
	var token = new CSL.Factory.Token(name,tokentype);
	for (var key in attributes){
		try {
			var attrfunc = CSL.Lib.Attributes[key].call(token,state,attributes[key]);
		} catch (e) {
			if (e == "TypeError: Cannot call method \"call\" of undefined"){
				throw "Unknown attribute \""+key+"\" in node \""+name+"\" while processing CSL file";
			} else {
				throw "CSL processor error, "+key+" attribute: "+e;
			}
		}
		if (attrfunc){
			attrfuncs.push(attrfunc);
		}
	}
	token.decorations = decorations;
	var target = state[state.build.area].tokens;
	CSL.Lib.Elements[name].build.call(token,state,target);
};
CSL.Factory.setDecorations = function(state,attributes){
	var ret = new Array();
	for each (var key in CSL.FORMAT_KEY_SEQUENCE){
		if (attributes[key]){
			ret.push([key,attributes[key]]);
			delete attributes[key];
		}
	}
	return ret;
};
CSL.Factory.renderDecorations = function(state){
	var ret = new Array();
	for each (hint in this.decorations){
		ret.push(state.fun.decorate[hint[0]][hint[1]]);
	}
	this.decorations = ret;
};
CSL.Factory.substituteOne = function(template) {
	return function(state,list) {
		if ("string" == typeof list){
			return template.replace("%%STRING%%",list);
		}
		print("USING is_delimiter (1) ... WHY?");
		var decor = template.split("%%STRING%%");
		var ret = [{"is_delimiter":true,"value":decor[0]}].concat(list);
		ret.push({"is_delimiter":true,"value":decor[1]});
		return ret;
	};
};
CSL.Factory.substituteTwo = function(template) {
	return function(param) {
		var template2 = template.replace("%%PARAM%%", param);
		return function(state,list) {
			if ("string" == typeof list){
				return template2.replace("%%STRING%%",list);
			}
			print("USING is_delimiter (2) ... WHY?");
			var decor = template2.split("%%STRING");
			var ret = [{"is_delimiter":true,"value":decor[0]}].concat(list);
			ret.push({"is_delimiter":true,"value":decor[1]});
			return ret;
		};
	};
};
CSL.Factory.Mode = function(mode){
	var decorations = new Object();
	var params = CSL.Output.Formats[mode];
	for (var param in params) {
		if ("@" != param[0]){
			decorations[param] = params[param];
			continue;
		}
		var func = false;
		var val = params[param];
		var args = param.split('/');
		if (typeof val == "string" && val.indexOf("%%STRING%%") > -1)  {
			if (val.indexOf("%%PARAM%%") > -1) {
				func = CSL.Factory.substituteTwo(val);
			} else {
				func = CSL.Factory.substituteOne(val);
			}
		} else if (typeof val == "boolean" && !val) {
			func = CSL.Output.Formatters.passthrough;
		} else if (typeof val == "function") {
			func = val;
		} else {
			throw "CSL.Compiler: Bad "+mode+" config entry for "+param+": "+val;
		}
		if (args.length == 1) {
			decorations[args[0]] = func;
		} else if (args.length == 2) {
			if (!decorations[args[0]]) {
				decorations[args[0]] = new Object();
			}
			decorations[args[0]][args[1]] = func;
		}
	}
	return decorations;
};
CSL.Factory.expandMacro = function(macro_key_token){
	var mkey = macro_key_token.postponed_macro;
	if (this.build.macro_stack.indexOf(mkey) > -1){
		throw "CSL processor error: call to macro \""+mkey+"\" would cause an infinite loop";
	} else {
		this.build.macro_stack.push(mkey);
	}
	var start_token = new CSL.Factory.Token("group",CSL.START);
	start_token.decorations = this.decorations;
	for (var i in macro_key_token.strings){
		start_token.strings[i] = macro_key_token.strings[i];
	}
	var newoutput = function(state,Item){
		//state.output.openLevel(this);
		state.output.startTag("group",this);
		//state.tmp.decorations.push(this.decorations);
	};
	start_token["execs"].push(newoutput);
	this[this.build.area].tokens.push(start_token);
	default xml namespace = "http://purl.org/net/xbiblio/csl"; with({});
	var macroxml = this.cslXml..macro.(@name == mkey);
	if (!macroxml.toString()){
		throw "CSL style error: undefined macro \""+mkey+"\"";
	}
	var navi = new this._getNavi( this, macroxml );
	this._build(navi);
	var end_token = new CSL.Factory.Token("group",CSL.END);
	var mergeoutput = function(state,Item){
		//
		// rendering happens inside the
		// merge method, by applying decorations to
		// each token to be merged.
		state.output.endTag();
		//state.output.closeLevel();
	};
	end_token["execs"].push(mergeoutput);
	this[this.build.area].tokens.push(end_token);
	this.build.macro_stack.pop();
};
CSL.Factory.cloneAmbigConfig = function(config){
	var ret = new Object();
	ret["names"] = new Array();
	ret["givens"] = new Array();
	ret["year_suffix"] = false;
	ret["disambiguate"] = false;
	for (var i in config["names"]){
		var param = config["names"][i];
		ret["names"][i] = param;
	}
	for (var i in config["givens"]){
		var param = new Array();
		for (var j in config["givens"][i]){
			param.push(config["givens"][i][j]);
		}
		ret["givens"].push(param);
	}
	ret["year_suffix"] = config["year_suffix"];
	ret["disambiguate"] = config["disambiguate"];
	return ret;
};
CSL.Factory.Stack = function(val,literal){
	this.mystack = new Array();
	if (literal || val){
		this.mystack.push(val);
	};
};
CSL.Factory.Stack.prototype.push = function(val,literal){
	if (literal || val){
		this.mystack.push(val);
	} else {
		this.mystack.push("");
	}
};
CSL.Factory.Stack.prototype.clear = function(){
	this.mystack = new Array();
};
CSL.Factory.Stack.prototype.replace = function(val,literal){
	if (this.mystack.length == 0){
		throw "Internal CSL processor error: attempt to replace nonexistent stack item with "+val;
	}
	if (literal || val){
		this.mystack[(this.mystack.length-1)] = val;
	} else {
		this.mystack[(this.mystack.length-1)] = "";
	}
};
CSL.Factory.Stack.prototype.pop = function(){
	return this.mystack.pop();
};
CSL.Factory.Stack.prototype.value = function(){
	return this.mystack[(this.mystack.length-1)];
};
CSL.Factory.Stack.prototype.length = function(){
	return this.mystack.length;
};
CSL.Factory.Token = function(name,tokentype){
	this.name = name;
	this.strings = new Object();
	this.strings.delimiter = "";
	this.strings.prefix = "";
	this.strings.suffix = "";
	this.decorations = false;
	this.variables = [];
	this.execs = new Array();
	this.tokentype = tokentype;
	this.evaluator = false;
	this.tests = new Array();
	this.succeed = false;
	this.fail = false;
	this.next = false;
};
CSL.Factory.AmbigConfig = function(){
	this.maxvals = new Array();
	this.minval = 1;
	this.names = new Array();
	this.givens = new Array();
	this.year_suffix = 0;
	this.disambiguate = 0;
};
CSL.Factory.Blob = function(token,str){
	if (token){
		this.strings = new Object();
		for (key in token.strings){
			this.strings[key] = token.strings[key];
		};
		this.decorations = new Array();
		for each (keyset in token.decorations){
			this.decorations.push(keyset.slice());
		}
	} else {
		this.strings = new Object();
		this.strings.prefix = "";
		this.strings.suffix = "";
		this.strings.delimiter = "";
		this.decorations = new Array();
	};
	if ("string" == typeof str){
		this.blobs = str;
	} else {
		this.blobs = new Array();
	};
	this.alldecor = [ this.decorations ];
};
CSL.Factory.Blob.prototype.push = function(blob){
	if ("string" == typeof this.blobs){
		throw "Attempt to push blob onto string object";
	} else {
		blob.alldecor = blob.alldecor.concat(this.alldecor);
		this.blobs.push(blob);
	}
};
CSL.Util = {};
CSL.Util.Names = new function(){};
CSL.Util.Names.outputNames = function(state,display_names){
	var segments = new this.StartMiddleEnd(state,display_names);
	var sort_order = state.output.getToken("name").strings["name-as-sort-order"];
	if (sort_order == "first"){
		state.output.addToken("start");
		state.output.getToken("start").strings.name_as_sort_order = true;
	} else if (sort_order == "all"){
		state.output.addToken("start");
		state.output.getToken("start").strings.name_as_sort_order = true;
		state.output.addToken("middle");
		state.output.getToken("middle").strings.name_as_sort_order = true;
		state.output.addToken("end");
		state.output.getToken("end").strings.name_as_sort_order = true;
	}
	var and = state.output.getToken("name").strings.delimiter;
	if (state.output.getToken("name").strings["delimiter-precedes-last"] == "always"){
		and = state.output.getToken("inner").strings.delimiter+and;
	} else if (state.output.getToken("name").strings["delimiter-precedes-last"] == "never"){
		if (!and){
			and = state.output.getToken("inner").strings.delimiter;
		}
	} else if ((segments.segments.start.length + segments.segments.middle.length) > 1){
		and = state.output.getToken("inner").strings.delimiter+and;
	} else {
		if (!and){
			and = state.output.getToken("inner").strings.delimiter;
		}
	}
	if (and.match(/^[&a-zA-Z\u0400-\u052f].*/)){
		and = " "+and;
	}
	if (and.match(/.*[&a-zA-Z\u0400-\u052f]$/)){
		and = and+" ";
	}
	state.output.getToken("name").strings.delimiter = and;
	state.output.openLevel("name");
	state.output.openLevel("inner");
	segments.outputSegmentNames("start");
	segments.outputSegmentNames("middle");
	state.output.closeLevel(); // inner
	segments.outputSegmentNames("end");
	state.output.closeLevel(); // name
};
CSL.Util.Names.StartMiddleEnd = function(state,names){
	this.state = state;
	this.nameoffset = 0;
	var start = names.slice(0,1);
	var middle = names.slice(1,(names.length-1));
	var endstart = 1;
	if (names.length > 1){
		endstart = (names.length-1);
	}
	var end = names.slice(endstart,(names.length));
	var ret = {};
	ret["start"] = start;
	ret["middle"] = middle;
	ret["end"] = end;
	this.segments = ret;
};
CSL.Util.Names.StartMiddleEnd.prototype.outputSegmentNames = function(seg){
	var state = this.state;
	for (var namenum in this.segments[seg]){
		this.namenum = parseInt(namenum,10);
		this.name = this.segments[seg][namenum];
		if (this.name.literal){
			//
			// XXXXX Separate formatting for institution names?
			// XXXXX This needs to be firmly settled in xbib.
			//
			state.output.append(this.name.literal);
		} else {
			var sequence = CSL.Util.Names.getNamepartSequence(this.name,state.output.getToken(seg));
			state.output.openLevel(sequence[0][0]);
			state.output.openLevel(sequence[0][1]);
			state.output.openLevel(sequence[0][2]);
			this.outputNameParts(sequence[1]);
			state.output.closeLevel();
			state.output.openLevel(sequence[0][2]);
			// XXX cloned code!  make this a function.
			this.outputNameParts(sequence[2]);
			state.output.closeLevel();
			state.output.closeLevel();
			//
			// articular goes here  //
			//
			this.outputNameParts(sequence[3]);
			state.output.closeLevel();
			//
			// the articular goes in at a different level, but
			// is nonetheless part of the name, so it goes into
			// this function to avoid repetition.
			// (special handling when comma is to be included)
			//if (name.suffix){
			//	state.output.squeeze();
			//	if (name.comma_suffix){
			//		state.tmp.delimiter.replace(", ");
			//	}
			//	state.output.append(name.suffix);
			//}
		}
	};
	this.nameoffset += this.segments[seg].length;
}
CSL.Util.Names.StartMiddleEnd.prototype.outputNameParts = function(subsequence){
	var state = this.state;
	for each (var key in subsequence){
		var namepart = this.name[key];
		if ("secondary-key" == key && !this.name.sticky){
			if (0 == state.tmp.disambig_settings["givens"][state.tmp.nameset_counter][(this.namenum+this.nameoffset)]){
				continue;
			} else if (1 == state.tmp.disambig_settings["givens"][state.tmp.nameset_counter][(this.namenum+this.nameoffset)]){
				namepart = CSL.Util.Names.initializeWith(namepart,state.tmp["initialize-with"]);
			}
		}
		//state.output.openLevel(key);
		state.output.append(namepart,key);
		//state.output.closeLevel();
	}
}
CSL.Util.Names.getNamepartSequence = function(name,token){
	if (name.comma_suffix){
		var suffix_sep = "commasep";
	} else {
		var suffix_sep = "space";
	}
	var romanesque = name["primary-key"].match(/.*[a-zA-Z\u0400-\u052f].*/);
	if (!romanesque ){ // neither roman nor Cyrillic characters
		var sequence = [["empty","empty","empty"],["prefix", "primary-key"],["secondary-key"],[]];
	} else if (name.sticky) { // entry likes sort order
		var sequence = [["space","space","space"],["prefix", "primary-key"],["secondary-key"],[]];
	} else if (token && token.strings.name_as_sort_order){
		var sequence = [["sortsep","sortsep","space"],["prefix", "primary-key"],["secondary-key"],["suffix"]];
	} else { // plain vanilla
		var sequence = [[suffix_sep,"space","space"],["secondary-key"],["prefix","primary-key"],["suffix"]];
	}
	return sequence;
};
CSL.Util.Names.deep_copy = function(nameset){
	var nameset2 = new Array();
	for each (name in nameset){
		var name2 = new Object();
		for (var i in name){
			name2[i] = name[i];
		}
		nameset2.push(name2);
	}
	return nameset2;
}
//
// XXXX A handy guide to variable assignments that need
// XXXX to be eliminated.  :)
//
CSL.Util.Names.reinit = function(state,Item){
	state.tmp.value = new Array();
	state.tmp.name_et_al_term = false;
	state.tmp.name_et_al_decorations = false;
	state.tmp.name_et_al_form = "long";
	state.tmp["et-al-min"] = false;
	state.tmp["et-al-use-first"] = false;
	state.tmp["initialize-with"] = false;
	state.tmp["name-as-sort-order"] = false;
	state.tmp.et_al_prefix = false;
};
CSL.Util.Names.getCommonTerm = function(state,namesets){
	if (namesets.length < 2){
		return false;
	}
	var base_nameset = namesets[0];
	var varnames = new Array();
	if (varnames.indexOf(base_nameset.type) == -1){
		varnames.push(base_nameset.type);
	}
	for each (nameset in namesets.slice(1)){
		if (!CSL.Util.Names.compareNamesets(base_nameset,nameset)){
			return false;
		}
		if (varnames.indexOf(nameset.type) == -1){
			varnames.push(nameset.type);
		}
	}
	varnames.sort();
	return varnames.join("");
};
CSL.Util.Names.compareNamesets = function(base_nameset,nameset){
	if (base_nameset.length != nameset.length){
		return false;
	}
	var name;
	for (var n in nameset.names){
		name = nameset.names[n];
		for each (var part in ["primary-key","secondary-key","prefix","suffix"]){
			if (base_nameset.names[n][part] != name[part]){
				return false;
			}
		}
	}
	return true;
};
CSL.Util.Names.initializeWith = function(name,terminator){
	var namelist = name.split(/\s+/);
	var nstring = "";
	for each (var n in namelist){
		var m = n.match( CSL.NAME_INITIAL_REGEXP);
		if (m){
			var extra = "";
			if (m[2]){
				extra = m[2].toLocaleLowerCase();
			}
			nstring = nstring + m[1].toLocaleUpperCase() + extra + terminator;
		};
	};
	if (nstring){
		return nstring;
	}
	return name;
};
CSL.Util.Dates = new function(){};
CSL.Util.Dates.year = new function(){};
CSL.Util.Dates.year["long"] = function(state,num){
	if (!num){
		num = 0;
	}
	return num.toString();
}
CSL.Util.Dates.year["short"] = function(state,num){
	num = num.toString();
	if (num && num.length == 4){
		return num.substr(2);
	}
}
CSL.Util.Dates["month"] = new function(){};
CSL.Util.Dates.month["numeric"] = function(state,num){
	return num.toString();
}
CSL.Util.Dates.month["numeric-leading-zeros"] = function(state,num){
	if (!num){
		num = 0;
	}
	num = num.toString();
	while (num.length < 2){
		num = "0"+num;
	}
	return num.toString();
}
CSL.Util.Dates.month["long"] = function(state,num){
	num = num.toString();
	while (num.length < 2){
		num = "0"+num;
	}
	num = "month-"+num;
	return state.opt.term[num]["long"][0];
}
CSL.Util.Dates.month["short"] = function(state,num){
	num = num.toString();
	while (num.length < 2){
		num = "0"+num;
	}
	num = "month-"+num;
	return state.opt.term[num]["short"][0];
}
CSL.Util.Dates["day"] = new function(){};
CSL.Util.Dates.day["numeric"] = function(state,num){
	return num.toString();
}
CSL.Util.Dates.day["numeric-leading-zeros"] = function(state,num){
	if (!num){
		num = 0;
	}
	num = num.toString();
	while (num.length < 2){
		num = "0"+num;
	}
	return num.toString();
}
CSL.Util.Dates.day["ordinal"] = function(state,num){
	var suffixes = ["st","nd","rd","th"];
	var str = num.toString();
	if ( (num/10)%10 == 1){
		str += suffixes[3];
	} else if ( num%10 == 1) {
		str += suffixes[0];
	} else if ( num%10 == 2){
		str += suffixes[1];
	} else if ( num%10 == 3){
		str += suffixes[2];
	} else {
		str += suffixes[3];
	}
	return str;
}
CSL.Util.Sort = new function(){};
CSL.Util.Sort.strip_prepositions = function(str){
	var m = str.toLocaleLowerCase().match(/((a|an|the)\s+)/);
	if (m){
		str = str.substr(m[1].length);
	};
	return str;
};
CSL.Util.substituteStart = function(state,target){
	if (state.build.area == "bibliography"){
		if (state.build.render_nesting_level == 0){
			var bib_first = new CSL.Factory.Token("group",CSL.START);
			bib_first.decorations = [["@bibliography","first"]];
			var func = function(state,Item){
				if (!state.tmp.render_seen){
					state.output.startTag("bib_first",bib_first);
				};
			};
			bib_first.execs.push(func);
			target.push(bib_first);
		}
		state.build.render_nesting_level += 1;
	}
	if (state.build.substitute_level.value() == 1){
		//
		// All top-level elements in a substitute environment get
		// wrapped in conditionals.  The substitute_level variable
		// is a stack, because spanned names elements (with their
		// own substitute environments) can be nested inside
		// a substitute environment.
		var choose_start = new CSL.Factory.Token("choose",CSL.START);
		target.push(choose_start);
		var if_start = new CSL.Factory.Token("if",CSL.START);
		//
		// Set a test of the shadow if token to skip this
		// macro if we have acquired a name value.
		var check_for_variable = function(state,Item){
			if (state.tmp.can_substitute.value()){
				return true;
			}
			return false;
		};
		if_start.tests.push(check_for_variable);
		//
		// this is cut-and-paste of the "any" evaluator
		// function, from Attributes.  These functions
		// should be defined in a namespace for reuse.
		// Sometime.
		var evaluator = function(state,Item){
			var res = this.fail;
			state.tmp.jump.replace("fail");
			for each (var func in this.tests){
				if (func.call(this,state,Item)){
					res = this.succeed;
					state.tmp.jump.replace("succeed");
					break;
				}
			}
			return res;
		};
		if_start.evaluator = evaluator;
		target.push(if_start);
	};
};
CSL.Util.substituteEnd = function(state,target){
	if (state.build.area == "bibliography"){
		state.build.render_nesting_level += -1;
		if (state.build.render_nesting_level == 0){
			var bib_first_end = new CSL.Factory.Token("group",CSL.END);
			var first_func_end = function(state,Item){
				if (!state.tmp.render_seen){
					state.output.endTag(); // closes bib_first
				};
			};
			bib_first_end.execs.push(first_func_end);
			target.push(bib_first_end);
			var bib_other = new CSL.Factory.Token("group",CSL.START);
			bib_other.decorations = [["@bibliography","other"]];
			var other_func = function(state,Item){
				if (!state.tmp.render_seen){
					state.tmp.render_seen = true;
					state.output.startTag("bib_other",bib_other);
				};
			};
			bib_other.execs.push(other_func);
			target.push(bib_other);
		};
	};
	if (state.build.substitute_level.value() == 1){
		var if_end = new CSL.Factory.Token("if",CSL.END);
		target.push(if_end);
		var choose_end = new CSL.Factory.Token("choose",CSL.END);
		target.push(choose_end);
	};
};
//
// This will probably become CSL.Util.Numbers
//
CSL.Util.Romanizer = function (){};
CSL.Util.Romanizer.prototype.format = function(num){
	var ret = "";
	if (num < 6000) {
		var numstr = num.toString().split("");
		numstr.reverse();
		var pos = 0;
		var n = 0;
		for (var pos in numstr){
			n = parseInt(numstr[pos],10);
			ret = CSL.ROMAN_NUMERALS[pos][n] + ret;
		}
	}
	return ret;
};
CSL.Util.Suffixator = function(slist){
	if (!slist){
		slist = CSL.SUFFIX_CHARS;
	}
	this.slist = slist.split(",");
};
CSL.Util.Suffixator.prototype.format = function(num){
	var suffixes = this.get_suffixes(num);
	return suffixes[(suffixes.length-1)];
}
CSL.Util.Suffixator.prototype.get_suffixes = function(num){
	var suffixes = new Array();
	for (var i=0; i <= num; i++){
		if (!i){
			suffixes.push([0]);
		} else {
			suffixes.push( this.incrementArray(suffixes[(suffixes.length-1)],this.slist) );
		}
	};
	for (pos in suffixes){
		var digits = suffixes[pos];
		var chrs = "";
		for each (digit in digits){
			chrs = chrs+this.slist[digit];
		}
		suffixes[pos] = chrs;
	};
	return suffixes;
};
CSL.Util.Suffixator.prototype.incrementArray = function (array){
	array = array.slice();
	var incremented = false;
	for (var i=(array.length-1); i > -1; i--){
		if (array[i] < (this.slist.length-1)){
			array[i] += 1;
			if (i < (array.length-1)){
				array[(i+1)] = 0;
			}
			incremented = true;
			break;
		}
	}
	if (!incremented){
		for (var i in array){
			array[i] = 0;
		}
		var newdigit = [0];
		array = newdigit.concat(array);
	}
	return array;
};
//		if (this.flipflops){
//			for each (var ff in this.flipflops){
//				style.fun.flipflopper.register( ff["start"], ff["end"], ff["func"], ff["alt"], ff["additive"] );
//			}
//		}
//>>===== FLIPFLOPS =====>>
//[
//  {
//    "start": "<span name=\"foreign-phrase\">",
//    "end": "</span>",
//    "func": ["@font-style", "italic"],
//    "alt": ["@font-style", "normal"]
//  }
//]
//<<===== FLIPFLOPS =====<<
//>>===== FLIPFLOPS =====>>
//[
//  {
//    "start":"'",
//    "end":"'",
//    "func":["@quotes","true"],
//    "alt":["@squotes","true"],
//    "additive":"true"
//  }
//]
//<<===== FLIPFLOPS =====<<
//>>===== FLIPFLOPS =====>>
//[
//    "start":"\"",
//    "end":"\"",
//    "func":["@quotes","true"],
//    "alt":["@squotes","true"],
//    "additive":"true"
//  },
//  {
//    "start":"'",
//    "end":"'",
//    "func":["@quotes","true"],
//    "alt":["@squotes","true"],
//    "additive":"true"
//  },
//  {
//    "start":"*",
//    "end":"*",
//    "func":["@font-weight","bold"],
//    "alt":["@font-weight","normal"],
//    "additive":"true"
//  }
//]
//<<===== FLIPFLOPS =====<<
CSL.Util.FlipFlopper = function(){
	this.flipflops = [];
	this.objlist = [];
	this.cont = true;
	this.stoplist = [];
};
CSL.Util.FlipFlopper.prototype.register = function(start, end, func, alt){
	var flipflop = {
		"start": start,
		"end": end,
		"func": func,
		"alt": alt
	};
	this.flipflops.push(flipflop);
};
CSL.Util.FlipFlopper.prototype.compose = function(blob){
	if (this.flipflops.length){
		this.stoplist = [];
		blob = this._compose(blob);
	}
	return blob;
}
CSL.Util.FlipFlopper.prototype._compose = function(blob){
	if (this.find(blob.blobs)){
		var str = blob.blobs;
		var flipflop = this.flipflops[this.fpos];
		var strlst = this.split(this.fpos, blob.blobs);
		if (strlst.length > 1){
			blob.blobs = new Array();
			//
			// Cast split items as unformatted objects for
			// a start.
			for (var j=0; j < strlst.length; j++){
				var tok = new CSL.Factory.Token();
				var newblob = new CSL.Factory.Blob(tok,strlst[j]);
				blob.push(newblob);
			}
			//
			// Apply registered formatting decorations to
			// every other element of the split, starting
			// with the second.
			//
			for (var j=1; j < blob.blobs.length; j += 2){
				this.applyFlipFlop(blob.blobs[j],flipflop,blob);
			}
			//
			// Install the bloblist and iterate over it
			//
			//blob.blobs = bloblist;
			for (var i in blob.blobs){
				blob.blobs[i] = this.compose(blob.blobs[i]);
			}
		} else {
			blob.blobs = strlst;
		}
	} // if find flipflop string inside blob
	return blob;
}
CSL.Util.FlipFlopper.prototype.find = function(str){
	this.fpos = -1;
	var min = [-1, -1];
	var values = [];
	var val = [];
	for (var i in this.flipflops){
		if (i in this.stoplist){
			continue;
		}
		val = [ i, str.indexOf(this.flipflops[i]["start"]) ];
		values.push(val.slice());
	}
	for each (var val in values){
		if (val[1] > min[1]){
			min = val;
		};
	}
	for each (var val in values){
		if (val[1] > -1 && val[1] < min[1]){
			min = val;
		}
	}
	this.fpos = min[0];
	if (this.fpos > -1){
		return true;
	}
	return false;
}
CSL.Util.FlipFlopper.prototype.applyFlipFlop = function(blob,flipflop){
	var found = false;
	var thing_to_add = flipflop.func;
	var breakme = false;
	for each (var blobdecorations in blob.alldecor){
		for (var i in blobdecorations){
			var decor = blobdecorations[i];
			var func_match = decor[0] == flipflop.func[0] && decor[1] == flipflop.func[1];
			var alt_match = decor[0] == flipflop.alt[0] && decor[1] == flipflop.alt[1];
			if (flipflop.alt && func_match){
				// replace with alt, mark as done
				thing_to_add = flipflop.alt;
				breakme = true;
				break;
			}
		}
		if (breakme){
			break;
		}
	}
	blob.decorations.reverse();
	blob.decorations.push( thing_to_add );
	blob.decorations.reverse();
};
CSL.Util.FlipFlopper.prototype.split = function(idx,str){
	var spec = this.flipflops[idx];
	var lst1 = str.split(spec["start"]);
	for (var i=(lst1.length-1); i > 0; i--){
		var first = lst1[(i-1)];
		var second = lst1[i];
		if ("\\" == first[(first.length-1)]){
			lst1[(i-1)] = first.slice(0,(first.length-1));
			var start = lst1.slice(0,i);
			start[(start.length-1)] += spec["start"];
			start[(start.length-1)] += lst1[i];
			var end = lst1.slice((i+1));
			lst1 = start.concat(end);
		}
	}
	if (lst1.length > 1){
		if (spec["start"] != spec["end"]){
			for (var i=(lst1.length-1); i > 0; i--){
				var sublst = lst1[i].split(spec["end"]);
				// reduce to a two-element list
				for (var j=(sublst.length-1); j > 1; j--){
					sublst[(j-1)] += spec["end"];
					sublst[(j-1)] += sublst[j];
					sublst.pop();
				}
				var start = lst1.slice(0,i);
				var end = lst1.slice((i+1));
				if (sublst.length == 1){
					start[(start.length-1)] += spec["start"];
					start[(start.length-1)] += sublst[0];
					lst1 = start.concat(end);
				} else {
					lst1 = start.concat(sublst).concat(end);
				}
			}
		} else {
			if (lst1.length && (lst1.length % 2) == 0){
				var buf = lst1.pop();
				lst1[(lst1.length-1)] += spec["start"];
				lst1[(lst1.length-1)] += buf;
			}
		}
	}
	return lst1;
}
CSL.Output = {};
CSL.Output.Number = function(num,mother_token){
	this.alldecor = new Array();
	this.num = num;
	this.blobs = num.toString();
	this.status = CSL.START;
	this.strings = new Object();
	if (mother_token){
		this.decorations = mother_token.decorations;
		this.strings.prefix = mother_token.strings.prefix;
		this.strings.suffix = mother_token.strings.suffix;
		this.successor_prefix = mother_token.successor_prefix;
		this.range_prefix = mother_token.range_prefix;
		this.splice_prefix = "";
		this.formatter = mother_token.formatter;
		if (!this.formatter){
			this.formatter =  new CSL.Output.DefaultFormatter();
		}
		if (this.formatter){
			this.type = this.formatter.format(1);
		}
	} else {
		this.decorations = new Array();
		this.strings.prefix = "";
		this.strings.suffix = "";
		this.successor_prefix = "";
		this.range_prefix = "";
		this.splice_prefix = "";
		this.formatter = new CSL.Output.DefaultFormatter();
	}
};
CSL.Output.Number.prototype.setFormatter = function(formatter){
	this.formatter = formatter;
	this.type = this.formatter.format(1);
};
CSL.Output.DefaultFormatter = function (){};
CSL.Output.DefaultFormatter.prototype.format = function (num){
	return num.toString();
};
//
// XXXXX: This needs a little attention.  Non-sequential numbers
// that follow other numbers should be marked SUCCESSOR.  They are
// currently marked START (i.e. they are ignored).  It looks like
// there are more combinations than can be expressed or handled
// with the three state flags in place at the moment.
//
CSL.Output.Number.prototype.checkNext = function(next){
	if ( ! next || ! next.num || this.type != next.type || next.num != (this.num+1)){
		if (this.status == CSL.SUCCESSOR_OF_SUCCESSOR){
			this.status = CSL.END;
		}
		if ("object" == typeof next){
			next.status = CSL.SEEN;
		}
	} else { // next number is in the sequence
		if (this.status == CSL.START || this.status == CSL.SEEN){
			next.status = CSL.SUCCESSOR;
		} else if (this.status == CSL.SUCCESSOR || this.status == CSL.SUCCESSOR_OF_SUCCESSOR){
			if (this.range_prefix){
				next.status = CSL.SUCCESSOR_OF_SUCCESSOR;
				this.status = CSL.SUPPRESS;
			} else {
				next.status = CSL.SUCCESSOR;
			}
		}
		// won't see this again, so no effect of processing, but this
		// wakes up the correct delimiter.
		if (this.status == CSL.SEEN){
			this.status = CSL.SUCCESSOR;
		}
	};
};
CSL.Output.Formatters = new function(){};
CSL.Output.Formatters.passthrough = function(state,string){
	return string;
};
//
// XXXXX
// A bit of interest coming up with vertical-align.
// This needs to include the prefixes and suffixes
// in its scope, so it's applied last, AFTER they
// are appended to the string.  I think it's the
// only one that will need to work that way.
CSL.Output.Formatters.lowercase = function(state,string) {
	if ("object" == typeof string){
		var ret = new Array();
		for each (item in string){
			ret.push(item.LowerCase());
		}
		return ret;
	}
	return string.LowerCase();
};
CSL.Output.Formatters.uppercase = function(state,string) {
	if ("object" == typeof string){
		var ret = new Array();
		for each (item in string){
			ret.push(item.toUpperCase());
		}
		return ret;
	}
	return string.toUpperCase();
};
CSL.Output.Formatters.capitalize_first = function(state,string) {
	return string[0].toUpperCase()+string.substr(1);
};
CSL.Output.Formatters.sentence_capitalization = function(state,string) {
	return string[0].toUpperCase()+string.substr(1).toLowerCase();
};
CSL.Output.Formatters.capitalize_all = function(state,string) {
	var strings = string.split(" ");
	for(var i=0; i<strings.length; i++) {
		if(strings[i].length > 1) {
            strings[i] = strings[i][0].toUpperCase()+strings[i].substr(1).toLowerCase();
        } else if(strings[i].length == 1) {
            strings[i] = strings[i].toUpperCase();
        }
    }
	return strings.join(" ");
};
CSL.Output.Formatters.title_capitalization = function(state,string) {
	if (!string) {
		return "";
	}
	var words = string.split(delimiterRegexp);
	var isUpperCase = string.toUpperCase() == string;
	var newString = "";
	var delimiterOffset = words[0].length;
	var lastWordIndex = words.length-1;
	var previousWordIndex = -1;
	for(var i=0; i<=lastWordIndex; i++) {
		// only do manipulation if not a delimiter character
		if(words[i].length != 0 && (words[i].length != 1 || !delimiterRegexp.test(words[i]))) {
			var upperCaseVariant = words[i].toUpperCase();
			var lowerCaseVariant = words[i].toLowerCase();
				// only use if word does not already possess some capitalization
				if(isUpperCase || words[i] == lowerCaseVariant) {
					if(
						// a skip word
						skipWords.indexOf(lowerCaseVariant.replace(/[^a-zA-Z]+/, "")) != -1
						// not first or last word
						&& i != 0 && i != lastWordIndex
						// does not follow a colon
						&& (previousWordIndex == -1 || words[previousWordIndex][words[previousWordIndex].length-1] != ":")
					) {
							words[i] = lowerCaseVariant;
					} else {
						// this is not a skip word or comes after a colon;
						// we must capitalize
						words[i] = upperCaseVariant[0] + lowerCaseVariant.substr(1);
					}
				}
				previousWordIndex = i;
		}
		newString += words[i];
	}
	return newString;
};
CSL.Output.Formats = function(){};
CSL.Output.Formats.prototype.html = {
	"@hanging-indent/bib":"<div style=\"line-height:2em;margin-left:0.5in;text-indent:-0.5in;\">\n%%STRING%%\n</div>",
	"@font-family":"<span style=\"font-family:%%PARAM%%\">%%STRING%%</span>",
	"@font-style/italic":"<i>%%STRING%%</i>",
	"@font-style/normal":"<span style=\"font-style:normal\">%%STRING%%</span>",
	"@font-style/oblique":"<em>%%STRING%%</em>",
	"@font-variant/small-caps":"<span style=\"font-variant:small-caps\">%%STRING%%</span>",
	"@font-variant/normal":false,
	"@font-weight/bold":"<b>%%STRING%%</b>",
	"@font-weight/normal":false,
	"@font-weight/light":false,
	"@text-decoration/none":false,
	"@text-decoration/underline":"<span style=\"text-decoration:underline\">%%STRING%%</span>",
	"@vertical-align/baseline":false,
	"@vertical-align/sup":"<sup>%%STRING%%</sup>",
	"@vertical-align/sub":"<sub>%%STRING%%</sub>",
	"@text-case/lowercase":CSL.Output.Formatters.lowercase,
	"@text-case/uppercase":CSL.Output.Formatters.uppercase,
	"@text-case/capitalize-first":CSL.Output.Formatters.capitalize_first,
	"@text-case/capitalize-all":CSL.Output.Formatters.capitalize_all,
	"@text-case/title":CSL.Output.Formatters.title_capitalization,
	"@text-case/sentence":CSL.Output.Formatters.sentence_capitalization,
	"@quotes/true":"&ldquo;%%STRING%%&rdquo;",
	"@quotes/left":"&ldquo;%%STRING%%",
	"@quotes/right":"%%STRING%%&rdquo;",
	"@quotes/noop":"%%STRING%%",
	"@squotes/true":"&lsquo;%%STRING%%&rsquo;",
	"@squotes/left":"&lsquo;%%STRING%%",
	"@squotes/right":"%%STRING%%&rsquo;",
	"@squotes/noop":"%%STRING%%",
	"@bibliography/wrapper": function(state,str){
		var cls = ["csl-bib-body"].concat(state.bibliography.opt["csl-bib-body"]).join(" ");
		return "<ul class=\""+cls+"\">\n"+str+"</ul>";
	},
	"@bibliography/entry": function(state,str){
		var cls = ["csl-bib-entry"].concat(state.bibliography.opt["csl-bib-entry"]).join(" ");
		return "<li class=\""+cls+"\">"+str+"</li>\n";
	},
	"@bibliography/first": function(state,str){
		//
		// The "first field" object could have a suffix ending
		// in a space.  The space needs to be placed beyond the
		// end of the span tag or it may vanish.
		//
		var start = str.length;
		for (var c=str.length; c>-1; c += -1){
			if (str[c] != " "){
				start = c;
				break;
			};
		};
		var cls = ["csl-bib-first"].concat(state.bibliography.opt["csl-bib-first"]).join(" ");
		return "<span class=\""+cls+"\">"+str.slice(0,start)+"</span>"+str.slice(start,str.length);
	},
	"@bibliography/other": function(state,str){
		//
		// See above.
		//
		var end = str.length;
		for (var c=0; c<str.length; c += 1){
			if (str[c] != " "){
				end = c;
				break;
			};
		};
		var cls = ["csl-bib-other"].concat(state.bibliography.opt["csl-bib-other"]).join(" ");
		return str.slice(0,end)+"<span class=\""+cls+"\">"+str.slice(end,str.length)+"</span>";
	}
};
CSL.Output.Formats = new CSL.Output.Formats();CSL.Output.Queue = function(state){
	this.state = state;
	this.queue = new Array();
	this.empty = new CSL.Factory.Token("empty");
	var tokenstore = {};
	tokenstore["empty"] = this.empty;
	this.formats = new CSL.Factory.Stack( tokenstore );
	this.current = new CSL.Factory.Stack( this.queue );
	this.suppress_join_punctuation = false;
};
CSL.Output.Queue.prototype.getToken = function(name){
	var ret = this.formats.value()[name];
	return ret;
};
// Store a new output format token based on another
CSL.Output.Queue.prototype.addToken = function(name,modifier,token){
	var newtok = new CSL.Factory.Token("output");
	if ("string" == typeof token){
		token = this.formats.value()[token];
	}
	if (token && token.strings){
		for (attr in token.strings){
			newtok.strings[attr] = token.strings[attr];
		}
		newtok.decorations = token.decorations;
	}
	if ("string" == typeof modifier){
		newtok.strings.delimiter = modifier;
	}
	this.formats.value()[name] = newtok;
};
//
// newFormat adds a new bundle of formatting tokens to
// the queue's internal stack of such bundles
CSL.Output.Queue.prototype.pushFormats = function(tokenstore){
	if (!tokenstore){
		tokenstore = new Object();
	}
	tokenstore["empty"] = this.empty;
	this.formats.push(tokenstore);
};
CSL.Output.Queue.prototype.popFormats = function(tokenstore){
	this.formats.pop();
};
CSL.Output.Queue.prototype.startTag = function(name,token){
	var tokenstore = new Object();
	tokenstore[name] = token;
	this.pushFormats( tokenstore );
	this.openLevel(name);
}
CSL.Output.Queue.prototype.endTag = function(){
	this.closeLevel();
	this.popFormats();
}
//
// newlevel adds a new blob object to the end of the current
// list, and adjusts the current pointer so that subsequent
// appends are made to blob list of the new object.
CSL.Output.Queue.prototype.openLevel = function(token){
	if (!this.formats.value()[token]){
		throw "CSL processor error: call to nonexistent format token \""+token+"\"";
	}
	var blob = new CSL.Factory.Blob(this.formats.value()[token]);
	var curr = this.current.value();
	curr.push( blob );
	this.current.push( blob );
};
CSL.Output.Queue.prototype.closeLevel = function(name){
	this.current.pop();
}
//
// append does the same thing as newlevel, except
// that the blob it pushes has text content,
// and the current pointer is not moved after the push.
CSL.Output.Queue.prototype.append = function(str,tokname){
	var blob = false;
	if (!tokname){
		var token = this.formats.value()["empty"];
	} else if (tokname == "literal"){
		var token = true;
		blob = str;
	} else if ("string" == typeof tokname){
		var token = this.formats.value()[tokname];
	} else {
		var token = tokname;
	}
	if (!token){
		throw "CSL processor error: unknown format token name: "+tokname;
	}
	if (!blob){
		blob = new CSL.Factory.Blob(token,str);
	}
	var bloblist = this.state.fun.flipflopper.compose(blob);
	if (bloblist.length > 1){
		this.openLevel("empty");
		var curr = this.current.value();
		for each (var blobbie in bloblist){
			if ("string" == typeof blobbie.blobs){
				this.state.tmp.term_predecessor = true;
			}
			curr.push( blobbie );
		}
		this.closeLevel();
	} else {
		var curr = this.current.value();
		if ("string" == typeof blob.blobs){
			this.state.tmp.term_predecessor = true;
		}
		curr.push( blob );
	}
}
//
// Maybe the way to do this is to take it by layers, and
// analyze a FLAT list of blobs returned during recursive
// execution.  If the list is all numbers and there is no
// group decor, don't touch it.  If it ends in numbers,
// set the group delimiter on the first in the series,
// and join the strings with the group delimiter.  If it
// has numbers followed by strings, render each number
// in place, and join with the group delimiter.  Return
// the mixed flat list, and recurse upward.
//
// That sort of cascade should work, and should be more
// easily comprehensible than this mess.
//
CSL.Output.Queue.prototype.string = function(state,myblobs,blob){
	var blobs = myblobs.slice();
	var ret = new Array();
	if (blobs.length == 0){
		return ret;
	}
	for (var i in blobs){
		var blobjr = blobs[i];
		if ("string" == typeof blobjr.blobs){
			if ("number" == typeof blobjr.num){
				ret.push(blobjr);
			} else if (blobjr.blobs){
				// skip empty strings!!!!!!!!!!!!
				var b = blobjr.blobs;
				if (!state.tmp.suppress_decorations){
					for each (var params in blobjr.decorations){
						b = state.fun.decorate[params[0]][params[1]](state,b);
					}
				}
				if (b[(b.length-1)] == "." && blobjr.strings.suffix && blobjr.strings.suffix[0] == "."){
					b = blobjr.strings.prefix + b + blobjr.strings.suffix.slice(1);
				} else {
					b = blobjr.strings.prefix + b + blobjr.strings.suffix;
				}
				ret.push(b);
			};
		} else if (blobjr.blobs.length){
			var addtoret = state.output.string(state,blobjr.blobs,blobjr);
			ret = ret.concat(addtoret);
		} else {
			continue;
		}
	};
	var span_split = 0;
	for (var j in ret){
		if ("string" == typeof ret[j]){
			span_split = (parseInt(j,10)+1);
		}
	}
	if (blob && (blob.decorations.length || blob.strings.suffix || blob.strings.prefix)){
		span_split = ret.length;
	}
	if (blob){
		var blob_delimiter = blob.strings.delimiter;
	} else {
		var blob_delimiter = "";
	}
	var blobs_start = state.output.renderBlobs( ret.slice(0,span_split), blob_delimiter );
	if (blobs_start && blob && (blob.decorations.length || blob.strings.suffix || blob.strings.prefix)){
		if (!state.tmp.suppress_decorations){
			for each (var params in blob.decorations){
				blobs_start = state.fun.decorate[params[0]][params[1]](state,blobs_start);
			}
		}
		//
		// XXXX: this is same as a code block above, factor out with
		// code above as model
		//
		var b = blobs_start;
		if (b[(b.length-1)] == "." && blob.strings.suffix && blob.strings.suffix[0] == "."){
			b = blob.strings.prefix + b + blob.strings.suffix.slice(1);
		} else {
			b = blob.strings.prefix + b + blob.strings.suffix;
		}
		blobs_start = b;
	}
	var blobs_end = ret.slice(span_split,ret.length);
	if (!blobs_end.length && blobs_start){
		ret = [blobs_start];
	} else if (blobs_end.length && !blobs_start) {
		ret = blobs_end;
	} else if (blobs_start && blobs_end.length) {
		ret = [blobs_start].concat(blobs_end);
	}
	if ("undefined" == typeof blob){
		this.queue = new Array();
		this.current.mystack = new Array();
		this.current.mystack.push( this.queue );
		if (state.tmp.suppress_decorations){
			ret = state.output.renderBlobs(ret);
		}
	} else if ("boolean" == typeof blob){
		ret = state.output.renderBlobs(ret);
	}
	return ret;
};
CSL.Output.Queue.prototype.clearlevel = function(){
	var blob = this.current.value();
	for (var i=(blob.blobs.length-1); i > -1; i--){
		blob.blobs.pop();
	}
};
CSL.Output.Queue.prototype.renderBlobs = function(blobs,delim){
	if (!delim){
		delim = "";
	}
	var state = this.state;
	var ret = "";
	var use_delim = "";
	for (var i=0; i < blobs.length; i++){
		if (blobs[i].checkNext){
			blobs[i].checkNext(blobs[(i+1)]);
		}
	}
	for each (var blob in blobs){
		if (ret){
			use_delim = delim;
		}
		if ("string" == typeof blob){
			//throw "Attempt to render string as rangeable blob"
			ret += use_delim;
			ret += blob;
		} else if (blob.status != CSL.SUPPRESS){
			// print("doing rangeable blob");
			//var str = blob.blobs;
			var str = blob.formatter.format(blob.num);
			if (!state.tmp.suppress_decorations){
				for each (var params in blob.decorations){
					str = state.fun.decorate[params[0]][params[1]](state,str);
				}
			}
			//if (!suppress_decor){
				str = blob.strings.prefix + str + blob.strings.suffix;
			//}
			if (blob.status == CSL.END){
				//
				// XXXXX needs to be drawn from the object
				ret += blob.range_prefix;
			} else if (blob.status == CSL.SUCCESSOR){
				ret += blob.successor_prefix;
			} else if (blob.status == CSL.START){
				ret += blob.splice_prefix;
			}
			ret += str;
		}
	}
	return ret;
};
//
// should allow batched registration of items by
// key.  should behave as an update, with deletion
// of items and the tainting of disambiguation
// partner sets affected by a deletes and additions.
//
//
// we'll need a reset method, to clear the decks
// in the citation area and start over.
CSL.Factory.Registry = function(state){
	this.debug = false;
	this.debug_sort = false;
	if (this.debug){
		print("---> Instantiate registry");
	}
	this.registry = new Object();
	this.ambigs = new Object();
	this.start = false;
	this.end = false;
	this.initialized = false;
	this.skip = false;
	this.maxlength = 0;
	this.sorter = new CSL.Factory.Registry.Comparifier(state,"bibliography_sort");
	this.getSortedIds = function(){
		var step = "next";
		var item_id = this.start;
		var ret = new Array();
		while (true){
			ret.push(item_id);
			item_id = this.registry[item_id][step];
			if ( ! item_id){
				break;
			}
		}
		return ret;
	};
};
CSL.Factory.Registry.prototype.insert = function(state,Item){
	if (this.debug){
		print("---> Start of insert");
	}
	if (this.registry[Item.id]){
		return;
	}
	var sortkeys = state.getSortKeys(Item,"bibliography_sort");
	var akey = state.getAmbiguousCite(Item);
	var abase = state.getAmbigConfig();
	var modes = state.getModes();
	var newitem = {
		"id":Item.id,
		"seq":1,
		"dseq":0,
		"sortkeys":sortkeys,
		"disambig":abase,
		"prev":false,
		"next":false
	};
	if (this.debug){
		print("---> Begin manipulating registry");
	}
	var breakme = false;
	if (!this.initialized){
		if (this.debug_sort){
			print("-->initializing registry with "+newitem.id);
		}
		this.registry[newitem.id] = newitem;
		this.start = newitem.id;
		this.end = newitem.id;
		this.initialized = true;
		//
		// XXXXX
		//this.registerAmbigToken(state,akey,Item.id,abase.slice());
		this.registerAmbigToken(state,akey,Item.id,abase);
		return;
	}
	if (-1 == this.sorter.compareKeys(newitem.sortkeys,this.registry[this.start].sortkeys)){
		if (this.debug_sort){
			print("-->inserting "+newitem.id+" before "+this.start+" as first entry");
		}
		newitem.next = this.registry[this.start].id;
		this.registry[this.start].prev = newitem.id;
		newitem.prev = false;
		newitem.seq = 1;
		var tok = this.registry[this.start];
		this.incrementSubsequentTokens(tok);
		this.start = newitem.id;
		this.registry[newitem.id] = newitem;
		breakme = true;
	}
	if (-1 == this.sorter.compareKeys(this.registry[this.end].sortkeys,newitem.sortkeys)  && !breakme){
		if (this.debug_sort){
			print("-->inserting "+newitem.id+" after "+this.end+" as last entry");
		}
		newitem.prev = this.registry[this.end].id;
		this.registry[this.end].next = newitem.id;
		newitem.next = false;
		newitem.seq = (this.registry[this.end].seq + 1);
		this.end = newitem.id;
		this.registry[newitem.id] = newitem;
		breakme = true;
	}
	var curr = this.registry[this.end];
	while (true && !breakme){
		// compare the new token to be added with
		// the one we're thinking about placing it after.
		var cmp = this.sorter.compareKeys(curr.sortkeys,newitem.sortkeys);
		if (cmp == -1){
			if (this.debug_sort){
				print("-->inserting "+newitem.id+" after "+curr.id);
			}
			// insert mid-list, after the tested item
			this.registry[curr.next].prev = newitem.id;
			newitem.next = curr.next;
			newitem.prev = curr.id;
			curr.next = newitem.id;
			newitem.seq = (curr.seq+1);
			this.incrementSubsequentTokens(this.registry[newitem.next]);
			this.registry[newitem.id] = newitem;
			breakme = true;
			break;
		} else if (cmp == 2){
			breakme = true;
		} else if (cmp == 0) {
			// insert _after_, but this one is equivalent
			// to the comparison partner for sortkey purposes
			// (so we needed to provide for cases where the
			// inserted object ends up at the end of
			// the virtual list.)
			if (false == curr.next){
				if (this.debug_sort){
					print("-->inserting "+newitem.id+" after "+curr.id+" as last entry, although equal");
				}
				newitem.next = false;
				newitem.prev = curr.id;
				curr.next = newitem.id;
				newitem.seq = (curr.seq+1);
				//this.incrementSubsequentTokens(curr);
				this.registry[newitem.id] = newitem;
				this.end = newitem.id;
				breakme = true;
				break;
			} else {
				if (this.debug_sort){
					print("-->inserting "+newitem.id+" after "+curr.id+", although equal");
				}
				this.registry[curr.next].prev = newitem.id;
				newitem.next = curr.next;
				newitem.prev = curr.id;
				curr.next = newitem.id;
				newitem.seq = curr.seq;
				this.registry[newitem.id] = newitem;
				this.incrementSubsequentTokens(newitem);
				breakme = true;
				break;
			}
		}
		if (breakme){
			break;
		}
		//
		// we scan in reverse order, because working
		// from the initial draft of the code, this
		// makes it simpler to order cites in submission
		// order, when no sort keys are available.
		curr = this.registry[curr.prev];
	};
	if (this.debug){
		print("---> End of registry insert");
	}
	this.registerAmbigToken(state,akey,Item.id,abase);
	if (this.ambigs[akey].length > 1){
		if (modes.length){
			if (this.debug){
				print("---> Names disambiguation begin");
			}
			var leftovers = this.disambiguateCites(state,akey,modes);
			if (this.debug){
				print("---> Names disambiguation done");
			}
			//
			// leftovers is a list of registry tokens.  sort them.
			leftovers.sort(this.compareRegistryTokens);
		} else {
			//
			// if we didn't disambiguate with names, everything is
			// a leftover.
			var leftovers = new Array();
			for each (var key in this.ambigs[akey]){
				leftovers.push(this.registry[key]);
				leftovers.sort(this.compareRegistryTokens);
			}
		}
	}
	if (leftovers && leftovers.length && state.opt.has_disambiguate){
		var leftovers = this.disambiguateCites(state,akey,modes,leftovers);
	}
	if ( leftovers && leftovers.length && state[state.tmp.area].opt["disambiguate-add-year-suffix"]){
		//var suffixes = state.fun.suffixator.get_suffixes(leftovers.length);
		for (var i in leftovers){
			this.registry[ leftovers[i].id ].disambig[2] = i;
			this.registry[ leftovers[i].id ].dseq = i;
		}
	}
	if (this.debug) {
		print("---> End of registry cleanup");
	}
};
CSL.Factory.Registry.Comparifier = function(state,keyset){
	var sort_directions = state[keyset].opt.sort_directions.slice();
    this.compareKeys = function(a,b){
		for (var i=0; i < a.length; i++){
			//
			// for ascending sort 1 uses 1, -1 uses -1.
			// For descending sort, the values are reversed.
			var cmp = a[i].toLocaleLowerCase().localeCompare(b[i].toLocaleLowerCase());
			if (0 < cmp){
				return sort_directions[i][1];
			} else if (0 > cmp){
				return sort_directions[i][0];
			}
		}
		return 0;
	};
};
CSL.Factory.Registry.prototype.compareRegistryTokens = function(a,b){
	if (a.seq > b.seq){
		return 1;
	} else if (a.seq < b.seq){
		return -1;
	}
	return 0;
};
CSL.Factory.Registry.prototype.incrementSubsequentTokens = function (tok){
	while (tok.next){
		tok.seq += 1;
		tok = this.registry[tok.next];
	}
	tok.seq += 1;
};
var debug = false;
CSL.Factory.Registry.prototype.disambiguateCites = function (state,akey,modes,candidate_list){
	if ( ! candidate_list){
		//
		// We start with the state and an ambig key.
		// We acquire a copy of the list of ambigs that relate to the key from state.
		var ambigs = this.ambigs[akey].slice();
		//
		// We clear the list of ambigs so it can be rebuilt
		this.ambigs[akey] = new Array();
	} else {
		//var ambigs = this.ambigs[akey].slice();
		//this.ambigs[akey] = new Array();
		// candidate list consists of registry tokens.
		// extract the ids and build an ambigs list.
		// This is roundabout -- we already collected
		// these once for the first-phase disambiguation.
		// Maybe it can be cleaned up later.
		//
		// XXXXX: ??? same as above?
		//
		var ambigs = new Array();
		for each (var reg_token in candidate_list){
			ambigs.push(reg_token.id);
			var keypos = this.ambigs[akey].indexOf(reg_token.id);
			if (keypos > -1){
				this.ambigs[akey] = this.ambigs[akey].slice(0,keypos).concat(this.ambigs[akey].slice((keypos+1)));
			}
		}
	}
	var id_vals = new Array();
	for each (var a in ambigs){
		id_vals.push(a);
	}
	var tokens = state.sys.retrieveItems(id_vals);
	if (candidate_list && candidate_list.length){
		modes = ["disambiguate_true"].concat(modes);
	}
	var checkerator = new this.Checkerator(tokens,modes);
	checkerator.lastclashes = (ambigs.length-1);
	var base = false;
	checkerator.pos = 0;
	while (checkerator.run()){
		var token = tokens[checkerator.pos];
		if (debug){
			print("<<<<<<<<<<<<<<<<<<<<<<<<< "+ token.id +" >>>>>>>>>>>>>>>>>>>>>>>>>>>");
		}
		//
		// skip items that have been finally resolved.
		if (this.ambigs[akey].indexOf(token.id) > -1){
			if (debug){
				print("---> Skip registered token for: "+token.id);
			}
			checkerator.pos += 1;
			continue;
		}
		checkerator.candidate = token.id;
		if (base == false){
			checkerator.mode = modes[0];
		}
		if (debug){
			print ("  ---> Mode: "+checkerator.mode);
		}
		if (debug){
			print("base in (givens):"+base["givens"]);
		}
		var str = state.getAmbiguousCite(token,base);
		var maxvals = state.getMaxVals();
		var minval = state.getMinVal();
		base = state.getAmbigConfig();
		if (debug){
			print("base out (givens):"+base["givens"]);
		}
		//
		// XXXXX: scrap this?
		//
		if (candidate_list && candidate_list.length){
			base["disambiguate"] = true;
		}
		//if (disambiguate_true){
		//	print("D TRUE");
		//	base["disambiguate"] = true;
		//}
		checkerator.setBase(base);
		checkerator.setMaxVals(maxvals);
		checkerator.setMinVal(minval);
		for each (testpartner in tokens){
			if (token.id == testpartner.id){
				continue;
			}
			var otherstr = state.getAmbiguousCite(testpartner,base);
			if (debug){
				print("  ---> last clashes: "+checkerator.lastclashes);
				print("  ---> master:    "+token.id);
				print("  ---> master:    "+str);
				print("  ---> partner: "+testpartner.id);
				print("  ---> partner: "+otherstr);
			}
			if(checkerator.checkForClash(str,otherstr)){
				break;
			}
		}
		if (checkerator.evaluateClashes()){
			var base_return = this.decrementNames(state,base);
			this.registerAmbigToken(state,akey,token.id,base_return);
			checkerator.seen.push(token.id);
			if (debug){
				print("  ---> Evaluate: storing token config: "+base);
			}
			continue;
		}
		if (checkerator.maxAmbigLevel()){
			if ( ! state["citation"].opt["disambiguate-add-year-suffix"]){
				//this.registerAmbigToken(state,akey,token.id,base);
				checkerator.mode1_counts = false;
				checkerator.maxed_out_bases[token.id] = CSL.Factory.cloneAmbigConfig(base);
				if (debug){
					print("  ---> Max out: remembering token config for: "+token.id);
					print("       ("+base["names"]+":"+base["givens"]+")");
				}
			} else {
				if (debug){
					print("  ---> Max out: NOT storing token config for: "+token.id);
					print("       ("+base["names"]+":"+base["givens"]+")");
				}
			}
			checkerator.seen.push(token.id);
			base = false;
			continue;
		}
		if (debug){
			print("  ---> Incrementing");
		}
		checkerator.incrementAmbigLevel();
	}
	var ret = new Array();
	for each (id in checkerator.ids){
		if (id){
			ret.push(this.registry[id]);
		}
	}
	for (i in checkerator.maxed_out_bases){
		this.registry[i].disambig = checkerator.maxed_out_bases[i];
	}
	return ret;
};
CSL.Factory.Registry.prototype.Checkerator = function(tokens,modes){
	this.seen = new Array();
	this.modes = modes;
	this.mode = this.modes[0];
	this.tokens_length = tokens.length;
	this.pos = 0;
	this.clashes = 0;
	this.maxvals = false;
	this.base = false;
	this.ids = new Array();
	this.maxed_out_bases = new Object();
	for each (token in tokens){
		this.ids.push(token.id);
	}
	this.lastclashes = -1;
	this.namepos = 0;
	this.modepos = 0;
	this.mode1_counts = false;
};
CSL.Factory.Registry.prototype.Checkerator.prototype.run = function(){
	if (this.seen.length < this.tokens_length){
		return true;
	}
	return false;
}
CSL.Factory.Registry.prototype.Checkerator.prototype.setMaxVals = function(maxvals){
	this.maxvals = maxvals;
};
CSL.Factory.Registry.prototype.Checkerator.prototype.setMinVal = function(minval){
	this.minval = minval;
};
CSL.Factory.Registry.prototype.Checkerator.prototype.setBase = function(base){
	this.base = base;
	if (! this.mode1_counts){
		this.mode1_counts = new Array();
		for each (i in this.base["givens"]){
			this.mode1_counts.push(0);
		}
	}
};
CSL.Factory.Registry.prototype.Checkerator.prototype.setMode = function(mode){
	this.mode = mode;
};
CSL.Factory.Registry.prototype.Checkerator.prototype.checkForClash = function(str,otherstr){
	if (str == otherstr){
		if (this.mode == "names" || this.mode == "disambiguate_true"){
			this.clashes += 1;
			if (debug){
				print("   (mode 0 clash, returning true)");
			}
			return true;
		}
		if (this.mode == "givens"){
			this.clashes += 1;
			if (debug){
				print("   (mode 1 clash, returning false)");
			}
		}
		return false;
	}
};
CSL.Factory.Registry.prototype.Checkerator.prototype.evaluateClashes = function(){
	if (!this.maxvals.length){
		return false;
	}
	if (this.mode == "names" || this.mode == "disambiguate_true"){
		if (this.clashes){
			this.lastclashes = this.clashes;
			this.clashes = 0;
			return false;
		} else {
			// cleared, so increment.  also quash the id as done.
			this.ids[this.pos] = false;
			this.pos += 1;
			this.lastclashes = this.clashes;
			return true;
		}
	}
	if (this.mode == "givens"){
		var ret = true;
		if (debug){
			print("  ---> Comparing in mode 1: clashes="+this.clashes+"; lastclashes="+this.lastclashes);
		}
		var namepos = this.mode1_counts[this.modepos];
		if (this.clashes && this.clashes == this.lastclashes){
			if (debug){
				print("   ---> Applying mode 1 defaults: "+this.mode1_defaults);
			}
			if (this.mode1_defaults){
				var old = this.mode1_defaults[(namepos-1)];
				if (debug){
					print("   ---> Resetting to default: ("+old+")");
				}
				this.base["givens"][this.modepos][(namepos-1)] = old;
			}
			ret = false;
		} else if (this.clashes) {
			if (debug){
				print("   ---> Expanding given name helped a little, retaining it");
			}
			ret = false;
		} else { // only non-clash should be possible
			if (debug){
				print("   ---> No clashes, storing token config and going to next");
			}
			this.mode1_counts = false;
			ret = true;
		}
		this.lastclashes = this.clashes;
		this.clashes = 0;
		if (ret){
			this.ids[this.pos] = false;
		}
		return ret;
	}
};
CSL.Factory.Registry.prototype.Checkerator.prototype.maxAmbigLevel = function (){
	if (!this.maxvals.length){
		return true;
	}
	if (this.mode == "disambiguate_true"){
		if (this.modes.indexOf("disambiguate_true") < (this.modes.length-1)){
			this.mode = this.modes[(this.modes.indexOf("disambiguate_true")+1)];
			this.modepos = 0;
		} else {
			this.pos += 1;
			return true;
		}
	}
	if (this.mode == "names"){
		//print(this.modepos+" : "+this.base[0].length+" : "+this.base[0][this.modepos]);
		if (this.modepos == (this.base["names"].length-1) && this.base["names"][this.modepos] == this.maxvals[this.modepos]){
			//
			// XXXXX: needs to be smarter?
			//
			//if (this.modes.indexOf("names") < (this.modes.length-1)){
			//	this.mode = this.modes[(this.modes.indexOf("names")+1)];
			//	this.modepos = 0;
			if (this.modes.length == 2){
				this.mode = "givens";
				this.modepos = 0;
				//this.pos = 0;
			} else {
				this.pos += 1;
				return true;
			}
		}
	}
	if (this.mode == "givens"){
		if (this.modepos == (this.mode1_counts.length-1) && this.mode1_counts[this.modepos] == (this.maxvals[this.modepos])){
			if (debug){
				print("-----  Item maxed out -----");
			}
			if (this.modes.length == 2){
				this.mode = "givens";
				this.pos += 1;
			} else {
				this.pos += 1;
			}
			//this.ids[this.pos] = false;
			return true;
		}
	}
	return false;
};
CSL.Factory.Registry.prototype.Checkerator.prototype.incrementAmbigLevel = function (){
	if (this.mode == "names"){
		var val = this.base["names"][this.modepos];
		if (val < this.maxvals[this.modepos]){
			this.base["names"][this.modepos] += 1;
		} else if (this.modepos < (this.base["names"].length-1)){
			this.modepos +=1;
			this.base["names"][this.modepos] = 0;
		}
	}
	if (this.mode == "givens"){
		var val = (this.mode1_counts[this.modepos]);
		if (val < this.maxvals[this.modepos]){
			this.mode1_counts[this.modepos] += 1;
			this.mode1_defaults = this.base["givens"][this.modepos].slice();
			this.base["givens"][this.modepos][val] += 1;
			if (debug){
				print("   ---> (A) Set expanded givenname param with base: "+this.base["givens"]);
			}
		} else if (this.modepos < (this.base["givens"].length-1)){
			this.modepos +=1;
			this.base["givens"][this.modepos][0] += 1;
			this.mode1_defaults = this.base["givens"][this.modepos].slice();
			if (debug){
				print("   ---> (B) Set expanded givenname param with base: "+this.base["givens"]);
			}
		} else {
			this.mode = "names";
			this.pos += 1;
		}
	}
};
CSL.Factory.Registry.prototype.registerAmbigToken = function (state,akey,id,ambig_config){
	if ( ! this.ambigs[akey]){
		this.ambigs[akey] = new Array();
	};
	var found = false;
	for (var i in this.ambigs[akey]){
		if (this.ambigs[akey].indexOf(id) > -1){
			found = true;
		}
	}
	if (!found){
		this.ambigs[akey].push(id);
	}
	this.registry[id].disambig = CSL.Factory.cloneAmbigConfig(ambig_config);
};
CSL.Factory.Registry.prototype.decrementNames = function(state,base){
	var base_return = CSL.Factory.cloneAmbigConfig(base);
	var do_me = false;
	for (var i=(base_return["givens"].length-1); i > -1; i--){
		for (var j=(base_return["givens"][i].length-1); j > -1; j--){
			if (base_return["givens"][i][j] == 2){
				do_me = true;
			}
		}
	}
	if (do_me){
		for (var i=(base_return["givens"].length-1); i > -1; i--){
			for (var j=(base_return["givens"][i].length-1); j > -1; j--){
				if (base_return["givens"][i][j] == 2){
					i = -1;
					break;
				}
				base_return["names"][i] += -1;
			}
		}
	}
	return base_return;
};
