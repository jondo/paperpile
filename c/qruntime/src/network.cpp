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

  QString root = catalystDir+"/root";

  QNetworkRequest myReq( req );

  //qDebug() << req.url();

  QUrl originalUrl = req.url();
  QString url = req.url().toString();
  
  // http queries are handled normally
  if (url.contains("http://")){
    //qDebug() << "passing through";
  } else {
    // Add root directory to file queries if not already absolute
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
