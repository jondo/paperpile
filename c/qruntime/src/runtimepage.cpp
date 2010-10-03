#include <QtGlobal>
#include <QtGui>
#include <QWebPage>
#include "runtimepage.h"

RuntimePage::RuntimePage(QObject * parent) : QWebPage(parent) {

  QWebPage::QWebPage();

};

void RuntimePage::javaScriptConsoleMessage ( const QString & message, int lineNumber, const QString & sourceID ) {

  if (!sourceID.isEmpty()){
    QFileInfo fileInfo(QUrl(sourceID).toLocalFile());
    fprintf( stderr, "[%s] %s (Line: %i, %s)\n", 
             qPrintable(QDateTime::currentDateTime().toString()), 
             qPrintable(message), 
             lineNumber, 
             qPrintable(fileInfo.fileName()));
  } else {
    fprintf( stderr, "[%s] %s\n", qPrintable(QDateTime::currentDateTime().toString()), qPrintable(message));
  }
}

