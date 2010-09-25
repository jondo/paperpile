#include <QtGui>
#include <QApplication>
#include "mainwindow.h"
#include "network.h"
#include <QProcess>
#include <qwebview.h>

int main(int argc, char * argv[]){
  QApplication app(argc, argv);

  QCoreApplication::setOrganizationName("Paperpile");
  QCoreApplication::setApplicationName("Paperpile");
  
  MainWindow *browser = new MainWindow();
  browser->show();
  
  return app.exec();

}
