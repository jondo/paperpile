Ext.HoverButton = function(config) {
  Ext.HoverButton.superclass.constructor.call(this, config);
};
Ext.extend(Ext.HoverButton, Ext.Button, {
  animateOpen:false,
  showSpeed:0.4,
  hideSpeed:0.5,
  hideDelay:250,
  hideDT:null,
  showDelay:100,
  showDT:null,
  inPosition:false,
  hideTimeout:0,
  initComponent: function() {
    Ext.HoverButton.superclass.initComponent.apply(this,arguments);

    this.hideDT = new Ext.util.DelayedTask(this.hideAnim,this);
    this.showDT = new Ext.util.DelayedTask(this.showAnim,this);
    
    this.on("menutriggerout",function(e) {
      if (this.inPosition) {
        this.hideDT.delay(this.hideDelay);
        this.showDT.cancel();
      }
    },this);
    this.menu.on("mouseover",function(e) {
      this.hideDT.cancel();
    },this);
    this.menu.on("mouseout",function(e) {
      if (this.inPosition) {
        this.hideDT.delay(this.hideDelay);
      }
      this.showDT.cancel();
    },this);

    //this.menu.getEl().setStyle("z-index",9);
    //this.menu.getEl().setStyle("position","absolute");
  },

  bodyMove:function(e) {
    //log(e);
    var xy = e.getXY();
    var xywh = this.getButtonMenuBox();
    if (xy[0] > xywh.loX && xy[0] < xywh.hiX && xy[1] > xywh.loY && xy[1] < xywh.hiY) {
      this.hideDT.cancel();
    } else if (e.within(this.menu.el) || e.within(this.el)) {
      this.hideDT.cancel();
    } else {
      this.hideDT.delay(this.hideDelay);
      this.showDT.cancel();
    }
  },
      
  getButtonMenuBox:function() {
    var xywh={};
    var mbox = this.menu.getEl().getBox();
    var bbox = this.getEl().getBox();
    
    // Take the rectangle around both boxes.
    xywh.loX = Math.min(mbox.x,bbox.x);
    xywh.hiX = Math.max(mbox.x+mbox.width,bbox.x+bbox.width);
    xywh.loY = Math.min(mbox.y,bbox.y);
    xywh.hiY = Math.max(mbox.y+mbox.height,bbox.y+bbox.height);
    return xywh;
  },
             
  hideAnim:function() {
    if (this.animateOpen) {
      this.menu.getEl().alignTo(this.el,"bl",[0,0],{
				duration:this.hideSpeed,
				scope:this,
				callback:function() {
				  this.menu.hide();
				  this.inPosition=false;
                                  Ext.getBody().un("mousemove",this.bodyMove,this);
				}
				});
    } else {
      this.hideMenu();
      this.inPosition=false;
      Ext.getBody().un("mousemove",this.bodyMove,this);
    }
  },

  showAnim: function() {
    if (this.animateOpen) {
      this.menu.show(this.el,"tl");
      this.menu.getEl().alignTo(this.el,"tl-bl?",[0,0],{
				duration:this.showSpeed,
				scope:this,
				callback:function() {
				  this.inPosition=true;
				}
			      }
			     );
      this.inPosition = false;
    } else {
      this.showMenu();
      this.inPosition=true;
    }
  },

  showMenu:function() {
    this.hideDT.cancel();
    this.showDT.cancel();
    Ext.HoverButton.superclass.showMenu.call(this,arguments);
  },
             
  hideMenu:function() {
    this.hideDT.cancel();
    this.showDT.cancel();
    Ext.HoverButton.superclass.hideMenu.call(this,arguments);    
  },
             
  onClick: function(e) {
    this.showMenu();
    this.inPosition = true;
  },

  onMouseDown:function(e) {
    this.showMenu();
    this.inPosition = true;
  },

  onMouseOver: function(e) {
    if (!this.menu.isVisible()) {
      Ext.getBody().on("mousemove",this.bodyMove,this);
      this.showDT.delay(this.showDelay);
    }
    //e.stopEvent();
    Ext.HoverButton.superclass.onMouseOver.call(this,e,arguments);
  }
});
