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
  proxy->catalystDir = runtime->getCatalystDir();
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
    QApplication::setWindowIcon(QIcon(runtime->getCatalystDir()+"/root/images/app_icon.svg"));
    setWindowTitle("Paperpile");
  }

  if (QCoreApplication::arguments().contains("--test")){
    qDebug() << runtime->getCatalystDir()+"/root/runtime.html";
    view->load(QUrl::fromLocalFile(runtime->getCatalystDir()+"/root/runtime.html"));
  } else {
    view->load(QUrl::fromLocalFile(runtime->getCatalystDir()+"/root/index.html"));
  }

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

  runtime->closeEvent(event);

}

bool MainWindow::isDebugMode(){

  return(QCoreApplication::arguments().contains("--debug"));

}
