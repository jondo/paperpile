//alert(pp_domain);
var PP = {};
IS_WEBIMPORT = true;
var scripts = ['/ext/adapter/ext/ext-base.js', '/ext/ext-all-debug.js', '/scripts/init.js', '/scripts/x-domain.js', '/js/misc/status.js'];
for (var i = 0; i < scripts.length; i++) {
  var script = scripts[i];
  var s = document.createElement('script');
  s.src = pp_domain + script;
  document.body.appendChild(s);
}

PP.startWebImport = function() {
  (function a() {
    if (typeof Ext == 'undefined' || !Ext.select) {
      window.setTimeout(a, 200)
      //console.log("waiting...");
    } else {
      PP.onLoad();
    }
  })();
}

PP.onLoad = function() {
  if (Paperpile.webImporter === undefined) {
    Paperpile.WebImporter = Ext.extend(Object, {
      handleStatusAction: function(actionType) {
        if (actionType == 'ACTION2') {
          this.clearEntries();
          Paperpile.status.clearMsg();
        } else {
          this.handleImportAll();
        }
      },
      handleImportButton: function(event, target, object) {
        var target = event.getTarget();
        var el = Ext.get(target);
        var entry = object.entry;

        this.handleImport([entry]);
      },
      handleImportAll: function() {
	  for (var i=0; i < this.entries.length; i++) {
	      var entry = this.entries[i];
	      this.handleImport([entry]);
	  }
          //this.handleImport(this.entries);
      },
      buttonForIndex: function(index) {
        return Ext.fly('pp-entry-button-' + index);
      },
      buttonWorking: function(index) {
        this.buttonForIndex(index).update('<img src="' + Paperpile.Url('/images/icons/job-running.gif') + '"/>');
      },
      buttonSuccess: function(index) {
        this.buttonForIndex(index).update('<img src="' + Paperpile.Url('/images/icons/tick.png') + '"/>');
        this.buttonForIndex(index).setStyle('cursor', 'default');
      },
      buttonFailure: function(index) {
        this.buttonForIndex(index).update('<img src="' + Paperpile.Url('/images/icons/error.png') + '"/>');
      },
      handleImport: function(entries) {
        var urls = [];
        var indices = [];
        for (var i = 0; i < entries.length; i++) {
          urls.push(entries[i].import_url);
          indices.push(entries[i].index);
          var el = this.buttonForIndex(entries[i].index);
          this.buttonWorking(entries[i].index);
        }

        Ext.Ajax.request({
          url: pp_domain + '/ajax/webimport/import_urls',
          params: {
            indices: indices,
            urls: urls,
            label: 'web-import',
            folder: 'asdf'
          },
          method: 'POST',
          scriptTag: false,
          disableCaching: true,
          success: function(response) {
            var json = Ext.util.JSON.decode(response.responseText);

            var results = json.results;
            for (var i = 0; i < results.length; i++) {
              var result = results[i];
              if (result.status == 'success') {
                this.buttonSuccess(result.index);
              } else {
                this.buttonFailure(result.index);
              }
            }

            Paperpile.status.clearMsg();
          },
          scope: this
        });
      },

      loadEntries: function(entries) {
        this.entries = entries;
        for (var i = 0; i < entries.length; i++) {
          var entry = entries[i];
          entry.index = i;
          var selector = entry.selector;
          var el = Ext.select(selector, true);
          var first = el.first();
          var highlightEl = Ext.DomHelper.append(document.body, {
            id: 'pp-entry-highlight-' + i,
            tag: 'div',
            style: {
              position: 'absolute',
              'z-index': '-1',
              background: 'rgba(255,255,0,0.3)'
            }
          },
            true);
          highlightEl.setBox(first.getBox());

          var buttonEl = Ext.DomHelper.append(document.body, {
            id: 'pp-entry-button-' + i,
            tag: 'div',
            style: {
              cursor: 'pointer',
              position: 'absolute',
              'z-index': '100',
              width: '16px',
              height: '16px',
            },
            html: '<img src="' + Paperpile.Url('/images/icons/add.png') + '"/>'
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
            var highlightEl = Ext.fly('pp-entry-highlight-' + i);
            highlightEl.remove();
            var buttonEl = Ext.fly('pp-entry-button-' + i);
            if (buttonEl) {
              buttonEl.un('click', Paperpile.webImporter.handleImportButton, Paperpile.webImporter);
              buttonEl.remove();
            }
          }
          this.entries = undefined;
        }
      }
    });
    Paperpile.webImporter = new Paperpile.WebImporter();
  }

  if (Paperpile.status === undefined) {
    Paperpile.status = new Paperpile.Status({
      fixedPosition: true
    });
  }

  Paperpile.webImporter.clearEntries();

  Paperpile.status.showBusy('Searching for references to import');
  var url = window.location.href;
  pp_domain = 'http://127.0.0.1:3210';
  Ext.Ajax.request({
    url: pp_domain + '/ajax/webimport/submit_page',
    params: {
      url: url
    },
    method: 'GET',
    scriptTag: true,
    disableCaching: true,
    success: function(response) {
      var json = Ext.util.JSON.decode(response.responseText);
      Paperpile.log('Type: ' + json.page_type);
      Paperpile.status.clearMsg();

      // Collect the links, add buttons, etc. etc.
      var entries = json.entries;
      Paperpile.webImporter.loadEntries(entries);

      //	    if (json.page_type == 'list' && entries.length > 1) {
      Paperpile.status.updateMsg({
        type: 'info',
        msg: 'Found ' + entries.length + ' references.',
        action1: 'Import all',
        action2: 'Cancel',
        callback: Paperpile.webImporter.handleStatusAction,
        scope: Paperpile.webImporter
      });
      //	    }
    },
    failure: function(response) {
      console.log("Error!");
      console.log(response);
    }
  });
};

PP.startWebImport();