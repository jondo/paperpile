Paperpile.ImageCache = Ext.extend(Ext.util.Observable, {
    images: [],
    
    get: function(url) {
	return this.images[url];
    },
    put: function(url,image) {
	this.images[url] = image;
    },

    clear: function() {
      for (var i=0; i < this.images.length; i++) {
	  var img = this.images[i];
	  
      }
}
});