Ext.define('Paperpile.pub.panel.Collections', {
  extend: 'Paperpile.pub.PubPanel',
  alias: 'widget.Collections',
  initComponent: function() {
    Ext.apply(this, {});

    this.callParent(arguments);
  },

  viewRequiresUpdate: function() {
    var needsUpdate = this.callParent(arguments);

    Ext.each(this.selection, function(pub) {
      if (pub.modified.labels || pub.modified.folders) {
        needsUpdate = true;
      }
    });
    return needsUpdate;
  },

  createTemplates: function() {
    var me = this;

    me.callParent(arguments);

    me.singleTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Folders and Labels</h2>',
      '<tpl if="folders">',
      '  <dt>Folders: </dt>',
      '  <dd>',
      '    <ul class="pp-folders">',
      '    <tpl for="this.getFoldersList(folders)">',
      '      <li class="pp-folder-list pp-folder-generic">',
      '        <a href="#" class="pp-action pp-textlink" action="OPEN_FOLDER" args="{guid}">{name}</a> &nbsp;&nbsp;',
      '        <a href="#" class="pp-action pp-textlink pp-second-link" action="REMOVE_FOLDER" args="{guid}">Remove</a>',
      '      </li>',
      '    </tpl>',
      '    </ul>',
      '  </dd>',
      '</tpl>',
      '<tpl if="labels">',
      '  <dt>Labels: </dt>',
      '  <dd>',
      '    <div class="pp-labels-div">',
      '      <tpl for="this.getLabelsList(labels)">',
      '        <div class="pp-label-box pp-label-style-{style}">',
      '          <div class="pp-label-name pp-label-style-{style}">{name}</div>',
      '          <div class="pp-action pp-label-remove pp-label-style-{style}" action="REMOVE_LABEL" args="{guid}">x</div>',
      '        </div>',
      '      </tpl>',
      '    </div>',
      '  </dd>',
      '</tpl>',
      '<div style="clear:left;"></div>',
      '</div>', {
        getFoldersList: function(folders) {
          var guids = folders.split(',');
          var store = Ext.getStore('folders');
          var data = [];
          Ext.each(guids, function(guid) {
            if (guid) {
              var record = store.getById(guid);
              if (record) {
                data.push(record.data);
              } else {
                Paperpile.log("No record found for folder GUID " + guid);
              }
            }
          });
          return data;
        },
        getLabelsList: function(labels) {
          var guids = labels.split(',');
          var store = Ext.getStore('labels');
          var data = [];
          Ext.each(guids, function(guid) {
            if (guid) {
              var record = store.getById(guid);
              if (record) {
                data.push(record.data);
              } else {
                Paperpile.log("No record found for label GUID " + guid);
              }
            }
          });
          return data;
        }
      });

    me.multiTpl = new Ext.XTemplate(
      '<div class="pp-box pp-box-side-panel pp-box-top pp-box-style1">',
      '<h2>Folders and Labels</h2>',
      '<tpl if="this.hasFolders(values)">',
      '  <dt>Folders: </dt>',
      '  <dd>',
      '    <ul class="pp-folders">',
      '    <tpl for="this.getFoldersList(values)">',
      '      <li class="pp-folder-list pp-folder-generic">',
      '        <a href="#" class="pp-action pp-textlink" action="OPEN_FOLDER" args="{guid}">{name}</a> &nbsp;&nbsp;',
      '        <a href="#" class="pp-action pp-textlink pp-second-link" action="REMOVE_FOLDER" args="{guid}">Remove</a>',
      '      </li>',
      '    </tpl>',
      '    </ul>',
      '  </dd>',
      '</tpl>',
      '<tpl if="this.hasLabels(values)">',
      '  <dt>Labels: </dt>',
      '  <dd>',
      '    <div class="pp-labels-div">',
      '      <tpl for="this.getLabelsList(values)">',
      '        <div class="pp-label-box pp-label-style-{style}">',
      '          <div class="pp-label-name pp-label-style-{style}">{name}</div>',
      '          <div class="pp-action pp-label-remove pp-label-style-{style}" action="REMOVE_LABEL" args="{guid}">x</div>',
      '        </div>',
      '      </tpl>',
      '    </div>',
      '  </dd>',
      '</tpl>',
      '<div style="clear:left;"></div>',
      '</div>', {
        isAllSelected: function(selection) {
          var grid = me.up('pubview').grid;
          return grid.isAllSelected();
        },
        hasFolders: function(selection) {
          var hasFolders = false;
          Ext.each(selection, function(pub) {
            if (pub.get('folders') != '') {
              hasFolders = true;
            }
          });
          return hasFolders;
        },
        hasLabels: function(selection) {
          var hasLabels = false;
          Ext.each(selection, function(pub) {
            if (pub.get('labels') != '') {
              hasLabels = true;
            }
          });
          return hasLabels;
        },
        getFoldersList: function(selection) {
          return this.getCollectionAsList(selection, 'folders');
        },
        getLabelsList: function(selection) {
          return this.getCollectionAsList(selection, 'labels');
        },
        getCollectionAsList: function(selection, collectionType) {
          var data = new Ext.util.MixedCollection();
          var store = Ext.getStore(collectionType);
          if (this.isAllSelected()) {
            // If all are selected, we collect all of this collectionType
            store.each(function(record) {
              data.add(record.get('guid'), record.data);
            });
          } else {
            Ext.each(selection, function(pub) {
              var guids = pub.get(collectionType).split(',');
              for (var i = 0; i < guids.length; i++) {
                var guid = guids[i];
                if (guid == '') {
                  continue;
                }
                if (!data.containsKey(guid)) {
                  var record = store.getById(guid);
                  data.add(guid, record.data);
                }
              }
            });
          }

          // Sort descending by count.
          data.sort('count', 'DESC');
          var all = data.getRange();
          // Max out at showing 10 collection items.
	  var maxCount = 10;
          if (data.getCount() > maxCount) {
            all = data.getRange(0, maxCount-1);
          }
          return all;
        }
      });
  }
});