#include "extpdf.h"
#include "pdf.h"
#include <stdio.h>
#include <QDebug>
#include <QtCore/QCoreApplication>
#include <QStringList>
#include <QFile>
#include <QtXml>
#include <QDomDocument>
#include <QTextStream>
#include <QImage>

ExtPdf::ExtPdf(QObject *parent) :
    QObject(parent){
}
 
void ExtPdf::process() {
  
  QStringList arguments = QCoreApplication::arguments(); 

  if (arguments.length() != 2){
    fprintf(stderr, "extpdf takes exactly one argument.\n");
    exit(1);
  }

  QDomDocument doc("parameters");
  QFile file(arguments.last());

  if (!file.open(QIODevice::ReadOnly)){
    fprintf(stderr, "Could not open parameter file '%s'\n", qPrintable(arguments.last()));
    exit(1);
  }

  if (!doc.setContent(&file)) {
    file.close();
    fprintf(stderr, "Could not parse XML in '%s'\n", qPrintable(arguments.last()));
    exit(1);
  }

  // <inFile> and <command> is common to all parameter files
  QString pdfFile = doc.elementsByTagName("inFile").at(0).toElement().text();
  QString command = doc.elementsByTagName("command").at(0).toElement().text();

  if (pdfFile.isEmpty()){
    fprintf(stderr, "No input file given in parameter file '%s'\n", qPrintable(arguments.last()));
    exit(1);
  }

  PDF pdf;

  pdf.setFile(pdfFile);
  pdf.openDocument();

  if (command == "INFO"){
    QVariantMap results = pdf.info();
    results["status"]="OK";
    printXML(results);
  }

  if (command == "WORDLIST"){
    int page = doc.elementsByTagName("page").at(0).toElement().text().toInt();
    QVariantMap results = pdf.wordList(page);
    results["status"]="OK";
    printXML(results);
  }
  
  if (command == "TEXT"){
    QTextStream out(stdout);
    pdf.dumpText();
  }

  if (command == "RENDER"){
    QString outFile = doc.elementsByTagName("outFile").at(0).toElement().text();
    int page = doc.elementsByTagName("page").at(0).toElement().text().toInt();
    float scale = doc.elementsByTagName("scale").at(0).toElement().text().toFloat();

    QImage img = pdf.render(page, scale);

    img.save(outFile);
  }

  pdf.closeDocument();

  done();
}

void ExtPdf::printXML(const QVariantMap & results){

  // Create document and root note
  QDomDocument doc("output");
  QDomElement root = doc.createElement("output");
  doc.appendChild(root);

  // Start recursive addition of all other nodes
  addNode(&doc, &root, QVariant(results), "");

  // Print XML
  QTextStream out(stdout);
  out << doc.toString();

} 

// Recursively add QVariant data to QDomDocument. 
// doc      ... the dom document object
// el       ... the current parent element
// data     ... the actual data
// tagName  ... Used to pass tag name when generating a list 

void ExtPdf::addNode(QDomDocument *doc, QDomElement* el, const QVariant & data, const QString & tagName ){

  // Data is a map, we loop through all keys
  if (data.type() == QVariant::Map){

    QMapIterator<QString, QVariant> item(data.toMap());
    while (item.hasNext()) {
      item.next();

      // If value is a list don't create an enclosing element but call
      // addNode with tagName set to key.
      if (item.value().type() == QVariant::List){
        addNode(doc, el, item.value(),item.key());
      } else {

        // Special treatment of data from function wordList. Creates
        // concise output with attributes
        if (el->tagName() == "word"){
          if (item.key() == "size" || item.key() == "bold" || 
              item.key() == "italic" || item.key() == "rotation"){
            el->setAttribute(item.key(), item.value().toInt());
          }

          if (item.key() == "font"){
            el->setAttribute(item.key(), item.value().toString());
          }
          

          if (item.key() == "bbox"){
            el->setAttribute(item.key(), item.value().toString());
          }

          if (item.key() == "word"){
            QDomText t = doc->createTextNode(item.value().toString());
            el->appendChild(t);
          }
          
        } else {
          QDomElement tag = doc->createElement(item.key());
          el->appendChild(tag);
          addNode(doc, &tag, item.value(),item.key());
        }
      }
    }
  }

  // Data is a list, we loop through all elements
  if (data.type() == QVariant::List){

    for (int i = 0; i < data.toList().size(); ++i) {
      QDomElement tag = doc->createElement(tagName);
      el->appendChild(tag);
      addNode(doc, &tag, data.toList().at(i), tagName);
    }
  }
  
  // If data is string or number we can output the data as text nodes
  if (data.type() == QVariant::String || data.type() == QVariant::Int ){
    QDomText t = doc->createTextNode(data.toString());
    el->appendChild(t);
  }

  // QSize is printed as <size>width height</size>
  if (data.type() == QVariant::Size){
    int width = data.toSize().width();
    int height = data.toSize().height();

    QDomElement tag = doc->createElement("size");
    QDomText t = doc->createTextNode(QString::number(width)+" "+QString::number(height));
    tag.appendChild(t);
    el->appendChild(tag);
  }
}
