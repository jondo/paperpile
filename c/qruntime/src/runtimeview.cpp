#include <QWebView>
#include <QApplication>
#include <QDebug>
#include "runtimeview.h"

RuntimeView::RuntimeView(QWidget * parent) : QWebView(parent) {

  QWebView::QWebView();

};


void RuntimeView::contextMenuEvent ( QContextMenuEvent * ev ) {


  if (QCoreApplication::arguments().contains("--debug")){
    QWebView::contextMenuEvent(ev);
  }

}
