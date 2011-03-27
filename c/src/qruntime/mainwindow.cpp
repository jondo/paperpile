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

#include <QtGui>
#include <QtWebKit>
#include <QWebInspector>
#include <QWebSettings>
#include "mainwindow.h"
#include "runtime.h"
#include "runtimeview.h"
#include "runtimepage.h"
#include "network.h"

MainWindow::MainWindow(){

  // Set up WebView

  view = new RuntimeView(this);
  runtime = new Runtime(this);

  RuntimePage* page = new RuntimePage();

  RuntimeNetworkAccessManager* proxy = new RuntimeNetworkAccessManager();
  proxy->plackDir = runtime->getPlackDir();
  page->setNetworkAccessManager( proxy );
  
  if (isDebugMode()){
    page->settings()->setAttribute(QWebSettings::DeveloperExtrasEnabled,true);
    QWebInspector *inspector = new QWebInspector;
    inspector->setPage(page);
  }

  page->settings()->setAttribute(QWebSettings::LocalContentCanAccessRemoteUrls,true);
  page->settings()->setAttribute(QWebSettings::LocalContentCanAccessFileUrls,true);

  view->setPage(page);

  exportRuntime();
  connect(page->mainFrame(), SIGNAL(javaScriptWindowObjectCleared()), this, SLOT(exportRuntime()));

  if (runtime->getPlatform() != "osx"){
    QApplication::setWindowIcon(QIcon(runtime->getPlackDir()+"/root/images/app_icon.svg"));
    setWindowTitle("Paperpile");
  }

  if (QCoreApplication::arguments().contains("--test")){
    qDebug() << runtime->getPlackDir()+"/root/runtime.html";
    view->load(QUrl::fromLocalFile(runtime->getPlackDir()+"/root/runtime.html"));
  } else {
    view->load(QUrl::fromLocalFile(runtime->getPlackDir()+"/root/index.html"));
  }

  QCoreApplication::setOrganizationName("Paperpile");
  QCoreApplication::setOrganizationDomain("paperpile.com");
  QCoreApplication::setApplicationName("Paperpile");

  // Set window geometry either from stored settings or if started the
  // first time to a default state
  
  QSettings settings;
  QByteArray geometry = settings.value("geometry").toByteArray();
  QByteArray windowState = settings.value("windowState").toByteArray();

  if (geometry.isEmpty() || windowState.isEmpty()){
    resize(1024,768);
    QRect frect = frameGeometry();
    frect.moveCenter(QDesktopWidget().availableGeometry().center());
    move(frect.topLeft());
  } else {
    restoreGeometry(geometry);
    restoreState(windowState);
  }


  setCentralWidget(view);
  setUnifiedTitleAndToolBarOnMac(true);
  
}

void MainWindow::exportRuntime(){

  QWebFrame *frame = view->page()->mainFrame();
  frame->addToJavaScriptWindowObject("QRuntime", runtime);
   
}

void MainWindow::closeEvent(QCloseEvent *event) {

  runtime->closeEvent(event);

  QSettings settings;
  settings.setValue("geometry", saveGeometry());
  settings.setValue("windowState", saveState());

}



bool MainWindow::isDebugMode(){

  return(QCoreApplication::arguments().contains("--debug"));

}

