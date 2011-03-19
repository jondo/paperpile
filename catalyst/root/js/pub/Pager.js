Ext.define('Paperpile.grid.Pager', {
  extend: 'Ext.PagingToolbar',
  constructor: function(config) {
    Ext.apply(this, config);

    // This creates a custom event called 'pagebutton', which the enclosing
    // grid might want to listen to in order to react to page button clicks.
    this.addEvents(
      'pagebutton');

    this.callParent(arguments);
  },
  initComponent: function() {

    Ext.apply(this, {
      displayInfo: false
    });

    this.callParent(arguments);

    // Remove some of the unneeded default paging items from this toolbar.
    var removeUs = [];
    var itemIds = ['first', 'last', 'inputItem', 'afterTextItem', 'refresh'];
    for (var i = 0; i < itemIds.length; i++) {
      var item = this.getComponent(itemIds[i]);
      if (item) {
        removeUs.push(item);
      } else {
        Paperpile.log("Couldn't find pager item " + itemIds[i] + " for removal!");
      }
    }
    for (var i = 0; i < this.items.length; i++) {
      var item = this.items.get(i);
      if (item.xtype == 'tbseparator' || item.xtype == 'tbtext') {
        removeUs.push(item);
      }
    }
    this.items.removeAll(removeUs);
  },

  onRender: function(ct) {
    this.myOnRender();
    this.callParent(arguments);
  },

  // Overriding the private Ext4.0 function.
  onLoad: function(store, r, o) {
    if (!this.rendered) {
      this.dsLoaded = [store, r, o];
      return;
    }

    var pageData = this.getPageData(),
    currPage = pageData.currentPage,
    pageCount = pageData.pageCount,
    afterText = Ext.String.format(this.afterPageText, isNaN(pageCount) ? 1 : pageCount);

    this.child('#prev').setDisabled(currPage === 1);
    this.child('#next').setDisabled(currPage === pageCount);
    this.updateInfo();
    this.fireEvent('change', this, pageData);
  },
  myOnRender: function() {
    this.tip = new Ext.tip.Tip({
      minWidth: 10,
      offsets: [0, -10],
      pager: this,
      renderTo: document.body,
      floating: true,
      style: {
        'z-index': -100
      },
      updatePage: function(page, string) {
        this.dragging = true;
        this.body.update(string);
        var x = this.pager.getPositionForPage(page) - this.getBox().width / 2;
        var y = this.pager.getBox().y - this.getBox().height;
        this.setPagePosition(x, y);
      }
    });

    this.progressBar = new Ext.ProgressBar({
      text: '',
      width: 50,
      height: 10,
      animate: {
        duration: 500,
      },
      cls: 'pp-toolbar-progress'
    });

    this.progressBar.on('render', function() {
      var me = this;
      me.progressBar.addListener({
        mousedown: {
          element: 'el',
          fn: me.handleProgressBarClick,
          scope: me
        },
        mousemove: {
          element: 'el',
          fn: me.handleMouseMove,
          scope: me
        },
        mouseover: {
          element: 'el',
          fn: me.handleMouseOver,
          delegate: '.x-progress-text-back',
          scope: me
        },
        mouseout: {
          element: 'el',
          delegate: '.x-progress-text-back',
          fn: me.handleMouseOut,
          scope: me
        }
      });

      me.progressBar.addListener({
        mouseover: {
          element: 'el',
          fn: me.handleMouseOver,
          delegate: '.x-progress-bar',
          scope: me
        },
        mouseout: {
          element: 'el',
          delegate: '.x-progress-bar',
          fn: me.handleMouseOut,
          scope: me
        }
      });
    },
    this);

    this.insert(2, this.progressBar);
    this.insert(2, new Ext.toolbar.Spacer({
      width: 5
    }));

    // Listen for clicks on the next and previous buttons, and forward to the pagebutton
    // event.
    this.mon(this.child('#next'), 'click', function() {
      this.fireEvent('pagebutton', this);
    },
    this);
    this.mon(this.child('#prev'), 'click', function() {
      this.fireEvent('pagebutton', this);
    },
    this);
  },
  handleMouseOver: function(e) {
    this.tip.show();
  },
  handleMouseOut: function(e) {
    this.tip.hide();
  },
  handleMouseMove: function(e) {
    var page = this.getPageForPosition(e.getXY());
    if (page > 0) {
      //var string = page+" ("+page*this.pageSize+" - "+(page+1)*this.pageSize+")";
      var string = "Page " + page + " of " + Math.ceil(this.store.getTotalCount() / this.store.pageSize);
      this.tip.updatePage(page, string);
    } else {
      this.tip.hide();
    }
  },
  handleProgressBarClick: function(e) {
    this.store.loadPage(this.getPageForPosition(e.getXY()));
    this.fireEvent('pagebutton', this);
  },
  getPositionForPage: function(page) {
    var pages = Math.ceil(this.store.getTotalCount() / this.store.pageSize);
    var position = Math.floor(page * (this.progressBar.getWidth() / pages));
    return this.progressBar.getBox().x + position;
  },
  getPageForPosition: function(xy) {
    var position = xy[0] - this.progressBar.getBox().x;
    var pages = Math.ceil(this.store.getTotalCount() / this.store.pageSize);
    var newpage = Math.ceil(position / (this.progressBar.width / pages));
    return newpage;
  },
  updateInfo: function() {
    this.callParent(arguments);

    var pgData = this.getPageData();
    var high = pgData.currentPage / pgData.pageCount;
    var low = (pgData.currentPage-1) / pgData.pageCount;

    this.updateRange(this.progressBar, low, high, '');
    if (high == 1 && low == 0) {
      this.progressBar.disable();
      this.progressBar.getEl().applyStyles('cursor:normal');
    } else {
      this.progressBar.enable();
      this.progressBar.getEl().applyStyles('cursor:pointer');
    }
  },

  updateRange: function(progress, low, high, text, animate) {
    progress.bar.setStyle('position', 'relative');
    progress.value = high || 0;
    if (text) {
      progress.updateText(text);
    }
    if (progress.rendered && !progress.isDestroyed) {
      var x_low = Math.floor(low * progress.getWidth() + 1);
      var x_high = Math.ceil(high * progress.getWidth() + 1);
      var w = Math.ceil(x_high - x_low);
      if (w < 2) {
        x_low -= 1;
        x_high += 1;
        w += 2;
      }
      progress.bar.setWidth(w);
      progress.bar.setX(progress.el.getX() + x_low, animate === true || (animate !== false && progress.animate));
    }
    progress.fireEvent('update', progress, high, text);
    return progress;
  }
});