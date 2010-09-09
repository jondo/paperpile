class RuntimePage : public QWebPage {
 public: 
  RuntimePage(QObject * parent=0);
  void test(); 

 protected:
  void javaScriptConsoleMessage ( const QString & message, int lineNumber, const QString & sourceID ) const;

};
