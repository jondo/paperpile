Ext.onReady(function() {

  Ext.select('p#check').update('<i>Ext Core successfully loaded</i>');
  
  Ext.select('a#start-select-file').on('click',testSelectFile, this);
  Ext.select('a#start-open-file').on('click',testOpenFile, this);
  Ext.select('a#start-open-url').on('click',testOpenUrl, this);
  Ext.select('a#start-read-clipboard').on('click',testReadClipboard, this);
  Ext.select('a#start-write-clipboard').on('click',testWriteClipboard, this);
  Ext.select('a#start-ajax1').on('click',testAjax1, this);
  Ext.select('a#start-ajax2').on('click',testAjax2, this);
  Ext.select('a#start-catalyst').on('click',startCatalyst, this);

});


testSelectFile = function(){

  var file = window.QRuntime.getOpenFileName("Select any file","/","All files (*.*)");

  Ext.select('p#result-select-file').update('<tt>'+file+'</tt>').highlight();
  
}

testOpenFile = function(){

  var file = window.QRuntime.getOpenFileName("Select any file","/","All files (*.*)");

  if (!file) return;

  window.QRuntime.openFile(file);
  
}

testOpenUrl = function(){

  window.QRuntime.openUrl("http://google.com");
  
}

testReadClipboard = function(){

  var text = window.QRuntime.getClipboard();
  
  Ext.select('p#result-read-clipboard').update('<tt>'+text+'</tt>').highlight();
  
}

testWriteClipboard = function(){

  window.QRuntime.setClipboard("Qt rocks!");

  Ext.select('p#result-write-clipboard').update('Clipboard updated!').highlight();
  
}



testAjax1 = function(){


  var xmlhttp=new XMLHttpRequest()
  try {
    xmlhttp.open('get', 'http://127.0.0.1:3210/ajax/app/heartbeat')
    xmlhttp.onreadystatechange = function(){
      if (xmlhttp.readyState == 4){
        alert("state 4" + xmlhttp.status+xmlhttp.responseText);
      }
      else {
        alert("state " + xmlhttp.readyState)
      }
    };
    xmlhttp.send(null);
  }
  catch (e){alert("An exception occurred in the script. Error name: " + e.name 
                  + ". Error message: " + e.message); 
           }

/*

  Ext.Ajax.request({
    url: 'http://127.0.0.1:3210/ajax/app/heartbeat',
    success: function(response, opts) {
      var obj = Ext.decode(response.responseText);
      alert('Success');
    },
    failure: function(response, opts) {
      alert('Failure'+response.status);
    }
  });

*/
}



testAjax2 = function(){


  /*
  var xmlhttp=new XMLHttpRequest()
  try {
    xmlhttp.open('get', 'http://127.0.0.1:3210/ajax/app/heartbeat')
    xmlhttp.onreadystatechange = function(){
      if (xmlhttp.readyState == 4){
        alert("state 4" + xmlhttp.status+xmlhttp.responseText);
      }
      else {
        alert("state " + xmlhttp.readyState)
      }
    };
    xmlhttp.send(null);
  }
  catch (e){alert("An exception occurred in the script. Error name: " + e.name 
                  + ". Error message: " + e.message); 
           }

*/

  debugger;

  Ext.Ajax.request({
    url: 'http://127.0.0.1:3210/ajax/app/heartbeat',
    success: function(response, opts) {
      var obj = Ext.decode(response.responseText);
      alert('Success');
    },
    failure: function(response, opts) {
      alert('Failure'+response.status);
    },
    xdomain:true
  });
}

update = function(string) {
  Ext.select('pre#result-catalyst-output').update(string);
};

startCatalyst = function(){

  window.QRuntime.catalystRead.connect(update);
  window.QRuntime.startCatalyst();

}



