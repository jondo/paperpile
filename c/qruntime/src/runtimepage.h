#include <QWebPage>
#include <QNetworkRequest>

class RuntimePage : public QWebPage {
 public: 
  RuntimePage(QObject * parent=0);

 protected:
  void javaScriptConsoleMessage ( const QString & message, int lineNumber, const QString & sourceID );
  bool acceptNavigationRequest ( QWebFrame * frame, const QNetworkRequest & request, NavigationType type );


};
