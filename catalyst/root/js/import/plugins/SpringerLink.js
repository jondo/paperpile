/* Copyright 2009, 2010 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.  You should have received a
   copy of the GNU General Public License along with Paperpile.  If
   not, see http://www.gnu.org/licenses. */


Paperpile.PluginPanelSpringerLink = Ext.extend(Paperpile.PluginPanel, {
  initComponent: function() {
    Ext.apply(this, {
      title: 'SpringerLink',
      iconCls: 'pp-icon-springerlink'
    });
    Paperpile.PluginPanelSpringerLink.superclass.initComponent.call(this);
  },
  createGrid: function(params) {
    return new Paperpile.PluginGridSpringerLink(params);
  }
});

Paperpile.PluginGridSpringerLink = Ext.extend(Paperpile.PluginGrid, {
    
    plugins:[
      new Paperpile.OnlineSearchGridPlugin(),
      new Paperpile.ImportGridPlugin()
    ],
    limit: 10,

    initComponent:function() {
        this.plugin_name = 'SpringerLink';

	this.aboutPanel = new Paperpile.AboutSpringerLink();
        Paperpile.PluginGridSpringerLink.superclass.initComponent.call(this);
    }
 
});

Paperpile.AboutSpringerLink = Ext.extend(Paperpile.PluginAboutPanel, {
    markup: [
        '<div class="pp-box pp-box-side-panel pp-box-style1">',
        '<div class="pp-springerlink-logo">&nbsp</div>',
        '<p class="pp-plugins-description">SpringerLink is a databases for high-quality scientific, technological and medical journals, books series and reference works. It offers over 1,750 peer reviewed journals and 27,000 eBooks.</p>',
        '<p><a target=_blank href="http://springerlink.com" class="pp-textlink">springerlink.com</a></p>',
        '</div>'],
    tabLabel: 'About SpringerLink'
});
