#include <QtGui>
#include <QFileSystemWatcher>

class QProcess;

class Runtime : public QObject{
  Q_OBJECT

 public:
  Runtime(QWidget *window);

 public:
  Q_INVOKABLE void openFile( const QString & file);
  Q_INVOKABLE void openUrl( const QString & url);
  Q_INVOKABLE void openFolder( const QString & folder);
  Q_INVOKABLE QString getClipboard();
  Q_INVOKABLE QString getPlatform();
  Q_INVOKABLE QString getCatalystDir();
  Q_INVOKABLE QString getInstallationDir();
  Q_INVOKABLE void setClipboard( const QString & text);
  Q_INVOKABLE void catalystStart();
  Q_INVOKABLE void catalystRestart();
  Q_INVOKABLE void catalystKill();
  Q_INVOKABLE void updaterStart(const QString & mode);
  Q_INVOKABLE void closeApp();
  Q_INVOKABLE void setSaveToClose(const bool & state);
  Q_INVOKABLE void resizeWindow(int w, int h);
  Q_INVOKABLE QVariantMap fileDialog(const QVariantMap & config);
  Q_INVOKABLE QVariantMap msgBox(const QVariantMap & config);
  Q_INVOKABLE QVariantMap fileInfo(const QString & file);
  Q_INVOKABLE void log(const QString & msg);
  Q_INVOKABLE bool isDebugMode();

  bool saveToClose;
  void closeEvent(QCloseEvent* event);

  
 signals:
  void catalystReady();
  void catalystRead(QString data);
  void catalystExit(QString error);
  void updaterReadLine(QString data);
  void updaterExit(QString error);
  void pushUpdate(QString data);
  void appExit();

  
 private slots:
  void readyReadCatalyst();
  void readyReadUpdater();
  void catalystStateChanged(QProcess::ProcessState newState);
  void updaterStateChanged(QProcess::ProcessState newState);
  void catalystError(QProcess::ProcessError error);
  void processPushUpdate(const QString & path);
  
 private:
  QWidget *mainWindow;
  QProcess *catalystProcess;
  QProcess *updaterProcess; 
  QFileSystemWatcher* watcher; 
  
};
