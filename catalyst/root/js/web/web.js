var s = document.createElement('script');
s.src = 'http://localhost:3000/js/web/ext-core-debug.js';
s.onload = function() {
  Ext.DomHelper.append(document.body, {
    tag: 'p',
    cls: 'some-class'
  });
  Ext.select('p.some-class').update('Ext Core successfully injected');
};

document.getElementsByTagName('head')[0].appendChild(s);