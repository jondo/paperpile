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


void Runtime::readyReadCatalyst(){

  QString string(catalystProcess->readAll());

  if (string.contains("powered by Catalyst")){
    emit catalystReady();
    qDebug() << "Catalyst READY";
  }

  //qDebug() << "line" << string;

  emit catalystRead(string);

}

QString Runtime::getCatalystDir(){

  if (getPlatform() == "osx"){
    QDir path(QCoreApplication::applicationDirPath()+"/../Resources/catalyst/");
    return(path.canonicalPath());
  }

  return("");

}

QString Runtime::getPlatform(){

#ifdef Q_OS_MAC
  return QString("osx");
#endif
 

}

void Runtime::catalystStateChanged(QProcess::ProcessState newState){

  qDebug() << "New State" << newState ;

  if (newState == QProcess::NotRunning){
    emit catalystExit("");
  }
}

void Runtime::catalystError(QProcess::ProcessError error){

  qDebug() << "Catalyst EXIT";
  emit catalystExit("");
  
}

void Runtime::catalystStart(){

  QString program;
  QStringList arguments;

  program = getCatalystDir() + "/" + "/perl5/" + getPlatform() + "/bin/paperperl";

  if (getPlatform() == "osx"){
    arguments << getCatalystDir() + "/script/osx_server.pl" << "--port" << "3210" << "--fork";
  }

  catalystProcess = new QProcess;

  catalystProcess->setReadChannel(QProcess::StandardError);

  catalystProcess->start(program, arguments);

  connect(catalystProcess, SIGNAL(readyRead()), this, SLOT(readyReadCatalyst()));
  
  connect(catalystProcess, SIGNAL(error(QProcess::ProcessError)), this, SLOT(catalystError(QProcess::ProcessError)));
  connect(catalystProcess, SIGNAL(stateChanged(QProcess::ProcessState)), this, SLOT(catalystStateChanged(QProcess::ProcessState)));

}

void Runtime::catalystKill(){

  catalystProcess->close();

}

void Runtime::closeApp(){

  mainWindow->close();

}




