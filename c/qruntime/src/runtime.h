#include <QtGui>

class QProcess;

class Runtime : public QObject{
  Q_OBJECT

    public:
  Runtime(QWidget *window);

 public:
  Q_INVOKABLE QString getOpenFileName
    ( const QString & caption, 
      const QString & dir, 
      const QString & filter
     );

  Q_INVOKABLE void openFile( const QString & file);
  Q_INVOKABLE void openUrl( const QString & url);
  Q_INVOKABLE QString getClipboard();
  Q_INVOKABLE QString getPlatform();
  Q_INVOKABLE QString getCatalystDir();
  Q_INVOKABLE void setClipboard( const QString & text);
  Q_INVOKABLE void startCatalyst();

  
 signals:
  void catalystReady();
  void catalystRead(QString data);
  void catalystError(QProcess::ProcessError error);

  private slots:
  void readyReadCatalyst();
  void catalystStateChanged(QProcess::ProcessState newState);
  void emitCatalystError(QProcess::ProcessError error);
  

 private:
  QWidget *mainWindow;
  QProcess *catalystProcess;
  
};
