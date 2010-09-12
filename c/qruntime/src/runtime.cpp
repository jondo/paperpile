#include <QtGui>
#include <QtWebKit>
#include <QProcess>
#include "runtime.h"

Runtime::Runtime(QWidget *window){

  mainWindow = window;

};


QString Runtime::getOpenFileName (const QString & caption = QString(), 
                                  const QString & dir = QString(), 
                                  const QString & filter = QString()){
 

  QString fileName = QFileDialog::getOpenFileName(mainWindow, caption, dir, filter);

  return(fileName);
}

void Runtime::openFile( const QString & file = QString()){

  QDesktopServices::openUrl(QUrl::fromLocalFile(file));

}

void Runtime::openUrl( const QString & url = QString()){

  QDesktopServices::openUrl(QUrl(url));

}

QString Runtime::getClipboard(){

  QClipboard *clipboard = QApplication::clipboard();
  return(clipboard->text());

}

void Runtime::setClipboard(const QString & text = QString()){

  QClipboard *clipboard = QApplication::clipboard();
  clipboard->setText(text);
}


void Runtime::catalystStateChanged(QProcess::ProcessState newState){

  qDebug() << "State changed: " << newState;
  
}

void Runtime::readyReadCatalyst(){

  QString string(catalystProcess->readAll());

  qDebug() << "line" << string;

  emit catalystRead(string);

}

QString Runtime::getCatalystDir(){

  return(QString("/Users/wash/play/paperpile/catalyst"));

}

QString Runtime::getPlatform(){
  
  return QString("osx");

}

void Runtime::startCatalyst(){

  QString program = "/Users/wash/play/paperpile/catalyst/perl5/osx/bin/paperperl";
  QStringList arguments;
  arguments << "/Users/wash/play/paperpile/catalyst/script/osx_server.pl" << "--port" << "3210" << "--fork";

  catalystProcess = new QProcess;
  catalystProcess->setReadChannel(QProcess::StandardError);

  catalystProcess->start(program, arguments);

  connect(catalystProcess, SIGNAL(stateChanged(QProcess::ProcessState)), this, SLOT(catalystStateChanged(QProcess::ProcessState)));
  connect(catalystProcess, SIGNAL(readyRead()), this, SLOT(readyReadCatalyst()));
  
  connect(catalystProcess, SIGNAL(error(QProcess::ProcessError)), this, SLOT(emitCatalystError(QProcess::ProcessError)));

}



void Runtime::emitCatalystError(QProcess::ProcessError error){

  qDebug() << "Catalyst process error:" << error;

}




