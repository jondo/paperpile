/*
 * $HeadURL:: http://svn.ambraproject.org/svn/ambra/tags/journal-publishing-system-1.3/a#$
 * $Id: init_article.js 8561 2010-07-08 21:05:03Z ssterling $
 *
 * Copyright (c) 2006-2010 by Public Library of Science
 * http://plos.org
 * http://ambraproject.org
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

dojo.require("dojo.fx");

// the "loading..." widget
var _ldc;

// annotation related globals
var annotationConfig = {
  articleContainer: "articleContainer",
  rhcCount: "dcCount",
  trigger: "addAnnotation",
  lastAncestor: "researchArticle",
  xpointerMarker: "xpt",
  // NOTE: 'note-pending' class is used to identify js-based annotation
  //  related document markup prior to persisting the annotation
  annotationMarker: "note note-pending",
  pendingAnnotationMarker: 'note-pending',
  annotationImgMarker: "noteImg",
  regionalDialogMarker : "rdm",
  excludeSelection: "noSelect",
  tipDownDiv: "dTip",
  tipUpDiv: "dTipu",
  isAuthor: false,  //TODO: *** Default to false when the hidden input is hooked up.
  isPublic: true,
  dfltAnnSelErrMsg: 'This area of text cannot be notated.',
  annSelErrMsg: null,
  rangeInfoObj: new Object(),
  annTypeMinorCorrection: 'MinorCorrection',
  annTypeFormalCorrection: 'FormalCorrection',
  annTypeRetraction: 'Retraction',
  styleMinorCorrection: 'minrcrctn', // generalized css class name for minor corrections
  styleFormalCorrection: 'frmlcrctn', // generalized css class name for formal corrections
  styleRetraction: 'retractionCssStyle' // generalized css class name for retractions.  Using Formal Corrections style.
};
var formalCorrectionConfig = {
  styleFormalCorrectionHeader: 'fch', // css class name for the formal correction header node
  fchId: 'fch', // the formal correction header node dom id
  fcListId: 'fclist', // the formal correction header sub-node referencing the ordered list
  annid: 'annid', // dom node attribute name to use to store annotation ids
  fcLinkClass: 'formalCorrectionHref' //The link class to that dojo uses to find links to attach events to
};
var retractionConfig = {
    //  styleRetractionHeader: 'retractionCssStyle', // css class name for the retraction header node
    //  The name "retractionHtmlId" is a bad choice.  The only reason it is being used is as an extension of a bad
    //  decision (i.e., naming formalCorrectionConfig.styleFormalCorrectionHeader and formalCorrectionConfig.fchId
    //  the same value: "fch") made when Formal Corrections were implemented.
  styleRetractionHeader: 'retractionHtmlId', // css class name for the retraction header node
  retractionHtmlId: 'retractionHtmlId', // the retraction header node dom id
  retractionListId: 'retractionlist', // the retraction header sub-node referencing the ordered list
  retractionAnnId: 'retractionAnnId' // dom node attribute name to use to store annotation ids
};
var _annotationDlg;
var _annotationForm;

// comment/multi-comment globals
var commentConfig = {
  cmtContainer: "cmtContainer",
  sectionTitle: "viewCmtTitle",
  sectionDetail: "viewCmtDetail",
  sectionComment: "viewComment",
  sectionCIStatement: "viewCIStatement",
  ciStatementMsg: "Competing interests declared: ",
  noCIStatementMsg: "No competing interests declared.",
  sectionLink: "viewLink",
  retrieveMsg: "retrieveMsg",
  tipDownDiv: "cTip",
  tipUpDiv: "cTipu"
};
var multiCommentConfig = {
  sectionTitle: "viewCmtTitle",
  sectionDetail: "viewCmtDetail",
  sectionComment: "viewComment",
  sectionCIStatement: "viewCIStatement",
  ciStatementMsg: "Competing interests declared: ",
  noCIStatementMsg: "No competing interests declared.",
  retrieveMsg: "retrieveMsg",
  tipDownDiv: "mTip",
  tipUpDiv: "mTipu"
};
var _commentDlg;
var _commentMultiDlg;

var _titleCue          = 'Enter your note title...';
var _commentCue        = 'Enter your note...';
var _statementCue      = 'Enter your competing interests...';

var elLocation;

function toggleAnnotation(obj, userType) {
  _ldc.show();
  var bugs = document.getElementsByTagAndClassName('a', 'bug');

  for (var i=0; i<bugs.length; i++) {
    var classList = new Array();
    classList = bugs[i].className.split(' ');
    for (var n=0; n<classList.length; n++) {
      if (classList[n].match(userType))
        bugs[i].style.display = (bugs[i].style.display == "none") ? "inline" : "none";
    }
  }

  toggleExpand(obj, null, "Show notes", "Hide notes");

  _ldc.hide();
}

function getAnnotationEl(annotationId) {
  var elements = document.getElementsByTagAndAttributeName('a', 'displayid');
  var targetEl;
  for (var i=0; i<elements.length; i++) {
    var elDisplay = ambra.domUtil.getDisplayId(elements[i]);
    var displayList = elDisplay.split(',');
    for (var n=0; n<displayList.length; n++) {
      if (displayList[n] == annotationId) {
        targetEl = elements[i];
        return targetEl;
      }
    }
  }
  return null;
}

function jumpToAnnotation(annotationId) {
  if(!annotationId) return;
  var anNode = getAnnotationEl(annotationId);
  if(anNode) jumpToElement(anNode);
}

function toggleExpand(obj, isOpen, textOn, textOff) {
  if (isOpen == false) {
    if (textOn) { dojox.data.dom.textContent(obj, textOn); }
  }
  else if (obj.innerHTML == textOff) {
    if (textOn) { dojox.data.dom.textContent(obj, textOn); }
  }
  else {
    if (textOff) { dojox.data.dom.textContent(obj, textOff); }
  }
}

function showAnnotationDialog() {
   // reset
  _annotationForm.cNoteType.selectedIndex = 0;
  dojo.byId('cdls').style.visibility = 'hidden';
  _annotationDlg.show();
}

/**
 * clears out any error messages and then calls sendupdateRating
 * @param targetObj
 */
function validateNewComment() {
  ambra.formUtil.disableFormFields(_annotationForm);
  var submitMsg = dojo.byId('submitMsg');

  if(submitMsg.style.display != 'none') {
    var ani = dojo.fx.wipeOut({ node:submitMsg, duration: 500 });
    dojo.connect(ani, "onEnd", function () { startValidateNewComment(); });
    ani.play();
  } else {
    startValidateNewComment();
  }
}

function startValidateNewComment() {
  var submitMsg = dojo.byId('submitMsg');
  ambra.domUtil.removeChildren(submitMsg);
  ambra.formUtil.disableFormFields(_annotationForm);

  _annotationForm.noteType.value = _annotationForm.cNoteType.value;

  if (_annotationForm.competingInterest[0].checked == true) {
    _annotationForm.ciStatement.value = "";
  }

  dojo.xhrPost({
     url: _namespace + "/annotation/secure/createAnnotationSubmit.action",
     handleAs:'json-comment-filtered',
     form: _annotationForm,
     error: function(response, ioArgs){
       handleXhrError(response, ioArgs);
       ambra.formUtil.enableFormFields(_annotationForm);
     },
     load: function(response, ioArgs){
       var jsonObj = response;
       if(jsonObj.actionErrors.length > 0) {
         var errorMsg = "";
         for (var i=0; i<jsonObj.actionErrors.length; i++) {
           errorMsg += jsonObj.actionErrors[i] + "\n";
         }
         var err = document.createTextNode(errorMsg);
         submitMsg.appendChild(err);
         dojo.fx.wipeIn({ node:submitMsg.id, duration: 500 }).play();
         ambra.formUtil.enableFormFields(_annotationForm);
         _annotationDlg.placeModalDialog();
       }
       else if (jsonObj.numFieldErrors > 0) {
         var fieldErrors = document.createDocumentFragment();

         for (var item in jsonObj.fieldErrors) {
           var errorString = "";
           for (var ilist in jsonObj.fieldErrors[item]) {
             var err = jsonObj.fieldErrors[item][ilist];
             if (err && typeof(err) == 'string') {
               errorString += err;
               var error = document.createTextNode(errorString.trim());
               var brTag = document.createElement('br');

               fieldErrors.appendChild(error);
               fieldErrors.appendChild(brTag);
             }
           }
         }
         submitMsg.appendChild(fieldErrors);
         dojo.fx.wipeIn({ node:submitMsg.id, duration: 500 }).play();
         ambra.formUtil.enableFormFields(_annotationForm);

         if (_annotationForm.competingInterest[0].checked == true) {
           _annotationForm.ciStatementArea.disabled = true;
         } else {
           _annotationForm.ciStatementArea.disabled = false;
         }         

         _annotationDlg.placeModalDialog();
       }
       else {
         _annotationDlg.hide();
         ambra.formUtil.textCues.reset(_annotationForm.cTitle, _titleCue);
         ambra.formUtil.textCues.reset(_annotationForm.cArea, _commentCue);
         ambra.formUtil.textCues.reset(_annotationForm.ciStatementArea, _statementCue);
         ambra.formUtil.enableFormFields(_annotationForm);
         // remember the newly added annotation
         document.articleInfo.annotationId.value = jsonObj.annotationId;
         // re-fetch article body
         getArticle();
         markDirty(true); // set dirty flag (this ensures a later re-visit of this page will pull fresh article data from the server rather than relying on the browser cache)
       }
     }//load
  });
}

/**
 * Quasi-unique cookie name to use for storing article dirty flag.
 */
var dirtyToken = '@__sra__@';

/**
 * Determines whether the article was marked as dirty or not.
 * @return true/false
 */
function shouldRefresh() { return (dojo.cookie(dirtyToken) == 'a'); }

/**
 * Marks or un-marks the article as "dirty" via a temporary browser cookie.
 * @param dirty true/false
 */
function markDirty(dirty) { dojo.cookie(dirtyToken,dirty?'a':'b'); }

/**
 * getArticle
 *
 * Re-fetches the article from the server
 * refreshing the article content area(s) of the page.
 */
function getArticle() {
  _ldc.show();
  dojo.xhrGet( {
    url: _namespace + "/article/fetchBody.action?articleURI=" + _annotationForm.target.value,
    handleAs:'text',

    error: function(response, ioArgs) {
      handleXhrError(response);
    },

    load: function(response, ioArgs) {
      // refresh article HTML content
      dojo.byId(annotationConfig.articleContainer).innerHTML = response;
      // re-apply article "decorations"
      ambra.displayComment.processBugCount();
      ambra.corrections.init();
      ambra.navigation.buildTOC(dojo.byId('sectionNavTopBox'), dojo.byId('sectionNavTop'));

      document.articleInfo.annotationId.value = ''; // reset
      _ldc.hide();

      //Rebind the text selection event
      ambra.displayAnnotationContext.init("researchArticle");
    }
  });
}

/**
 * createAnnotationOnMouseDown()
 *
 * Method triggered on onmousedown or onclick event of a tag.  When this method is
 * triggered, it initiates an annotation creation using the currently-selected text.
 */
function createAnnotationOnMouseDown() {
  // reset form
  //TODO: Move this to be more inline with how _annotationForm is defined
  //This is fine for now, but in the future being this is a dijit widget, we may
  //run into issues
  var submitMsg = dojo.byId('submitMsg');

  submitMsg.style.display = 'none';
  
  ambra.formUtil.textCues.reset(_annotationForm.cTitle, _titleCue);
  ambra.formUtil.textCues.reset(_annotationForm.cArea, _commentCue);
  ambra.formUtil.textCues.reset(_annotationForm.ciStatementArea, _statementCue);

  _annotationForm.noteType.value = "";
  _annotationForm.commentTitle.value = "";
  _annotationForm.comment.value = "";
  _annotationForm.ciStatement.value = "";
  _annotationForm.isCompetingInterest.value = "false";

  _annotationForm.competingInterest[0].checked = true;
  _annotationForm.competingInterest[1].checked = false;

  _annotationForm.ciStatementArea.disabled = true;

  // create it
  ambra.annotation.createNewAnnotation();
  return false;
}

  // --------------------------------
  // annotation (note) dialog related
  // --------------------------------
  _annotationForm = document.createAnnotation;

  dojo.connect(_annotationForm.cNoteType, "change", function () {
    dojo.byId('cdls').style.visibility = _annotationForm.cNoteType.value == 'correction' ? 'visible' : 'hidden';
  });

  dojo.connect(_annotationForm.cTitle, "focus", function () {
    ambra.formUtil.textCues.off(_annotationForm.cTitle, _titleCue);
  });

  dojo.connect(_annotationForm.cTitle, "change", function () {
    var fldTitle = _annotationForm.commentTitle;
    if(_annotationForm.cTitle.value != "" && _annotationForm.cTitle.value != _titleCue) {
      fldTitle.value = _annotationForm.cTitle.value;
    }
    else {
      fldTitle.value = "";
    }
  });

  dojo.connect(_annotationForm.cTitle, "blur", function () {
    var fldTitle = _annotationForm.commentTitle;
    if(_annotationForm.cTitle.value != "" && _annotationForm.cTitle.value != _titleCue) {
      fldTitle.value = _annotationForm.cTitle.value;
    }
    else {
      fldTitle.value = "";
    }
    ambra.formUtil.textCues.on(_annotationForm.cTitle, _titleCue);
  });

  dojo.connect(_annotationForm.cArea, "focus", function () {
    ambra.formUtil.textCues.off(_annotationForm.cArea, _commentCue);
  });

  dojo.connect(_annotationForm.cArea, "change", function () {
    var fldTitle = _annotationForm.comment;
    if(_annotationForm.cArea.value != "" && _annotationForm.cArea.value != _commentCue) {
      fldTitle.value = _annotationForm.cArea.value;
    }
    else {
      fldTitle.value = "";
    }
  });

  dojo.connect(_annotationForm.cArea, "blur", function () {
    var fldTitle = _annotationForm.comment;
    if(_annotationForm.cArea.value != "" && _annotationForm.cArea.value != _commentCue) {
      fldTitle.value = _annotationForm.cArea.value;
    }
    else {
      fldTitle.value = "";
    }
    ambra.formUtil.textCues.on(_annotationForm.cArea, _commentCue);
    //ambra.formUtil.checkFieldStrLength(_annotationForm.cArea, 500);
  });

  dojo.connect(_annotationForm.ciStatementArea, "focus", function () {
    ambra.formUtil.textCues.off(_annotationForm.ciStatementArea, _statementCue);
  });

  dojo.connect(_annotationForm.ciStatementArea, "change", function () {
    var fldTitle = _annotationForm.ciStatement;
    if(_annotationForm.ciStatementArea.value != "" && _annotationForm.ciStatementArea.value != _statementCue) {
      fldTitle.value = _annotationForm.ciStatementArea.value;
    }
    else {
      fldTitle.value = "";
    }
  });

  dojo.connect(_annotationForm.ciStatementArea, "blur", function () {
    var fldTitle = _annotationForm.ciStatement;
    if(_annotationForm.ciStatementArea.value != "") {
      fldTitle.value = _annotationForm.ciStatementArea.value;
    }
    else {
      fldTitle.value = "";
    }
    ambra.formUtil.textCues.on(_annotationForm.ciStatementArea, _statementCue);
  });

  dojo.connect(_annotationForm.competingInterest[0], "click", function () {
    var fldTitle = _annotationForm.isCompetingInterest;

    _annotationForm.ciStatementArea.disabled = true;

    fldTitle.value = "false";
  });

  dojo.connect(_annotationForm.competingInterest[1], "click", function () {
    var fldTitle = _annotationForm.isCompetingInterest;

    _annotationForm.ciStatementArea.disabled = false;

    fldTitle.value = "true";
  });

dojo.addOnLoad(function() {
  // int loading "throbber"
  _ldc = dijit.byId("LoadingCycle");

  dojo.connect(dojo.byId("btn_post"), "click", function(e) {
    validateNewComment();
    e.preventDefault();
    return false;
  });

  dojo.connect(dojo.byId("btn_cancel"), "click", function(e) {
    ambra.domUtil.removeChildren(dojo.byId('submitMsg'));
    _annotationDlg.hide();
    ambra.formUtil.enableFormFields(_annotationForm);
    if(!annotationConfig.rangeInfoObj.isSimpleText) {
      // we are in an INDETERMINISTIC state for annotation markup
      // Article re-fetch is necessary to maintain the integrity of the existing annotation markup
      getArticle();
    }
    else {
      // we can safely rollback the pending annotation markup from the dom
      ambra.annotation.undoPendingAnnotation();
    }
    e.preventDefault();

    //Reinit the contextMenu as the regional dialog disables it
    ambra.displayAnnotationContext.init("researchArticle");

    return false;
  });

  _annotationDlg = dijit.byId("AnnotationDialog");
  //var dlgCancel = dojo.byId('btn_cancel');
  //_annotationDlg.setCloseControl(dlgCancel);
  _annotationDlg.setTipDown(dojo.byId(annotationConfig.tipDownDiv));
  _annotationDlg.setTipUp(dojo.byId(annotationConfig.tipUpDiv));

  // -------------------------
  // comment dialog related
  // -------------------------
  _commentDlg = dijit.byId("CommentDialog");
  var commentDlgClose = dojo.byId('btn_close');
  //_commentDlg.setCloseControl(commentDlgClose);
  _commentDlg.setTipDown(dojo.byId(commentConfig.tipDownDiv));
  _commentDlg.setTipUp(dojo.byId(commentConfig.tipUpDiv));

  dojo.connect(commentDlgClose, 'click', function(e) {
    _commentDlg.hide();
    ambra.displayComment.mouseoutComment(ambra.displayComment.target);
    return false;
  });

  // -------------------------
  // multi-comment dialog related
  // -------------------------
  _commentMultiDlg = dijit.byId("CommentDialogMultiple");
  var popupCloseMulti = dojo.byId('btn_close_multi');
  //_commentMultiDlg.setCloseControl(popupCloseMulti);
  _commentMultiDlg.setTipDown(dojo.byId(multiCommentConfig.tipDownDiv));
  _commentMultiDlg.setTipUp(dojo.byId(multiCommentConfig.tipUpDiv));

  dojo.connect(popupCloseMulti, 'click', function(e) {
    _commentMultiDlg.hide();
    ambra.displayComment.mouseoutComment(ambra.displayComment.target);
    return false;
  });

  // init routines
  ambra.rating.init();
  ambra.displayComment.init();
  ambra.displayComment.processBugCount();
  ambra.corrections.init();
  ambra.displayAnnotationContext.init("researchArticle");
  ambra.navigation.buildTOC(dojo.byId('sectionNavTopBox'), dojo.byId('sectionNavTop'));

  // jump to annotation?
  jumpToAnnotation(document.articleInfo.annotationId.value);

  // re-fetch article if "dirty" for firefox only as their page cache is not updated via xhr based dom alterations.
  if(dojo.isFF && shouldRefresh()) getArticle();

  markDirty(false);	// unset dirty flag
});
