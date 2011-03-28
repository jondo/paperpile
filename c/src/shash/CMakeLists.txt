project(shash)
add_definitions(-std=c99)
add_executable(shash lookup3.c  shash.c  simi.c  simiw.c)

if(CMAKE_BUILD_TYPE STREQUAL "Release")

  # Windows
  if(WIN32)
    set(GUI_TYPE WIN32)
    set(BIN_DIR "${PROJECT_BINARY_DIR}/../../../plack/bin/win32")
    add_custom_command(
      TARGET shash
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/shash.exe ${BIN_DIR}
      COMMENT "Copying shash.exe to ${BIN_DIR}")
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
      TARGET shash
      POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_BINARY_DIR}/shash ${BIN_DIR}
      COMMENT "Copying shash to ${BIN_DIR}")
  endif()
endif()