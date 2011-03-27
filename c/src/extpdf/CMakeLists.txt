project(extpdf)

SET(QT_USE_QTXML TRUE)

set (SOURCES
  main.cpp 
  extpdf.cpp
  pdf.cpp)

set (MOC_HEADERS
  pdf.h  
  extpdf.h)
 
find_package( Qt4 REQUIRED )
include( ${QT_USE_FILE} )
add_definitions( ${QT_DEFINITIONS} )

QT4_WRAP_CPP( MOC_SRCS ${MOC_HEADERS} )

if (WIN32)
  include_directories( ${PROJECT_SOURCE_DIR}/../../../../local/include
    ${CMAKE_BINARY_DIR} )
  link_directories (${PROJECT_SOURCE_DIR}/../../../../local/lib)  
endif(WIN32)

add_executable( extpdf ${SOURCES} ${MOC_SRCS} )

target_link_libraries( extpdf ${QT_LIBRARIES} poppler-qt4 poppler )

if(CMAKE_BUILD_TYPE STREQUAL "Release")
  if(WIN32)
    set(GUI_TYPE WIN32)
    set(DIST_DIR "${PROJECT_BINARY_DIR}/../../../catalyst/bin/win32")
    add_custom_command(
      TARGET extpdf
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/extpdf.exe ${DIST_DIR}
      COMMENT "Copying extpdf.exe to ${DIST_DIR}")
  endif()
endif()