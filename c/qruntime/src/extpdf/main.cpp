#include <QtCore/QCoreApplication>
#include <QTimer>
#include "extpdf.h"
#include <stdio.h>

int main(int argc, char *argv[]){

  QCoreApplication a(argc, argv);

  // Do weird things to run this command line program in Qt event loop
  ExtPdf ext(&a);
  QObject::connect(&ext, SIGNAL( done() ), &a, SLOT( quit() ), Qt::QueuedConnection);
  QTimer::singleShot(0, &ext, SLOT( process() ));
    
  return a.exec();
}
