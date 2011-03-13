/*
 * $HeadURL:: http://ambraproject.org/svn/ambra/head/ambra/libs/js/src/main/scripts/ambr#$
 * $Id: alm.js 7770 2009-07-07 18:51:15Z josowski $
 *
 * Copyright (c) 2006-2010 by Public Library of Science
 * http://plos.org
 * http://ambraproject.org
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * ambra.alm
 *
 * This class has utilities for fetching data from the ALM application.
 **/

dojo.provide("alm");

dojo.require("dojo.io.script");

(function() {
  dojo.declare("alm", null, {
    constructor:function() {
      if(almHost != null && almHost != '' && almHost != 'alm.example.org') {
        //almHost should always be defined as a global variable
        this.host = almHost;
      } else {
        throw new Error('The related article metrics server is not defined.  Make sure the ambra/platform/freemarker/almHost node is defined the ambra.xml file.');
      }
    },

    /*
    * If the article is less then 48 hours old, we don't want to display
    * the data quiet yet.
    * */
    validateArticleDate:function(date) {
      //The article publish date should be stored in the current page is a hidden form variable
      var pubDateInMilliseconds = new Number(date);
      var todayMinus48Hours = (new Date()).getTime() - 172800000;

      if(todayMinus48Hours < pubDateInMilliseconds) {
        return false;
      } else {
        return true;
      }
    },

    isArticle:function(doi) {
      if(doi.indexOf("image") > -1) {
        return false;
      }

      return true;
    },

    validateDOI:function(doi) {
      if(doi == null) {
        throw new Error('DOI is null.');
      }

      doi = encodeURI(doi);

      return doi.replace(new RegExp('/', 'g'),'%2F').replace(new RegExp(':', 'g'),'%3A');
    },

    getIDs:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);

      var request = "articles/" + doi + ".json?history=0";
      this.getData(request, callBack, errorCallback);
    },

    getRelatedBlogs:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);

      var request = "articles/" + doi + ".json?citations=1&source=Bloglines,Nature,Postgenomic,research%20Blogging";
      this.getData(request, callBack, errorCallback);
    },

    getSocialBookMarks:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);

      var request = "articles/" + doi + ".json?citations=1&source=Citeulike,Connotea";
      this.getData(request, callBack, errorCallback);
    },

    getCites:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);

      var request = "articles/" + doi + ".json?citations=1&source=CrossRef,PubMed%20Central,Scopus";
      this.getData(request, callBack, errorCallback);
    },

    getCounter:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);

      var request = "articles/" + doi + ".json?citations=1&source=Counter";
      this.getData(request, callBack, errorCallback);
    },

    getBiodData:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);

      var request = "articles/" + doi + ".json?citations=1&source=Biod";
      this.getData(request, callBack, errorCallback);
    },

    getCitesCrossRefOnly:function(doi, callBack, errorCallback) {
      doi = this.validateDOI(doi);
      
      var request = "articles/" + doi + ".json?citations=1&source=CrossRef";
      this.getData(request, callBack, errorCallback);
    },

    /*
    * Get summaries and counter data for the collectiong of article IDs
    * passed in.  If an article is not found, or a source data is not found
    * The data will be missing in the resultset.
    * */
    getSummaryForArticles:function(dois, callBack, errorCallback) {
      idString = "";
      for (a = 0; a < dois.length; a++) {
        if(idString != "") {
          idString = idString + ",";
        }

        idString = idString + this.validateDOI("info:doi/" + dois[a]);
      }

      var request = "group/articles.json?id=" + idString + "&group=statistics";
      this.getData(request, callBack, errorCallback);
    },

    massageCounterData:function(data, pubDateMS)
    {
      //Do some final calculations on the results
      var pubDate = new Date(pubDateMS);
      var pubYear = pubDate.getFullYear();
      //Add one as getMonth is zero based
      var pubMonth = pubDate.getMonth() + 1;

      data.totalPDF = 0;
      data.totalXML = 0;
      data.totalHTML = 0;
      data.total = 0;

      //Don't display any data from any date before the publication date
      for(var a = 0; a < data.length; a++) {
        if(data[a].year < pubYear || (data[a].year == pubYear && data[a].month < pubMonth)) {
          data.splice(a,1);
          a--;
        }
      }

      for(var a = 0; a < data.length; a++) {
        var totalViews = new Number(data[a].html_views)+ new Number(data[a].xml_views) + new Number(data[a].pdf_views);
        //Total views for the current period
        data[a].total = totalViews;

        //Total views so far
        data[a].cumulativeTotal = new Number(data.total) + totalViews;
        data[a].cumulativePDF = data.totalPDF + new Number(data[a].pdf_views);
        data[a].cumulativeXML = data.totalXML + new Number(data[a].xml_views);
        data[a].cumulativeHTML = data.totalHTML + new Number(data[a].html_views);

        //The grand totals
        data.totalPDF += new Number(data[a].pdf_views);
        data.totalXML += new Number(data[a].xml_views);
        data.totalHTML += new Number(data[a].html_views);
        data.total += totalViews;
      }

      return data;
    },

    /**
      *  host is the host and to get the JSON response from
      *  chartIndex is the  current index of the charts[] array
      *  callback is the method that populates the chart of  "chartIndex"
      *  errorCallback is the method that gets called when:
      *    --The request fails (Network error, network timeout)
      *    --The request is "empty" (Server responds, but with nothing)
      *    --The callback method fails
      **/
    getData:function(request, callBack, errorCallback) {
      var url = this.host + "/" + request;

      console.log(url);

      var getArgs = {
        callbackParamName: "callback",
        url:url,
        caller:this,
        callback:callBack,
        errorCallback:errorCallback,

        load:function(response, args) {
          /**
           * Callback is the method being called.
           * args.args.caller is the object the method is part of
           **/
          if(response == null) {
            throw new Error('The server did not send an appropriate response.');
          }

          callBack.call(args.args.caller, response);
          return response;
        },

        error:function(response, args) {
          /**
            * Callback is the method being called.
            * args.args.caller is the object the method is part of
            **/
          errorCallback.call(args.args.caller, "Our system is having a bad day. We are working on it. Please check back later.");
          return response;
        },

        timeout:10000
      };

      dojo.io.script.get(getArgs);
    }
  });
})();

function setError(textID, message) {
  dojo.byId(textID).style.display = 'none';
  dojo.byId(textID).innerHTML = '<span class="inlineError"><img src="' + appContext + '/images/icon_error.gif"/>&nbsp;' + message + '</span>';
  dojo.fx.wipeIn({ node:textID, duration: 1000 }).play();
}

function setDelayMessageError(textID) {
  dojo.byId(textID).style.display = 'none';
  dojo.byId(textID).innerHTML = '<span class="inlineError"><img src="' + appContext + '/images/icon_error.gif"/>&nbsp;This article was only recently published.</span>';
  dojo.fx.wipeIn({ node:textID, duration: 1000 }).play();
}

function setNoDataMessageError(textID) {
  dojo.byId(textID).style.display = 'none';
  dojo.byId(textID).innerHTML = '<span class="inlineError"><img src="' + appContext + '/images/icon_error.gif"/>&nbsp;We don\'t collect usage data for this type of content.</span>';
  dojo.fx.wipeIn({ node:textID, duration: 1000 }).play();
}


