QT      +=  webkit network

HEADERS =   mainwindow.h runtime.h runtimeview.h runtimepage.h network.h
SOURCES =   main.cpp mainwindow.cpp runtime.cpp runtimeview.cpp runtimepage.cpp network.cpp
TARGET = paperpile
DESTDIR = ..

macx {
  QMAKE_POST_LINK = ../postlink.sh
}

