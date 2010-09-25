QT      +=  webkit network

HEADERS =   mainwindow.h runtime.h runtimeview.h runtimepage.h network.h
SOURCES =   main.cpp mainwindow.cpp runtime.cpp runtimeview.cpp runtimepage.cpp network.cpp
TARGET = paperpile



macx {
  DESTDIR = ..
  QMAKE_POST_LINK = ../postlink.sh
}

unix:!macx {
  DESTDIR = ../bin

  exists( ../bin ) {
    QMAKE_CLEAN += -r ../bin
  }

  QMAKE_CLEAN += ../catalyst
  
  QMAKE_POST_LINK = rm -f ../catalyst && ln -s `pwd`/../../../catalyst ../catalyst

}
