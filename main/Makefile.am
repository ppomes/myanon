# Generated sources
BUILT_SOURCES = configparser.h dumpparser.h
CLEANFILES = configparser.h configparser.c configscanner.c dumpparser.h dumpparser.c dumpscanner.c

# Main target
bin_PROGRAMS = myanon

# Sources
myanon_SOURCES = configparser.y configscanner.l dumpparser.y dumpscanner.l myanon.c

# Flex/Bison flags
AM_YFLAGS = -d -Wno-yacc
AM_LFLAGS = -8

# include flags
myanon_CFLAGS = -I$(top_srcdir)/uthash -I$(top_srcdir)/hmac

# link with flex
myanon_LDADD = $(LIBLEX) $(top_builddir)/hmac/libhmac.a
