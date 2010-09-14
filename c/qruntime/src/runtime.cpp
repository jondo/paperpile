#include <QtGui>
#include <QtWebKit>
#include <QProcess>
#include "runtime.h"

Runtime::Runtime(QWidget *window){

  mainWindow = window;
  catalystProcess = 0;

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

void Runtime::resizeWindow(int w, int h){

  mainWindow->resize(w,h);

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

  if (catalystProcess !=0){
    if (catalystProcess->state() == QProcess::Running){
      catalystProcess->close();
    }
  }
}

void Runtime::closeApp(){

  mainWindow->close();

}


QVariantMap Runtime::fileDialog(const QVariantMap & config){

  qDebug() << config;

  QVariantMap map;

  QFileDialog dialog(mainWindow);

  if (config.contains("AcceptMode")){
    //dialog.setAcceptMode(config["AcceptMode"].toInt());
  }

  //dialog.setFileMode(QFileDialog::AnyFile);

  QStringList fileNames;
  if (dialog.exec()){
    fileNames = dialog.selectedFiles();
  }
  
  map["files"]=fileNames;
 
  
  return(map);
  
}

QVariantMap Runtime::fileInfo(const QString & file){

  QVariantMap map;

  QFileInfo info(file);

  map["exists"] = info.exists();
  map["absoluteDir"] = info.absoluteDir().path(); 
  map["absoluteFilePath"] = info.absoluteFilePath();
  map["absolutePath"] = info.absolutePath(); 
  map["baseName"] = info.baseName(); 
  map["bundleName"] = info.bundleName(); 
  map["canonicalFilePath"] = info.canonicalFilePath(); 
  map["canonicalPath"] = info.canonicalPath(); 
  map["completeBaseName"] = info.completeBaseName(); 
  map["completeSuffix"] = info.completeSuffix(); 
  map["dir"] = info.dir().path(); 
  map["fileName"] = info.fileName(); 
  map["filePath"] = info.filePath(); 
  map["isAbsolute"] = info.isAbsolute(); 
  map["isDir"] = info.isDir(); 
  map["isExecutable"] = info.isExecutable(); 
  map["isFile"] = info.isFile(); 
  map["isHidden"] = info.isHidden(); 
  map["isReadable"] = info.isReadable(); 
  map["isRelative"] = info.isRelative(); 
  map["isRoot"] = info.isRoot(); 
  map["isSymLink"] = info.isSymLink(); 
  map["isWritable"] = info.isWritable(); 

  return map;

}



