Ext.define('Paperpile.grid.ContextMenu', {
  extend: 'Ext.menu.Menu',
  alias: 'widget.gridcontext',
  plusings: [new Ext.ux.TDGi.MenuKeyTrigger()],
  itemId: 'context'
});