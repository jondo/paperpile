Ext.BLANK_IMAGE_URL = './ext/resources/images/default/s.gif';
Ext.ns('Paperpile');

IS_TITANIUM = !(window['Titanium'] == undefined);
IS_CHROME = navigator.userAgent.toLowerCase().indexOf('chrome') > -1;
IS_WEBIMPORT = !(window['PP'] == undefined);

Paperpile.Url = function(url) {
  return (IS_TITANIUM || IS_WEBIMPORT) ? 'http://127.0.0.1:3210' + url : url;
};

Paperpile.log = function() {
  if (IS_TITANIUM) {
    Titanium.API.debug(arguments[0]);
  } else if (IS_CHROME) {
    console.log(arguments[0]);
  } else if (window.console) {
    console.log(arguments);
  }
};
