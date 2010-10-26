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

bool RuntimePage::acceptNavigationRequest ( QWebFrame * frame, const QNetworkRequest & request, NavigationType type ){

  // Webpage wants to open a new window, we delegate to the system browser
  if (frame == 0){
    QDesktopServices::openUrl(QUrl(request.url()));
    return 0;
  // Call parent function for all other requests
  } else {
    return(QWebPage::acceptNavigationRequest (frame, request, type ));
  }

}
