#include <QWebPage>

class RuntimePage : public QWebPage {
 public: 
  RuntimePage(QObject * parent=0);

 protected:
  void javaScriptConsoleMessage ( const QString & message, int lineNumber, const QString & sourceID );

};
