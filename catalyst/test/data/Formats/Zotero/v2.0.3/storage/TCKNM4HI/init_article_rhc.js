/*
 * $HeadURL:: http://ambraproject.org/svn/ambra/head/ambra/webapp/src/main/webapp/javasc#$
 * $Id: init_article_metrics.js 7723 2009-06-03 00:23:44Z ssterling $
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
 *
 * This Javascript file formats ALM (Article Level Metrics) content (the "response" parameter in
 * all the following functions) for display in the Right Hand Column of the Article page.
 * Each of these methods is called from the other functions defined in the other Javascript
 * files with names like "init_article_FOO.js".
 */
function setChartDataInRHC(response) {
  dojo.byId('totalDataInRHC').style.display = 'none';

  //  If there is no data, then suppress this output.
  if (response.article == null
      || response.article.source == null || response.article.source.length < 1
      || response.article.source[0].citations == null || response.article.source[0].citations.length < 1
      || response.article.source[0].citations[0].citation == null
      || response.article.source[0].citations[0].citation.views == null
      ) {
    return;
  }

  var almService = new alm();
  var pubDateInMilliseconds = new Number(dojo.byId('articlePubDate').value);
  var data = almService.massageCounterData(response.article.source[0].citations[0].citation.views, pubDateInMilliseconds);
  var metricsTabURL = dojo.byId('metricsTabURL').value;

  //If there is no data, don't bother rendering it in the right hand column
  if(data.total > 0) {
    dojo.byId('totalDataInRHC').innerHTML = "<p/><strong>Total Article Views: " + "<a href=\"" + metricsTabURL + "#usage\">" + data.total + "</a></strong>";
    dojo.fx.wipeIn({ node:'totalDataInRHC', duration: 1000 }).play();
  }
}

function setChartDataInRHCError(message)
{
  //If there is no data or error, then suppress this output. 
}

/**
 * Format the response from Article Level Metrics as HTML for the Right Hand Column of the
 * Article pages.
 *
 * @param response The reply back from the Article Level Metrics server.
 * @param args All of the other arguments for communication with ALM.  Not used by this method.
 */
function setCitesInRHC(response) {
  dojo.byId('relatedCitesInRHC').style.display = 'none';

  var numCitesRendered = 0;
  var doi = escape(dojo.byId('doi').value);

  if (response.article.source.length > 0) {
    var html = "";

    for (var a = 0; a < response.article.source.length; a++) {
      var url = response.article.source[a].public_url;

      //  If CrossRef, then compose a URL to our own CrossRef Citations page.
      if (response.article.source[a].source == 'CrossRef' && response.article.source[a].count > 0) {
        html = html + "<dd><a href=\"" + dojo.byId('crossRefPageURL').value + "\">CrossRef ("
            + response.article.source[a].count + ")</a></dd>";
        numCitesRendered++;
      }
      //  Only list links that HAVE DEFINED URLS
      else if (url && response.article.source[a].count > 0) {
        html = html + "<dd><a href=\"" + url + "\">" + response.article.source[a].source + " ("
              + response.article.source[a].count + ")</a></dd>";
        numCitesRendered++;
      }
    }
  }

  if (numCitesRendered == 0) {
  } else {
    html = "<dl class='related'><dt>Cited in<dt>" + html + "</dl>";
    dojo.byId('relatedCitesInRHC').innerHTML = html;
    dojo.fx.wipeIn({ node:'relatedCitesInRHC', duration: 1000 }).play();
  }
}

function setCitesInRHCError(message)
{
  //If there is no data or error, then suppress this output. 
}

/**
 * Format the response from Article Level Metrics as HTML for the Right Hand Column of the
 * Article pages.
 *
 * @param response The reply back from the Article Level Metrics server.
 * @param args All of the other arguments for communication with ALM.  Not used by this method.
 */
function setIDsInRHC(response) {
  if (response.article.pub_med) {
    var pubMedID = 0;
    pubMedID = response.article.pub_med;

    dojo.byId('pubMedRelatedURLInRHC').href="http://www.ncbi.nlm.nih.gov/sites/entrez?Db=pubmed&DbFrom=pubmed&Cmd=Link&LinkName=pubmed_pubmed&LinkReadableName=Related%20Articles&IdsFromResult=" + pubMedID + "&ordinalpos=1&itool=EntrezSystem2.PEntrez.Pubmed.Pubmed_ResultsPanel.Pubmed_RVCitation";
    dojo.fx.wipeIn({ node:'pubMedRelatedLIInRHC', duration: 500 }).play();
  }
}

function setIDsInRHCError(message) {
  //If there is no data or error, then suppress this output. 
}