// rating related globals
var _ldc;

var ratingConfig =  {
  insight:  "rateInsight",
  reliability: "ratingReliability",
  style: "rateStyle"
};
var _ratingDlg;
var _ratingsForm;
var _ratingTitle;
var _ratingComments;
var _submitMsg;

var _ratingTitleCue    = 'Enter your comment title...';
var _ratingCommentCue   = 'Enter your comment...';
var _ratingStatementCue   = 'Enter your competing interests...';

dojo.addOnLoad(function() {
  // ---------------------
  // rating dialog related
  // ---------------------
  _ldc = dijit.byId("LoadingCycle");
  
  _ratingsForm = document.ratingForm;
  _ratingTitle = _ratingsForm.cTitle;
  _ratingComments = _ratingsForm.cArea;
  _ratingCIStatement = _ratingsForm.ciStatementArea;
  _submitMsg = dojo.byId('submitRatingMsg');
  _ratingDlg = dijit.byId("Rating");
  //_ratingDlg.setCloseControl(dojo.byId('btn_cancel_rating'));

  dojo.connect(_ratingTitle, "onfocus", function () {
    ambra.formUtil.textCues.off(_ratingTitle, _ratingTitleCue);
  });

  dojo.connect(_ratingTitle, "onchange", function () {
    var fldTitle = _ratingsForm.commentTitle;
    if(_ratingsForm.cTitle.value != "" && _ratingsForm.cTitle.value != _ratingTitleCue) {
      fldTitle.value = _ratingsForm.cTitle.value;
    }
    else {
      fldTitle.value = "";
    }
  });

  dojo.connect(_ratingTitle, "onblur", function () {
    var fldTitle = _ratingsForm.commentTitle;
    if(_ratingsForm.cTitle.value != "" && _ratingsForm.cTitle.value != _ratingTitleCue) {
      fldTitle.value = _ratingsForm.cTitle.value;
    }
    else {
      fldTitle.value = "";
    }
    ambra.formUtil.textCues.on(_ratingTitle, _ratingTitleCue);
  });

  dojo.connect(_ratingComments, "onfocus", function () {
    ambra.formUtil.textCues.off(_ratingComments, _ratingCommentCue);
  });

  dojo.connect(_ratingComments, "onchange", function () {
    var fldTitle = _ratingsForm.comment;
    if(_ratingsForm.cArea.value != "" && _ratingsForm.cArea.value != _ratingCommentCue) {
      fldTitle.value = _ratingsForm.cArea.value;
    }
    else {
      fldTitle.value = "";
    }
  });

  dojo.connect(_ratingComments, "onblur", function () {
    var fldTitle = _ratingsForm.comment;
    if(_ratingsForm.cArea.value != "" && _ratingsForm.cArea.value != _ratingCommentCue) {
      fldTitle.value = _ratingsForm.cArea.value;
    }
    else {
      fldTitle.value = "";
    }
    ambra.formUtil.textCues.on(_ratingComments, _ratingCommentCue);
    //ambra.formUtil.checkFieldStrLength(_ratingComments, 500);
  });

  dojo.connect(_ratingCIStatement, "onfocus", function () {
    ambra.formUtil.textCues.off(_ratingCIStatement, _ratingStatementCue);
  });

  dojo.connect(_ratingCIStatement, "onchange", function () {
    var fldTitle = _ratingsForm.ciStatement;
    if(_ratingsForm.ciStatementArea.value != "" &&
       _ratingsForm.ciStatementArea.value != _ratingStatementCue) {
      fldTitle.value = _ratingsForm.ciStatementArea.value;
    }
    else {
      fldTitle.value = "";
    }
  });

  dojo.connect(_ratingCIStatement, "onblur", function () {
    var fldTitle = _ratingsForm.ciStatement;
    if(_ratingsForm.ciStatementArea.value != "" &&
       _ratingsForm.ciStatementArea.value != _ratingStatementCue) {
      fldTitle.value = _ratingsForm.ciStatementArea.value;
    }
    else {
      fldTitle.value = "";
    }
    ambra.formUtil.textCues.on(_ratingCIStatement, _ratingStatementCue);
    //ambra.formUtil.checkFieldStrLength(_ratingComments, 500);
  });

  dojo.connect(_ratingsForm.competingInterest[0], "click", function () {
    var fldTitle = _ratingsForm.isCompetingInterest;

    _ratingsForm.ciStatementArea.disabled = true;

    fldTitle.value = "false";
  });

  dojo.connect(_ratingsForm.competingInterest[1], "click", function () {
    var fldTitle = _ratingsForm.isCompetingInterest;

    _ratingsForm.ciStatementArea.disabled = false;

    fldTitle.value = "true";
  });



  dojo.connect(dojo.byId("btn_post_rating"), "onclick", function(e) {
    updateRating();
    e.preventDefault();
    return false;
  });

  dojo.connect(dojo.byId("btn_cancel_rating"), "onclick", function(e) {
    ambra.rating.hide();
    e.preventDefault();
    return false;
  });
});