AC_INIT(src/extpdf.cc)
AM_CONFIG_HEADER(config.h)

PACKAGE=extpdf
VERSION=0.1

AM_INIT_AUTOMAKE($PACKAGE,$VERSION)

AC_PROG_CXX

AC_STDC_HEADERS
AC_PROG_INSTALL

PKG_CHECK_MODULES(DEPS, poppler-glib poppler mxml)

AC_ARG_WITH(podofo,
    [ --with-podofo=<path> prefix of podofo installation. e.g. /usr/local or /usr],
    [PODOFO_PREFIX=$with_podofo],
    AC_MSG_ERROR([You must call configure with the --with-podofo option.
    This tells configure where to find the podofo C library and headers.
    e.g. --with-podofo=/usr/local or --with-podofo=/usr])
)

PODOFO_LIBS="-L${PODOFO_PREFIX}/lib -lpodofo"
PODOFO_CFLAGS="-I${PODOFO_PREFIX}/include/podofo"

AC_SUBST(PODOFO_LIBS)
AC_SUBST(PODOFO_CFLAGS)

AC_SUBST(DEPS_CFLAGS)
AC_SUBST(DEPS_LIBS)

AC_OUTPUT([
Makefile 
src/Makefile 
])
