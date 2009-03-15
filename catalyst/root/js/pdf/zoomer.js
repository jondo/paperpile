Paperpile.PDFzoomer = Ext.extend(Ext.Slider, {
    initComponent: function() {

        this.map=[0.1,0.2,0.4,0.6,0.8,
                  1.0,
                  1.2,1.4,1.6,1.8,2.0];
        
        Ext.apply(this, {  width: 200,
                           value: 5,
                           increment: 1,
                           minValue: 0,
                           maxValue: 10,
                           plugins: new Paperpile.PDFzoomerTip()
                        });

    }
});

Paperpile.PDFzoomerTip = Ext.extend(Ext.Tip, {
    minWidth: 10,
    offsets : [0, -10],
    init : function(slider){
        slider.on('dragstart', this.onSlide, this);
        slider.on('drag', this.onSlide, this);
        slider.on('dragend', this.hide, this);
        slider.on('destroy', this.destroy, this);
    },

    onSlide : function(slider){
        this.show();
        this.body.update(this.getText(slider));
        this.doAutoWidth();
        this.el.alignTo(slider.thumb, 'b-t?', this.offsets);
    },

    getText : function(slider){

        var raw=slider.getValue();
        var text=slider.map[raw];

        return text*100+'%';

    }
});
