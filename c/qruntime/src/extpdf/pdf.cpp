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
};


void PDF::openDocument(){

  document = Poppler::Document::load(getFile());

}

void PDF::closeDocument(){
    
}

QVariantMap PDF::info(){

  QVariantMap map;

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

QString PDF::text(){

  QString text;

  for (int i = 0; i < document->numPages(); ++i){
    Poppler::Page* pdfPage = document->page(i);

    if (pdfPage == 0) {
      fprintf(stderr, "Error opening page %i.\n", i);
      exit(1);
    }
 
    text.append(pdfPage->text(QRect(0,0,0,0)));
   
    delete pdfPage;
  }
  return text;
}

QImage PDF::render(int page, float scale){


  Poppler::Page* pdfPage = document->page(page);

  QImage img = pdfPage->renderToImage();

  return img;

}


QVariantMap PDF::wordList(int pageNum){

  QVariantMap map;

  Poppler::Page* pdfPage = document->page(pageNum);

  TextOutputDev* output_dev = new TextOutputDev(0, gFalse, gFalse, gFalse);
  
  GooString* filename_g = new GooString (qPrintable(getFile()));
  PDFDoc *doc = new PDFDoc(filename_g, NULL, NULL);

  Page* page = doc->getCatalog()->getPage(pageNum+1);

  int rotation = 0;

  doc->displayPageSlice(output_dev,pageNum + 1, 72, 72,
                        rotation, false, false, false, -1, -1, -1, -1);

  TextWordList *word_list = output_dev->makeWordList();
  
  if (!word_list) {
    delete output_dev;
    return map;
  }
  
  for (int i = 0; i < word_list->getLength(); i++) {
    TextWord *word = word_list->get(i);
    GooString *gooWord = word->getText();
    QString string = QString::fromUtf8(gooWord->getCString());
    delete gooWord;
    double xMin, yMin, xMax, yMax;
    word->getBBox(&xMin, &yMin, &xMax, &yMax);
    
    qDebug() << word->getFontSize() << word->getFontInfo()->getFontName()->getCString() << word->getFontInfo()->isBold();
        
    qDebug() << string;

  }

  delete output_dev;

  //  TextBox* text_box = new TextBox(string, QRectF(xMin, yMin, xMax-xMin, yMax-yMin));
  //   text_box->m_data->hasSpaceAfter = word->hasSpaceAfter() == gTrue;
  //   text_box->m_data->charBBoxes.reserve(word->getLength());
  //   for (int j = 0; j < word->getLength(); ++j)
  //   {
  //       word->getCharBBox(j, &xMin, &yMin, &xMax, &yMax);
  //       text_box->m_data->charBBoxes.append(QRectF(xMin, yMin, xMax-xMin, yMax-yMin));
  //   }
    
  //   wordBoxMap.insert(word, text_box);
    
  //   output_list.append(text_box);
  // }
  
  // for (int i = 0; i < word_list->getLength(); i++) {
  //   TextWord *word = word_list->get(i);
  //   TextBox* text_box = wordBoxMap.value(word);
  //   text_box->m_data->nextWord = wordBoxMap.value(word->nextWord());
  // }
  
  // delete word_list;
  // delete output_dev;
  
  return map;
}




QString PDF::getFile(){

  return _file;

}

void PDF::setFile(const QString & file){

  _file = file;

}

