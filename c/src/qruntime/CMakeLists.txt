project (paperpile)

## Our own sources
set(SOURCES
  main.cpp 
  mainwindow.cpp
  network.cpp
  runtime.cpp
  runtimepage.cpp
  runtimeview.cpp)
 
set(MOC_HEADERS
  mainwindow.h   
  network.h
  runtime.h
  runtimepage.h)

## Configure Qt stuff
SET(QT_USE_QTNETWORK TRUE)
SET(QT_USE_QTWEBKIT TRUE)

find_package(Qt4 REQUIRED)
include(${QT_USE_FILE} )
add_definitions(${QT_DEFINITIONS})

QT4_WRAP_CPP(MOC_SRCS ${MOC_HEADERS})


## External libraries to be linked statically
if (APPLE)
  set (LOCAL_TREE "/usr/local")
else()
  SET (LOCAL_TREE "${PROJECT_SOURCE_DIR}/../../../../local")
endif()
 
if (APPLE)
  set(EXTRA, 
  ${LOCAL_TREE}/lib/libpoppler-qt4.a 
  ${LOCAL_TREE}/lib/libpoppler.a
  ${LOCAL_TREE}/lib/libfreetype.a
  ${LOCAL_TREE}/lib/libfontconfig.a
  ${LOCAL_TREE}/lib/libjpeg.a
  ${LOCAL_TREE}/lib/libpng12.a)
else()
  if(WIN32)
    set(EXTRA, 
    ${LOCAL_TREE}/lib/libpoppler-qt4.dll.a 
    ${LOCAL_TREE}/lib/libpoppler.dll.a)
  else()
    set(EXTRA, 
    ${LOCAL_TREE}/lib/libpoppler-qt4.a 
    ${LOCAL_TREE}/lib/libpoppler.a)
  endif()
endif()

include_directories( ${LOCAL_TREE}/include )
link_directories (${LOCAL_TREE}/lib)

# Define target
add_executable(paperpile MACOSX_BUNDLE ${SOURCES} ${MOC_SRCS})

target_link_libraries( 
  paperpile ${QT_LIBRARIES} ${EXTRA}
  )


# Release mode installs binaries
if(CMAKE_BUILD_TYPE STREQUAL "Release")

  # Windows
  if(WIN32)
    set(GUI_TYPE WIN32) #Suppress console
    set(DIST_DIR "${PROJECT_BINARY_DIR}/../../../qt/win32")
    add_custom_command(
      TARGET paperpile
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/paperpile.exe ${DIST_DIR}
      COMMENT "Copying paperpile.exe to ${DIST_DIR}")
  endif()

  # Linux
  if (UNIX AND NOT APPLE)
    execute_process(COMMAND uname -m OUTPUT_VARIABLE ARCH OUTPUT_STRIP_TRAILING_WHITESPACE)
    if (ARCH STREQUAL "x86_64")
      set(DIST_DIR "${PROJECT_BINARY_DIR}/../../../qt/linux64")
    else()
      set(DIST_DIR "${PROJECT_BINARY_DIR}/../../../qt/linux32")
    endif()

    add_custom_command(
      TARGET paperpile
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/paperpile ${DIST_DIR}/bin
      COMMENT "Copying paperpile to ${DIST_DIR}/bin")
  endif()

  if (APPLE)
    set(DIST_DIR "${PROJECT_BINARY_DIR}/../../../qt/osx/Contents/MacOS")
    add_custom_command(
      TARGET paperpile
      POST_BUILD
      COMMAND macdeployqt ${PROJECT_BINARY_DIR}/paperpile.app
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/paperpile.app/Contents/MacOS/paperpile ${DIST_DIR}
      COMMENT "Running macdeployqt on paperpile.app and copying executable")
  endif()


endif()

