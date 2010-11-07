#include <qwebview.h>

class QWebview;

class RuntimeView : public QWebView {
 
 public: RuntimeView(QWidget * parent=0);

 protected:
  void contextMenuEvent ( QContextMenuEvent * ev );

  //javaScriptConsoleMessage ( const QString & message, int lineNumber, const QString & sourceID ) const;

  void dragLeaveEvent(QDragLeaveEvent * event);

};
