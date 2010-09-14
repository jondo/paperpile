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
  page->setNetworkAccessManager( proxy );

  QWebInspector *inspector = new QWebInspector;
  inspector->setPage(page);

  page->settings()->setAttribute(QWebSettings::LocalContentCanAccessRemoteUrls,true);
  page->settings()->setAttribute(QWebSettings::LocalContentCanAccessFileUrls,true);
  page->settings()->setAttribute(QWebSettings::DeveloperExtrasEnabled,true);

  view->setPage(page);

  exportRuntime();
  connect(page->mainFrame(), SIGNAL(javaScriptWindowObjectCleared()), this, SLOT(exportRuntime()));

  //view->load(QUrl::fromLocalFile(runtime->getCatalystDir()+"/root/index.html"));
  view->load(QUrl::fromLocalFile("/Users/wash/play/paperpile/catalyst/root/runtime.html"));
  

  
  // Set up main Window
  resize(1024,768);
  QRect frect = frameGeometry();
  frect.moveCenter(QDesktopWidget().availableGeometry().center());
  move(frect.topLeft());

  setCentralWidget(view);
  setUnifiedTitleAndToolBarOnMac(true);
  
}

void MainWindow::exportRuntime(){

  QWebFrame *frame = view->page()->mainFrame();
  frame->addToJavaScriptWindowObject("QRuntime", runtime);
   
}

void MainWindow::closeEvent(QCloseEvent *event) {

  runtime->catalystKill();

  qDebug() << "Now closing window, add shutdown code here";

}

