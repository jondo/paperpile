#include "pdf.h"
#include <QFile>
#include <QDebug>
#include <QImage>

#include <poppler/qt4/poppler-qt4.h>

#include <poppler/TextOutputDev.h>
#include <poppler/goo/GooString.h>
#include <poppler/Catalog.h>
#include <poppler/Page.h>
#include <poppler/PDFDoc.h>

PDF::PDF(QObject *parent){
  document = 0;
  poppler_doc = 0;
};


void PDF::openDocument(){

  document = Poppler::Document::load(getFile());
  
  GooString* filename_g = new GooString (qPrintable(getFile()));

  poppler_doc = new PDFDoc(filename_g, NULL, NULL);

  document->setRenderBackend(Poppler::Document::SplashBackend);
  document->setRenderHint(Poppler::Document::TextAntialiasing);

}

void PDF::closeDocument(){

  delete(document);
  delete(poppler_doc);

}

QVariantMap PDF::info(){

  QVariantMap map;

  // First get all key-value information stored in the PDF

  QStringList keys = document->infoKeys();
  Q_FOREACH(const QString &key, keys) {
    map[key]=document->info(key);
  }

  // Then get numeber of pages and size for each page

  map["numPages"] = document->numPages();
  
  QList<QVariant> pageList;

  for (int i = 0; i < document->numPages(); ++i){
    Poppler::Page* pdfPage = document->page(i);

    if (pdfPage == 0) {
      fprintf(stderr, "Error opening page %i.\n", i);
      exit(1);
    }
    
    pageList.append(QVariant(pdfPage->pageSize()));

    delete pdfPage;
  }

  map["page"] = pageList;

  return map;
}

// Not in use. Qt4 function "text" does not render text in a useful
// way neither with PhysicalLayout nor RawOrderLayout 

/*
QString PDF::text(){

  QString text;

  for (int i = 0; i < document->numPages(); ++i){
    Poppler::Page* pdfPage = document->page(i);

    if (pdfPage == 0) {
      fprintf(stderr, "Error opening page %i.\n", i);
      exit(1);
    }
 
    //text.append(pdfPage->text(QRect(0,0,0,0), Poppler::Page::PhysicalLayout));
   
    delete pdfPage;
  }
  return text;
}
*/

// Dumps the whole text of the document to stdout
void PDF::dumpText(){

  char out[] = "-";

  TextOutputDev* textOut = new TextOutputDev(out, gFalse, gFalse, gFalse);
  
  if (textOut->isOk()) {
    poppler_doc->displayPages(textOut, 1, poppler_doc->getNumPages(), 72, 72, 0, gTrue, gFalse, gFalse);
  } else {
    fprintf(stderr, "Error dumping text via TextOutputDev.");
    exit(1);
  }
}


QImage PDF::render(int page, float scale){


  Poppler::Page* pdfPage = document->page(page);

  QImage img = pdfPage->renderToImage();

  return img;

}


QVariantMap PDF::wordList(int pageNum){
  
  QVariantMap map;

  //First add general info about document
  map["info"] = info();
  
  // Get list of words directly from Poppler
  Poppler::Page* pdfPage = document->page(pageNum);
  TextOutputDev* output_dev = new TextOutputDev(0, gFalse, gFalse, gFalse);
  Page* page = poppler_doc->getCatalog()->getPage(pageNum+1);

  int rotation = 0;
  poppler_doc->displayPageSlice(output_dev,pageNum + 1, 72, 72,
                                rotation, false, false, false, -1, -1, -1, -1);

  TextWordList *word_list = output_dev->makeWordList();
  
  if (!word_list) {
    delete output_dev;
    return map;
  }
  
  QList<QVariant> wordList;

  for (int i = 0; i < word_list->getLength(); i++) {
    TextWord *word = word_list->get(i);
    GooString *gooWord = word->getText();
  
    QVariantMap mmap;

    // The actual word
    mmap["word"] = QString::fromUtf8(gooWord->getCString());;
    delete gooWord;

    // Bounding box
    double xMin, yMin, xMax, yMax;
    word->getBBox(&xMin, &yMin, &xMax, &yMax);
    mmap["bbox"] = QString::number(xMin,'f',2)+" "+QString::number(yMin,'f',2)+ " "+QString::number(xMax,'f',2)+" "+QString::number(yMax,'f',2);

    // Font features
    mmap["size"] = word->getFontSize();

    if (word->getFontName()){
      mmap["font"] = QString::fromUtf8(word->getFontName()->getCString());
    }
    
    if (word->getFontInfo()->isBold()) mmap["bold"]=1;
    if (word->getFontInfo()->isItalic()) mmap["italic"]=1;
    if (word->getRotation()) mmap["rotation"] = word->getRotation() * 90;
    
    wordList.append(mmap);

  }

  map["word"] = wordList;

  delete output_dev;

  return map;
}


QString PDF::getFile(){

  return _file;

}

void PDF::setFile(const QString & file){

  _file = file;

}

