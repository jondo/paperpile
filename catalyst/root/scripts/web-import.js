/*

Things get a bit complicated here, so I'll be verbose. Feel free to
delete this text when the code is better documented!

This script is called by the inline Javascript from Paperpile's
browser button.  the variable 'pp_domain' should be pre-set to the
prefix for the current Paperpile server, i.e. 'http://localhost:3210'.

For a lack of any better place to put it, here's the contents of the
browser button link:
javascript:var%20b=document.body;var%20pp_domain='http://localhost:3210';void(z=document.createElement('script'));void(z.src=pp_domain+'/scripts/web-import.js?time='+new%20Date().getTime());void(b.appendChild(z));

When the user pressed that button in her bookmarks toolbar, what we do
is the following: 1. Insert inline <link> and <script> elements to
load the necessary css and Javascript to the current page. Cross our
fingers for no css crosstalk so the page stays looking the
same. Important files include:
  (a) Ext adapter -- we usually use the 'base' Ext adapter, except
when JQuery is already loaded into a page. In that case, we switch to
the JQuery adapter.
  (b) 'x-domain.js' overrides -- a few overrides which allow us to
easily use the Ext.Ajax interface for doing JSONP cross-domain Ajax.
  (c) 'status.js' -- use this fairly generic status class to give
Paperpile-like feedback during the import process.
  
2. Once the necessary Javascript is loaded, call the PP.onLoad()
callback.

3. Before doing anything else, call PP.init() to recreate some of the
core Paperpile methods and objects.

4. Create the Paperpile.webImport instance which will hold the state
of the web import for this page.

5. Make an AJAX call to the /ajax/webimport/submit_page location,
which lets the Catalyst backend scan the current page, identify
whether it's a single reference or a list, and either immediately
import the single reference or return the list of references back to
the frontend.

6. If it's a list of references, the front-end then populates the
current page with nice highlight indicators and buttons galore.

7. Each individual import action results in a call to
/ajax/webimport/import_refs (currently importing only one reference
per call).

There's a little bit of further trickiness here, because the backend
is actually caching the list of what we'll call 'link objects' in the
session store. So the import_refs call only refers to the 'link_id' of
a given link object. On the backend side, we might want to store extra
data associated with a given identified link object (such as a pre-populated
Publication object) for use when we actually import the reference. See
the _get_links_from_page method of Paperpile/Controller/Ajax/WebImport.pm
for details on how this works.
*/

var PP = {};
IS_WEBIMPORT = true; // used by the Paperpile.Url function so we always add the full HTTP prefix to Paperpile URLs. 
// Loads a CSS file into the current document's HEAD element.
function loadCss(css_file) {
  var headID = document.getElementsByTagName("head")[0];
  var s = document.createElement('link');
  s.type = 'text/css';
  s.rel = 'stylesheet';
  s.href = pp_domain + css_file;
  headID.appendChild(s);
}

// Loads a Javascript file into the current document, triggering a callback when the script is loaded.
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

// web-import is blank right now... maybe we could move the few bits of paperpile.css
// that we actually use into web-import, to save space?
var styles = ['/ext/resources/css/structure/qtips.css', '/ext/resources/css/xtheme-gray.css', '/css/web-import.css', '/css/paperpile.css'];
for (var i = 0; i < styles.length; i++) {
  loadCss(styles[i]);
}

// Decide which adaptor to use -- if the page already has JQuery loaded
// (pubmed annoyingly does), use the jquery adaptor.
var adapterScript = '/ext/adapter/ext/ext-base-debug.js';
if (typeof jQuery != 'undefined') {
  adapterScript = '/ext/adapter/jquery/ext-jquery-adapter-debug.js';
}

// Load these scripts in order, using a counter to proceed with injection
// only when the previous script is fully loaded.
var scripts = [adapterScript, '/ext/ext-all-debug.js', '/scripts/x-domain.js', '/js/misc/status.js'];
var loaded_count = 0;
function load_next() {
  if (loaded_count == scripts.length) {
    // We're done -- carry on, soldier.
    PP.onLoad();
  } else {
    loadScript(scripts[loaded_count++], load_next);
  }
};

load_next(); // Trigger the loading cycle.
// This stuff is mostly scraped out of paperpile.js on an ad hoc basis.
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

// The main function, called once all Javascript libraries are loaded.
PP.onLoad = function() {
  PP.init();
  if (Paperpile.webImporter === undefined) {
    Paperpile.WebImporter = Ext.extend(Object, {
      page_type: null,
      list_type: null,

      // Handles the actions shown once a reference list page is finished
      // scanning.
      handleStatusAction: function(actionType) {
        if (actionType == 'ACTION2') {
          this.clearEntries();
          Paperpile.status.clearMsg();
        } else {
          this.handleImportAll();
        }
      },
      // Handles the actions shown once an 'all import' action is finished.
      handleFinishedAction: function(actionType) {
        this.clearEntries();
        Paperpile.status.clearMsg();
      },
      // Handles a single import button press.
      // (we provide the 'entry' link object as an extra argument in the handler)
      handleImportButton: function(event, target, object) {
        var target = event.getTarget();
        var el = Ext.get(target);
        var entry = object.entry;

        this.handleImport([entry], false);
      },
      handleImportAll: function() {
        Paperpile.status.showBusy('Importing all references');

        // Terminology note: an 'entry' is the same as a 'link object'...
        for (var i = 0; i < this.entries.length; i++) {
          var entry = this.entries[i];
          // Fire off a 'handleImport' call for each of the found references.
          // TODO: Think of a better way to handle lots of found references
          // without barraging the backend with 50+ requests all at once.
          //
          // One possibility would be to collate the requests in groups of
          // 2 or 3 as necessary.
          var delay = i * 500;
          entry.working = true;
          this.handleImport.defer(delay, this, [
            [entry], true]);
        }
      },
      // Called every time an import request comes back.
      // Count up the status of each import job, and only show
      // the 'finished' status message when there's no working
      // imports remaining.
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
            } else if (e.status == 'failure') {
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
        // Gets the button element for an entry with a given link_id.
        return Ext.get('pp-entry-button-' + entry.link_id);
      },
      // Finds an entry hashref from a given link_id.
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
      // These are small methods to update the visual appearance of the
      // buttonElement for a given entry.
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
      // Adds a tooltip to the entry.
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

      // Do a call to the backend to import the given entry/ies.
      handleImport: function(entries, updateStatus) {
        var linkIds = [];
        for (var i = 0; i < entries.length; i++) {
          var link_id = entries[i].link_id;
          linkIds.push(link_id);
          this.buttonWorking(entries[i]);
          entries[i].working = true;
        }

        var url = window.location.href; // Pass the URL to the backend because it's used as an identifying key for the link object cache.
        Ext.Ajax.request({
          url: Paperpile.Url('/ajax/webimport/import_refs'),
          params: {
            link_ids: linkIds,
            page_url: url,
            //label: 'web-import', //TODO! Add UI and backend for importing directly into a folder or label.
            //folder: 'asdf', // TODO!
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

              // Store the status of the result (from the backend)
              // into the corresponding entry (in the frontend).
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

            // We don't want to call the updateStatus on single imports,
            // so the importAll method sets this flag to true.
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
      // Loads the buttons and highlight elements for the given list
      // of entries.
      loadEntries: function(entries) {
        this.entries = entries;
        for (var i = 0; i < entries.length; i++) {
          var entry = entries[i];
          var link_id = entry.link_id;

          // The backend is responsible for giving each entry a selector
          // which will identify the correct HTML element to highlight and
          // place a button near. See the _get_links_from_page method
          // in WebImport.pm for more details.
          var selector = entry.selector;
          var el = Ext.select(selector, true); // Select the el.
          var first = el.first(); // Take the first (hopefully the only) one.
          first.setStyle('z-index', '50'); // Boost up the z-index of this element to hopefully hover above our highlight DIVs.
          first.setStyle('position', 'relative');
          var z = 0;
          var highlightEl = Ext.DomHelper.append(document.body, {
            id: 'pp-entry-highlight-' + link_id,
            tag: 'div',
            style: {
              position: 'absolute',
              'z-index': z,
              background: 'rgba(255,255,0,0.3)' // Make it transparent just in case it's not floating 'below' the target element.
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
              width: '16px',
              height: '16px',
            },
            html: '<img src="' + Paperpile.Url('/images/icons/add.png') + '" ext:qtip="asdfasdf"/>'
          },
          true);
          entry.button = buttonEl;

	    // This could probably be tweaked a bit, it doesn't look perfect all the time.
          buttonEl.alignTo(highlightEl, 'bl-tr', [-2, 2]);
          buttonEl.on('click', Paperpile.webImporter.handleImportButton, Paperpile.webImporter, {
            entry: entry // Provide the current entry as an argument to the handler callback.
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
      fixedPosition: true // Fix to the top of the screen.
    });
  }

  var params = {
    url: window.location.href
  };
  // PubMed hack! We also need to send the entire current document's contents to the backend, because pubmed doesn't give us a good stable URL for the backend to browse.
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
	    // We know this page is a list because of the 'page_type', but
	    // there are no entries in the list. Nothing was found!
          Paperpile.status.updateMsg({
            type: 'info',
            msg: 'No references found in page.',
            duration: 5,
            hideOnClick: true
          });
        }
      } else if (json.page_type == 'single') {
        var result = json.result;
        if (result.status == 'failure') {
          Paperpile.status.updateMsg({
            type: 'error',
              msg: 'No reference information found ('+result.error+')'
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