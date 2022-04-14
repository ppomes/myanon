AC_INIT([myanon], [0.3], [pierre.pomes@gmail.com])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])
AC_CONFIG_SRCDIR([config.h.in])
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_CC
AC_PROG_YACC
AC_PROG_LEX(noyywrap)
AC_PROG_INSTALL
AM_PROG_AR
AC_PROG_RANLIB

# Checks flex/bison version
AC_PATH_PROG([FLEX],[flex])
AX_PROG_FLEX_VERSION([2.6.0],,AC_MSG_ERROR([GNU flex 2.6+ is required]))

AC_PATH_PROG([BISON],[bison])
AX_PROG_BISON_VERSION([3.0.0],,AC_MSG_ERROR([GNU bison v3+ is required]))

# Checks for header files.
AC_CHECK_HEADERS(stdio.h, ,[AC_MSG_ERROR([Cannot find stdio.h header])])
AC_CHECK_HEADERS(stddef.h, ,[AC_MSG_ERROR([Cannot find stddef.h header])])
AC_CHECK_HEADERS(stdlib.h, ,[AC_MSG_ERROR([Cannot find stdlib.h header])])
AC_CHECK_HEADERS(stdbool.h, ,[AC_MSG_ERROR([Cannot find stdbool.h header])])
AC_CHECK_HEADERS(stdint.h, ,[AC_MSG_ERROR([Cannot find stdint.h header])])
AC_CHECK_HEADERS(strings.h, ,[AC_MSG_ERROR([Cannot find string.h header])])
AC_CHECK_HEADERS(errno.h, ,[AC_MSG_ERROR([Cannot find errno.h header])])
AC_CHECK_HEADERS(getopt.h, ,[AC_MSG_ERROR([Cannot find getopt.h header])])
AC_CHECK_HEADERS(sys/time.h, ,[AC_MSG_ERROR([Cannot find sys/time.h header])])

AC_CONFIG_FILES([Makefile
                 hmac/Makefile
                 main/Makefile])
AC_OUTPUT
