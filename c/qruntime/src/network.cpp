/* Copyright 2009, 2010 Paperpile

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
