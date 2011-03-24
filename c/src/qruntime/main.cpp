/* Copyright 2009-2011 Paperpile

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

#include <QtGui>
#include <QApplication>
#include "mainwindow.h"
#include "network.h"
#include <QProcess>
#include <qwebview.h>

#include <poppler-qt4.h>

int main(int argc, char * argv[]){
  QApplication app(argc, argv);

  QCoreApplication::setOrganizationName("Paperpile");
  QCoreApplication::setApplicationName("Paperpile");
  
  MainWindow *browser = new MainWindow();
  browser->show();
  
  return app.exec();

}
