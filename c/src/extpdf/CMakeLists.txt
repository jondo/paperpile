project(extpdf)

# This is the tree where the poppler library is installed
SET (LOCAL_TREE "${PROJECT_SOURCE_DIR}/../../../../local")

SET(QT_USE_QTXML TRUE)

set (SOURCES main.cpp extpdf.cpp pdf.cpp)

set (MOC_HEADERS pdf.h extpdf.h)
 
find_package( Qt4 REQUIRED )
include( ${QT_USE_FILE} )
add_definitions( ${QT_DEFINITIONS} )

QT4_WRAP_CPP( MOC_SRCS ${MOC_HEADERS} )

include_directories( ${LOCAL_TREE}/include )
link_directories (${LOCAL_TREE}/lib)

add_executable( extpdf ${SOURCES} ${MOC_SRCS} )

target_link_libraries( extpdf ${QT_LIBRARIES} ${LOCAL_TREE}/lib/libpoppler-qt4.a ${LOCAL_TREE}/lib/libpoppler.a )

if(CMAKE_BUILD_TYPE STREQUAL "Release")

  # Windows
  if(WIN32)
    set(GUI_TYPE WIN32)
    set(BIN_DIR "${PROJECT_BINARY_DIR}/../../../plack/bin/win32")
    add_custom_command(
      TARGET extpdf
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/extpdf.exe ${BIN_DIR}
      COMMENT "Copying extpdf.exe to ${BIN_DIR}")
  endif()

  # Linux
  if (UNIX AND NOT APPLE)
    execute_process(COMMAND uname -m OUTPUT_VARIABLE ARCH OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (ARCH STREQUAL "x86_64")
      set(BIN_DIR "${PROJECT_BINARY_DIR}/../../../plack/bin/linux64")
    else()
      set(BIN_DIR "${PROJECT_BINARY_DIR}/../../../plack/bin/linux32")
    endif()
    
    add_custom_command(
      TARGET extpdf
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/extpdf ${BIN_DIR}
      COMMENT "Copying extpdf to ${BIN_DIR}")
  endif()
endif()