Paperpile.utils = {
  splitPath: function(path) {
    var parts = path.split('/');
    var file = parts[parts.length - 1];
    var newParts = parts.slice(0, parts.length - 1);
    var dir = newParts.join('/');
    return {
      dir: dir,
      file: file
    };
  },

  // Returns true if path is absolute. Gets more interesting under Windows...
  isAbsolute: function(path) {

    return (path.substring(0, 1) == '/');

  },

  openURL: function(url) {
    if (IS_TITANIUM) {
      var process = Titanium.Process.launch('xdg-open', url);
    } else {
      window.open(url, '_blank');
    }
  },

  openFile: function(file) {

    if (IS_TITANIUM) {

      var process = Titanium.Process.launch('xdg-open', file);
      // TODO: handle return of xdg-open; we wait until process
      // API is more stable
    } else {
      window.open('/serve/' + file, '_blank');
    }

  },

  get_platform: function() {

    var platform = '';

    if (IS_TITANIUM) {

      // Determine platform we are running on
      var osname = Titanium.Platform.name;
      var ostype = Titanium.Platform.ostype;

      if (osname === 'Linux') {
        if (ostype === '64bit') {
          platform = 'linux64';
        } else {
          platform = 'linux32';
        }
      }
    }

    return (platform);
  },

  // Encode tag using our special format to allow unique full text searches
  encodeTag: function(tag) {

    tag = tag.replace(/ /g, "99");

    return '88' + tag + '88';

  },

  catPath: function() {

    var parts = [];

    // Note: we can't run join on the arguments array which is
    // technically no array object
    for (var i = 0; i < arguments.length; ++i) {
      parts.push(arguments[i]);
    }

    return parts.join('/');
  },

  // The intended purpose of this function is to convert the GMT
  // timestamp to local time; for now it justs chops of the time
  // from the date string
  localDate: function(date) {
    return date.replace(/\d+:\d+:\d+/g, "");
  },

  secondsAgo: function(date_str) {
    var time = ('' + date_str).replace(/-/g, "/").replace(/[TZ]/g, " ");
    var dt = new Date;
    var seconds = ((dt - new Date(time) + (dt.getTimezoneOffset() * 60000)) / 1000);
    return seconds;
  },

  /*
 * Javascript Humane Dates
 * Copyright (c) 2008 Dean Landolt (deanlandolt.com)
 * Re-write by Zach Leatherman (zachleat.com)
 * 
 * Adopted from the John Resig's pretty.js
 * at http://ejohn.org/blog/javascript-pretty-date
 * and henrah's proposed modification 
 * at http://ejohn.org/blog/javascript-pretty-date/#comment-297458
 * 
 * Licensed under the MIT license.
 */

  prettyDate: function(date_str) {

    var time_formats = [
      [60, 'Just now'],
      [90, '1 minute'], // 60*1.5
    [3600, 'minutes', 60], // 60*60, 60
    [5400, '1 hour'], // 60*60*1.5
    [86400, 'hours', 3600], // 60*60*24, 60*60
    [129600, '1 day'], // 60*60*24*1.5
    [604800, 'days', 86400], // 60*60*24*7, 60*60*24
    [907200, '1 week'], // 60*60*24*7*1.5
    [2628000, 'weeks', 604800], // 60*60*24*(365/12), 60*60*24*7
    [3942000, '1 month'], // 60*60*24*(365/12)*1.5
    [31536000, 'months', 2628000], // 60*60*24*365, 60*60*24*(365/12)
    [47304000, '1 year'], // 60*60*24*365*1.5
    [3153600000, 'years', 31536000], // 60*60*24*365*100, 60*60*24*365
    [4730400000, '1 century'], // 60*60*24*365*100*1.5
    ];

    var time = ('' + date_str).replace(/-/g, "/").replace(/[TZ]/g, " ");
    var dt = new Date;
    var seconds = ((dt - new Date(time) + (dt.getTimezoneOffset() * 60000)) / 1000);
    var token = ' ago';
    var i = 0;
    var format;

    if (seconds < 0) {
      seconds = Math.abs(seconds);
      token = '';
    }

    while (format = time_formats[i++]) {
      if (seconds < format[0]) {
        if (format.length == 2) {
          return format[1] + (i > 1 ? token : ''); // Conditional so we don't return Just Now Ago
        } else {
          return Math.round(seconds / format[2]) + ' ' + format[1] + (i > 1 ? token : '');
        }
      }
    }

    // overflow for centuries
    if (seconds > 4730400000) return Math.round(seconds / 4730400000) + ' Centuries' + token;

    return date_str;
  }
};