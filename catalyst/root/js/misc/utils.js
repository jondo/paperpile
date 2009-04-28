Paperpile.utils = {
    splitPath : function(path) { 
        console.log(path);

        var parts=path.split('/');
        var file=parts[parts.length-1];
        var newParts=parts.slice(0,parts.length-1);
        //newParts.unshift('ROOT');
        var dir=newParts.join('/');
        return {dir:dir, file:file};
        
    }
}
