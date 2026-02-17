# Generated sources
BUILT_SOURCES = configparser.h dumpparser.h jsonparser.h
MAINTAINERCLEANFILES = configparser.h configparser.c configscanner.c dumpparser.h dumpparser.c dumpscanner.c jsonparser.h jsonparser.c jsonscanner.c

# Main target
bin_PROGRAMS = myanon

# Man page
man_MANS = myanon.1

# Sources
myanon_SOURCES = configparser.y configscanner.l dumpparser.y dumpscanner.l jsonparser.y jsonscanner.l myanon.c

# Headers
noinst_HEADERS = myanon.h json.h

# Flex/Bison flags
AM_YFLAGS = -d -Wno-yacc
AM_LFLAGS = -8

# include flags and linking
if USE_OPENSSL
myanon_CFLAGS = -I$(top_srcdir)/uthash $(OPENSSL_CFLAGS) $(PYTHON_INCLUDE)
myanon_LDADD = $(LIBLEX) $(OPENSSL_LIBS) $(PYTHON_LIBS)
else
myanon_CFLAGS = -I$(top_srcdir)/uthash -I$(top_srcdir)/hmac $(PYTHON_INCLUDE)
myanon_LDADD = $(LIBLEX) $(top_builddir)/hmac/libhmac.a $(PYTHON_LIBS)
endif
