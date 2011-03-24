#ifndef EXTPDF_H
#define EXTPDF_H
 
#include <QObject>
#include <QVariantMap>
#include <QDomDocument>
 
class ExtPdf : public QObject{
Q_OBJECT

  void addNode(QDomDocument *doc, QDomElement* el, const QVariant & data, const QString & tagName);

public:
  explicit ExtPdf(QObject *parent = 0);
  void printXML(const QVariantMap &results); 
signals:
  void done();
 
public slots:
  void process();

 
};
 
#endif
