
Ext.regModel('Paperpile.models.Collection', {
  fields: ['guid', 'name', 'type', 'parent', 'sort_order', 'hidden', 'style', 'data'],
  idProperty: 'guid',
  save: function() {
    if (!this.get('guid')) {
      this.set('guid', Paperpile.utils.generateUUID());
      Paperpile.Ajax({
        url: '/ajax/crud/new_collection',
        params: {
          type: this.get('type') === 'FOLDER' ? 'FOLDER' : 'LABEL',
          text: this.get('name'),
          node_id: this.get('guid'),
          type: this.get('type'),
          style: this.get('style'),
          parent_id: this.get('parent')
        },
        success: function(response) {},
        scope: this
      });
    }
  }
});