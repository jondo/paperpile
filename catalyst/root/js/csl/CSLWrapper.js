Ext.define('Paperpile.csl.CSLWrapper', {
  statics: {
    loadCslScripts: function() {
      if (!window.CSL) {
        Ext.ux.ScriptMgr.load({
          scripts: ['js/csl/xmldom.js', 'js/csl/citeproc.js'],
          callback: function() {
            Paperpile.log("Loaded!");
          }
        })
      }
    },
    getFormattedCitation: function(records) {
      var json = this.recordsToJson(records);

      Ext.Ajax.request({
        url: Paperpile.Url('/csl/chicago-author-date.csl'),
        success: function(response) {
          var csl = response.responseText;

          Ext.Ajax.request({
            url: Paperpile.Url('/csl/locales-en-US.xml'),
            success: function(response) {
              var en_us = response.responseText;
              var locale = {
                'en-US': en_us
              };

              var Sys = function() {};
              Sys.prototype.retrieveItem = function(id) {
                return json[id];
              };
              Sys.prototype.retrieveLocale = function(lang) {
                return locale[lang];
              };

              var citeproc, output;
              var sys = new Sys();
              citeproc = new CSL.Engine(sys, csl, 'en-us');

              var keys = [];
              for (guid in json) {
                keys.push(guid);
              }
              citeproc.updateItems(keys);
              citeproc.setOutputFormat('text');
              output = citeproc.makeBibliography();
              QRuntime.setClipboard(output[1].join("\n"));
              Paperpile.log("Copied!");
	      Paperpile.log(output[0]);
	      Paperpile.log(output[1]);

              /*
              var win = Ext.create('widget.window', {
                width: 300,
                height: 300,
		  autoScroll: true,
                items: [{
                  html: output[1],
                }],
                dockedItems: [{
			      text: 'Hello!',
			      dock: 'bottom',
                }]
              });
	      win.show();
	      */
	      
            }
          });
        }
      });
    },
    recordsToJson: function(records) {
      var json = [];
      Ext.each(records, function(record) {
        var data = record.data;
        var cur_json = {};
        Ext.apply(cur_json, data);

        cur_json.id = data.guid;
        cur_json.DOI = data.doi;
        //cur_json.type = data.pubtype;
        cur_json.type = 'article-journal';

        // Get the pub date into the right format.
        var date = {
          'date-parts': [
            [
            data.year, Ext.util.Date.getMonthNumber(data.month), data.day]]
        };
        cur_json.issued = date;

        cur_json['container-title'] = data.journal;

        // Get the authors into the right format.
        var authorToks = data.authors.split(/\sand\s/);
        var authors = [];
        for (var i = 0; i < authorToks.length; i++) {
          var author = authorToks[i];
          toks = author.split(/,\s/);
          authors.push({
            family: toks[0],
            given: toks[1],
            'parse-names': true
          });
        }
        cur_json.author = authors;

        json[data.guid] = cur_json;
      });
      return json;
    }
  }
});