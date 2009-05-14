AC_INIT(src/yumpdf.cc)
AM_CONFIG_HEADER(config.h)

PACKAGE=yumpdf
VERSION=0.1

AM_INIT_AUTOMAKE($PACKAGE,$VERSION)

AC_PROG_CXX

AC_STDC_HEADERS
AC_PROG_INSTALL

PKG_CHECK_MODULES(DEPS, cairo)

AC_ARG_WITH([libs],
    [ --with-libs=<path> prefix of libraries (podofo, mxml, poppler)],
    [LOCAL_PREFIX=$with_libs],
    AC_MSG_ERROR("You have to specify the location of necessary libraries with --with-libs")       
)

AC_CHECK_FILE([${LOCAL_PREFIX}/lib/libmxml.a],,AC_MSG_ERROR("Static miniXML library not found."))
AC_CHECK_HEADERS([mxml.h],,AC_MSG_ERROR("miniXML headers not found."))

AC_CHECK_FILE([${LOCAL_PREFIX}/lib/libpodofo.a],,AC_MSG_ERROR("Static PoDoFo library not found."))
AC_CHECK_HEADER([podofo/podofoapi.h],,AC_MSG_ERROR("PoDoFo headers not found."))

AC_CHECK_FILE([${LOCAL_PREFIX}/lib/libpoppler.a],,AC_MSG_ERROR("Static Poppler library not found."))
AC_CHECK_HEADER([${LOCAL_PREFIX}/include/poppler/poppler-config.h],,AC_MSG_ERROR("Poppler headers not found."))

PODOFO_LIBS="${LOCAL_PREFIX}/lib/libpodofo.a -ljpeg"
PODOFO_CFLAGS="-I${LOCAL_PREFIX}/include/podofo"

POPPLER_LIBS="${LOCAL_PREFIX}/lib/libpoppler.a"
POPPLER_CFLAGS="-I${LOCAL_PREFIX}/include/poppler"

MXML_LIBS="${LOCAL_PREFIX}/lib/libmxml.a"
MXML_CFLAGS="-I${LOCAL_PREFIX}/include"

AC_SUBST(PODOFO_LIBS)
AC_SUBST(PODOFO_CFLAGS)

AC_SUBST(POPPLER_CFLAGS)
AC_SUBST(POPPLER_LIBS)

AC_SUBST(MXML_CFLAGS)
AC_SUBST(MXML_LIBS)

AC_SUBST(DEPS_CFLAGS)
AC_SUBST(DEPS_LIBS)

AC_OUTPUT([
Makefile 
src/Makefile 
])
