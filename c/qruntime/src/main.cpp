#include <QtGui>
#include <QWebview>
#include <QApplication>
#include "mainwindow.h"
#include "network.h"
#include <QProcess>

int main(int argc, char * argv[]){
  QApplication app(argc, argv);

  QCoreApplication::setOrganizationName("Paperpile");
  QCoreApplication::setApplicationName("Paperpile");
  
  MainWindow *browser = new MainWindow();
  browser->show();
  

  //String program = "/Users/wash/play/paperpile/catalyst/script/start_osx.sh";

     
  return app.exec();

}
