//alert(pp_domain);
var PP = {};
IS_WEBIMPORT = true;

function loadCss(css_file) {
  var headID = document.getElementsByTagName("head")[0];
  var s = document.createElement('link');
  s.type = 'text/css';
  s.rel = 'stylesheet';
  s.href = pp_domain + css_file;
  //  s.media = 'screen';
  headID.appendChild(s);
}

function loadScript(file, callback) {
  js = document.createElement('script');
  js.setAttribute('type', 'text/javascript');
  js.setAttribute('src', pp_domain + file);
  document.getElementsByTagName('body')[0].appendChild(js);

  js.onreadystatechange = function() {
    if (js.readyState == 'complete') {
      callback();
    }
  }
  js.onload = function() {
    callback();
  }

}

var styles = ['/ext/resources/css/structure/qtips.css', '/ext/resources/css/xtheme-gray.css', '/css/web-import.css', '/css/paperpile.css'];
for (var i = 0; i < styles.length; i++) {
  loadCss(styles[i]);
}

// Decide which adaptor to use -- if the page already has JQuery (pubmed does),
// use the jquery adaptor.
var adapterScript = '/ext/adapter/ext/ext-base-debug.js';
if (typeof jQuery != 'undefined') {
  adapterScript = '/ext/adapter/jquery/ext-jquery-adapter-debug.js';
}

// Load these scripts in order, using a counter to proceed with injection only when the next one's ready.
var scripts = [adapterScript, '/ext/ext-all-debug.js', '/scripts/x-domain.js', '/js/misc/status.js'];
var loaded_count = 0;
function load_next() {
  if (loaded_count == scripts.length) {
    PP.onLoad();
  } else {
    loadScript(scripts[loaded_count++], load_next);
  }
};

load_next();

PP.init = function() {
  Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
  Ext.ns('Paperpile');

  IS_TITANIUM = !(window['Titanium'] == undefined);
  IS_CHROME = navigator.userAgent.toLowerCase().indexOf('chrome') > -1;
  IS_WEBIMPORT = !(window['PP'] == undefined);

  Paperpile.Url = function(url) {
    return (IS_TITANIUM || IS_WEBIMPORT) ? 'http://127.0.0.1:3210' + url : url;
  };

  Paperpile.log = function() {
    if (IS_TITANIUM) {
      Titanium.API.debug(arguments[0]);
    } else if (IS_CHROME) {
      console.log(arguments[0]);
    } else if (window.console) {
      console.log(arguments);
    }
  };
};

PP.onLoad = function() {
  PP.init();
  if (Paperpile.webImporter === undefined) {
    Paperpile.WebImporter = Ext.extend(Object, {
	page_type:null,
	list_type:null,
      handleStatusAction: function(actionType) {
        if (actionType == 'ACTION2') {
          this.clearEntries();
          Paperpile.status.clearMsg();
        } else {
          this.handleImportAll();
        }
      },
      handleFinishedAction: function(actionType) {
        this.clearEntries();
        Paperpile.status.clearMsg();
      },
      handleImportButton: function(event, target, object) {
        var target = event.getTarget();
        var el = Ext.get(target);
        var entry = object.entry;

        this.handleImport([entry], false);
      },
      handleImportAll: function() {
        Paperpile.status.showBusy('Importing all references');

        for (var i = 0; i < this.entries.length; i++) {
          var entry = this.entries[i];
          var delay = i * 500;
	  entry.working = true;
          this.handleImport.defer(delay, this, [
            [entry], true]);
        }
      },
      updateListStatus: function() {
        var numEntries = this.entries.length;
        var successEntries = 0;
        var existEntries = 0;
        var workingEntries = 0;
        var failedEntries = 0;
        for (var i = 0; i < this.entries.length; i++) {
          var e = this.entries[i];
          if (e.working) {
            workingEntries++;
          } else {
            if (e.status == 'success') {
              successEntries++;
            } else if (e.status == 'exists') {
              existEntries++;
            } else if (e.status == 'failure'){
              failedEntries++;
            }
          }
        }

        if (workingEntries > 0) {
          return;
        }

        var results = [
          successEntries > 0 ? successEntries + ' imported' : '',
          existEntries > 0 ? existEntries + ' existing' : '',
          failedEntries > 0 ? failedEntries + ' failed' : ''];
        var cleanResults = [];
        for (var i = 0; i < results.length; i++) {
          if (results[i] != '') {
            cleanResults.push(results[i]);
          }
        }
        var parens = cleanResults.length > 0 ? ' (' + cleanResults.join(', ') + ')' : '';
        var msg = 'Finished importing references' + parens + '.';

        Paperpile.status.updateMsg({
          type: 'info',
          msg: msg,
          action1: 'Clear',
          callback: Paperpile.webImporter.handleFinishedAction,
        });
      },
      buttonForEntry: function(entry) {
//        Paperpile.log(entry);
//        Paperpile.log(entry.link_id);
        return Ext.get('pp-entry-button-' + entry.link_id);
      },
      findEntry: function(link_id) {
        var entries = this.entries;
	  if (entries === undefined) {
	      return null;
	  }
        for (var i = 0; i < this.entries.length; i++) {
          if (this.entries[i].link_id === link_id) {
            return this.entries[i];
          }
        }
        return null;
      },
      buttonWorking: function(entry) {
        this.buttonForEntry(entry).update('<img src="' + Paperpile.Url('/images/icons/job-running.gif') + '"/>');
      },
      buttonSuccess: function(entry) {
        this.buttonForEntry(entry).update('<img src="' + Paperpile.Url('/images/icons/tick.png') + '"/>');
        this.tooltipForEntry(entry, "Successfully imported <b>" + entry.pub._citation_display + "</b> into your library.")
      },
      buttonExists: function(entry) {
        this.buttonForEntry(entry).update('<img id="img-' + entry.link_id + '" src="' + Paperpile.Url('/images/icons/page.png') + '"/>');
        this.tooltipForEntry(entry, "Reference <b>" + entry.pub._citation_display + "</b> already exists in your library.");
      },
      buttonFailure: function(entry) {
        this.buttonForEntry(entry).update('<img src="' + Paperpile.Url('/images/icons/error.png') + '"/>');
        this.tooltipForEntry(entry, entry.error);
      },
      tooltipForEntry: function(entry, html) {
        var el = this.buttonForEntry(entry);
        var tip = new Ext.ToolTip({
          anchor: 'left',
          showDelay: 0,
          hideDelay: 0,
          html: html,
          target: el.id
        });
      },
      removeListener: function(entry) {
        this.buttonForEntry(entry).un('click', Paperpile.webImporter.handleImportButton, Paperpile.webImporter);
        this.buttonForEntry(entry).setStyle('cursor', 'default');
      },
      handleImport: function(entries, updateStatus) {
        var linkIds = [];
        for (var i = 0; i < entries.length; i++) {
          var link_id = entries[i].link_id;
          linkIds.push(link_id);
          this.buttonWorking(entries[i]);
          entries[i].working = true;
        }

        var url = window.location.href;

        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/webimport/import_urls'),
          params: {
            link_ids: linkIds,
            url: url,
            label: 'web-import',
            folder: 'asdf'
          },
          method: 'GET',
          scriptTag: false,
          disableCaching: true,
          success: function(response) {
            var json = Ext.util.JSON.decode(response.responseText);

            var results = json.results;
            for (var i = 0; i < results.length; i++) {
              var result = results[i];
              var entry = this.findEntry(result.link_id);
              Ext.apply(entry, result);
              if (result.status == 'success') {
                this.buttonSuccess(result);
              } else if (result.status == 'exists') {
                this.buttonExists(result);
              } else if (result.status == 'failure') {
                this.buttonFailure(result);
              }
              this.removeListener(result);
              this.findEntry(result.link_id).working = false;
            }
            //Paperpile.status.clearMsg();
            if (updateStatus) {
              this.updateListStatus();
            }
          },
          failure: function(response) {
            for (var i = 0; i < entries.length; i++) {
              var entry = entries[i];
              this.buttonFailure(entry);
              this.removeListener(entry);
              entry.working = false;
              entry.status = 'failure';
            }
            if (updateStatus) {
              this.updateListStatus();
            }
          },
          scope: this
        });
      },
      loadEntries: function(entries) {
        this.entries = entries;
        for (var i = 0; i < entries.length; i++) {
          var entry = entries[i];
          var link_id = entry.link_id;
          var selector = entry.selector;
          var el = Ext.select(selector, true);
          var first = el.first();
	    first.setStyle('z-index','50');
	    first.setStyle('position','relative');
	    var z = 0;
	    if (this.list_type == 'pubmed_list') {
		// Something about pubmed doesn't like a -1 z-index.
		z = 0;
	    }
          var highlightEl = Ext.DomHelper.append(document.body, {
            id: 'pp-entry-highlight-' + link_id,
            tag: 'div',
            style: {
              position: 'absolute',
              'z-index': z,
              background: 'rgba(255,255,0,0.3)'
            }
          },
            true);
          highlightEl.setBox(first.getBox());

          var buttonEl = Ext.DomHelper.append(document.body, {
            id: 'pp-entry-button-' + link_id,
            tag: 'div',
            style: {
              cursor: 'pointer',
              position: 'absolute',
              //              'z-index': '100',
              width: '16px',
              height: '16px',
            },
            html: '<img src="' + Paperpile.Url('/images/icons/add.png') + '" ext:qtip="asdfasdf"/>'
          },
          true);
          entry.button = buttonEl;
          buttonEl.alignTo(highlightEl, 'bl-tr', [-2, 2]);
          buttonEl.on('click', Paperpile.webImporter.handleImportButton, Paperpile.webImporter, {
            entry: entry
          });
        }
      },
      clearEntries: function() {
        if (this.entries !== undefined) {
          var entries = this.entries;
          for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            var link_id = entry.link_id;
            var highlightEl = Ext.fly('pp-entry-highlight-' + link_id);
            highlightEl.remove();
            var buttonEl = Ext.fly('pp-entry-button-' + link_id);
            if (buttonEl) {
              buttonEl.un('click', Paperpile.webImporter.handleImportButton, Paperpile.webImporter);
              buttonEl.remove();
            }
          }
          this.entries = undefined;
        }
      },
    });
    Paperpile.webImporter = new Paperpile.WebImporter();
  }

  if (Paperpile.status === undefined) {
    Paperpile.status = new Paperpile.Status({
      fixedPosition: true
    });
  }

    var params = {
	url : window.location.href
    };

    // PubMed hack! Send the entire document's contents to the backend, because pubmed doesn't give us a good URL.
    if (params.url.match(/nih.gov/)) {
	params.pubmed_content = document.getElementsByTagName('body')[0].innerHTML;
    }

  Paperpile.webImporter.clearEntries();
  Paperpile.status.showBusy('Searching for references to import');

  Ext.Ajax.request({
    url: Paperpile.Url('/ajax/webimport/submit_page'),
      params: params,
    method: 'POST',
    scriptTag: true,
    disableCaching: true,
    success: function(response) {
      var json = Ext.util.JSON.decode(response.responseText);
      Paperpile.status.clearMsg();

      // Collect the links, add buttons, etc. etc.
      var entries = json.entries || [];

	Paperpile.webImporter.page_type = json.page_type;
	Paperpile.webImporter.list_type = json.list_type;

      if (json.page_type == 'list') {
        Paperpile.webImporter.loadEntries(entries);
        if (entries.length > 0) {
          Paperpile.status.updateMsg({
            type: 'info',
            msg: 'Found ' + entries.length + ' references.',
            action1: 'Import all',
            action2: 'Clear',
            callback: Paperpile.webImporter.handleStatusAction,
            scope: Paperpile.webImporter
          });
        } else {
          Paperpile.status.updateMsg({
            type: 'info',
            msg: 'No references found in page.',
            duration: 5,
            hideOnClick: true
          });
//          Paperpile.log("No entries!");
          // TODO: Some message indicating that we didn't find anything to import.
        }
      } else if (json.page_type == 'single') {
        var result = json.result;
        if (result.status == 'failure') {
          Paperpile.status.updateMsg({
            type: 'error',
            msg: result.error
          });
        } else if (result.status == 'exists') {
          var pub = result.pub;
          Paperpile.status.updateMsg({
            type: 'info',
            msg: 'Reference ' + pub._citation_display + ' already exists in your library.'
          });
        } else {
          var pub = result.pub;
          Paperpile.status.updateMsg({
            type: 'info',
            msg: 'Successfully imported ' + pub._citation_display + '.'
          });
        }
      }
    },
    failure: function(response) {
      Paperpile.status.updateMsg({
        type: 'error',
        msg: 'Error communicating with Paperpile: ' + response.statusText
      });
    }
  });
};