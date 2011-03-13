/*
 * $HeadURL:: http://ambraproject.org/svn/ambra/head/ambra/webapp/src/main/webapp/javasc#$
 * $Id: init_article_body.js 7770 2009-07-07 18:51:15Z ssterling $
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
dojo.require("dojo.fx");

dojo.addOnLoad(
  function() {
    var almService = new alm();
    var doi = dojo.byId('doi').value;
    var articleDate = dojo.byId('articlePubDate').value;

    if(almService.validateArticleDate(articleDate) && almService.isArticle(doi)) {
      //Make calls to fill in data in the right hand column
      almService.getIDs(doi, setIDsInRHC, setIDsInRHCError);
      almService.getCites(doi, setCitesInRHC, setCitesInRHCError);
      almService.getCounter(doi, setChartDataInRHC, setChartDataInRHCError);
      almService.getBiodData(doi, setBiodArticle, setBiodArticleError);
    }
  }
);

function setBiodArticleError(message)
{
  //Just ignore errors for this content area
}

function setBiodArticle(response)
{
  var contentHeaderNode = dojo.byId('contentHeader');
  var publishedNode = dojo.query('div#publisher p a');
  var doi = response.article.doi;
  var newPublishedNode = null;

  if (response.article.source.length > 0) {
    if(response.article.source[0].count > 0) {
      if(publishedNode.length == 0) {
        //If the published HTML node does not exist, create it
        newPublishedNode = dojo.create("div", {
            id:"publisher",
            style:"display:none",
            innerHTML:"<p>This article is featured in <a href=\"http://hubs.plos.org/web/biodiversity/article/" + doi + "\">PLoS Hubs: Biodiversity</a></p>"
          },
          contentHeaderNode, "after");
        dojo.fx.wipeIn({ node:newPublishedNode, duration:250 }).play();
      } else {
        //If the 'published' node exists, add a new element
        newPublishedNode = dojo.create("span", {
            id:"newPublishedNode",
            style: "opacity:0",
            innerHTML:"&nbsp;and in <a href=\"http://hubs.plos.org/web/biodiversity/article/" + doi + "\">PLoS Hubs: Biodiversity</a>"
          },
          publishedNode[0], "after");
        dojo.fadeIn({ node:newPublishedNode, duration:250 }).play();
      }
    }
  }
}