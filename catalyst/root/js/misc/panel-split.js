/*
 * A split panel plugin.
 * 
*/

Ext.ux.PanelSplit = Ext.extend(Ext.util.Observable, {

  constructor: function(leftPanel, callback, scope) {
    this.leftPanel = leftPanel;
    this.callback = callback;
    this.scope = scope;
  },

  init: function(p) {
    // Apply the plugin's properties to the leftPanel object
    // passed to the plugin constructor.
    // This panel will have the splitbar attached to it, and will
    // handle all the events.
    this.leftPanel.splitCallback = this.callback;
    this.leftPanel.splitCallbackScope = this.scope;
    Ext.Function.createSequence(this.leftPanel.afterRender,this.afterRender);
    //this.leftPanel.afterRender = this.leftPanel.afterRender.createSequence(this.afterRender);
    Ext.Function.createSequence(this.leftPanel.onDestroy, this.onDestroy);
    //this.leftPanel.onDestroy = this.leftPanel.onDestroy.createSequence(this.onDestroy);
  },

  afterRender: function() {
    this.el.setStyle({
      'border-right-color': '#F0F0F0',
      'border-right-width': '4px'
    });
    this.splitMoved = function(split, newSize) {
      // use the splitbar position parent panel to define the new fraction
      var box = this.splitParent.getBox();
      var fraction = newSize / box.width;

      // Call the callback function with the new fraction defined by the split bar.
      this.splitCallback.call(this.splitCallbackScope, fraction);

      this.updateSplitPos();
    };

    this.updateSplitPos = function() {
      // Update the splitbar's position based on the size and position of the 
      // panel passed to the plugin's constructor.
      var b1 = this.getBox();
      var sd = this.splitEl.dom;
      var s = sd.style;
      var sw = sd.offsetWidth;
      s.left = (b1.width - sw) + 'px';
      s.top = (0) + 'px';
      s.height = Math.max(0, b1.height) + 'px';
    };

    this.splitParent = this.ownerCt;

    // Create an element to hold the split el.
    this.splitEl = this.el.createChild({
      cls: "x-layout-split x-layout-split-h pp-split",
      html: "&#160;",
      id: this.el.id + '-xsplit'
    });

    this.splitPane = new Ext.SplitBar(this.splitEl, this.el,
      Ext.SplitBar.HORIZONTAL);

    // Turn off the default size-setting callback. It causes some bugs.
    this.splitPane.adapter.setElementSize = Ext.emptyFn;
    this.splitPane.placement = Ext.SplitBar.LEFT;

    // Trigger a resize when the split pane is finished moving.
    this.splitPane.on('moved', this.splitMoved, this);

    // Update the splitbar position upon layout.
    this.on('afterlayout', this.updateSplitPos, this);

    this.updateSplitPos();
  },

  onDestroy: function() {
    this.splitPane.destroy();
    this.splitEl.remove();
    this.splitCallback = null;
  }
});