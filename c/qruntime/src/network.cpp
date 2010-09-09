#include <QNetworkRequest>
#include <QNetworkReply>
#include <QDebug>
#include "network.h"

RuntimeNetworkAccessManager::RuntimeNetworkAccessManager( QObject *parent ) :
    QNetworkAccessManager( parent ){
}

QNetworkReply *RuntimeNetworkAccessManager::createRequest( Operation op,
                                                             const QNetworkRequest &req,
                                                             QIODevice *outgoingData ){

  QString root("/Users/wash/play/paperpile/catalyst/root");

  QNetworkRequest myReq( req );

  //qDebug() << req.url();

  QUrl originalUrl = req.url();
  QString url = req.url().toString();

  if (url.contains("http://127.0.0.1")){
    //qDebug() << "passing through";
  } else {
    if (!url.contains(root)){
      url.replace("file://", "");
      url= root+url;
      //qDebug() << "Rewrite to " << url;
    }
  }
  
  myReq.setUrl( QUrl(url) );

  QNetworkReply *reply = QNetworkAccessManager::createRequest( op, myReq, outgoingData );

  return reply;
}
