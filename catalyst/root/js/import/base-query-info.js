Paperpile.BaseQueryInfoPlugin = function(config) {
  Ext.apply(this, config);
};

Ext.extend(Paperpile.BaseQueryInfoPlugin, Ext.util.Observable, {
  init: function(grid) {
    grid.hasBaseQuery = function() {
      return this.plugin_base_query != '';
    };

    // Creates a new 'base query' toolbar item and a tooltip for it
    // if it hasn't been created already. If the item and tooltip
    // already exist, update them with the current base query.
    grid.updateBaseQueryTooltip = function() {
      if (!this.hasBaseQuery()) {
        return;
      }
      if (!this.rendered) {
        return;
      }

      var normalized = this.normalizeQuery(this.plugin_base_query);
      var str = this.parenthesizeQuery(normalized);
      var html = [
        '<div class="pp-query-info-body">',
        '  <h2>Base query:</h2>',
        '  ' + str,
        '</div>'].join('');

      if (!this.actions['BASE_QUERY_INFO']) {
        this.actions['BASE_QUERY_INFO'] = new Ext.Toolbar.Button({
          id: 'pp-query-info-' + this.id,
          cls: 'pp-query-info-button',
          iconCls: 'pp-icon-info',
          disabled: true,
          allowDepress: false,
          enableToggle: false,
          handleMouseEvents: false
        });
        this.actions['BASE_QUERY_INFO'].on('render', function() {
          this.baseQueryTip = new Ext.ToolTip({
            target: 'pp-query-info-' + this.id,
            minWidth: 50,
            maxWidth: 500,
            html: html,
            anchor: 'top',
            showDelay: 0,
            dismissDelay: 0,
            hideDelay: 0
          });
        },
        this);
      }
      var item = this.actions['BASE_QUERY_INFO'];

      if (this.baseQueryTip && this.baseQueryTip.rendered) {
        this.baseQueryTip.body.dom.innerHTML = html;
      } else if (this.basQueryTip) {
        this.baseQueryTip.html = html;
      }

      var tbar = this.getTopToolbar();
      if (!tbar.items.contains(item)) {
        tbar.insertButton(0, item);
      }

    };

    grid.normalizeQuery = function(query) {
      // Do some magic here to turn the query into a data structure
      //return [['123','and','456'],'or','asdf'];
      return query;
    };

    grid.parenthesizeQuery = function(array) {
      if (Ext.isArray(array) && array.length == 3) {
        return "(" + this.parenthesizeQuery(array[0]) + " " + array[1] + " " + this.parenthesizeQuery(array[2]) + ")";
      } else {
        // array is actually a single string. Format it and return.
        return this.formatQueryToken(array);
      }
    };

    // Takes a single query token and returns the formatted HTML.
    grid.formatQueryToken = function(token) {
      if (token.match('labelid')) {
        // The code for labels and folders is very much the same --
        // jump into the store to get the display_name (and style for labels)
        // and then turn it into a div / li item.
        var labelid = token.match('labelid:(.*)')[1];
        var store = Ext.StoreMgr.lookup('label_store');
        var record = store.findByGUID(labelid);
        return '<div class="pp-label-grid-inline pp-label-style-' + record.get('style') + '">' + record.get('display_name') + '</div>';
      } else if (token.match('folderid')) {
        var folderid = token.match('folderid:(.*)')[1];
        var store = Ext.StoreMgr.lookup('folder_store');
        var record = store.findByGUID(folderid);
        return '<li class="pp-folder-list pp-folder-generic">' + record.get('display_name') + '</li>';
      } else {
        // Anything else to think of? We could do fancier things like
        // add a little person for author field and a journal-like icon
        // for journal fields, but we don't need to get ridiculous here.
        return '<span class="pp-query-info-token">' + token + '</span>';
      }
    };

    grid.on('render', grid.updateBaseQueryTooltip, grid);
  }
});

Ext.reg("base-query-info-plugin", Paperpile.BaseQueryInfoPlugin);