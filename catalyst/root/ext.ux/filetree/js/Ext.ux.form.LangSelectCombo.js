// vim: ts=4:sw=4:nu:fdc=4:nospell
/*global Ext */
/**
 * @class Ext.ux.form.LangSelectCombo
 * @extends Ext.ux.form.IconCombo
 *
 * Combo pre-configured for language selection. Keeps state if a provider is set.
 * 
 * @author    Ing. Jozef Sakáloš 
 * @copyright (c) 2008, by Ing. Jozef Sakáloš
 * @version   1.0
 * @date      21. March 2008
 * @revision   $Id: Ext.ux.form.LangSelectCombo.js 531 2009-02-02 01:07:35Z jozo $
 *
 * @license Ext.ux.form.GenderCombo is licensed under the terms of
 * the Open Source LGPL 3.0 license.  Commercial use is permitted to the extent
 * that the code/component(s) do NOT become part of another Open Source or Commercially
 * licensed development library or toolkit without explicit permission.
 * 
 * <p>License details: <a href="http://www.gnu.org/licenses/lgpl.html"
 * target="_blank">http://www.gnu.org/licenses/lgpl.html</a></p>
 */

Ext.ns('Ext.ux.form');

/**
 * Creates new LangSelectCombo
 * @constructor
 * @param {Object} config A config object
 */
Ext.ux.form.LangSelectCombo = Ext.extend(Ext.ux.form.IconCombo, {
	 selectLangText:'Select Language'
	,lazyRender:true
	,lazyInit:true
	,langVariable:'locale'
	,typeAhead:true
	/**
	 * @cfg {Array} data Two dimensional array that contains available locales in the form of
	 *<pre>
	 *[
	 *&nbsp;	 ['cs_CZ', 'Český', 'ux-flag-cz']
	 *&nbsp;	,['de_DE', 'Deutsch', 'ux-flag-de']
	 *&nbsp;	,['fr_FR', 'French', 'ux-flag-fr']
	 *&nbsp;	,['nl_NL', 'Dutch', 'ux-flag-nl']
	 *&nbsp;	,['en_US', 'English', 'ux-flag-us']
	 *&nbsp;	,['ru_RU', 'Russian', 'ux-flag-ru']
	 *&nbsp;	,['sk_SK', 'Slovenský', 'ux-flag-sk']
	 *&nbsp;	,['es_ES', 'Spanish', 'ux-flag-es']
	 *&nbsp;	,['tr_TR', 'Turkish', 'ux-flag-tr']
	 *]
	 * </pre>
	 * First field is locale code, second is language name and third is iconCls for country flags to display
	 */
	,data:[
		 ['cs_CZ', 'Český', 'ux-flag-cz']
		,['de_DE', 'Deutsch', 'ux-flag-de']
		,['fr_FR', 'French', 'ux-flag-fr']
		,['nl_NL', 'Dutch', 'ux-flag-nl']
		,['en_US', 'English', 'ux-flag-us']
		,['ru_RU', 'Russian', 'ux-flag-ru']
		,['sk_SK', 'Slovenský', 'ux-flag-sk']
		,['es_ES', 'Spanish', 'ux-flag-es']
		,['tr_TR', 'Turkish', 'ux-flag-tr']
	]
	,initComponent:function() {
		var langCode = Ext.state.Manager.getProvider() ? Ext.state.Manager.get(this.langVariable) : 'en_US'
		langCode = langCode ? langCode : 'en_US'

		var config = {
			store:new Ext.data.SimpleStore({
				id:0
				,fields:[
					 {name:'langCode', type:'string'}
					,{name:'langName', type:'string'}
					,{name:'langCls', type:'string'}
				]
				,data:this.data
			})
			,valueField:'langCode'
			,displayField:'langName'
			,iconClsField:'langCls'
			,triggerAction:'all'
			,mode:'local'
			,forceSelection:true
			,value:langCode
		}; // eo config object

		// apply config
        Ext.apply(this, Ext.apply(this.initialConfig, config));

		// call parent
		Ext.ux.form.LangSelectCombo.superclass.initComponent.apply(this, arguments);

	} // eo function initComponent

	,onSelect:function(record) {
		// call parent
		Ext.ux.form.LangSelectCombo.superclass.onSelect.apply(this, arguments);

		var langCode = record.get('langCode');
		// save state to state manager
		if(Ext.state.Manager.getProvider()) {
			Ext.state.Manager.set(this.langVariable, langCode);
		}

		// reload page
		window.location.search = this.langVariable + '=' + langCode;

	} // eo function onSelect

}) // eo extend

// eof
