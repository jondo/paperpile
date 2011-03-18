Ext.define('Paperpile.grid.Pager', {
	extend: 'Ext.PagingToolbar',
  constructor: function(config) {
    Ext.apply(this, config);

    // This creates a custom event called 'pagebutton', which the enclosing
    // grid might want to listen to in order to react to page button clicks.
    this.addEvents(
      'pagebutton'
    );

    this.callParent(config);
},
  initComponent: function() {
    this.callParent();

    var itemIds = ['first', 'last', 'inputItem', 'afterTextItem', 'refresh'];
    for (var i=0; i < itemIds.length; i++) {
	this.remove(this.getComponent(itemIds[i]));
    }

    this.on('render', this.myOnRender, this);

  },
  myOnRender: function() {
    this.tip = new Ext.Tip({
      minWidth: 10,
      offsets: [0, -10],
      pager: this,
      renderTo: document.body,
      style: {
        'z-index': 100
      },
      updatePage: function(page, string) {
        this.dragging = true;
        this.body.update(string);
        this.doAutoWidth();
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
        duration: 1,
        easing: 'easeOutStrong'
      },
      cls: 'pp-toolbar-progress'
    });
    this.mon(
      this.progressBar, 'render', function(pb) {
        this.mon(pb.getEl(), 'mousedown', this.handleProgressBarClick, this);
        this.mon(pb.getEl(), 'mousemove', this.handleMouseMove, this);
        this.mon(pb.getEl(), 'mouseover', this.handleMouseOver, this);
        this.mon(pb.getEl(), 'mouseout', this.handleMouseOut, this);
      },
      this);
    this.insert(2, this.progressBar);
    this.insert(2, new Ext.Toolbar.Spacer({
      width: 5
    }));

    // Listen for clicks on the next and previous buttons, and forward to the pagebutton
    // event.
    this.mon(this.next, 'click', function(){this.fireEvent('pagebutton',this);},this); 
    this.mon(this.prev, 'click', function(){this.fireEvent('pagebutton',this);},this);
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
      var string = "Page " + page + " of " + Math.ceil(this.store.getTotalCount() / this.pageSize);
      this.tip.updatePage(page, string);
    } else {
      this.tip.hide();
    }
  },
  handleProgressBarClick: function(e) {
    this.changePage(this.getPageForPosition(e.getXY()));
    this.fireEvent('pagebutton',this);
  },
  getPositionForPage: function(page) {
    var pages = Math.ceil(this.store.getTotalCount() / this.pageSize);
    var position = Math.floor(page * (this.progressBar.width / pages));
    return this.progressBar.getBox().x + position;
  },
  getPageForPosition: function(xy) {
    var position = xy[0] - this.progressBar.getBox().x;
    var pages = Math.ceil(this.store.getTotalCount() / this.pageSize);
    var newpage = Math.ceil(position / (this.progressBar.width / pages));
    return newpage;
  },
  updateInfo: function() {
    this.callParent();
    var count = this.store.getCount();
    var pgData = this.getPageData();
    var pageNum = this.readPage(pgData);
    pageNum = pgData.activePage;
    var high = pageNum / pgData.pages;
    var low = (pageNum - 1) / pgData.pages;
    this.progressBar.updateRange(low, high, '');
    if (high == 1 && low == 0) {
      this.progressBar.disable();
      this.progressBar.getEl().applyStyles('cursor:normal');
    } else {
      this.progressBar.enable();
      this.progressBar.getEl().applyStyles('cursor:pointer');
    }
  }
});
