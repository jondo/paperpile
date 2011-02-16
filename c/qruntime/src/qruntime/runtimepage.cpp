/* Copyright 2009-2011 Paperpile

   This file is part of Paperpile

   Paperpile is free software: you can redistribute it and/or modify it
   under the terms of the GNU Affero General Public License as
   published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   Paperpile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Affero General Public License for more details.  You should have
   received a copy of the GNU Affero General Public License along with
   Paperpile.  If not, see http://www.gnu.org/licenses. */

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

bool RuntimePage::shouldInterruptJavaScript() {
  
  fprintf( stderr, "[%s] %s\n", qPrintable(QDateTime::currentDateTime().toString()), "Caught Javascript timeout warning.");

  // In debug mode we want to see the warning in the frontend, we never show it to the user though. 
  if (QCoreApplication::arguments().contains("--debug")){
    return QWebPage::shouldInterruptJavaScript();
  } else {
    return false;
  }
}
