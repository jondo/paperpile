//========================================================================
//
// Parameters.cc
//
// Specifics parameters to pdftoxml
//
// author: Sophie Andrieu
// Xerox Research Centre Europe
//
//========================================================================

#include "Parameters.h"
#include <stdio.h>

#if MULTITHREADED
#  define lockGlobalParams            gLockMutex(&mutex)
#  define unlockGlobalParams          gUnlockMutex(&mutex)
#else
#  define lockGlobalParams
#  define unlockGlobalParams
#endif

Parameters *parameters = NULL;

Parameters::Parameters() {}

Parameters::~Parameters() {}

void Parameters::setDisplayImage(GBool image) {
  lockGlobalParams;
  displayImage = image;
  unlockGlobalParams;
}

void Parameters::setDisplayText(GBool text) {
  lockGlobalParams;
  displayText = text;
  unlockGlobalParams;
}

void Parameters::setDisplayBlocks(GBool block) {
  lockGlobalParams;
  displayBlocks = block;
  unlockGlobalParams;
}

void Parameters::setDisplayOutline(GBool outl) {
  lockGlobalParams;
  displayOutline = outl;
  unlockGlobalParams;
}

void Parameters::setCutAllPages(GBool cutPages) {
  lockGlobalParams;
  cutAllPages = cutPages;
  unlockGlobalParams;
}

void Parameters::setFullFontName(GBool fullFontsNames) {
  lockGlobalParams;
  fullFontName = fullFontsNames;
  unlockGlobalParams;
}

void Parameters::setImageInline(GBool imagesInline) {
  lockGlobalParams;
  imageInline = imagesInline;
  unlockGlobalParams;
}
