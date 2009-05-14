bin_PROGRAMS = yumpdf

yumpdf_SOURCES = yumpdf.cc viewer.cc annotation.cc annotation.h yumpdf.h viewer.h

yumpdf_LDADD = $(DEPS_LIBS) $(POPPLER_LIBS) $(PODOFO_LIBS) $(MXML_LIBS)

AM_CPPFLAGS = $(DEPS_CFLAGS) $(POPPLER_CFLAGS) $(PODOFO_CFLAGS) $(MXML_CFLAGS)
