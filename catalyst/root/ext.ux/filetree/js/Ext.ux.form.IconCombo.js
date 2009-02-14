// vim: ts=4:sw=4:nu:fdc=2:nospell
/*global Ext */
/**
 * @class Ext.ux.form.IconCombo
 * @extends Ext.form.ComboBox
 *
 * Adds icons on the left side of both the default combo textbox
 * and dropdown list. CSS classes to be used for these icons must
 * be in combo store to show up correctly.
 *
 * @author  Ing. Jozef Sakáloš
 * @copyright (c) 2008, Ing. Jozef Sakáloš
 * @version   1.0
 * @date      19. March 2008
 * @revision  $Id: Ext.ux.form.IconCombo.js 531 2009-02-02 01:07:35Z jozo $
 *
 * @license Ext.ux.form.IconCombo is licensed under the terms of
 * the Open Source LGPL 3.0 license.  Commercial use is permitted to the extent
 * that the code/component(s) do NOT become part of another Open Source or Commercially
 * licensed development library or toolkit without explicit permission.
 * 
 * <p>License details: <a href="http://www.gnu.org/licenses/lgpl.html"
 * target="_blank">http://www.gnu.org/licenses/lgpl.html</a></p>
 */

Ext.ns('Ext.ux.form');

/**
 * Creates new IconCombo
 * @constructor 
 * @param {Object} config A config object
 */
Ext.ux.form.IconCombo = Ext.extend(Ext.form.ComboBox, {
	initComponent:function() {

		var config = {
			tpl:  '<tpl for=".">'
				+ '<div class="x-combo-list-item ux-icon-combo-item '
				+ '{' + this.iconClsField + '}">'
				+ '{' + this.displayField + '}'
				+ '</div></tpl>'
		}; // eo config object

		// apply config
        Ext.apply(this, Ext.apply(this.initialConfig, config));

		// call parent initComponent
		Ext.ux.form.IconCombo.superclass.initComponent.apply(this, arguments);

	} // eo function initComponent

	,onRender:function(ct, position) {
		// call parent onRender
		Ext.ux.form.IconCombo.superclass.onRender.apply(this, arguments);

		// adjust styles
		this.wrap.applyStyles({position:'relative'});
		this.el.addClass('ux-icon-combo-input');

		// add div for icon
		this.icon = Ext.DomHelper.append(this.el.up('div.x-form-field-wrap'), {
			tag: 'div', style:'position:absolute'
		});
	} // eo function onRender

	,afterRender:function() {
		Ext.ux.form.IconCombo.superclass.afterRender.apply(this, arguments);
		if(undefined !== this.value) {
			this.setValue(this.value);
		}
	} // eo function afterRender
	,setIconCls:function() {
        var rec = this.store.query(this.valueField, this.getValue()).itemAt(0);
        if(rec && this.icon) {
            this.icon.className = 'ux-icon-combo-icon ' + rec.get(this.iconClsField);
        }
	} // eo function setIconCls

    ,setValue: function(value) {
        Ext.ux.form.IconCombo.superclass.setValue.call(this, value);
        this.setIconCls();
    } // eo function setValue

	,clearValue:function() {
		Ext.ux.form.IconCombo.superclass.clearValue.call(this);
		if(this.icon) {
			this.icon.className = '';
		}
	} // eo function clearValue

});

// register xtype
Ext.reg('iconcombo', Ext.ux.form.IconCombo);

// eof
