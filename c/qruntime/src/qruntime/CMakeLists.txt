project ( paperpile )

SET(QT_USE_QTNETWORK TRUE)
SET(QT_USE_QTWEBKIT TRUE)

set ( SOURCES
     main.cpp 
     mainwindow.cpp
     network.cpp
     runtime.cpp
     runtimepage.cpp
     runtimeview.cpp
)
 
set ( MOC_HEADERS
     mainwindow.h   
     network.h
     runtime.h
     runtimepage.h
)

 
find_package( Qt4 REQUIRED )
include( ${QT_USE_FILE} )
add_definitions( ${QT_DEFINITIONS} )

if (WIN32)
   include_directories( ${PROJECT_SOURCE_DIR}/../../../../../local/include/poppler/qt4 
                        ${CMAKE_BINARY_DIR} )
link_directories (${PROJECT_SOURCE_DIR}/../../../../../local/lib)  
endif(WIN32)


QT4_WRAP_CPP( MOC_SRCS ${MOC_HEADERS} )
 
#add_executable( paperpile WIN32 ${SOURCES} ${MOC_SRCS} )
add_executable( paperpile ${SOURCES} ${MOC_SRCS} )

target_link_libraries( paperpile ${QT_LIBRARIES} poppler-qt4 )
