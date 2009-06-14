Paperpile.utils = {
    splitPath : function(path) { 
        var parts=path.split('/');
        var file=parts[parts.length-1];
        var newParts=parts.slice(0,parts.length-1);
        var dir=newParts.join('/');
        return {dir:dir, file:file};
        
    }
}
