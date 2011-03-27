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
#include <QProcess>
#include "runtime.h"

Runtime::Runtime(QWidget *window){

  mainWindow = window;
  plackProcess = 0;
  updaterProcess = 0;
  saveToClose = 0;

  //watcher = new	QFileSystemWatcher();
  //watcher->addPath(QString("c:\\Users\\wash\\tmp"));
  //connect(watcher, SIGNAL(directoryChanged(QString)), this, SLOT(processPushUpdate(QString)));


};


void Runtime::openFile( const QString & file = QString()){

  QDesktopServices::openUrl(QUrl::fromLocalFile(file));

}

void Runtime::openUrl( const QString & url = QString()){

  QDesktopServices::openUrl(QUrl(url));

}

void Runtime::openFolder( const QString & folder = QString()){

#ifdef Q_WS_MAC
  QStringList args;
  args << "-e";
  args << "tell application \"Finder\"";
  args << "-e";
  args << "activate";
  args << "-e";
  args << "select POSIX file \""+folder+"\"";
  args << "-e";
  args << "end tell";
  QProcess::startDetached("osascript", args);
#endif
	 
#ifdef Q_WS_WIN
  //QStringList args;
  //args << "/select," << QDir::toNativeSeparators(filePath);
  //QProcess::startDetached("explorer", args);
#endif

}

QString Runtime::getClipboard(){

  QClipboard *clipboard = QApplication::clipboard();
  return(clipboard->text());

}

void Runtime::setClipboard(const QString & text = QString()){

  QClipboard *clipboard = QApplication::clipboard();
  clipboard->setText(text);
}


void Runtime::readyReadPlack(){

  QString string(plackProcess->readAll());

  if (string.contains("Starting Paperpile server")){
    emit plackReady();
  }

  emit plackRead(string);

}

void Runtime::readyReadUpdater(){

  while (updaterProcess->canReadLine()){
    QString string(updaterProcess->readLine());
    string = string.replace(QRegExp("\n$"), QString::null); 
    log("Updater output: "+string);
    emit updaterReadLine(string);
  }
}



QString Runtime::getPlackDir(){

  QString platform = getPlatform();

  QString appDir = QCoreApplication::applicationDirPath();

  // We are in the build directory .../c/build
  if (appDir.contains(QRegExp("c.build"))){
    QDir path(appDir+"/../../../plack/");
    return(path.canonicalPath());
  }

  if (platform == "osx"){
    QDir path(QCoreApplication::applicationDirPath()+"/../Resources/plack/");
    return(path.canonicalPath());
  }

  if (platform == "linux32" || platform == "linux64"){
    QDir path(QCoreApplication::applicationDirPath()+"/../plack/");
    return(path.canonicalPath());
  }

  
  if (platform == "win32"){

    // We are in an uninstalled checkout in .../qt/win32
    if (appDir.contains(QRegExp("qt.win32"))){
      QDir path(appDir+"/../../plack/");
      return(path.canonicalPath());
    }
    
    // We are in a normal installation
    QDir path(QCoreApplication::applicationDirPath()+"/plack/");
    return(path.canonicalPath());
  }

  return("");

}

QString Runtime::getInstallationDir(){

  QString platform = getPlatform();

  if (platform == "osx"){
    QDir path(QCoreApplication::applicationDirPath()+"/../..");
    return(path.canonicalPath());
  }

  if (platform == "linux32" || platform == "linux64"){
    QDir path(QCoreApplication::applicationDirPath()+"/..");
    return(path.canonicalPath());
  }

  return("");

}


QString Runtime::getPlatform(){

#ifdef Q_OS_MAC
  return QString("osx");
#endif

#ifdef Q_WS_WIN
  return QString("win32");
#endif

#if defined Q_OS_LINUX && defined __x86_64
  return QString("linux64");
#endif

#if defined Q_OS_LINUX && defined __i386__
  return QString("linux32");
#endif


}

void Runtime::resizeWindow(int w, int h){

  mainWindow->resize(w,h);

}

void Runtime::plackStateChanged(QProcess::ProcessState newState){

  QString msg;

  if (newState == QProcess::NotRunning){
    emit plackExit(QString("State changed to 'Not Running'"));
    msg="'Not Running'";
  }

  if (newState == QProcess::Starting) msg ="'Starting'";
  if (newState == QProcess::Running) msg ="'Running'";

  msg.prepend("Plack process status changed to ");

  log(msg);

}

void Runtime::plackError(QProcess::ProcessError error){
  
  QString msg;

  if (error == QProcess::FailedToStart)	msg="Failed to start";
  if (error == QProcess::Crashed)	msg="Killed";
  if (error == QProcess::Timedout)	msg="Timed out";
  if (error == QProcess::WriteError)	msg="Write error";
  if (error == QProcess::ReadError)	msg="Read Error";
  if (error == QProcess::UnknownError)	msg="Unknown Error";

  msg.prepend("Plack process: ");

  log(msg);

  emit plackExit(msg);
  
}


void Runtime::processPushUpdate(const QString & path){

  qDebug() << "Direcotory changed" << path;
  
}

void Runtime::updaterStart(const QString & mode){

  QString program;
  QStringList arguments;

  QString platform = getPlatform();

  program = getPlackDir() + "/" + "/perl5/" + platform + "/bin/paperperl";

  arguments << getPlackDir() + "/script/updater.pl" << "--" + mode;

  updaterProcess = new QProcess;

  QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
  env.remove("PERL5LIB");
  updaterProcess->setProcessEnvironment(env);

  connect(updaterProcess, SIGNAL(readyRead()), this, SLOT(readyReadUpdater()));
  connect(updaterProcess, SIGNAL(stateChanged(QProcess::ProcessState)), this, SLOT(updaterStateChanged(QProcess::ProcessState)));

  updaterProcess->start(program, arguments);

}


void Runtime::updaterStateChanged(QProcess::ProcessState newState){
  
  QString msg;

  if (newState == QProcess::NotRunning){
    emit updaterExit(QString("State changed to 'Not Running'"));
    msg="'Not Running'";
  }

  if (newState == QProcess::Starting) msg ="'Starting'";
  if (newState == QProcess::Running) msg ="'Running'";

  msg.prepend("Updater process status changed to ");
  log(msg);
}

void Runtime::plackStart(){

  QString program;
  QStringList arguments;

  QString platform = getPlatform();
  
  QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
  env.remove("PERL5LIB");

  program = getPlackDir() + "/" + "/perl5/" + platform + "/bin/paperperl";
  
  if (platform == "osx"){
    arguments << getPlackDir() + "/script/osx_server.pl" << "--port" << "3210" << "--fork";
  }

  if (platform == "linux32" || platform == "linux64"){
    arguments << getPlackDir() + "/script/paperpile_server.pl" << "-fork";
  }

  if (platform == "win32"){
    arguments << getPlackDir() + "/script/server.pl" << "--port" << "3210" << "--host" <<"127.0.0.1";
    QString oldPath = env.value("PATH");
    env.insert("PATH", oldPath + ";" +getPlackDir()+"\\perl5\\win32\\dll");
  }


  plackProcess = new QProcess;

  plackProcess->setProcessEnvironment(env);

  plackProcess->setReadChannel(QProcess::StandardError);

  connect(plackProcess, SIGNAL(readyRead()), this, SLOT(readyReadPlack()));
  connect(plackProcess, SIGNAL(error(QProcess::ProcessError)), this, SLOT(plackError(QProcess::ProcessError)));
  connect(plackProcess, SIGNAL(stateChanged(QProcess::ProcessState)), this, SLOT(plackStateChanged(QProcess::ProcessState)));

  plackProcess->start(program, arguments);

}


void Runtime::plackKill(){

  if (plackProcess !=0){
    if (plackProcess->state() == QProcess::Running){
      plackProcess->close();
    }
  }
}

void Runtime::plackRestart(){

  plackKill();
  plackStart();

}

// If saveToClose is false the close event is dispatched to the
// frontend. The frontend either ignores the close event or explicitly
// sets saveToClose to true and then calls closeApp again.
void Runtime::setSaveToClose(const bool & state){

  saveToClose = state;

}


void Runtime::closeApp(){

  mainWindow->close();

}

QVariantMap Runtime::fileDialog(const QVariantMap & config){


  QString caption;

  if (config.contains("Caption")){
    caption = config["Caption"].toString();
  }
 
  QFileDialog dialog(mainWindow, caption);

  if (config.contains("AcceptMode")){
    if (config["AcceptMode"] == "AcceptOpen") dialog.setAcceptMode(QFileDialog::AcceptOpen);
    if (config["AcceptMode"] == "AcceptSave") dialog.setAcceptMode(QFileDialog::AcceptSave);
  }

  if (config.contains("LookInLabel")) dialog.setLabelText(QFileDialog::LookIn,config["LookInLabel"].toString());
  if (config.contains("FileNameLabel")) dialog.setLabelText(QFileDialog::FileName,config["FileNameLabel"].toString());
  if (config.contains("FileTypeLabel")) dialog.setLabelText(QFileDialog::FileType,config["FileTypeLabel"].toString());
  if (config.contains("AcceptLabel")) dialog.setLabelText(QFileDialog::Accept,config["AcceptLabel"].toString());
  if (config.contains("RejectLabel")) dialog.setLabelText(QFileDialog::Reject,config["RejectLabel"].toString());

  if (config.contains("FileMode")){
  if (config["FileMode"] == "AnyFile") dialog.setFileMode(QFileDialog::AnyFile);
    if (config["FileMode"] == "ExistingFile") dialog.setFileMode(QFileDialog::ExistingFile);
    if (config["FileMode"] == "Directory") dialog.setFileMode(QFileDialog::Directory);
    if (config["FileMode"] == "ExistingFiles") dialog.setFileMode(QFileDialog::ExistingFiles);
  }


  if (config.contains("ShowDirsOnly")) dialog.setOption(QFileDialog::ShowDirsOnly,config["ShowDirsOnly"].toBool());
  if (config.contains("DontResolveSymlinks")) dialog.setOption(QFileDialog::DontResolveSymlinks,config["DontResolveSymlinks"].toBool());
  if (config.contains("DontConfirmOverwrite")) dialog.setOption(QFileDialog::DontConfirmOverwrite,config["DontConfirmOverwrite"].toBool());


  if (config.contains("NameFilters")){
    dialog.setNameFilters(config["NameFilters"].toStringList());
  }

  if (config.contains("DefaultSuffix")){
    dialog.setDefaultSuffix(config["DefaultSuffix"].toString());
  }

  if (config.contains("DefaultSuffix")){
    dialog.setDefaultSuffix(config["DefaultSuffix"].toString());
  }

  if (config.contains("Directory")){
    dialog.setDirectory(config["Directory"].toString());
  }

  QVariantMap output;
  
  if (dialog.exec()){
    output["files"]=dialog.selectedFiles();
    output["answer"]=QString("OK");
  } else {
    output["answer"]=QString("CANCEL");
  }
  
  output["filter"]=dialog.selectedNameFilter();
 
  return(output);
  
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
  map["suffix"] = info.suffix(); 
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


void Runtime::log(const QString & msg){

  fprintf( stderr, "[%s] %s\n", qPrintable(QDateTime::currentDateTime().toString()), qPrintable(msg) );
}

QVariantMap Runtime::msgBox(const QVariantMap & config){

  QVariantMap output;
  output["dummy"]=QString();
  
  return(output);
  
}

bool Runtime::isDebugMode(){

  return(QCoreApplication::arguments().contains("--debug"));

}


void Runtime::closeEvent(QCloseEvent* event){

  if (saveToClose){
    plackKill();
  } else {
    event->ignore();
    emit appExit();
  }
}
