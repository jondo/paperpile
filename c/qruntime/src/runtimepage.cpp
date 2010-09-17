#include <QtGlobal>
#include <QtGui>
#include <QWebPage>
#include "runtimepage.h"

RuntimePage::RuntimePage(QObject * parent) : QWebPage(parent) {

  QWebPage::QWebPage();

};

void RuntimePage::javaScriptConsoleMessage ( const QString & message, int lineNumber, const QString & sourceID ) {

  qDebug() << message << " (Line:" << lineNumber << "," << sourceID << ")";

}

