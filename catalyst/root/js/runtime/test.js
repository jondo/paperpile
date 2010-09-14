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
  Ext.select('a#start-window-resize').on('click',resizeWindow, this);
  Ext.select('a#start-file-info').on('click',fileInfo, this);

});


testSelectFile = function(){

/*
AcceptMode
 AcceptOpen  0
 AcceptSave  1

DialogLabel
 LookIn	      0
 FileName	  1
 FileType	  2
 Accept	      3
 Reject	      4

FileMode
 AnyFile       0    The name of a file, whether it exists or not.
 ExistingFile  1    The name of a single existing file.
 Directory	   2    The name of a directory. Both files and directories are displayed.
 ExistingFiles 3    The names of zero or more existing files. 

*/


  //var file = window.QRuntime.getOpenFileName("Select any file","/","All files (*.*)");

  var results = window.QRuntime.fileDialog({'AcceptMode':0, 'DialogLabel':0, 'FileMode':0});

  Ext.select('p#result-select-file-files').update('<tt>'+results.files.join(',')+'</tt>').highlight();
  
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

  window.QRuntime.catalystReady.connect(
    function(){
      //alert("Catalyst ready");
    }
  );

  window.QRuntime.catalystExit.connect(
    function(error){
      //alert("Catalyst error"+error);
    }
  );
  
  
  window.QRuntime.startCatalyst();

}


resizeWindow = function(){
  window.QRuntime.resizeWindow(800,600);
}


fileInfo = function(){
  

  QRuntime.fileInfo("/Users/wash/test.txt");

}


