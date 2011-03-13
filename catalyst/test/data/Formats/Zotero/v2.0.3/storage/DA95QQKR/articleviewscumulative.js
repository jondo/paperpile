dojo.provide("reporting.articleViewsCumulative");

dojo.require("ambra.domUtil");
dojo.require("ambra.formUtil");

dojo.require("dojox.fx");
dojo.require("dojox.gfx.fx");
dojo.require("dojox.charting.Chart2D");
dojo.require("dojox.charting.plot2d.Lines");
dojo.require("dojox.charting.action2d.Magnify");
dojo.require("dojox.charting.action2d.Tooltip");
dojo.require("dojox.charting.plot2d.Grid");

dojo.require("dojox.charting.themes.Grasshopper");

(function(){

  dojo.declare("reporting.articleViewsCumulative", null,  {
    
    create:function(data, objectID, lineColor, pubDate)
    {
      var avChart = new dojox.charting.Chart2D(objectID);
      
      avChart.addPlot("default", {
          type: "Default",
          markers: true,
          tension: 0,
          shadows: {dx: 2, dy: 2, dw: 2}
        });
      
      var series = [ { x: 0, y: 0, tooltip: '<div id=\"infoBox\" class=\"infoBoxPad\">Article published on: ' +
        Date.formatDate(pubDate) + '</div>' } ];

      for(var a = 0; a < data.length; a++)
      {
        series[series.length] = {
          x: a + 1,
          y: data[a].cumulativeTotal,
          tooltip: "<div id=\"infoBox\"><table id=\"mini\"><colgroup><col />" +
                   "<col class=\"emph\" /><col /></colgroup><thead><tr>" +
                   "<th scope=\"col\" class=\"text\">View Type</th><th scope=\"col\">" +
                   "<span class=\"noWrap\">Views in<br/>" +
                   Date.getMonthShortName(data[a].month - 1) + " '" +
                   (new String(data[a].year)).substring(2) + "</span></th>" +
                   "<th scope=\"col\" class=\"primary\"><span class=\"noWrap\">Total since<br/>" +
                   Date.getMonthShortName(pubDate.getMonth()) +
                   " " + pubDate.getDate() + " '" + (new String(pubDate.getFullYear())).substring(2) +
                   "</span></th></tr></thead><tfoot><tr><td class=\"text\">Total</td>" +
                   "<td>" + data[a].total +"</td><td class=\"primary\">" + data[a].cumulativeTotal +
                   "</td></tr></tfoot><tbody><tr><td class=\"text\">HTML</td>" +
                   "<td>" + data[a].html_views + "</td><td class=\"primary\">" +
                   data[a].cumulativeHTML + "</td></tr><tr><td class=\"text\">PDF</td><td>" +
                   data[a].pdf_views + "</td><td class=\"primary\">" + data[a].cumulativePDF +
                   "</td></tr><tr><td class=\"text\">XML</td><td>" + data[a].xml_views + "</td>" +
                   "<td class=\"primary\">" + data[a].cumulativeXML + "</td></tr></tbody></table>" +
                   "</div>"
        };
      }
      
      var hStep = Math.round(data.length / 12) + 1;
      
      avChart.addAxis("x", {
        min: 0, max: data.length + 1,
        vertical: false,
        leftbottom: true,
        majorTickStep: hStep,
        minorTicks: false,
        majorTick: { length: 5, color:"#E0E0E0" }, 
        minorTick: { length:2, color: "#E0E0E0" } 
      });
      
      avChart.addAxis("y", { 
        vertical: true, min: 0, max: data.total + (data.total * .1), 
        leftbottom: true,
        minorTicks: false,
        majorTick: { length: 5, color:"#E0E0E0" }, 
        minorTick: { length:2, color: "#E0E0E0" }
      });
        
      avChart.addPlot("plot", {type: "Grid", hAxis:"x", vAxis:"y", 
        hMajorLines: true, hMinorLines: false, 
        vMajorLines: true, vMinorLines: false });

      //Safari seems to have issue with the rounded markers.
      //If dojo fixes this in a later revision, we can remove this.
      //Check the dojo test site: http://archive.dojotoolkit.org/nightly/dojotoolkit/dojox/charting/tests/test_event2d.html
      if(dojo.isSafari) {
        markerStyle = "m-2,-2 l0,6 6,0 0,-6 z";
      } else {
        markerStyle = "m-3,0 c0,-4 6,-4 6,0 m-6,0 c0,4 6,4 6,0";
      }
      
      avChart.addSeries("Article Views", series, { 
        stroke: {color: lineColor, width: 1},
        marker: markerStyle
      });

      var ani_1 = new dojox.charting.action2d.Magnify(avChart, "default", 
        { scale: 3 });
      var ani_2 = new dojox.charting.action2d.Tooltip(avChart, "default");

      avChart.setTheme(new dojox.charting.Theme(
      {
        axis: { 
          majorTick: { color: "#E0E0E0", width: 1 },
          minorTick: { color: "#E0E0E0", width: 1 }
        }
      }));      
      
      avChart.render();
    }
  });
})();

